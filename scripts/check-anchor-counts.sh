#!/usr/bin/env bash
# cepa anchor-count check — read-only. Enforces CLAUDE.md § "Anchors must not
# encode a count that can drift" over every tracked .md file. Run from the repo
# root. Never modifies anything.
#
# The rule is cited, not restated: read it in CLAUDE.md. The one-line form this
# script mechanizes: a heading that carries a count slugifies to an anchor that
# carries it too, so a link to it breaks SILENTLY the day the count changes —
# in-page anchors resolve in the reader's browser, and nothing in git, CI, or a
# renderer fails. This script is the thing that fails.
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
#   * Scope is `git ls-files '*.md'` minus todos/ and memory/. Those two are
#     dated records — generated review files and residual shards — that quote
#     defect shapes as evidence and are never navigation; gating them would
#     make a correct record of a bad heading fail CI. Their outbound links are
#     not checked either. docs/ is gitignored, so it is out of scope by
#     construction.
#   * Fenced blocks (``` and ~~~) and code spans are stripped before links are
#     read: CLAUDE.md quotes `[the full table](#commands-11)` in a code span,
#     and that is a record, not a link. Indented (4-space) code blocks are NOT
#     stripped, and setext headings (`===` / `---` underlines) are NOT indexed.
#     The corpus uses neither today; a setext heading would surface as a leg-2
#     MISS on any link to it, which is loud, not silent.
#   * The slug is an approximation of github-slugger: rendered text, lowercase,
#     drop everything but word characters, `-`, `_` and space, space → `-`,
#     duplicates suffixed -1, -2. Emoji, HTML entities and exotic Unicode
#     punctuation may slug differently on GitHub. A divergence shows up as a
#     leg-2 MISS on a link that works, which is the safe direction.
#   * Absolute URLs (`https://…#frag`, including github.com blob links into
#     this repo) are not resolved. Fragments on non-.md targets (`x.sh#L10`)
#     are line anchors, not headings, and are skipped.
#   * Fragments compare exactly (after %-decoding). GitHub's page script may
#     forgive a case mismatch; this script does not.
#
# Usage: bash scripts/check-anchor-counts.sh
# Exit: 0 when zero MISS. 1 on any MISS. WARN never fails.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

command -v python3 >/dev/null 2>&1 || { echo "MISS: python3 not found — check UNVERIFIED"; exit 1; }
files="$(git ls-files -- '*.md' 2>/dev/null)" || { echo "MISS: git ls-files failed — check UNVERIFIED"; exit 1; }

# Guards are marked `# GUARD:<name>` so the controls can remove each one and
# prove it is load-bearing. Keep each guard on ONE line with its marker.
read -r -d '' PYSRC <<'PY'
import os, re, sys
from collections import Counter
from urllib.parse import unquote

EXCLUDE = ("todos/", "memory/")
files = [f for f in sys.stdin.read().splitlines() if f and not f.startswith(EXCLUDE)]  # GUARD:exclude
tracked = set(files)

FENCE_RE = re.compile(r"^[ \t]*(`{3,}|~{3,})")
HEADING_RE = re.compile(r"^ {0,3}(#{1,6})[ \t]+(.*?)[ \t]*#*[ \t]*$")
CODESPAN_RE = re.compile(r"(`+)(?:(?!\n[ \t]*\n).)+?\1", re.S)
INLINE_LINK_RE = re.compile(r"\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
REF_DEF_RE = re.compile(r"^ {0,3}\[[^\]]+\]:\s*<?(\S+?)>?(?:\s|$)", re.M)
HTML_ANCHOR_RE = re.compile(r"<a\s[^>]*\b(?:id|name)=[\"']([^\"']+)[\"']", re.I)
COUNT_RE = re.compile(r"\(\s*\d+\s*\)")
DIGIT_TOKEN_RE = re.compile(r"(?:^|-)\d+(?:-|$)")

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
    return out

def rendered(text):
    text = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"<[^>]+>", "", text)
    text = text.replace("`", "")
    return re.sub(r"(?<!\w)_+|_+(?!\w)", "", text)

def slug_base(text):
    s = rendered(text).strip().lower()
    s = re.sub(r"[^\w\- ]", "", s)  # GUARD:punct
    return s.replace(" ", "-")

index = {}      # file -> set of valid fragments
headings = {}   # file -> [(lineno, rendered text, slug)]
bodies = {}     # file -> fence-stripped text

for f in files:
    try:
        with open(f, encoding="utf-8") as fh:
            lines = fh.read().split("\n")
    except OSError as e:
        say("MISS", f"{f}: unreadable ({e}) — check UNVERIFIED for this file")
        continue
    lines = strip_fences(lines)  # GUARD:fence
    seen, frags, hs = Counter(), set(), []
    for i, ln in enumerate(lines, 1):
        m = HEADING_RE.match(ln)
        if not m:
            continue
        base = slug_base(m.group(2))
        s = base
        if seen[base]:
            s = f"{base}-{seen[base]}"  # GUARD:dup
        seen[base] += 1
        frags.add(s)
        hs.append((i, rendered(m.group(2)).strip(), s))
    body = "\n".join(lines)
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
    body = CODESPAN_RE.sub("", body)  # GUARD:codespan
    targets = INLINE_LINK_RE.findall(body) + REF_DEF_RE.findall(body)
    for t in targets:
        if "#" not in t or re.match(r"^[a-z][a-z0-9+.-]*:", t, re.I):
            continue
        path, frag = t.split("#", 1)
        frag = unquote(frag)
        if path:  # GUARD:xfile
            if not path.endswith(".md"):
                continue
            if path.startswith("/"):
                dest = path.lstrip("/")
            else:
                dest = os.path.normpath(os.path.join(os.path.dirname(f), path))
            if dest.startswith(EXCLUDE):
                continue
        else:
            dest = f
        n_links += 1
        if frag not in index.get(dest, set()):  # GUARD:leg2
            if dest in tracked:
                say("MISS", f"{f}: link '{t}' — no heading in {dest} slugs to #{frag}")
            else:
                say("MISS", f"{f}: link '{t}' targets {dest}, which is not a tracked .md in scope — anchor UNRESOLVED")
            continue
        if DIGIT_TOKEN_RE.search(frag):  # GUARD:leg3
            say("WARN", f"{f}: link '{t}' resolves, but its anchor carries a number — confirm it is an ordinal or version, not a count or a duplicate-heading suffix")

print(f"INFO scanned {len(index)} file(s); {n_headings} heading(s) indexed; {n_links} anchor link(s) resolved against them")
print(f"-- {miss} MISS, {warn} WARN --")
sys.exit(1 if miss else 0)
PY

printf '%s\n' "$files" | python3 -c "$PYSRC"
