#!/usr/bin/env bash
# cepa Orca lane — creates, names and removes a lane (a linked worktree)
# through Orca (punch-list L55). `cepa:autonomy` §12b rule 2 owns WHEN and WHO
# (coord@main only, from the main checkout; removal only when the operator
# asks); this script owns HOW each action is done and proved.
#
# Why: lanes made with `git worktree add` have no fixed name in the Orca
# sidebar (`displayNameMode: "automatic"` shows the branch, or the repo name
# when parked), skip the repo's `orca.yaml` hooks, and were created by hand in
# five steps, three times in one repo (artist360-docs, 2026-11-01).
#
# Usage: orca-lane.sh  <stdin      (it takes no arguments)
#   stdin is FIELD lines only, inside the session's quoted heredoc
#   (`<<'CEPA_FIELDS'`), so no value is ever inside a quoted shell string:
#     cli: <cli>       §12a's printed `cli=` value, checked as orca-rebind.sh
#                      checks it.
#     action: create | name | rm
#     lane: <wt>       create and rm only: the lane's directory basename and
#                      sidebar name. A §10a `<wt>` that slug() leaves
#                      unchanged: [A-Za-z0-9_] runs joined by single `-`, at
#                      most 64 characters, never `main`.
#     base: <branch>   create only: the trunk the lane parks on, as a branch
#                      name (`main`, `dev`); the script uses origin/<base>.
#   `name` takes cli and action only, and refuses lane or base; `rm` refuses
#   base (it tests no base: the operator's #4 decision dropped the
#   squash-blind `origin/<base>..<branch>` test, so base had no use).
#   A field line is `<name>: <value>`, each name at most once. An empty line
#   ends the fields; only empty lines may follow. Any other line is refused.
#
# Scope (review finding #2): every read is scoped to THIS repo. The repo is
# the `repo list` row whose path is this main checkout; `worktree list` runs
# with `--repo id:<repoId>`, and rows of any other repoId are dropped. Every
# `show`, `set` and `rm` addresses a lane only by the full `id:` that list
# returned, never by `name:`, `branch:`, `path:` or `active`. The script runs
# only from the main checkout (git-dir equals git-common-dir).
#
# A read counts only when complete (review finding #13): exit 0, `"ok": true`,
# `truncated: false`, `totalCount` equal to the rows returned and below
# `--limit`, and no omitted host. Anything else is UNKNOWN: a pre-check
# refuses, and a post-check reports "removal not proved".
#
# Paths (review finding #5): Orca returns Windows UNC paths. A path
# `\\wsl.localhost\<distro>\a\b` becomes `/a/b` only when <distro> equals
# WSL_DISTRO_NAME; a path that already starts with `/` is kept; any other
# form is UNKNOWN.
#
# What each action does, in order:
#   create  1. Refuse when a worktree of this repo (Orca's list or `git
#              worktree list`) already has the basename or display name
#              <lane>, or `refs/heads/chore/<lane>/park` exists: Orca does
#              not refuse a taken name, it suffixes the path and the branch
#              (U1 below).
#           2. `worktree create --repo id:<repoId> --name <lane> --branch
#              chore/<lane>/park --base-branch origin/<base> --no-parent
#              --setup inherit --json` (review finding #18: the repo's own
#              setup policy decides; the summary prints it).
#           3. From create's JSON: the path's basename must be <lane>
#              (finding #14), the display name <lane> and fixed. Then
#              `symbolic-ref` must read chore/<lane>/park (finding #6).
#              A mismatch stops here with the lane kept for the operator.
#           4. Park: the branch must have no commit beyond origin/<base>;
#              detach at the lane's own HEAD commit (the same commit, so no
#              file changes under a running setup); delete that branch.
#           5. `worktree show` by id must report the fixed name <lane>.
#   name    For each non-main worktree of this repo whose displayNameMode is
#           not `fixed`: `worktree set --display-name <basename>` by id. A
#           basename that is not a <wt> name is skipped. Then re-list: each
#           renamed lane must read fixed with its basename. Idempotent.
#   rm      1. Exactly one non-main worktree of this repo has the basename
#              <lane>; it must be its own git toplevel and in `git worktree
#              list`; a fixed sidebar name that is not <lane>, or another
#              lane showing <lane>, is ambiguous and refused.
#           2. Refuse on any tracked or untracked change (`status --porcelain
#              --untracked-files=all`; ignored files excluded here).
#           3. `git fetch --prune origin` (60 s bound; a failure refuses),
#              then refuse when HEAD, or any commit in the lane's HEAD reflog, is
#              on no origin ref: the same test as `cepa:autonomy` §11b's
#              reflog guard (cited there, owned there).
#           4. Refuse when `worktree ps` shows an agent on the lane, or the
#              read is not complete.
#           5. List the ignored files and directories it will delete (the
#              operator's #4 decision: list them, then remove).
#           6. `worktree rm --worktree id:<id> --run-hooks --json`. Never
#              `--force`, never `--allow-failed-archive-hook`.
#           7. Removed only when absent from Orca's list (a complete read)
#              AND from `git worktree list`. The branch the lane held is
#              reported deleted or kept; Orca decides that (U1 below).
#
# Prints one summary line per action (and per renamed lane), and on exit 1 or
# 3 a last line `Ending first line: Needed from you: …`. Exit codes:
#   0  `ORCA lane: created …`, `ORCA lane: named …`, `ORCA lane: removed …`.
#   1  `ORCA lane: not created — …` or `ORCA lane: kept <lane> — …`: a guard
#      refused, or a read was not complete. Orca was not asked to write.
#   3  `ORCA lane failed: …`: an Orca write failed or was not proved, or the
#      created lane did not match. A lane is never removed by this script to
#      undo a failed create.
#   4  `ORCA lane refused: <reason>` — a field or the environment failed its
#      check. No Orca call was made.
#
# U1 — measured on Orca 1.4.245 (WSL), 2026-11-01, in this repo, on probe
# lanes `lane-probe` / `lane-probe2` (all removed; commands in the L55 PR):
#   - `create --json` returns in ~4 s with `"ok": true`, path
#     `\\wsl.localhost\Ubuntu-24.04\home\evan\orca\workspaces\<repo>\<name>`,
#     `displayName: <name>`, `displayNameMode: "fixed"`, the branch, and NO
#     setup field. It returns BEFORE the setup starts: the setup runs in a
#     `Setup` terminal pane through `<git-dir>/orca/setup-runner.sh`.
#   - The setup is read from the NEW lane's own orca.yaml (the base ref's),
#     not the caller's worktree and not the main checkout's working tree.
#   - A setup that exits 1 is invisible: create still says `"ok": true` with
#     no warning, the Setup pane looks the same as on success, and `worktree
#     show`/`terminal show`/`worktree ps` carry no exit code. So this script
#     cannot read a setup result, and says so.
#   - A taken `--name` is NOT refused: Orca made `<name>-2` with the same
#     display name, and suffixed the branch (`…-2`).
#   - A bad `--base-branch` exits 1 with `error.code: runtime_error` ("Could
#     not refresh base ref …"): Orca fetches the base ref itself.
#   - The archive hook is read from the MAIN CHECKOUT's working-tree
#     orca.yaml (the lane's own `archive:` did not run), runs with the lane as
#     its directory, and `rm` waits for it. A failed hook exits 1 with
#     `error.code: worktree_archive_hook_failed`, `error.data.exitCode` and
#     `error.data.output`, and nothing is removed.
#   - `rm` deleted the checked-out branch both when its tip was on
#     origin/main and when its tip was only on another origin ref.
#   - `worktree show` right after a park still reported the old branch; 5 s
#     later it read empty. The display name is read, not the branch.
#   - `worktree list --repo path:<linux path>` returns `repo_not_found`;
#     `--repo id:<repoId>` works.
#
# STATED LIMITS:
#   - The setup result is not proved (above). A worker started with
#     `worker-start` under a `wait-for-setup` policy waits for it; under
#     `start-immediately` it does not. The summary names the policy.
#   - Check-then-create is not atomic: two coordinators creating one <lane> at
#     once can both pass step 1. One coord@main per repo makes it rare; the
#     basename check in step 3 then stops the second.
#   - `rm` runs the repo's archive hook with Orca's own bound; the script
#     bounds the call at 330 s. Worst case about 530 s: four reads at
#     2 x 17 s, the fetch 62 s, rm 332 s. Run the block with a tool timeout
#     of 10 minutes. A call the bound killed reads as "removal not proved";
#     Orca's hook may still be running on the server then.
#   - The archive hook's output is never relayed (repo rule: relayed content
#     is stripped); the failure line gives its exit code only.
#   - The live-agent check sees agents Orca knows (`worktree ps`). A session
#     started from a plain terminal is not seen, and the checks and the
#     `rm` are not atomic.
#   - A lane whose HEAD reflog holds squash-merged commits from a deleted
#     branch is refused (§11b's guard); the operator decides.
#   - `name` skips a lane whose basename another lane already shows.
#   - The setup starts before the park: a `setup:` that reads the branch
#     name sees `chore/<lane>/park`, then a detached HEAD, and one that
#     commits can race the detach on index.lock (the lane is then kept on
#     the park branch). A setup should use the directory name only.
#   - The ignored-file list is printed, not kept: the files are deleted.
#   - Orca keeps a branch it cannot prove merged; the script reports it and
#     never deletes it.
set -u

refuse() { echo "ORCA lane refused: $1"; exit 4; }
kept() {
  echo "ORCA lane: $1"
  echo "Ending first line: Needed from you: $2"
  exit 1
}
failed() {
  echo "ORCA lane failed: $1"
  echo "Ending first line: Needed from you: ${2:-inspect the lane in Orca (worktree show by id) and say how to proceed}"
  exit 3
}

[ $# -eq 0 ] || refuse "orca-lane.sh takes no arguments; its fields go on stdin"
unset cepa_ln_f_cli cepa_ln_f_action cepa_ln_f_lane cepa_ln_f_base
cepa_ln_seen=" "
while IFS= read -r cepa_ln_line || [ -n "$cepa_ln_line" ]; do
  cepa_ln_line=${cepa_ln_line%$'\r'}
  [ -n "$cepa_ln_line" ] || break
  [[ $cepa_ln_line =~ ^([a-z]+):(\ (.*))?$ ]] || refuse "a heredoc line is not a <name>: <value> field"
  cepa_ln_k=${BASH_REMATCH[1]} cepa_ln_v=${BASH_REMATCH[3]}
  cepa_ln_v=${cepa_ln_v%"${cepa_ln_v##*[![:space:]]}"}
  case "$cepa_ln_k" in cli|action|lane|base) ;; *) refuse "a field name is not cli, action, lane or base" ;; esac
  [[ $cepa_ln_seen != *" $cepa_ln_k "* ]] || refuse "the $cepa_ln_k field is given twice"
  cepa_ln_seen+="$cepa_ln_k "
  printf -v "cepa_ln_f_$cepa_ln_k" '%s' "$cepa_ln_v"
done
{ cepa_ln_rest=$(cat); } 2>/dev/null
[ -z "${cepa_ln_rest//[[:space:]]/}" ] || refuse "the heredoc holds a line after its fields"

[[ $cepa_ln_seen == *" cli "* ]] || refuse "the cli field is missing"
cepa_ln_cli=$cepa_ln_f_cli
case "$cepa_ln_cli" in
  ''|-*|*[!A-Za-z0-9._/-]*) refuse "the cli is not a plain command name" ;;
  /*) [ "$cepa_ln_cli" = "${ORCA_CLI_COMMAND:-}" ] || refuse "a cli path must equal ORCA_CLI_COMMAND" ;;
  */*) refuse "a cli path must be absolute and equal ORCA_CLI_COMMAND" ;;
esac
case "${cepa_ln_cli##*/}" in
  orca-ide|orca-dev) ;;
  orca) [ "$(uname -s 2>/dev/null)" != Linux ] || refuse "bare orca on Linux is the screen reader" ;;
  *) refuse "the cli does not name an Orca CLI" ;;
esac
[[ $cepa_ln_seen == *" action "* ]] || refuse "the action field is missing"
cepa_ln_action=$cepa_ln_f_action
case "$cepa_ln_action" in create|name|rm) ;; *) refuse "the action is not create, name or rm" ;; esac
# Per-action fields (review finding #10).
cepa_ln_lane= cepa_ln_base=
case "$cepa_ln_action" in
  name)
    [[ $cepa_ln_seen != *" lane "* ]] || refuse "name takes no lane field"
    [[ $cepa_ln_seen != *" base "* ]] || refuse "name takes no base field" ;;
  rm)
    [[ $cepa_ln_seen == *" lane "* ]] || refuse "the lane field is missing"
    [[ $cepa_ln_seen != *" base "* ]] || refuse "rm takes no base field" ;;
  create)
    [[ $cepa_ln_seen == *" lane "* ]] || refuse "the lane field is missing"
    [[ $cepa_ln_seen == *" base "* ]] || refuse "the base field is missing" ;;
esac
cepa_ln_wt_re='^[A-Za-z0-9_]+(-[A-Za-z0-9_]+)*$'
if [[ $cepa_ln_seen == *" lane "* ]]; then
  cepa_ln_lane=$cepa_ln_f_lane
  [[ $cepa_ln_lane =~ $cepa_ln_wt_re ]] && [ "${#cepa_ln_lane}" -le 64 ] \
    || refuse "the lane is not a <wt> name ([A-Za-z0-9_] runs joined by single -, at most 64)"
  [ "$cepa_ln_lane" != main ] || refuse "the lane may not be main (reserved for the main checkout)"
fi
if [[ $cepa_ln_seen == *" base "* ]]; then
  cepa_ln_base=$cepa_ln_f_base
  [[ $cepa_ln_base =~ ^[A-Za-z0-9_][A-Za-z0-9._/-]{0,99}$ ]] \
    || refuse "the base is not a branch name"
  git check-ref-format "refs/heads/$cepa_ln_base" 2>/dev/null || refuse "the base is not a valid branch name"
fi

command -v "$cepa_ln_cli" >/dev/null 2>&1 || refuse "$cepa_ln_cli is not on PATH"
command -v timeout >/dev/null 2>&1 || refuse "no timeout command to bound the Orca calls"
command -v python3 >/dev/null 2>&1 || refuse "no python3 to read the Orca output"
cepa_ln_gd=$(git rev-parse --path-format=absolute --git-dir 2>/dev/null) || cepa_ln_gd=
cepa_ln_cd=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || cepa_ln_cd=
case "$cepa_ln_gd" in /*) ;; *) refuse "not in a git checkout" ;; esac
[ "$cepa_ln_gd" = "$cepa_ln_cd" ] || refuse "run it from the main checkout (coord@main), not a linked worktree"
cepa_ln_main=$(git rev-parse --show-toplevel 2>/dev/null) || cepa_ln_main=
case "$cepa_ln_main" in /*) ;; *) refuse "the main checkout's toplevel is unreadable" ;; esac
[ "$cepa_ln_main" = "${cepa_ln_main%%$'\n'*}" ] || refuse "the main checkout's path is not one line"
cepa_ln_tmp=$(mktemp -d 2>/dev/null) || refuse "mktemp failed"
trap 'rm -rf "$cepa_ln_tmp"' EXIT

# One Orca call, bounded at $3 seconds plus a 2-second kill. A read is retried
# once on the WSL interop error (orca-send.sh's rule); a write never is.
cepa_ln_orca() {
  local out=$1 retry=$2 bound=$3 try e
  shift 3
  for try in 1 2; do
    timeout -k 2 "$bound" "$cepa_ln_cli" "$@" </dev/null >"$out" 2>"$cepa_ln_tmp/err" && return 0
    [ "$retry" = 1 ] && [ "$try" = 1 ] || return 1
    { e=$(<"$cepa_ln_tmp/err"); } 2>/dev/null || return 1
    [[ $e == *UtilAcceptVsock* && $e == *"accept4 failed 110"* ]] || return 1
  done
  return 1
}

# Every Orca JSON read. Mode first; exit 1 means the shape is not known or
# the read is not complete, which the caller treats as UNKNOWN.
cepa_ln_py() {
  python3 -I -c '
import json, re, sys
mode, f = sys.argv[1], sys.argv[2]
args = sys.argv[3:]
LIMIT = 500
try:
    d = json.load(open(f))
except Exception:
    sys.exit(1)

def linux(p, distro):
    if not isinstance(p, str) or not p or any(ord(c) < 32 or ord(c) == 127 for c in p):
        return None
    m = re.fullmatch(r"\\\\wsl\.localhost\\([^\\]+)\\(.*)", p)
    if m:
        if not distro or m.group(1) != distro:
            return None
        p = "/" + m.group(2).replace("\\", "/")
    if not p.startswith("/") or "\\" in p:
        return None
    if any(s in (".", "..") for s in p.split("/")[1:]):
        return None
    return p.rstrip("/") or None

def safe(s, pat=r"[A-Za-z0-9._/@ -]{1,100}"):
    return s if isinstance(s, str) and re.fullmatch(pat, s) else "?"

def complete(r, key):
    rows = r.get(key)
    hs = r.get("hostScope") or {}
    if not isinstance(rows, list) or r.get("truncated") is not False:
        sys.exit(1)
    if r.get("totalCount") != len(rows) or len(rows) >= LIMIT:
        sys.exit(1)
    if hs.get("omittedHostIds") != []:
        sys.exit(1)
    return rows

if mode == "ok":
    sys.exit(0 if d.get("ok") is True else 1)
r = d.get("result") if d.get("ok") is True else None
if mode == "repo":
    main, distro = args
    if not isinstance(r, dict) or not isinstance(r.get("repos"), list):
        sys.exit(1)
    hit = [x for x in r["repos"] if isinstance(x, dict) and linux(x.get("path"), distro) == main]
    if len(hit) != 1:
        sys.exit(2 if not hit else 1)
    rid = hit[0].get("id")
    if not (isinstance(rid, str) and re.fullmatch(r"[A-Za-z0-9-]{1,64}", rid)):
        sys.exit(1)
    pol = ((hit[0].get("hookSettings") or {}).get("setupRunPolicy"))
    print(rid, pol if isinstance(pol, str) and re.fullmatch(r"[a-z-]{1,40}", pol) else "unknown")
elif mode == "rows":
    rid, distro, main = args
    if not isinstance(r, dict):
        sys.exit(1)
    rows = complete(r, "worktrees")
    out, mains = [], 0
    for w in rows:
        if not isinstance(w, dict) or w.get("repoId") != rid:
            continue
        p = linux(w.get("path"), distro)
        wid = w.get("id")
        if p is None or not isinstance(wid, str) or wid != rid + "::" + w["path"]:
            sys.exit(1)
        ismain = w.get("isMainWorktree") is True
        if ismain:
            mains += 1
            if p != main:
                sys.exit(1)
        br = w.get("branch") or ""
        br = br[len("refs/heads/"):] if isinstance(br, str) and br.startswith("refs/heads/") else ""
        out.append("\t".join([wid, p, p.rsplit("/", 1)[-1], safe(w.get("displayNameMode"), r"[a-z]{1,20}"),
                              safe(w.get("displayName")), "1" if ismain else "0", safe(br) if br else "-"]))
    if mains != 1:
        sys.exit(1)
    print("\n".join(out))
elif mode == "created":
    rid, distro = args
    w = r.get("worktree") if isinstance(r, dict) else None
    if not isinstance(w, dict) or w.get("repoId") != rid:
        sys.exit(1)
    p = linux(w.get("path"), distro)
    wid = w.get("id")
    if p is None or not isinstance(wid, str) or wid != rid + "::" + w["path"]:
        sys.exit(1)
    print("\t".join([wid, p, safe(w.get("displayName")), safe(w.get("displayNameMode"), r"[a-z]{1,20}")]))
elif mode == "shown":
    w = r.get("worktree") if isinstance(r, dict) else None
    if not isinstance(w, dict) or w.get("id") != args[0]:
        sys.exit(1)
    print(safe(w.get("displayName")), safe(w.get("displayNameMode"), r"[a-z]{1,20}"))
elif mode == "agents":
    if not isinstance(r, dict):
        sys.exit(1)
    rows = [w for w in complete(r, "worktrees") if isinstance(w, dict) and w.get("worktreeId") == args[0]]
    if len(rows) != 1 or not isinstance(rows[0].get("agents"), list):
        sys.exit(1)
    print(len(rows[0]["agents"]))
elif mode == "rmres":
    if d.get("ok") is True:
        print("removed" if isinstance(r, dict) and r.get("removed") is True else "unknown")
    else:
        e = d.get("error") if isinstance(d.get("error"), dict) else {}
        code = safe(e.get("code"), r"[a-z_]{1,64}")
        data = e.get("data") if isinstance(e.get("data"), dict) else {}
        x = data.get("exitCode")
        # Hook output is repo-run text: stripped here, never relayed
        # (repo rule: relayed content is stripped at every relay point).
        print(code, x if type(x) is int else "?")
elif mode == "err":
    e = d.get("error") if isinstance(d.get("error"), dict) else {}
    print(safe(e.get("code"), r"[a-z_]{1,64}"))
else:
    sys.exit(1)
' "$@" 2>/dev/null
}

cepa_ln_distro=${WSL_DISTRO_NAME:-}
# This repo's Orca id, from the `repo list` row whose path is this checkout.
cepa_ln_orca "$cepa_ln_tmp/repos.json" 1 15 repo list --json \
  || kept "${cepa_ln_lane:-lanes} unchanged — repo list failed" "check that Orca is running, then ask this session to run the block again"
cepa_ln_rc=0
cepa_ln_repo=$(cepa_ln_py repo "$cepa_ln_tmp/repos.json" "$cepa_ln_main" "$cepa_ln_distro") || cepa_ln_rc=$?
[ "$cepa_ln_rc" != 2 ] || kept "${cepa_ln_lane:-lanes} unchanged — Orca has no repo at $cepa_ln_main" \
  "add this repo to Orca (orca repo add), then ask this session to run the block again"
[ "$cepa_ln_rc" = 0 ] || kept "${cepa_ln_lane:-lanes} unchanged — repo list returned a shape this reader does not know, or two repos at $cepa_ln_main" \
  "check Orca's repo list for $cepa_ln_main"
read -r cepa_ln_rid cepa_ln_policy <<<"$cepa_ln_repo"

# This repo's worktrees, as TSV rows: id, path, basename, mode, name, main, branch.
cepa_ln_rows() {
  cepa_ln_orca "$cepa_ln_tmp/list.json" 1 15 worktree list --repo "id:$cepa_ln_rid" --limit 500 --json || return 1
  cepa_ln_py rows "$cepa_ln_tmp/list.json" "$cepa_ln_rid" "$cepa_ln_distro" "$cepa_ln_main"
}

# ---------------------------------------------------------------- name
if [ "$cepa_ln_action" = name ]; then
  cepa_ln_all=$(cepa_ln_rows) || kept "no lane renamed — worktree list was not a complete read of this repo" \
    "check Orca's worktree list for this repo, then ask this session to run the block again"
  cepa_ln_n=0 cepa_ln_fixed=0 cepa_ln_skip=0 cepa_ln_done=
  while IFS=$'\t' read -r w_id w_path w_base w_mode w_name w_main w_br; do
    [ -n "$w_id" ] && [ "$w_main" = 0 ] || continue
    if [ "$w_mode" = fixed ]; then cepa_ln_fixed=$((cepa_ln_fixed + 1)); continue; fi
    if ! [[ $w_base =~ $cepa_ln_wt_re ]] || [ "${#w_base}" -gt 64 ] || [ "$w_base" = main ]; then
      echo "ORCA lane: skipped $w_path — its basename is not a <wt> name"
      cepa_ln_skip=$((cepa_ln_skip + 1)); continue
    fi
    # Two lanes showing one name make rm ambiguous (PR #118 review).
    if grep -qxF -- "$w_base" <<<"$(grep -vF -- "$w_id"$'\t' <<<"$cepa_ln_all" | cut -f5)"; then
      echo "ORCA lane: skipped $w_path — another lane already shows the name $w_base"
      cepa_ln_skip=$((cepa_ln_skip + 1)); continue
    fi
    cepa_ln_orca "$cepa_ln_tmp/set.json" 0 15 worktree set --worktree "id:$w_id" --display-name "$w_base" --json \
      && cepa_ln_py ok "$cepa_ln_tmp/set.json" \
      || failed "worktree set failed for $w_path; $cepa_ln_n lane(s) were renamed before it" \
                "check lane $w_base in Orca, then ask this session to run the name block again (it is idempotent)"
    cepa_ln_done+="$w_id"$'\t'"$w_base"$'\n'
    cepa_ln_n=$((cepa_ln_n + 1))
  done <<<"$cepa_ln_all"
  if [ "$cepa_ln_n" -gt 0 ]; then
    cepa_ln_after=$(cepa_ln_rows) || failed "renamed $cepa_ln_n lane(s), but the re-list was not complete, so the names are not proved" \
      "check the lane names in Orca's sidebar, then ask this session to run the name block again"
    while IFS=$'\t' read -r d_id d_base; do
      [ -n "$d_id" ] || continue
      cepa_ln_hit=$(while IFS=$'\t' read -r w_id w_path w_base w_mode w_name w_main w_br; do
        [ "$w_id" = "$d_id" ] && echo "$w_mode $w_name"; done <<<"$cepa_ln_after")
      [ "$cepa_ln_hit" = "fixed $d_base" ] \
        || failed "after worktree set, $d_base reads '${cepa_ln_hit:-absent}', not 'fixed $d_base'" \
                  "check lane $d_base in Orca, then ask this session to run the name block again"
      echo "ORCA lane: named $d_base"
    done <<<"$cepa_ln_done"
  fi
  echo "ORCA lane: named $cepa_ln_n lane(s); $cepa_ln_fixed already fixed; $cepa_ln_skip skipped"
  exit 0
fi

cepa_ln_all=$(cepa_ln_rows) || kept "${cepa_ln_lane} unchanged — worktree list was not a complete read of this repo" \
  "check Orca's worktree list for this repo, then ask this session to run the block again"
cepa_ln_gwl=$(git worktree list --porcelain 2>/dev/null) || kept "$cepa_ln_lane unchanged — git worktree list failed" \
  "check git worktree list in the main checkout"

# ---------------------------------------------------------------- create
if [ "$cepa_ln_action" = create ]; then
  cepa_ln_park="chore/$cepa_ln_lane/park"
  while IFS=$'\t' read -r w_id w_path w_base w_mode w_name w_main w_br; do
    [ -n "$w_id" ] || continue
    [ "$w_base" != "$cepa_ln_lane" ] && [ "$w_name" != "$cepa_ln_lane" ] \
      || kept "not created — Orca already lists a worktree named $cepa_ln_lane ($w_path)" \
              "choose another lane name, or use the existing lane $cepa_ln_lane"
  done <<<"$cepa_ln_all"
  while IFS= read -r g; do
    case "$g" in "worktree "*) [ "${g##*/}" != "$cepa_ln_lane" ] \
      || kept "not created — git worktree list already has a worktree named $cepa_ln_lane (${g#worktree })" \
              "choose another lane name, or use the existing lane $cepa_ln_lane" ;; esac
  done <<<"$cepa_ln_gwl"
  ! git show-ref --verify -q "refs/heads/$cepa_ln_park" \
    || kept "not created — branch $cepa_ln_park already exists, and Orca would suffix the new one" \
            "delete branch $cepa_ln_park if it is a leftover, or choose another lane name"
  cepa_ln_orca "$cepa_ln_tmp/create.json" 0 180 worktree create --repo "id:$cepa_ln_rid" --name "$cepa_ln_lane" \
      --branch "$cepa_ln_park" --base-branch "origin/$cepa_ln_base" --no-parent --setup inherit --json \
    || failed "worktree create failed ($(cepa_ln_py err "$cepa_ln_tmp/create.json" || echo "no JSON error; it may have been killed by the 180 s bound, so a lane may exist"))" \
              "check Orca's worktree list for $cepa_ln_lane, then say how to proceed"
  cepa_ln_new=$(cepa_ln_py created "$cepa_ln_tmp/create.json" "$cepa_ln_rid" "$cepa_ln_distro") \
    || failed "worktree create returned a shape this reader does not know; the lane, if made, is kept"
  IFS=$'\t' read -r c_id c_path c_name c_mode <<<"$cepa_ln_new"
  [ "${c_path##*/}" = "$cepa_ln_lane" ] \
    || failed "Orca placed the lane at $c_path, whose basename is not $cepa_ln_lane; it is kept for the operator" \
              "inspect $c_path and remove it in Orca if it is unwanted"
  [ "$c_name" = "$cepa_ln_lane" ] && [ "$c_mode" = fixed ] \
    || failed "the new lane's display name is '$c_name' ($c_mode), not $cepa_ln_lane (fixed); it is kept at $c_path"
  cepa_ln_top=$(git -C "$c_path" rev-parse --show-toplevel 2>/dev/null) || cepa_ln_top=
  [ "$cepa_ln_top" = "$c_path" ] || failed "$c_path is not its own git toplevel; it is kept"
  cepa_ln_br=$(git -C "$c_path" symbolic-ref -q --short HEAD 2>/dev/null) || cepa_ln_br=
  [ "$cepa_ln_br" = "$cepa_ln_park" ] \
    || failed "the new lane is on branch '${cepa_ln_br:-detached}', not $cepa_ln_park; nothing was deleted, and the lane is kept at $c_path"
  cepa_ln_head=$(git -C "$c_path" rev-parse --verify -q HEAD 2>/dev/null) || cepa_ln_head=
  [ -n "$cepa_ln_head" ] || failed "the new lane's HEAD is unreadable; it is kept at $c_path"
  cepa_ln_ahead=$(git rev-list --count "refs/remotes/origin/$cepa_ln_base..refs/heads/$cepa_ln_park" 2>/dev/null) || cepa_ln_ahead=
  [ "$cepa_ln_ahead" = 0 ] \
    || failed "$cepa_ln_park has ${cepa_ln_ahead:-unknown} commit(s) not on origin/$cepa_ln_base, so it was not deleted; the lane is kept at $c_path"
  # The same commit, so detaching changes no file under a running setup.
  git -C "$c_path" checkout -q --detach "$cepa_ln_head" 2>/dev/null \
    || failed "detaching the lane at $cepa_ln_head failed; it is kept at $c_path on $cepa_ln_park"
  git branch -D "$cepa_ln_park" >/dev/null 2>&1 \
    || failed "the lane is parked at $cepa_ln_head, but deleting $cepa_ln_park failed" "delete branch $cepa_ln_park by hand"
  cepa_ln_orca "$cepa_ln_tmp/show.json" 1 15 worktree show --worktree "id:$c_id" --json \
    || failed "the lane is created and parked at $c_path, but worktree show failed, so its name is not proved" \
              "check that lane $cepa_ln_lane shows its name in Orca's sidebar"
  cepa_ln_shown=$(cepa_ln_py shown "$cepa_ln_tmp/show.json" "$c_id") || cepa_ln_shown=
  [ "$cepa_ln_shown" = "$cepa_ln_lane fixed" ] \
    || failed "the lane is created and parked at $c_path, but worktree show reports '${cepa_ln_shown:-an unknown shape}', not '$cepa_ln_lane fixed'" \
              "check that lane $cepa_ln_lane shows its name in Orca's sidebar"
  echo "ORCA lane: created $cepa_ln_lane at $c_path, parked detached at ${cepa_ln_head:0:12} (origin/$cepa_ln_base), named $cepa_ln_lane (fixed); setup policy $cepa_ln_policy — Orca reports no setup result, so read the lane's Setup tab before starting a worker"
  exit 0
fi

# ---------------------------------------------------------------- rm
cepa_ln_hits=0
while IFS=$'\t' read -r w_id w_path w_base w_mode w_name w_main w_br; do
  [ -n "$w_id" ] && [ "$w_main" = 0 ] && [ "$w_base" = "$cepa_ln_lane" ] || continue
  cepa_ln_hits=$((cepa_ln_hits + 1))
  r_id=$w_id r_path=$w_path
done <<<"$cepa_ln_all"
[ "$cepa_ln_hits" -gt 0 ] || kept "kept $cepa_ln_lane — no lane of this repo has that name in Orca's list" \
  "check the lane name (orca worktree list) and ask again"
[ "$cepa_ln_hits" = 1 ] || kept "kept $cepa_ln_lane — $cepa_ln_hits lanes of this repo have that basename" \
  "say which lane to remove"
[ "$r_path" != "$cepa_ln_main" ] || kept "kept $cepa_ln_lane — it is the main checkout" "check the lane name"
case $'\n'"$cepa_ln_gwl"$'\n' in *$'\n'"worktree $r_path"$'\n'*) ;; *)
  kept "kept $cepa_ln_lane — $r_path is not in this repo's git worktree list" "inspect $r_path and Orca's row for it" ;; esac
# The operator names a lane by what the sidebar shows: a fixed name that is
# not <lane>, or another lane showing <lane>, is ambiguous (PR #118 review).
while IFS=$'\t' read -r w_id w_path w_base w_mode w_name w_main w_br; do
  [ -n "$w_id" ] || continue
  if [ "$w_id" = "$r_id" ]; then
    [ "$w_mode" != fixed ] || [ "$w_name" = "$cepa_ln_lane" ] \
      || kept "kept $cepa_ln_lane — the sidebar shows it as '$w_name'" "say which lane to remove, by its sidebar name and path"
  elif [ "$w_name" = "$cepa_ln_lane" ]; then
    kept "kept $cepa_ln_lane — another lane ($w_path) also shows the name $cepa_ln_lane" "say which lane to remove, by its path"
  fi
done <<<"$cepa_ln_all"
cepa_ln_top=$(git -C "$r_path" rev-parse --show-toplevel 2>/dev/null) || cepa_ln_top=
[ "$cepa_ln_top" = "$r_path" ] || kept "kept $cepa_ln_lane — $r_path is not its own git toplevel" "inspect $r_path"
cepa_ln_st=$(git -C "$r_path" status --porcelain --untracked-files=all 2>/dev/null) || cepa_ln_st='git status failed'
[ -z "$cepa_ln_st" ] || kept "kept $cepa_ln_lane — it has changes (${cepa_ln_st%%$'\n'*})" \
  "commit, push or discard the changes in $cepa_ln_lane, then ask again"
# Origin refs are re-read first: a remote-tracking ref of a branch the
# remote already deleted would otherwise vouch for unpushed work.
timeout -k 2 60 git fetch -q --prune origin </dev/null >/dev/null 2>&1 \
  || kept "kept $cepa_ln_lane — git fetch --prune origin failed, so which commits origin holds is unknown" \
          "check the network and the origin remote, then ask again"
# The reflog guard: the same test as cepa:autonomy §11b (owned there).
cepa_ln_head=$(git -C "$r_path" rev-parse --verify -q HEAD 2>/dev/null) || cepa_ln_head=
[ -n "$cepa_ln_head" ] || kept "kept $cepa_ln_lane — HEAD unreadable" "inspect $r_path"
cepa_ln_on=$(git for-each-ref --contains "$cepa_ln_head" --format='%(refname)' refs/remotes/origin/ 2>/dev/null) || cepa_ln_on=
[ -n "$cepa_ln_on" ] || kept "kept $cepa_ln_lane — HEAD $cepa_ln_head is on no origin ref" \
  "push or discard the commit in $cepa_ln_lane, then ask again"
cepa_ln_refl=$(git -C "$r_path" log -g --format=%H HEAD 2>/dev/null) || cepa_ln_refl=
[ -n "$cepa_ln_refl" ] || kept "kept $cepa_ln_lane — HEAD reflog unreadable" "inspect $r_path"
# shellcheck disable=SC2086 # the reflog is a list of SHAs, one word each
cepa_ln_lost=$(git rev-list $(sort -u <<<"$cepa_ln_refl") --not --remotes=origin 2>/dev/null) || cepa_ln_lost='git rev-list failed'
[ -z "$cepa_ln_lost" ] || kept "kept $cepa_ln_lane — HEAD reflog holds a commit no origin ref has (${cepa_ln_lost%%$'\n'*})" \
  "push or recover that commit from $cepa_ln_lane's reflog, then ask again; if it was squash-merged and its branch deleted, say so, and the operator decides whether to expire that lane's reflog"
cepa_ln_orca "$cepa_ln_tmp/ps.json" 1 15 worktree ps --limit 500 --json \
  || kept "kept $cepa_ln_lane — worktree ps failed, so a live agent cannot be ruled out" "check $cepa_ln_lane for a live agent"
cepa_ln_agents=$(cepa_ln_py agents "$cepa_ln_tmp/ps.json" "$r_id") \
  || kept "kept $cepa_ln_lane — worktree ps was not a complete read, so a live agent cannot be ruled out" \
          "check $cepa_ln_lane for a live agent"
[ "$cepa_ln_agents" = 0 ] || kept "kept $cepa_ln_lane — $cepa_ln_agents agent(s) on it in worktree ps" \
  "close the agent in $cepa_ln_lane, then ask again"
cepa_ln_br=$(git -C "$r_path" symbolic-ref -q --short HEAD 2>/dev/null) || cepa_ln_br=
cepa_ln_igs=$(git -C "$r_path" status --porcelain --ignored 2>/dev/null) \
  || kept "kept $cepa_ln_lane — git status --ignored failed, so the ignored files cannot be listed" "inspect $r_path"
cepa_ln_ign=$(sed -n 's/^!! //p' <<<"$cepa_ln_igs")
cepa_ln_ni=0
while IFS= read -r g; do
  [ -n "$g" ] || continue
  cepa_ln_ni=$((cepa_ln_ni + 1))
  [ "$cepa_ln_ni" -le 20 ] && echo "ORCA lane: deleting ignored $g"
done <<<"$cepa_ln_ign"
[ "$cepa_ln_ni" -le 20 ] || echo "ORCA lane: deleting ignored … and $((cepa_ln_ni - 20)) more"
cepa_ln_orca "$cepa_ln_tmp/rm.json" 0 330 worktree rm --worktree "id:$r_id" --run-hooks --json || true
cepa_ln_res=$(cepa_ln_py rmres "$cepa_ln_tmp/rm.json") || cepa_ln_res="unknown"
case "$cepa_ln_res" in
  removed|unknown) ;;
  "worktree_archive_hook_failed "*)
    read -r _ cepa_ln_x <<<"$cepa_ln_res"
    failed "the archive hook failed (exit $cepa_ln_x; its output is not relayed — read it in Orca); Orca removed nothing, and $cepa_ln_lane is kept" \
           "fix the repo's archive hook and ask again; deleting anyway is the operator's own orca worktree rm --allow-failed-archive-hook, never this script's" ;;
  *) failed "worktree rm failed (${cepa_ln_res%% *}); $cepa_ln_lane may be kept" "check lane $cepa_ln_lane in Orca" ;;
esac
# The proof is absence, never the reply.
cepa_ln_after=$(cepa_ln_rows) \
  || failed "removal not proved — the re-list of Orca's worktrees was not complete (rm said: $cepa_ln_res; when unknown, the archive hook may still be running)" \
            "check Orca's worktree list for $cepa_ln_lane"
while IFS=$'\t' read -r w_id w_rest; do
  [ "$w_id" != "$r_id" ] || failed "removal not proved — $cepa_ln_lane is still in Orca's list (rm said: $cepa_ln_res; when unknown, the archive hook may still be running: wait a few minutes before running rm again)" \
                                   "check lane $cepa_ln_lane in Orca"
done <<<"$cepa_ln_after"
cepa_ln_gwl=$(git worktree list --porcelain 2>/dev/null) \
  || failed "removal not proved — git worktree list failed" "check git worktree list"
case $'\n'"$cepa_ln_gwl"$'\n' in *$'\n'"worktree $r_path"$'\n'*)
  failed "removal not proved — $r_path is still in git worktree list" "check git worktree list" ;; esac
if [ -z "$cepa_ln_br" ]; then
  cepa_ln_bmsg="it held no branch (parked)"
elif git rev-parse --verify -q "refs/heads/$cepa_ln_br" >/dev/null 2>&1; then
  cepa_ln_bmsg="Orca kept branch $cepa_ln_br (it keeps a branch it cannot prove merged)"
else
  cepa_ln_bmsg="Orca deleted branch $cepa_ln_br"
fi
echo "ORCA lane: removed $cepa_ln_lane ($r_path) — absent from Orca's list and git worktree list; $cepa_ln_ni ignored path(s) deleted; $cepa_ln_bmsg"
exit 0
