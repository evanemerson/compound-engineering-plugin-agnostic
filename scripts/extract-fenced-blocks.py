#!/usr/bin/env python3
"""Extract fenced ```bash blocks from a markdown command file.

This is the extraction half of residual 2g's checker (see
`memory/tasks.d/2026-09-26-forced-phi-scrub-verification.md`). 2g's rule:

    A fenced-block instruction file must never carry state across a block
    boundary in a shell variable. State crosses blocks only through the
    FILESYSTEM -- the same path, or an explicit re-read.

Five instances of that class have shipped on the brain-writeback surface
alone, and EVERY ONE was found by running the extracted block rather than by
reading the diff -- including instance 5, which was written by the session
implementing 2g's first enforcement with 2g's text in front of it. So this
exists to make "run the block" a one-command operation instead of an ad-hoc
python snippet retyped per investigation. It was retyped three times during
the 2026-10-02 verification before being committed, which is the whole reason
it is a file now.

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
# `$NAME`, `${NAME}`, `${NAME:-default}`, `${NAME%suffix}` ...
USE_RE = re.compile(r"\$\{?([A-Za-z_][A-Za-z0-9_]*)")

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
SOURCE_RE = re.compile(r"^[ \t]*(?:\.|source)\s+\S", re.M)


def names(body):
    assigned = set(ASSIGN_RE.findall(body)) | set(FOR_RE.findall(body))
    used = {n for n in USE_RE.findall(body) if not n.isdigit()}
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
