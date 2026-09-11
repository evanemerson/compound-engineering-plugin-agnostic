#!/usr/bin/env bash
# Fixtures for the classes no repo in the portfolio can exercise:
#   - non-trunk base (negative path)   - multiple merged PRs on one head
#   - MERGED + OPEN on one head
# PR data is synthesized because these shapes do not occur in the portfolio.
set -u
CL=$(mktemp); trap 'rm -f "$CL"' EXIT
pass=0; fail=0
ok(){ echo "  PASS: $1"; pass=$((pass+1)); }
no(){ echo "  FAIL: $1"; fail=$((fail+1)); }

cat > "$CL" <<'PYEOF'
import json,sys
prs=json.loads(sys.argv[1])
b,trunk,tip=sys.argv[2],sys.argv[3],sys.argv[4]
held=[x for x in sys.argv[5].split(',') if x]
g=[p for p in prs if p["headRefName"]==b]
def out(s): print(s); sys.exit()
if b==trunk: out("trunk — excluded by rule")
if b in held: out("worktree-held")
if not g: out("no PR ever opened")
if any(p["state"]=="OPEN" for p in g): out("open PR on the same head")
m=[p for p in g if p["state"]=="MERGED"]
if not m: out("closed PR only")
if len(m)>1: out("multiple merged PRs on one head: "+",".join("#%d"%p["number"] for p in m))
p=m[0]
if p["baseRefName"]!=trunk: out("non-trunk base")
if tip!=p["headRefOid"]: out("tip moved past headRefOid")
out("LISTED")
PYEOF
classify(){ python3 "$CL" "$1" "$2" "$3" "$4" "$5"; }

echo "== non-trunk base: NEGATIVE path (never exercised by a real repo) =="
r=$(classify '[{"number":13,"state":"MERGED","headRefName":"fix/x","headRefOid":"aaa","baseRefName":"main"}]' fix/x dev aaa "")
[ "$r" = "non-trunk base" ] && ok "merged into main while trunk is dev -> $r" || no "got: $r"

echo "== non-trunk base: POSITIVE path (dpc-pro exercised this 70x) =="
r=$(classify '[{"number":14,"state":"MERGED","headRefName":"fix/y","headRefOid":"bbb","baseRefName":"dev"}]' fix/y dev bbb "")
[ "$r" = "LISTED" ] && ok "merged into dev while trunk is dev -> $r" || no "got: $r"

echo "== multiple merged PRs on one head (5 heads portfolio-wide) =="
J='[{"number":164,"state":"MERGED","headRefName":"feature/nav","headRefOid":"329f407b","baseRefName":"dev"},
    {"number":166,"state":"MERGED","headRefName":"feature/nav","headRefOid":"cb53af86","baseRefName":"dev"},
    {"number":168,"state":"MERGED","headRefName":"feature/nav","headRefOid":"f3ad8deb","baseRefName":"dev"}]'
r=$(classify "$J" feature/nav dev 4067ad5e "")
case "$r" in
  "multiple merged PRs on one head:"*) ok "3 merges -> $r";;
  *) no "got: $r";;
esac
echo "  (old spec had no bucket: merged[0] under gh's newest-first = #168 ->"
echo "   'tip moved past headRefOid' — right verdict, wrong reason)"

echo "== MERGED + OPEN on one head (zero occurrences portfolio-wide) =="
J='[{"number":40,"state":"MERGED","headRefName":"feat/base","headRefOid":"X","baseRefName":"dev"},
    {"number":41,"state":"OPEN","headRefName":"feat/base","headRefOid":"X","baseRefName":"dev"}]'
r=$(classify "$J" feat/base dev X "")
[ "$r" = "open PR on the same head" ] && ok "merged+open -> $r (never lists)" || no "got: $r"

echo "== ordering: worktree-held beats every PR condition (the #53 fix) =="
r=$(classify '[]' fix/api-bug dev zzz "fix/api-bug")
[ "$r" = "worktree-held" ] && ok "no PR at all + held -> $r (old order: 'no merged PR')" || no "got: $r"

echo "== trunk excluded before anything, even as a PR head =="
r=$(classify '[{"number":1,"state":"MERGED","headRefName":"dev","headRefOid":"q","baseRefName":"main"}]' dev dev q "")
[ "$r" = "trunk — excluded by rule" ] && ok "dev as a PR head -> $r" || no "got: $r"

echo "== closed-only vs never-opened stay distinct (the #53 split) =="
r=$(classify '[{"number":53,"state":"CLOSED","headRefName":"fix/z","headRefOid":"c","baseRefName":"dev"}]' fix/z dev c "")
[ "$r" = "closed PR only" ] && ok "CLOSED only -> $r" || no "got: $r"
r=$(classify '[]' chore/scaffold dev s "")
[ "$r" = "no PR ever opened" ] && ok "no PR at all -> $r" || no "got: $r"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
