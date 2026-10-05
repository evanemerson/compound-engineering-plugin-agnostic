#!/usr/bin/env bash
# Control for the batch-sibling match: the anchored pattern that decides which
# open PR is a sibling of a `batch:<id>` fan-out. The pattern's home is the
# "Recognizing a sibling" block of section 2b in
# plugins/cepa/skills/autonomy/SKILL.md, and this script READS it from there —
# it never carries its own copy, or an edit to the shipped pattern would leave
# this control green while it checked something nobody runs.
#
# What it asserts, in order:
#   1. COPIES — the pattern's distinctive head `^[a-z]+/` occurs exactly once
#      under plugins/, inside a jq `test("...")` call, in the autonomy skill.
#      A second copy (a command restating the query) is a MISS: that is how the
#      five copies this pattern once had came to need five edits.
#   2. FIXTURES — the extracted pattern, with a fixture id substituted, matches
#      every sibling shape and rejects every non-sibling shape below.
#   3. MUTANTS — each mutant is built FROM the extracted pattern by a single
#      substitution, and must fail at least one fixture. A mutant whose anchor
#      text is gone is a MISS, never a skip: it means the pattern changed shape
#      and these fixtures need re-reading. A mutant no fixture kills means a
#      fixture the pattern needs is missing.
#
# Why each mutant matters:
#   substring    — `<id>-` alone. The reason the pattern is anchored at all:
#                  it catches `feat/refactor-<id>-cleanup` and, for a short id,
#                  most of the repo's branches.
#   no-caret     — drops `^`, so any later `x/` can start the match.
#   no-wt-group  — drops the optional worktree segment: the pre-worktree
#                  pattern, blind to `<type>/<wt>/<id>-<desc>`.
#   loose-wt     — lets the worktree group span several segments.
#   no-tail      — drops the trailing `[^/]*$`. A worktree NAMED `<id>-x` then
#                  makes `feat/<id>-x/cleanup` a false sibling.
#   loose-prefix — `[^/]+` for `[a-z]+`, admitting an upper-case prefix.
#
# STATED LIMITS — a green run does not mean:
#   - gh's own engine agrees. `gh --jq` runs gojq (Go RE2); this runs Python
#     `re`, offline. The pattern uses only anchors, a character class, an
#     optional group and a negated class — constructs both engines treat alike.
#     The equivalence was spot-checked once through `gh api ... --jq` on
#     2026-10-05; nothing re-checks it.
#   - one id cannot shadow another. Ids may contain `-`, so id `jul26a` matches
#     a branch for id `jul26a-b`. The pre-worktree pattern had the same
#     property; the id grammar, not this pattern, would have to change.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

python3 - <<'PY'
import os, re, sys

HOME = "plugins/cepa/skills/autonomy/SKILL.md"
ID = "jul26a"
passed = failed = 0

def ok(msg):
    global passed; passed += 1; print("PASS", msg)

def miss(msg):
    global failed; failed += 1; print("FAIL", msg)

def finish():
    print("-- %d/%d checks passed --" % (passed, passed + failed))
    sys.exit(1 if failed else 0)

# 1. COPIES
head = "^[a-z]+/"
hits = []
for root, _, files in os.walk("plugins"):
    for name in files:
        path = os.path.join(root, name)
        try:
            text = open(path, encoding="utf-8").read()
        except (UnicodeDecodeError, OSError):
            continue
        for n, line in enumerate(text.splitlines(), 1):
            if head in line:
                hits.append((path, n, line))
if len(hits) != 1:
    miss("expected exactly one occurrence of %r under plugins/, found %d: %s"
         % (head, len(hits), ", ".join("%s:%d" % (p, n) for p, n, _ in hits) or "none"))
    finish()
path, n, line = hits[0]
m = re.search(r'test\("([^"]+)"\)', line)
if path != HOME or not m:
    miss("the one occurrence is not a jq test(...) call in %s: %s:%d" % (HOME, path, n))
    finish()
template = m.group(1)
if template.count("<id>") != 1:
    miss("pattern must contain <id> exactly once: %r" % template)
    finish()
ok("one copy of the sibling pattern, at %s:%d" % (path, n))

# 2. FIXTURES — (branch, is a sibling)
CASES = [
    ("feat/jul26a-transcript-upload", True),        # main-checkout form
    ("feat/roles/jul26a-transcript-upload", True),  # worktree form
    ("feat/jul26a-x/jul26a-cleanup", True),         # worktree named after the id, real sibling
    ("feat/refactor-jul26a-cleanup", False),        # substring in the description
    ("feat/roles/refactor-jul26a-cleanup", False),  # substring, worktree form
    ("feat/jul26a-x/cleanup", False),               # worktree named <id>-x, unrelated work
    ("feat/a/b/jul26a-x", False),                   # one segment too many
    ("jul26a-foo", False),                          # no type prefix
    ("feat/jul26ab-x", False),                      # id is a prefix of a longer word
    ("Feat/jul26a-x", False),                       # upper-case prefix
]

def failures(pattern):
    rx = re.compile(pattern)
    return [b for b, want in CASES if bool(rx.search(b)) != want]

live = template.replace("<id>", ID)
bad = failures(live)
if bad:
    miss("the shipped pattern %r misclassifies: %s" % (live, ", ".join(bad)))
else:
    ok("the shipped pattern classifies all %d fixtures" % len(CASES))

# 3. MUTANTS — (name, old, new); "substring" replaces the whole pattern.
MUTANTS = [
    ("no-caret", "^[a-z]", "[a-z]"),
    ("no-wt-group", "([^/]+/)?", ""),
    ("loose-wt", "([^/]+/)?", "(.*/)?"),
    ("no-tail", "<id>-[^/]*$", "<id>-"),
    ("loose-prefix", "^[a-z]+/", "^[^/]+/"),
]
for name, old, new in MUTANTS:
    if template.count(old) != 1:
        miss("mutant %s: anchor %r occurs %d times in %r — re-read these fixtures"
             % (name, old, template.count(old), template))
        continue
    mutant = template.replace(old, new).replace("<id>", ID)
    if failures(mutant):
        ok("mutant %s is killed" % name)
    else:
        miss("mutant %s survives every fixture: %r" % (name, mutant))
if failures(ID + "-"):
    ok("mutant substring is killed")
else:
    miss("mutant substring survives every fixture")

finish()
PY
