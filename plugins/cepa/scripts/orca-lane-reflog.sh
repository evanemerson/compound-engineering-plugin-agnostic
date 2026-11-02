#!/usr/bin/env bash
# cepa lane reflog check — is every commit in a lane's HEAD reflog landed?
# Called by orca-lane.sh `rm` (step 3, punch-list L58); also safe to run by
# hand, because it only reads (git, and `gh pr list`).
#
# Why: `cepa:autonomy` §11b's reflog guard refuses when any commit in the HEAD
# reflog is on no origin ref. A reused lane fails that test after every squash
# merge whose branch was deleted: the squash puts NEW commits on origin, the
# branch's own commits stay only in the reflog. Measured 2026-11-01: the
# integrity lane, parked after #119, held 47 such reflog commits; the roles
# lane held 92. All were landed. So `rm` refused every reused lane.
#
# The sanctioned extra test (L58): a reflog commit that origin lacks counts as
# landed when the HEAD reflog shows it was made on branch <b>, and
# `gh pr list --state all --head <b>` returns a MERGED PR whose mergedAt is not
# earlier than the commit's committer date. The date test keeps a commit made
# on <b> AFTER its PR merged (never pushed, never landed) refused.
#
# Usage: orca-lane-reflog.sh <lane-path>
#   Run it after `git fetch --prune origin`; it does not fetch.
#   It runs gh from <lane-path>, so gh reads that repo's remote.
#
# Which branch held a commit (read from the HEAD reflog, oldest first):
#   - `checkout: moving from A to B` puts HEAD on B; B is a branch unless it
#     is a hex object name or names a remote-tracking ref or tag.
#   - `rebase (start)` keeps the branch; the rebase's commits are held until
#     `rebase (finish): returning to refs/heads/<b>`, which assigns them to
#     <b>. A rebase that never finishes leaves its commits held by no branch.
#   - Every other entry (commit, amend, merge, reset, pull, cherry-pick) is
#     made on the branch HEAD is on, or on no branch when HEAD is detached.
#   A commit held by no branch is never vouched for.
#
# A commit C that origin lacks is covered when some reflog commit S that
# reaches C is vouched for: a squash of S's branch lands every commit S
# reaches that its base lacks. Only reflog commits that reach a missing
# commit are checked. A reflog commit that no merged PR vouches for passes
# two more ways, in order:
#   - a vouched reflog commit reaches it (the same squash argument);
#   - patch identity: every commit it reaches that origin's default branch
#     lacks is marked `-` by `git cherry` (an equal patch is on the default
#     branch — a commit rebased or cherry-picked before it landed). The
#     default is origin/HEAD, else `gh repo view`'s defaultBranchRef.
#     Measured 2026-11-01: the roles lane's first reflog commit (763afca,
#     made detached and reset away) landed as 881ba1a this way.
#
# Exit codes and output (one line, except exit 0):
#   0  every reflog commit is on origin, or vouched for. One line per branch
#      used: `vouched <branch> by merged PR #<n>`; then `landed: …`.
#   1  `unlanded <sha> — <reason>`: a commit is not on origin and no merged
#      PR vouches for it. The caller refuses.
#   3  `unknown — <reason>`: the answer could not be read (gh missing or
#      failed, too many branches to ask about, a git read failed). The caller
#      refuses; this is never a pass.
#   4  `refused: <reason>` — the argument failed its check.
#
# STATED LIMITS:
#   - It trusts the committer date. A rebase or amend after the merge sets a
#     new date and stays refused; a clock that was wrong does not.
#   - A branch name reused for a second PR: any MERGED PR with that head name
#     and a late enough mergedAt vouches.
#   - Reflog entries expire (gc.reflogExpire, 90 days by default); commits
#     whose entries expired are not tested here or by §11b.
#   - At most 60 branches are asked about, one gh call each, all inside one
#     60 s budget (each call bounded at 20 s or what is left of the budget,
#     whichever is less). A run that spends the budget is UNKNOWN, never a
#     pass. Measured 2026-11-01: 11 branches took about 6 s in all.
set -u
LIMIT=60 BUDGET=60

[ $# -eq 1 ] || { echo "refused: usage: orca-lane-reflog.sh <lane-path>"; exit 4; }
lp=$1
case "$lp" in /*) ;; *) echo "refused: the lane path is not absolute"; exit 4 ;; esac
top=$(git -C "$lp" rev-parse --show-toplevel 2>/dev/null) || top=
[ "$top" = "$lp" ] || { echo "refused: $lp is not its own git toplevel"; exit 4; }
command -v python3 >/dev/null 2>&1 || { echo "unknown — no python3"; exit 3; }
command -v timeout >/dev/null 2>&1 || { echo "unknown — no timeout command to bound gh"; exit 3; }

refl=$(git -C "$lp" log -g --format='%H%x09%gs' HEAD 2>/dev/null) || { echo "unknown — the HEAD reflog is unreadable"; exit 3; }
[ -n "$refl" ] || { echo "unknown — the HEAD reflog is empty"; exit 3; }

# Reflog commits that reach a commit origin lacks.
need=
for s in $(cut -f1 <<<"$refl" | sort -u); do
  m=$(git -C "$lp" rev-list -1 "$s" --not --remotes=origin 2>/dev/null) || { echo "unknown — git rev-list failed on $s"; exit 3; }
  [ -z "$m" ] || need+="$s $(git -C "$lp" log -1 --format=%ct "$s" 2>/dev/null)"$'\n'
done
if [ -z "$need" ]; then
  echo "landed: every HEAD reflog commit is on an origin ref"
  exit 0
fi

# Which branches held each needed commit; refs that make a checkout target
# not a branch are read here, so the reader needs no git.
nonbr=$(git -C "$lp" for-each-ref --format='%(refname)' refs/remotes refs/tags 2>/dev/null \
  | sed -e 's#^refs/remotes/##' -e 's#^refs/tags/##') || nonbr=
held=$(REFL="$refl" NEED="$need" NONBR="$nonbr" python3 -I -c '
import os, re
need = {l.split()[0] for l in os.environ["NEED"].splitlines() if l.strip()}
nonbr = set(os.environ["NONBR"].splitlines())
rows = [l.split("\t", 1) for l in os.environ["REFL"].splitlines() if l]
rows.reverse()  # git prints newest first
held = {}
cur, pending, rebasing = None, [], False
def isbranch(b):
    return bool(b) and not re.fullmatch(r"[0-9a-f]{7,64}", b) and b not in nonbr and b != "HEAD"
for r in rows:
    sha, subj = r[0], (r[1] if len(r) > 1 else "")
    m = re.match(r"checkout: moving from .* to (\S+)$", subj)
    if m and not rebasing:
        cur = m.group(1) if isbranch(m.group(1)) else None
        continue
    if subj.startswith("rebase") and "(start)" in subj.split(":")[0]:
        rebasing, pending = True, []
        continue
    m = re.match(r"rebase[^:]*\((finish|abort)\): returning to refs/heads/(\S+)$", subj)
    if m:
        b = m.group(2)
        if m.group(1) == "finish":
            for p in pending + [sha]:
                held.setdefault(p, set()).add(b)
        rebasing, pending, cur = False, [], b
        continue
    if rebasing:
        pending.append(sha)
    elif cur:
        held.setdefault(sha, set()).add(cur)
for s in sorted(need):
    print(s + "\t" + " ".join(sorted(held.get(s, ()))))
') || { echo "unknown — the reflog reader failed"; exit 3; }

# Every branch to ask about, each checked as a branch name before gh sees it.
branches=$(cut -f2 <<<"$held" | tr ' ' '\n' | sed '/^$/d' | sort -u)
nb=$(grep -c . <<<"$branches")
[ "$nb" -le "$LIMIT" ] || { echo "unknown — $nb branches hold unlanded reflog commits, more than the $LIMIT this check asks gh about"; exit 3; }
if [ -n "$branches" ]; then
  command -v gh >/dev/null 2>&1 || { echo "unknown — gh is not on PATH, so PR state cannot be read"; exit 3; }
fi
declare -A merged=()
t0=$SECONDS
while IFS= read -r b; do
  [ -n "$b" ] || continue
  [[ $b =~ ^[A-Za-z0-9_][A-Za-z0-9._/-]{0,199}$ ]] && git check-ref-format "refs/heads/$b" 2>/dev/null \
    || { echo "unknown — the reflog names a branch this check will not pass to gh"; exit 3; }
  left=$((BUDGET - (SECONDS - t0)))
  [ "$left" -ge 3 ] || { echo "unknown — gh spent the ${BUDGET} s budget before every branch was asked about"; exit 3; }
  [ "$left" -le 20 ] || left=20
  out=$(cd "$lp" && timeout -k 2 "$left" gh pr list --state all --head "$b" --limit 50 \
        --json number,state,mergedAt --jq '.[] | [.number, .state, (.mergedAt // "-")] | @tsv' </dev/null 2>/dev/null) \
    || { echo "unknown — gh pr list failed for branch $b"; exit 3; }
  merged[$b]=$out
done <<<"$branches"

# A needed commit is vouched for by a MERGED PR of a branch that held it,
# merged at or after the commit's committer date. A needed commit that is not
# vouched for itself is covered when a vouched commit reaches it (the squash
# of that commit's branch landed it). Anything else is unlanded.
used= lines= vouched= open_=
while IFS=$'\t' read -r s bs; do
  [ -n "$s" ] || continue
  ct=$(grep -m1 "^$s " <<<"$need" | cut -d' ' -f2)
  pr=
  for b in $bs; do
    pr=$(PRS="${merged[$b]}" CT="$ct" python3 -I -c '
import os, re
from datetime import datetime
ct = int(os.environ["CT"] or 0)
for l in os.environ["PRS"].splitlines():
    f = l.split("\t")
    if len(f) != 3 or f[1] != "MERGED" or not re.fullmatch(r"[0-9]{1,7}", f[0]):
        continue
    try:
        at = datetime.fromisoformat(f[2].replace("Z", "+00:00")).timestamp()
    except ValueError:
        continue
    if ct and at >= ct:
        print(f[0]); break
') || pr=
    if [ -n "$pr" ]; then
      [[ $used == *"#$pr "* ]] || { used+="#$pr "; lines+="vouched $b by merged PR #$pr"$'\n'; }
      break
    fi
  done
  if [ -n "$pr" ]; then
    vouched+="$s"$'\n'
  elif [ -n "$bs" ]; then
    open_+="$s"$'\t'"on no origin ref, and no PR of $bs is MERGED after it was committed"$'\n'
  else
    open_+="$s"$'\t'"held by no branch in the HEAD reflog (detached, or an unfinished rebase)"$'\n'
  fi
done <<<"$held"
# The last test is patch identity: a commit rewritten before it landed (a
# rebase, or a cherry-pick onto the trunk) has a new SHA but the same patch.
# `git cherry <default> <s>` marks a commit `-` when the default branch holds
# an equal patch; every commit <s> reaches that the default lacks must be `-`.
dflt=
cepa_default() {
  [ -z "$dflt" ] || return 0
  dflt=$(git -C "$lp" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null) || dflt=
  dflt=${dflt#origin/}
  if [ -z "$dflt" ]; then
    command -v gh >/dev/null 2>&1 || return 1
    left=$((BUDGET - (SECONDS - t0)))
    [ "$left" -ge 3 ] || return 1
    [ "$left" -le 20 ] || left=20
    dflt=$(cd "$lp" && timeout -k 2 "$left" gh repo view --json defaultBranchRef --jq .defaultBranchRef.name </dev/null 2>/dev/null) || dflt=
  fi
  [[ $dflt =~ ^[A-Za-z0-9_][A-Za-z0-9._/-]{0,199}$ ]] && git check-ref-format "refs/heads/$dflt" 2>/dev/null \
    && git -C "$lp" rev-parse -q --verify "refs/remotes/origin/$dflt^{commit}" >/dev/null 2>&1 || { dflt=; return 1; }
}
nr=0 np=0
while IFS=$'\t' read -r s why; do
  [ -n "$s" ] || continue
  hit=
  while IFS= read -r v; do
    [ -n "$v" ] || continue
    if git -C "$lp" merge-base --is-ancestor "$s" "$v" 2>/dev/null; then hit=1; break; fi
  done <<<"$vouched"
  if [ -n "$hit" ]; then nr=$((nr + 1)); continue; fi
  cepa_default || { echo "unlanded ${s:0:12} — $why; origin's default branch is unknown, so patch identity was not tested"; exit 1; }
  ch=$(git -C "$lp" cherry "refs/remotes/origin/$dflt" "$s" 2>/dev/null) || ch=
  if [ -n "$ch" ] && ! grep -qv '^- ' <<<"$ch"; then np=$((np + 1)); continue; fi
  echo "unlanded ${s:0:12} — $why"
  exit 1
done <<<"$open_"
printf '%s' "$lines"
echo "landed: $(grep -c . <<<"$need") reflog commit(s) origin lacks — $(grep -c . <<<"$vouched") by a merged PR, $nr through a vouched commit that reaches it, $np by an equal patch on origin/${dflt:-<default>}"
exit 0
