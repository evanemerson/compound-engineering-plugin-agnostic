#!/usr/bin/env bash
# cepa anchor-count check — read-only. Enforces CLAUDE.md § "Anchors must not
# encode a count that can drift" over tracked .md files (scope and exclusions
# under STATED LIMITS). Run from the repo root. Never modifies anything.
#
# The rule is cited, not restated: read it in CLAUDE.md. The one-line form this
# script mechanizes: a heading that carries a count slugifies to an anchor that
# carries it too, so a link to it breaks SILENTLY the day the count changes —
# anchors are resolved in the reader's browser, so nothing in git or a renderer
# fails. This script is the thing that fails.
#
#   Leg 0 (MISS): the scan read zero files or indexed zero headings. That is a
#     probe that never reached its target, not a clean tree — see CONCEPTS.md
#     `### Absence measurement`. It must not read as a pass.
#   Leg 1 (MISS): a heading whose rendered text holds a parenthesized bare
#     integer — `## Commands (11)`. That is the count convention this repo used
#     and #64 shipped. It fires whether or not any link in the repo points at
#     the heading: the rule says the link "is the half nobody re-reads", and
#     links from OUTSIDE the repo (a GitHub URL to a README section) are links
#     this script cannot see. Rewrite the heading without the number.
#   Leg 2 (MISS): a link `#frag` or `path.md#frag` whose fragment matches no
#     heading slug (and no `<a id|name="…">`) in its target file. This is the
#     failure the rule describes, measured directly: whatever drifted, the link
#     now points nowhere. A target .md that is not tracked is also a MISS — the
#     anchor cannot be resolved, which must not read as resolved.
#   Leg 3 (WARN): a link that DOES resolve, but whose fragment carries a bare
#     integer token — `#step-3`, `#django-52`, `#notes-1`. A checker cannot
#     tell a count from an ordinal or a version (the rule's own test is "would
#     the number have to be edited if the repo grew", which is a question about
#     meaning, not text). So it reports and never fails. `#notes-1` is worth
#     the WARN on its own: it is GitHub's duplicate-heading suffix, which shifts
#     when another `## Notes` is added above it.
#
# WHAT IS FLAGGED VS ONLY REPORTED, in one place. MISS: the `(N)` heading shape,
# and any anchor link that resolves to nothing. WARN: a digit in a resolving
# link's fragment. NOT SEEN AT ALL: an unlinked heading with a count in any
# shape other than `(N)` — `## 11 commands`, `## Agents (12 total)`. Leg 1
# stays narrow because a wider pattern (any digit in a heading) would fire on
# every `## Step 3` and `## Django 5.2`, which the rule calls stable; the moment
# such a heading is LINKED, leg 3 reports it.
#
# THE TWO SIBLING CLAIMS ARE NOT GATEABLE, and this script does not try. The
# rule names them: whether prose correctly characterizes a CI trigger is
# interpretation, not arithmetic; and whether a branch-protection claim still
# holds is mutable platform state that drifts with no commit, so no checker
# reading the tree can see it change. A green run here says nothing about
# either.
#
# STATED LIMITS — none of these can read as a pass:
#   * Scope is `git ls-files -z '*.md'` minus the TOP-LEVEL todos/ and memory/.
#     Those two are dated records — generated review files and residual
#     shards — that quote defect shapes as evidence and are never navigation;
#     gating them would make a correct record of a bad heading fail CI. Their
#     outbound links are not checked, and links INTO them are skipped too.
#     docs/ is gitignored, so it is never scanned; a tracked file's link INTO
#     docs/ is a leg-2 MISS, because the target is not a tracked .md.
#   * Fenced blocks (``` and ~~~) and code spans are stripped before links are
#     read: CLAUDE.md's anchors rule quotes `[the full table](#commands-11)` in
#     a code span, and that is a record, not a link. A fence still open at end
#     of file is a MISS, because everything after its opener went unscanned.
#     HTML comments are blanked too: a heading or `<a id>` inside one renders
#     nothing. Indented (4-space) code blocks are NOT stripped. Setext headings
#     (`===` / `---` underlines) are NOT indexed: a link to one is a leg-2 MISS
#     (loud), but an unlinked count in one is not seen (silent).
#   * The slug approximates github-slugger: rendered text (link text kept,
#     tags dropped, entities decoded, code-span text kept literally),
#     lowercase, drop everything but word characters, `-`, `_` and space,
#     space → `-`, duplicates suffixed -1, -2 with github-slugger's collision
#     rule. Emoji and exotic Unicode punctuation may still slug differently on
#     GitHub, and that divergence can go EITHER way: a working link reported
#     as a MISS, or a dead one passing. A green run does not prove an anchor
#     resolves on GitHub.
#   * Links are read in three forms: inline `[t](dest "title")` (any title
#     quoting, `<dest>` with spaces), reference definitions `[r]: dest`, and
#     `<a href>`. A bare destination may hold one level of balanced
#     parentheses; deeper nesting is cut at the first unbalanced `)`, which
#     reads as a MISS. A link to a directory resolves to its README.md, as
#     GitHub renders it; a directory with no tracked README.md is skipped.
#   * Absolute URLs (`https://…#frag`, `mailto:`), including github.com blob
#     links into this repo, are not resolved. Fragments on non-.md targets
#     (`x.sh#L10`) are line anchors, not headings, and are skipped. An empty
#     fragment (`#`) and `#top` scroll to the top in every browser, so they
#     pass unless the target defines them.
#   * Fragments compare exactly (after %-decoding). GitHub's page script may
#     forgive a case mismatch; this script does not.
#
# Usage: bash scripts/check-anchor-counts.sh
# Exit: 0 when zero MISS. 1 on any MISS. WARN never fails.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

command -v python3 >/dev/null 2>&1 || { echo "MISS: python3 not found — check UNVERIFIED"; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "MISS: not a git work tree — check UNVERIFIED"; exit 1; }

# Guards are marked `# GUARD:<name>` so the controls can remove each one and
# prove it is load-bearing. Keep each guard on ONE line with its marker.
read -r -d '' PYSRC <<'PY'
import html, os, re, sys
from urllib.parse import unquote

EXCLUDE = ("todos/", "memory/")
raw = sys.stdin.buffer.read().decode("utf-8", "surrogateescape").split("\0")
files = [f for f in raw if f and not f.startswith(EXCLUDE)]  # GUARD:exclude
tracked = set(files)

# A backtick fence's info string may not contain a backtick (CommonMark), so a
# line opening with ```x``` is a code span, not a fence.
FENCE_RE = re.compile(r"^[ \t]*(`{3,}(?=[^`]*$)|~{3,})")  # GUARD:infostring
HEADING_RE = re.compile(r"^(?: {0,3}> ?)*(?: {0,3}(?:[-*+]|\d+[.)]) +)?( {0,3})(#{1,6})[ \t]+(.*?)(?:[ \t]+#+)?[ \t]*$")  # GUARD:blockquote
CODESPAN_RE = re.compile(r"(?<![\\`])(`+)(?!`)(?:(?!\n[ \t]*\n).)+?(?<!`)\1(?!`)", re.S)
INLINE_LINK_RE = re.compile(r"\]\(\s*(?:<([^<>\n]+)>|((?:[^()\s<>]|\([^()\s]*\))+))(?:\s+(?:\"[^\"]*\"|'[^']*'|\([^)]*\)))?\s*\)")  # GUARD:linkre
REF_DEF_RE = re.compile(r"^ {0,3}\[(?!\^)[^\]]+\]:\s*<?(\S+?)>?(?:\s|$)", re.M)
HREF_RE = re.compile(r"<a\s(?:[^>]*\s)?href=[\"']([^\"']+)[\"']", re.I)
HTML_ANCHOR_RE = re.compile(r"<a\s(?:[^>]*\s)?(?:id|name)=[\"']([^\"']+)[\"']", re.I)  # GUARD:anchorattr
COUNT_RE = re.compile(r"\(\s*\d+\s*\)")
DIGIT_TOKEN_RE = re.compile(r"(?:^|-)\d+(?:-|$)")
COMMENT_RE = re.compile(r"<!--.*?-->", re.S)
SCHEME_RE = re.compile(r"^[a-z][a-z0-9+.-]*:", re.I)

miss = 0
warn = 0

def say(kind, msg):
    global miss, warn
    print(f"{kind}: {msg}")
    if kind == "MISS":
        miss += 1
    else:
        warn += 1

def strip_fences(lines):
    out, fence = [], None
    for ln in lines:
        m = FENCE_RE.match(ln)
        if fence is None:
            if m:
                fence = m.group(1)
                out.append("")
                continue
            out.append(ln)
        else:
            if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= len(fence) and ln.strip() == m.group(1):
                fence = None
            out.append("")
    return out, fence

def rendered(text):
    # re.split with two groups yields [prose, ticks, code, prose, ticks, code, …].
    parts = re.split(r"(`+)(.+?)\1", text)
    out = []
    for i, p in enumerate(parts):
        if i % 3 == 1:
            continue
        if i % 3 == 2:
            out.append(p)  # GUARD:codekeep
            continue
        p = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", p)
        p = re.sub(r"<[^>]+>", "", p)
        p = html.unescape(p)  # GUARD:entity
        out.append(re.sub(r"(?<!\w)_+|_+(?!\w)", "", p))
    return "".join(out)

def slug_base(text):
    s = rendered(text).strip().lower()
    s = re.sub(r"[^\w\- ]", "", s)  # GUARD:punct
    return s.replace(" ", "-")

index = {}      # file -> set of valid fragments
headings = {}   # file -> [(lineno, rendered text, slug)]
bodies = {}     # file -> fence- and code-span-stripped text

for f in files:
    try:
        with open(f, encoding="utf-8") as fh:
            lines = fh.read().split("\n")
    except (OSError, UnicodeDecodeError) as e:
        say("MISS", f"{f}: unreadable ({e}) — check UNVERIFIED for this file")
        continue
    lines, open_fence = strip_fences(lines)  # GUARD:fence
    # An HTML comment renders nothing, so a heading or <a id> inside one is no
    # link target. Blank it but keep its newlines, so line numbers stay true.
    lines = COMMENT_RE.sub(lambda m: "\n" * m.group(0).count("\n"), "\n".join(lines)).split("\n")  # GUARD:comments
    if open_fence is not None:  # GUARD:unterminated
        say("MISS", f"{f}: a {open_fence} fence is never closed — everything after it went unscanned")
    occ, frags, hs = {}, set(), []
    for i, ln in enumerate(lines, 1):
        m = HEADING_RE.match(ln)
        if not m:
            continue
        base = slug_base(m.group(3))
        s = base
        if s in occ:  # GUARD:dup
            while True:
                occ[base] += 1
                s = f"{base}-{occ[base]}"
                if s not in occ:
                    break
        occ[s] = 0
        frags.add(s)
        hs.append((i, rendered(m.group(3)).strip(), s))
    body = "\n".join(lines)
    body = CODESPAN_RE.sub("", body)  # GUARD:codespan
    for a in HTML_ANCHOR_RE.findall(body):
        frags.add(a)  # GUARD:htmlanchor
    index[f], headings[f], bodies[f] = frags, hs, body

n_headings = sum(len(v) for v in headings.values())
if not index or n_headings == 0:  # GUARD:leg0
    say("MISS", f"scanned {len(index)} file(s), indexed {n_headings} heading(s) — a probe that read nothing is not a clean tree")

# Leg 1 — a heading that carries a parenthesized count.
for f, hs in headings.items():
    for lineno, text, s in hs:
        if COUNT_RE.search(text):  # GUARD:leg1
            say("MISS", f"{f}:{lineno}: heading '{text}' carries a count, so its anchor #{s} breaks when the count changes — drop the number from the heading")

# Legs 2-3 — every anchor link.
n_links = 0
for f, body in bodies.items():
    targets = [a or b for a, b in INLINE_LINK_RE.findall(body)]
    targets += REF_DEF_RE.findall(body)  # GUARD:refdef
    targets += HREF_RE.findall(body)  # GUARD:href
    for t in targets:
        if "#" not in t:
            continue
        if SCHEME_RE.match(t): continue  # GUARD:scheme
        path, frag = t.split("#", 1)
        frag = unquote(frag)  # GUARD:unquote
        if path:  # GUARD:xfile
            path = unquote(path)  # GUARD:pathunquote
            if path.startswith("/"):
                dest = path.lstrip("/")  # GUARD:rooted
            else:
                dest = os.path.normpath(os.path.join(os.path.dirname(f), path))  # GUARD:relative
            if not dest.endswith(".md"):
                # GitHub serves a directory link as its README.md.
                dest = os.path.join(dest, "README.md")  # GUARD:dirreadme
                if dest not in tracked: continue  # GUARD:nonmd
            if dest.startswith(EXCLUDE): continue  # GUARD:exclinks
        else:
            dest = f
        valid = index.get(dest, set())
        if (not frag or frag == "top") and frag not in valid: continue  # GUARD:top
        n_links += 1
        if frag not in valid:  # GUARD:leg2
            if dest in tracked:
                say("MISS", f"{f}: link '{t}' — no heading in {dest} slugs to #{frag}")
            else:
                say("MISS", f"{f}: link '{t}' targets {dest}, which is not a tracked .md in scope — anchor UNRESOLVED")
            continue
        if DIGIT_TOKEN_RE.search(frag):  # GUARD:leg3
            say("WARN", f"{f}: link '{t}' resolves, but its anchor carries a number — confirm it is an ordinal or version, not a count or a duplicate-heading suffix")

print(f"INFO scanned {len(index)} file(s); {n_headings} heading(s) indexed; {n_links} anchor link(s) checked against them")
print(f"-- {miss} MISS, {warn} WARN --")
sys.exit(1 if miss else 0)
PY

# -z plus quotepath=false: a non-ASCII or quote-bearing name arrives verbatim,
# not as a C-quoted string that open() cannot find.
git -c core.quotepath=false ls-files -z -- '*.md' | python3 -c "$PYSRC"
st=("${PIPESTATUS[@]}")
[ "${st[0]}" = 0 ] || { echo "MISS: git ls-files failed (rc=${st[0]}) — check UNVERIFIED"; exit 1; }
exit "${st[1]}"
