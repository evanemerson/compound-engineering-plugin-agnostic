#!/usr/bin/env bash
# cepa lane reflog check — is every commit in a lane's HEAD reflog landed?
# Called by orca-lane.sh `rm` (step 3, punch-list L58), which runs
# `cepa:autonomy` §11b's plain reflog test first and calls this only for the
# commits that test flags. Also safe to run by hand: it only reads (git, and
# `gh pr list` / `gh repo view`).
#
# Why: a reused lane fails §11b's test after every squash merge whose branch
# was deleted — the squash puts a NEW commit on origin, and the branch's own
# commits stay only in the lane's reflog. Measured 2026-11-01: the integrity
# lane held 49 such commits and the roles lane 100, all landed.
#
# Usage: orca-lane-reflog.sh <lane-path>
#   Run it after `git fetch --prune origin`; it does not fetch.
#   gh runs from <lane-path>, so it reads that repo's remote.
#
# A reflog commit C that origin lacks is LANDED when one of these holds, in
# this order (PR #123 review: a merged PR alone does not prove C was in it):
#   1. C is an ancestor of the final head (`headRefOid`) of a MERGED,
#      same-repo PR into origin's default branch, whose head branch held C
#      in the HEAD reflog. The squash landed exactly what that head reaches.
#      (A PR into another base — a stacked PR whose base was later dropped —
#      never vouches.)
#   2. `git cherry <that head> C` marks every commit C reaches that the head
#      lacks `-` (an equal patch is in the head: C was rebased before it was
#      pushed), and that range holds no merge commit (git cherry skips them).
#   3. C was replaced by `git commit --amend` (the next reflog entry is
#      `commit (amend)`), and its replacement is landed. An amend discards the
#      old version on purpose.
#   4. A commit already landed by 1-3 reaches C.
#   5. Patch identity on origin's default branch: rule 2 with the default
#      branch in place of a PR head (a commit rebased or cherry-picked onto
#      the trunk).
#   The default branch is origin/HEAD, else `gh repo view`; unknown is exit 3.
#   Measured 2026-11-01 with rules 1, 2 and 3: integrity 42 by rule 1, 6 by
#   rule 2, 1 by rule 3 (0755a97); roles 88 by rule 1, 12 by rule 2.
#
# Which branch held a commit (the HEAD reflog, oldest first):
#   - `checkout: moving from A to B` puts HEAD on B when B is a branch name
#     (the name regex, not hex, not a remote-tracking ref or tag); any other
#     target (a SHA, `HEAD~1`, `@{-1}`) is detached.
#   - `rebase (start)` holds the rebase's commits until `rebase (finish):
#     returning to refs/heads/<b>` assigns them to <b>; an unfinished rebase
#     leaves them held by no branch.
#   - `Branch: renamed refs/heads/X to refs/heads/Y` moves HEAD from X to Y.
#   - Every other entry is made on the branch HEAD is on, or detached.
#   Attribution only chooses which PRs to ask about: rule 1 still needs C to
#   be in the PR's head, so a detached `checkout --detach <b>` cannot vouch.
#
# Exit codes and output (one line, except exit 0):
#   0  every reflog commit is on origin, or landed. One `vouched <branch> by
#      merged PR #<n>` line per PR used; then `landed: …`.
#   1  `unlanded <sha> — <reason>`. The caller refuses.
#   3  `unknown — <reason>`: gh missing or failed, too many branches, the
#      budget spent, a git read failed. The caller refuses; never a pass.
#   4  `refused: <reason>` — the argument failed its check.
#
# STATED LIMITS:
#   - A PR head that is not in the local object store cannot vouch (rule 1
#     and 2 skip it); a lane that made its own commits has them.
#   - Rule 3 trusts the reflog's amend entries: what an amend dropped is not
#     kept.
#   - Reflog entries expire (gc.reflogExpire, 90 days by default); commits
#     whose entries expired are tested neither here nor by §11b.
#   - At most 60 branches are asked about, one gh call each, inside one 35 s
#     budget (each call bounded at 15 s or what is left, plus a 2 s kill).
#     orca-lane.sh bounds this whole script at 60 s. Spending either bound is
#     UNKNOWN, never a pass.
set -u
LIMIT=60 BUDGET=35

[ $# -eq 1 ] || { echo "refused: usage: orca-lane-reflog.sh <lane-path>"; exit 4; }
lp=$1
case "$lp" in /*) ;; *) echo "refused: the lane path is not absolute"; exit 4 ;; esac
top=$(git -C "$lp" rev-parse --show-toplevel 2>/dev/null) || top=
[ "$top" = "$lp" ] || { echo "refused: $lp is not its own git toplevel"; exit 4; }
command -v python3 >/dev/null 2>&1 || { echo "unknown — no python3"; exit 3; }
command -v timeout >/dev/null 2>&1 || { echo "unknown — no timeout command to bound gh"; exit 3; }
brre='^[A-Za-z0-9_][A-Za-z0-9._/-]{0,199}$'

refl=$(git -C "$lp" log -g --format='%H%x09%gs' HEAD 2>/dev/null) || { echo "unknown — the HEAD reflog is unreadable"; exit 3; }
[ -n "$refl" ] || { echo "unknown — the HEAD reflog is empty"; exit 3; }

# A reflog commit reaches a commit origin lacks exactly when it is one itself,
# so one rev-list finds every commit to test (PR #123 review: one call, not
# one per reflog entry).
# shellcheck disable=SC2046 # the reflog is a list of SHAs, one word each
lost=$(git -C "$lp" rev-list $(cut -f1 <<<"$refl" | sort -u) --not --remotes=origin 2>/dev/null) \
  || { echo "unknown — git rev-list over the HEAD reflog failed"; exit 3; }
need=$(sort -u <<<"$(cut -f1 <<<"$refl")" | grep -xF -f <(printf '%s\n' "$lost") 2>/dev/null) || need=
if [ -z "$need" ]; then
  echo "landed: every HEAD reflog commit is on an origin ref"
  exit 0
fi

# Per needed commit: the branches that held it and its amend replacement.
nonbr=$(git -C "$lp" for-each-ref --format='%(refname)' refs/remotes refs/tags 2>/dev/null \
  | sed -e 's#^refs/remotes/##' -e 's#^refs/tags/##') || nonbr=
held=$(REFL="$refl" NEED="$need" NONBR="$nonbr" BRRE="$brre" python3 -I -c '
import os, re
need = set(os.environ["NEED"].split())
nonbr = set(os.environ["NONBR"].splitlines())
brre = re.compile(os.environ["BRRE"])
rows = [l.split("\t", 1) for l in os.environ["REFL"].splitlines() if l]
rows.reverse()  # git prints newest first
held, amend = {}, {}
cur, pending, rebasing, prev = None, [], False, None
def isbranch(b):
    return bool(brre.match(b)) and not re.fullmatch(r"[0-9a-f]{7,64}", b) and b not in nonbr \
        and b != "HEAD" and ".." not in b and not b.endswith((".lock", "/", ".")) and "//" not in b
for r in rows:
    sha, subj = r[0], (r[1] if len(r) > 1 else "")
    if subj.startswith("commit (amend):") and prev:
        amend.setdefault(prev, sha)
    m = re.match(r"checkout: moving from .* to (\S+)$", subj)
    rn = re.match(r"Branch: renamed refs/heads/(\S+) to refs/heads/(\S+)$", subj)
    if rn:
        if cur == rn.group(1):
            cur = rn.group(2) if isbranch(rn.group(2)) else None
    elif m and not rebasing:
        cur = m.group(1) if isbranch(m.group(1)) else None
    elif subj.startswith("rebase") and "(start)" in subj.split(":")[0]:
        rebasing, pending = True, []
    elif re.match(r"rebase[^:]*\((finish|abort)\): returning to refs/heads/(\S+)$", subj):
        m = re.match(r"rebase[^:]*\((finish|abort)\): returning to refs/heads/(\S+)$", subj)
        b = m.group(2) if isbranch(m.group(2)) else None
        if m.group(1) == "finish" and b:
            for p in pending + [sha]:
                held.setdefault(p, set()).add(b)
        rebasing, pending, cur = False, [], b
    elif rebasing:
        pending.append(sha)
    elif cur:
        held.setdefault(sha, set()).add(cur)
    prev = sha
for s in sorted(need):
    a = amend.get(s, "")
    print(s + "\t" + " ".join(sorted(held.get(s, ()))) + "\t" + (a if a != s else ""))
') || { echo "unknown — the reflog reader failed"; exit 3; }

# Merged same-repo PR heads per branch, read once each.
branches=$(cut -f2 <<<"$held" | tr ' ' '\n' | sed '/^$/d' | sort -u)
nb=$(grep -c . <<<"$branches")
[ "$nb" -le "$LIMIT" ] || { echo "unknown — $nb branches hold unlanded reflog commits, more than the $LIMIT this check asks gh about"; exit 3; }
[ -z "$branches" ] || command -v gh >/dev/null 2>&1 || { echo "unknown — gh is not on PATH, so PR state cannot be read"; exit 3; }
declare -A heads=()
t0=$SECONDS
gh_left() {
  left=$((BUDGET - (SECONDS - t0)))
  [ "$left" -ge 3 ] || return 1
  [ "$left" -le 15 ] || left=15
}
dflt=$(git -C "$lp" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null) || dflt=
dflt=${dflt#origin/}
if [ -z "$dflt" ] && command -v gh >/dev/null 2>&1 && gh_left; then
  dflt=$(cd "$lp" && timeout -k 2 "$left" gh repo view --json defaultBranchRef --jq .defaultBranchRef.name </dev/null 2>/dev/null) || dflt=
fi
[[ $dflt =~ $brre ]] && git check-ref-format "refs/heads/$dflt" 2>/dev/null \
  && git -C "$lp" rev-parse -q --verify "refs/remotes/origin/$dflt^{commit}" >/dev/null 2>&1 \
  || { echo "unknown — origin's default branch is unknown"; exit 3; }
while IFS= read -r b; do
  [ -n "$b" ] || continue
  [[ $b =~ $brre ]] && git check-ref-format "refs/heads/$b" 2>/dev/null \
    || { echo "unknown — the reflog names a branch this check will not pass to gh"; exit 3; }
  gh_left || { echo "unknown — gh spent the ${BUDGET} s budget before every branch was asked about"; exit 3; }
  out=$(cd "$lp" && timeout -k 2 "$left" gh pr list --state all --head "$b" --limit 50 \
        --json number,state,baseRefName,headRefOid,isCrossRepository \
        --jq '.[] | [.number, .state, .baseRefName, .headRefOid, (.isCrossRepository | tostring)] | @tsv' </dev/null 2>/dev/null) \
    || { echo "unknown — gh pr list failed for branch $b"; exit 3; }
  hs=
  while IFS=$'\t' read -r n st bb h x; do
    [[ $n =~ ^[0-9]{1,7}$ && $st == MERGED && $bb == "$dflt" && $h =~ ^[0-9a-f]{40}$ && $x == false ]] || continue
    git -C "$lp" cat-file -e "$h^{commit}" 2>/dev/null || continue
    hs+="$n:$h "
  done <<<"$out"
  heads[$b]=$hs
done <<<"$branches"

# One commit range is patch-equal to a target when git cherry marks every
# commit `-` and the range holds no merge commit.
patch_in() {  # <target> <commit>
  local ch m
  ch=$(git -C "$lp" cherry "$1" "$2" 2>/dev/null) || return 1
  [ -n "$ch" ] && ! grep -qv '^- ' <<<"$ch" || return 1
  m=$(git -C "$lp" rev-list -1 --merges "$1..$2" 2>/dev/null) || return 1
  [ -z "$m" ]
}

declare -A ok=() succ=() why=()
lines= used=
n1=0 n2=0 n3=0 n4=0 n5=0
while IFS=$'\t' read -r s bs a; do
  [ -n "$s" ] || continue
  succ[$s]=$a
  for b in $bs; do
    for nh in ${heads[$b]}; do
      if git -C "$lp" merge-base --is-ancestor "$s" "${nh#*:}" 2>/dev/null; then ok[$s]=1; n1=$((n1 + 1))
      elif patch_in "${nh#*:}" "$s"; then ok[$s]=2; n2=$((n2 + 1))
      else continue; fi
      [[ $used == *"#${nh%%:*} "* ]] || { used+="#${nh%%:*} "; lines+="vouched $b by merged PR #${nh%%:*}"$'\n'; }
      break 2
    done
  done
  if [ -z "${ok[$s]:-}" ]; then
    if [ -n "$bs" ]; then why[$s]="no merged PR of $bs has it in its head, and no rule below lands it"
    else why[$s]="held by no branch in the HEAD reflog (detached, or an unfinished rebase), and no rule below lands it"; fi
  fi
done <<<"$held"

# Rules 3 and 4 depend on other commits' results: repeat until nothing changes.
changed=1
while [ -n "$changed" ]; do
  changed=
  for s in "${!why[@]}"; do
    [ -z "${ok[$s]:-}" ] || continue
    a=${succ[$s]:-}
    if [ -n "$a" ] && { [ -n "${ok[$a]:-}" ] || [ -z "$(git -C "$lp" rev-list -1 "$a" --not --remotes=origin 2>/dev/null)" ]; }; then
      ok[$s]=3; n3=$((n3 + 1)); changed=1; continue
    fi
    for v in "${!ok[@]}"; do
      if git -C "$lp" merge-base --is-ancestor "$s" "$v" 2>/dev/null; then ok[$s]=4; n4=$((n4 + 1)); changed=1; break; fi
    done
  done
done

for s in "${!why[@]}"; do
  [ -z "${ok[$s]:-}" ] || continue
  patch_in "refs/remotes/origin/$dflt" "$s" || { echo "unlanded ${s:0:12} — ${why[$s]}"; exit 1; }
  ok[$s]=5; n5=$((n5 + 1))
done
printf '%s' "$lines"
echo "landed: $(grep -c . <<<"$need") reflog commit(s) origin lacks — $n1 in a merged PR's head, $n2 by an equal patch in one, $n3 replaced by a landed amend, $n4 reached by a landed commit, $n5 by an equal patch on origin/$dflt"
exit 0
