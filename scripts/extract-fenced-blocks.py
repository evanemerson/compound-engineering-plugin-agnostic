#!/usr/bin/env python3
"""Extract fenced ```bash blocks from a markdown command file.

This is the extraction half of residual 2g's checker. 2g's rule, its shipped
instances, and the reviewable form are owned by
`memory/tasks.d/2026-09-26-forced-phi-scrub-verification.md` -- read it there.
This docstring deliberately does NOT restate the rule: it previously carried a
copy plus its own instance count, and the count went stale (it said "five"
after the sixth instance was recorded in the shard) while the restated rule sat
beside a pointer to the file that owns it. That is the two classes this repo
has a rule for each of -- count drift, and cross-cutting policy restated at a
second site -- in one paragraph.

What matters here and is NOT in the shard: EVERY instance was found by RUNNING
the extracted block, never by reading the diff. This script exists to make
"run the block" one command instead of an ad-hoc python snippet retyped per
investigation -- it was retyped three times during the 2026-10-02 verification
before being committed, which is why it is a file.

Two modes:

  --emit <dir>    write each block to <dir>/b<N>.sh, dedented to its fence
                  indentation. Run them under `bash -e`, in SEPARATE
                  processes, to reproduce the real execution model.

  --report        (default) per block, list variables ASSIGNED in it and
                  variables USED but not assigned in it. A name in the
                  second list that is not an environment variable or a
                  documented literal is a 2g candidate.

The report is deliberately a CANDIDATE list, not a verdict. It cannot know
which names the harness exports (`CLAUDE_PLUGIN_ROOT` is the canonical
example -- it is NOT exported into the Bash tool's shell, which is instance 1
of the class) nor which are intentional literals. Deciding that is the small
allowlist 2g describes. A tool that guessed would produce false confidence in
exactly the place this repo has been burned for it.

THE GATE HALF IS `scripts/check-fenced-block-state.sh`, which runs --report
across every command file, applies 2g's allowlist, and FAILS on what is left.
This script stays candidate-only; the judgment lives there.

Usage:
    python3 scripts/extract-fenced-blocks.py <file.md> [--report]
    python3 scripts/extract-fenced-blocks.py <file.md> --emit /tmp/blocks
"""

import argparse
import pathlib
import re
import sys

# Dedent to the FENCE's indentation, not to the minimum indentation of the
# body. A heredoc terminator must sit at column 0 of the emitted script, and
# inside a markdown list the fence itself is indented -- so the fence's indent
# is the only correct amount to strip. Stripping the body minimum would leave
# a terminator indented and silently swallow every following line as heredoc
# body, which this repo has recorded as "a silent killer" in compound.md.
FENCE_RE = re.compile(r"^([ \t]*)```(\w*)\s*$")

# `NAME=`, `export NAME=`, `local NAME=`, and `for NAME in`. Deliberately
# simple: this feeds a human-read candidate list, so a missed exotic form
# costs a second look, while a clever regex that silently mis-parses costs a
# wrong all-clear.
#
# re.M IS LOAD-BEARING, and its absence is the first thing this file got
# wrong. Without it `^` anchors to the start of the whole BLOCK, not of each
# line, so only an assignment on the block's very first column-0 line is ever
# seen -- every indented assignment and every assignment after line 1 is
# missed. Measured 2026-10-02: the deliberately-broken and the fixed shapes of
# compound.md's step-4 block produced IDENTICAL reports, because the fixed
# block's `CEPA_ROOT=` was invisible. A checker for 2g that cannot see a
# re-assignment reports the fix and the defect the same way, which is worse
# than no checker. `[ \t]*` covers the indented case explicitly rather than
# relying on the alternation.
ASSIGN_RE = re.compile(
    r"""(?:^[ \t]*|;[ \t]*|\|[ \t]*|&[ \t]*|\b(?:export|local|readonly|declare)\s+)
        ([A-Za-z_][A-Za-z0-9_]*)=                             # NAME=
     """,
    re.X | re.M,
)
FOR_RE = re.compile(r"\bfor\s+([A-Za-z_][A-Za-z0-9_]*)\s+in\b")
# `read NAME`, `read -r NAME`, `read -r a b c` -- a read loop ASSIGNS its
# variables, and missing that reports them as cross-block candidates. Measured
# 2026-10-03: compound.md's promote loop (`while read -r id || [ -n "$id" ]`)
# surfaced `id` as a used-not-assigned name, which is a parser gap, not a 2g
# finding. Allowlisting it in the gate would have papered the gap into a
# permanent suppression and made the next loop variable an unexamined pass, so
# it is fixed here instead. Flags are skipped; everything after them is a name.
#
# `read` MUST be anchored to a COMMAND POSITION, and a bare `\bread\b` is the
# second thing this file got wrong. Measured 2026-10-03: `\bread\b` matched the
# prose comment "Re-read the payload path from the pointer rather than retyping
# it" and harvested `from`, `it`, `rather`, `than`, `the`, `there`, `retyping`,
# `path`, `payload` and `pointer` as ASSIGNED variables. That is strictly worse
# than the missing-`read` gap it was fixing: a bogus name in `assigned`
# SUPPRESSES a real candidate of the same name, so the over-report is a
# wrong-all-clear in exactly the class this script exists to find -- the same
# shape as the re.M defect above. Command position means start-of-line, or
# after `|`, `;`, `&&`, `||`, `(`, or `while`/`until`/`do`/`then`/`else`.
# `while`/`until` are load-bearing: `while read -r id` is THE shape that
# motivated this regex (compound.md's promote loop), and a command-position
# list that omits them re-introduces the very gap being closed -- measured,
# `id` returned as a candidate until they were added.
READ_RE = re.compile(
    r"""(?:^[ \t]*|[|;&(][ \t]*|\b(?:while|until|do|then|else)[ \t]+)
        read[ \t]+((?:-[A-Za-z]+[ \t]+)*)        # flags, no-arg forms only
        ((?:[A-Za-z_][A-Za-z0-9_]*[ \t]*)+)      # one or more NAMEs
     """,
    re.X | re.M,
)


def read_names(body):
    """Variable names assigned by `read` / `read -r` lines in `body`.

    Deliberately conservative, matching ASSIGN_RE's stance: a flag that takes
    an argument (`read -d ''`, `read -n 1`) is not modelled, so such a line
    contributes nothing rather than guessing that the argument is a name. An
    under-report costs a second look at a candidate list; an over-report
    silently marks a name as assigned when it is not, which is the wrong-
    all-clear this whole script exists to avoid.
    """
    out = set()
    for _flags, rest in READ_RE.findall(body):
        out.update(rest.split())
    return out


# `$NAME`, `${NAME}`, `${NAME:-default}`, `${NAME%suffix}` ...
USE_RE = re.compile(r"\$\{?([A-Za-z_][A-Za-z0-9_]*)")

# A FULL-LINE comment is not a use. Measured 2026-10-03: setup.md's block 1
# carries the comment "do NOT resolve it through $CEPA_ROOT" and nothing else
# mentioning the name, so the gate reported a 2g violation in a block whose
# prose says the opposite. Stripping these is a false-positive fix, and a false
# positive on a prose comment is the shape that gets a gate switched off.
#
# ONLY full-line comments, and only for the USES scan. A trailing `# ...` can
# follow real code on the same line, and cutting at the first `#` would also
# cut `${X#prefix}`, a `#`-containing string, or a `$#` -- turning a
# false-positive fix into an under-report, which is the wrong-all-clear
# direction. Assignments are deliberately NOT filtered: an assignment seen
# inside a comment adds a name to `assigned`, which SUPPRESSES candidates, so
# the conservative choice there is the opposite one.
COMMENT_LINE_RE = re.compile(r"^[ \t]*#.*$", re.M)

# Shell builtins and positional/special parameters are never 2g candidates.
SHELL_BUILTIN = {
    "IFS", "PATH", "HOME", "PWD", "OLDPWD", "SHELL", "USER", "LOGNAME",
    "HOSTNAME", "TERM", "LANG", "LC_ALL", "TMPDIR", "RANDOM", "SECONDS",
    "LINENO", "FUNCNAME", "BASH_SOURCE", "BASHPID", "PPID", "UID", "EUID",
    "PIPESTATUS", "REPLY", "OPTARG", "OPTIND",
}


def extract(path):
    """Return [(lang, indent, body)] for every fenced block in `path`."""
    blocks = []
    current = None
    for line in path.read_text().splitlines(keepends=True):
        m = FENCE_RE.match(line)
        if m and current is None:
            current = {"lang": m.group(2), "indent": m.group(1), "lines": []}
            continue
        if current is not None and re.match(r"^[ \t]*```\s*$", line):
            blocks.append(current)
            current = None
            continue
        if current is not None:
            current["lines"].append(line)
    # An unterminated fence is a malformed source file, not an empty result --
    # say so rather than silently returning the blocks that happened to close.
    if current is not None:
        sys.exit(f"FATAL: unterminated fence in {path} (opened, never closed)")
    for b in blocks:
        ind = b["indent"]
        b["body"] = "".join(
            ln[len(ind):] if ln.startswith(ind) else ln for ln in b["lines"]
        )
    return blocks


# A sourced script sets variables this parser cannot see -- `resolve-plugin-root.sh`
# sets $CEPA_ROOT that way, which is the canonical case in this repo. Sourcing
# is therefore reported SEPARATELY rather than folded into `assigned`: claiming
# a name is assigned when only a `.` line is visible would launder the one
# thing a reader has to check by hand.
# COMMAND POSITION, not line start, and the difference is not academic: this
# repo's actual resolve idiom is `[ -f "$R" ] && . "$R" && break`, where the
# `.` sits after `&&`. A `^[ \t]*\.`-anchored probe reports "sources nothing"
# for every one of those blocks -- measured 2026-10-03: 6 of the 7 blocks the
# gate flagged were this false positive, in compound.md, compound-refresh.md
# and setup.md. An absence claim is a fact about the probe (CLAUDE.md), and a
# probe aimed at the wrong shape converts "unknown" into a confident wrong
# answer in whichever direction the consumer happens to need.
SOURCE_RE = re.compile(
    r"(?:^[ \t]*|[|;&(][ \t]*|\b(?:then|else|do)[ \t]+)(?:\.|source)[ \t]+\S",
    re.M,
)


# A HEREDOC BODY IS DATA, NOT CODE, and an assignment-shaped line inside one
# is the worst kind of false signal this parser can emit. Measured 2026-10-03:
# a block writing an operator runbook --
#
#     cat > /tmp/runbook.md <<'EOF'
#     To reproduce by hand:
#     P=/tmp/payload.json
#     EOF
#     bash client writeback "$P"
#
# -- reported `assigned: P` from the heredoc TEXT, so `$P` stopped being a
# candidate, leg 1 saw nothing, and the gate passed a block where `$P` is
# genuinely unset. On compound.md's writeback path that is the v1.26.8 shape:
# writeback falls back to the unscrubbed original, i.e. a PHI leak. `task.md`
# block 9 already contains a heredoc, so this is latent rather than theoretical.
#
# Masking (blanking the body lines) can only make `assigned` SMALLER, which is
# the direction this file argues for everywhere else: an under-report costs a
# second look at a candidate, while a phantom assignment SUPPRESSES every real
# candidate of that name. Deliberately conservative about what it treats as a
# terminator -- an unterminated heredoc masks to end of block, since the shell
# would also swallow the rest.
HEREDOC_START_RE = re.compile(r"<<-?\s*([\"']?)([A-Za-z_][A-Za-z0-9_]*)\1")


def mask_heredocs(body):
    """Blank out heredoc BODY lines, keeping line numbering intact."""
    out, pending = [], None
    for line in body.splitlines():
        if pending is None:
            out.append(line)
            m = HEREDOC_START_RE.search(line)
            if m:
                pending = m.group(2)
            continue
        # `<<-` permits a tab-indented terminator; plain `<<` does not, but
        # accepting leading whitespace either way only ENDS masking sooner,
        # which is the conservative direction.
        if line.strip() == pending:
            out.append(line)
            pending = None
        else:
            out.append("")
    return "\n".join(out)


def names(body):
    code = mask_heredocs(body)
    assigned = (
        set(ASSIGN_RE.findall(code))
        | set(FOR_RE.findall(code))
        | read_names(code)
    )
    # THREE DIFFERENT VIEWS OF THE BLOCK, and every asymmetry points the same
    # way: shrink `assigned`, never shrink `used`.
    #   assigned -> heredoc-masked, comments NOT stripped (see COMMENT_LINE_RE:
    #               ASSIGN_RE's anchor already excludes `#NAME=`).
    #   used     -> raw body minus FULL-LINE comments. NOT heredoc-masked: a
    #               `$NAME` inside a heredoc really is expanded by the shell
    #               unless the delimiter is quoted, and masking it would HIDE a
    #               real use — the wrong-all-clear direction.
    #   sources  -> raw body, so a `.` line is never missed.
    used = {
        n for n in USE_RE.findall(COMMENT_LINE_RE.sub("", body))
        if not n.isdigit()
    }
    sources = bool(SOURCE_RE.search(body))
    return assigned, used - SHELL_BUILTIN, sources


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("file")
    ap.add_argument("--lang", default="bash", help="fence language (default: bash)")
    ap.add_argument("--emit", metavar="DIR", help="write blocks to DIR/b<N>.sh")
    ap.add_argument("--report", action="store_true", help="assigned-vs-used report")
    args = ap.parse_args()

    path = pathlib.Path(args.file)
    if not path.is_file():
        sys.exit(f"FATAL: not a file: {path}")

    blocks = [b for b in extract(path) if b["lang"] == args.lang]
    if not blocks:
        # Zero blocks is a fact about the probe (CLAUDE.md), so name the
        # filter that produced it rather than reporting a bare "none".
        print(f"no ```{args.lang} blocks in {path}")
        return 0

    if args.emit:
        out = pathlib.Path(args.emit)
        out.mkdir(parents=True, exist_ok=True)
        for i, b in enumerate(blocks):
            dest = out / f"b{i}.sh"
            dest.write_text(b["body"])
            print(f"{dest}  ({len(b['lines'])} lines)")
        print(
            f"\n{len(blocks)} block(s). Run each under `bash -e` in a SEPARATE\n"
            "process -- a single shell would share state the real execution\n"
            "model does not, which is the defect class this exists to find."
        )
        return 0

    # Names assigned in an EARLIER block are the actual 2g signal: that block
    # was a different process, so the name is unset here. Separate them from
    # names never assigned anywhere (environment variables and literals), which
    # are a different question and mostly benign.
    seen_earlier = set()
    for i, b in enumerate(blocks):
        assigned, used, sources = names(b["body"])
        external = sorted(used - assigned)
        stale = sorted(n for n in external if n in seen_earlier)
        print(f"block {i}: {len(b['lines'])} lines")
        print(f"  assigned: {', '.join(sorted(assigned)) or '(none)'}")
        print(f"  used-not-assigned: {', '.join(external) or '(none)'}")
        if sources:
            print(
                "  sources a script: names it sets are NOT visible to this\n"
                "    parser -- check them by hand (resolve-plugin-root.sh sets"
                " $CEPA_ROOT)"
            )
        if stale:
            print(f"  >> 2g DEFECT CANDIDATES: {', '.join(stale)}")
            print(
                "     Assigned in an earlier block, used here, re-assigned\n"
                "     NOWHERE in this one. That earlier block was a different\n"
                "     process, so each of these is unset at this point. Either\n"
                "     re-resolve it in this block or pass it through a file."
            )
        seen_earlier |= assigned
    print(
        "\nCANDIDATES, not verdicts. A name can be legitimately external (an\n"
        "exported env var, or a literal the prose tells the agent to\n"
        "substitute). Deciding that is the allowlist residual 2g describes."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
