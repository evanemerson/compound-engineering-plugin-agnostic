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
#     confirm: <wt>    rm only, and required: the lane again (review finding
#                      #17), so one misfilled value cannot select a lane.
#   `name` takes cli and action only, and refuses lane, base or confirm; `rm`
#   refuses base (it tests no base: the operator's #4 decision dropped the
#   squash-blind `origin/<base>..<branch>` test, so base had no use); create
#   refuses confirm.
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
#   create  0. Re-fetch origin/<base> (60 s bound; review finding #28 and
#              L76), before the lists are read. A failure refuses: the lane's
#              orca.yaml and base would be unknown; `ls-remote --exit-code`
#              (10 s bound) tells a missing base from a network fault.
#           1. Refuse when a worktree of this repo (Orca's list or `git
#              worktree list`) already has the basename or display name
#              <lane>, or `refs/heads/chore/<lane>/park` exists: Orca does
#              not refuse a taken name, it suffixes the path and the branch
#              (U1 below). One shape is RESUMED instead (review finding #4):
#              exactly one non-main Orca lane with basename and fixed name
#              <lane>, in `git worktree list`, its own toplevel, with branch
#              chore/<lane>/park present and the lane either on it or
#              detached at its tip — a create that stopped in step 4 or 5.
#              A resume skips steps 1b, 2 and 3; it still runs step 0, so
#              it needs the network. A lane absent from Orca's list is never
#              re-created by a re-run while Orca may still be creating it:
#              see step 2b.
#          1b. L76: read origin/<base>'s orca.yaml. Refuse when the repo's
#              saved hook settings (the `repo list` row's `hookSettings`)
#              shadow its `scripts.setup` (H1 below). A read or shape this
#              script does not know refuses (default-deny).
#           2. `worktree create --repo id:<repoId> --name <lane> --branch
#              chore/<lane>/park --base-branch origin/<base> --no-parent
#              --setup inherit --json` (review finding #18: the repo's own
#              setup policy decides; the summary prints it).
#          2b. L79: Orca keeps creating after its CLI gives up. Only a
#              definite Orca error code is a failed create. `runtime_timeout`,
#              no JSON (the 180 s bound's kill looks like this), or a non-zero
#              exit with no code is NO RESULT: read `worktree list` at most 12
#              times, 10 s apart, the last read starting before 120 s. A row
#              with basename or display name <lane> that reads fixed and
#              <lane> goes to step 3; a row that never settles goes to step 3
#              as it stands. Two rows stop here, all kept. No row is a failure
#              (exit 3) that says a lane may still appear and to re-check
#              Orca's list, never to start another create: that made
#              `<lane>-2` in the L79 report. A lane that shows later is
#              resumed by a re-run (step 1).
#           3. From create's JSON, or step 2b's row: the path's basename must
#              be <lane> (finding #14), the display name <lane> and fixed. Then
#              `symbolic-ref` must read chore/<lane>/park (finding #6).
#              A mismatch stops here with the lane kept for the operator.
#           4. Park: re-fetch origin/<base> again (60 s bound; review finding
#              #28: Orca fetched it itself after step 0, so the local ref can
#              be older than the lane; a failed fetch keeps the old ref, which
#              fails closed). The branch must have no commit beyond
#              origin/<base>;
#              detach at the lane's own HEAD commit (the same commit, so no
#              file changes under a running setup); delete that branch.
#           5. `worktree show` by id must report the fixed name <lane>.
#           6. L76 (PR #133 review): re-run 1b's check against the orca.yaml
#              the parked lane holds — Orca's fetch can be newer than step
#              0's, and a resume skipped 1b. The setup has already run, so a
#              shadow or unknown shape here is a failure (exit 3).
#   name    For each non-main worktree of this repo whose displayNameMode is
#           not `fixed`: `worktree set --display-name <basename>` by id. A
#           basename that is not a <wt> name is skipped. Then re-list: each
#           renamed lane must read fixed with its basename. Idempotent.
#           A skipped lane makes the exit 1, with an Ending line (review
#           finding #30), after the renames that could be done.
#   rm      1. Exactly one non-main worktree of this repo has the basename
#              <lane>; it must be its own git toplevel and in `git worktree
#              list`; a fixed sidebar name that is not <lane>, or another
#              lane showing <lane>, is ambiguous and refused.
#           2. Refuse on any tracked or untracked change (`status --porcelain
#              --untracked-files=all`; ignored files excluded here). When every
#              change is a deleted tracked file, the refusal says that after a
#              failed rm it is Orca's partial removal (L77 item 4; this run
#              cannot know that an earlier one failed).
#           3. `git fetch --prune origin` (60 s bound; a failure refuses),
#              then refuse when HEAD is on no origin ref. Then
#              `cepa:autonomy` §11b's plain reflog test (owned there): when
#              a commit in the lane's HEAD reflog is on no origin ref,
#              orca-lane-reflog.sh (L58; its header owns the test, bounded
#              here at 60 s) decides whether each such commit landed. Only
#              its exit 0 with a `landed:` line passes; anything else
#              refuses. An empty HEAD reflog (L77 item 2: it expired) refuses
#              too, and its Ending line gives the re-park that writes a
#              landed entry. The resolved trunk is read here, after the fetch
#              (`cepa_ln_trunk_read` owns how, and how it differs from §8),
#              and passed to orca-lane-reflog.sh (L77 item 1).
#           4. Refuse when `worktree ps` shows an agent on the lane, or the
#              read is not complete. A finished agent blocks as well (`done`
#              also marks an idle live session, T1); when every agent is done,
#              the Ending line lists the terminal handles to close (L77 item
#              3), from one `terminal list` read.
#           5. Refuse unless the main checkout's orca.yaml (where Orca reads
#              the archive hook, U1) is clean in `git status`, not a
#              symlink, and, when present, byte-equal to the resolved trunk's
#              copy on origin (review finding #16 and L77 item 5; hashing the
#              file also sees an edit `skip-worktree` hides from status). An
#              unknown trunk refuses.
#          5b. L76: refuse when the saved hook settings shadow that orca.yaml's
#              `scripts.archive` (H1 below); an unknown shape refuses. List the
#              ignored files and directories it will delete (the operator's #4
#              decision: list them, then remove).
#           6. `worktree rm --worktree id:<id> --run-hooks --json`. Never
#              `--force`, never `--allow-failed-archive-hook`. A failed hook
#              that exits 2 on a lane not at origin/<base> names the re-park
#              (L77 item 6). After any other failed rm, the tracked paths now
#              deleted are reported as Orca's partial removal (L77 item 4).
#           7. Removed only when absent from Orca's list (a complete read)
#              AND from `git worktree list`. The branch the lane held is
#              reported deleted or kept; Orca decides that (U1 below).
#
# Prints one summary line per action (and per renamed lane), and on exit 1 or
# 3 a last line `Ending first line: Needed from you: …`. Exit codes:
#   0  `ORCA lane: created …` (or `resumed and created …`), `ORCA lane: named
#      …`, `ORCA lane: removed …`.
#   1  `ORCA lane: not created — …` or `ORCA lane: kept <lane> — …`: a guard
#      refused, or a read was not complete; Orca was not asked to write.
#      Also `name` when it skipped a lane: it exits 1 AFTER its renames,
#      and its summary line counts the skips.
#   3  `ORCA lane failed: …`: an Orca write failed or was not proved, or the
#      created lane did not match. A lane is never removed by this script to
#      undo a failed create. A create that gave no result is not run again
#      while the lane is absent (step 2b).
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
# T1 — L77 item 3, measured on Orca 1.4.246 (WSL), 2026-11-04, read-only, over
# every repo's rows of `worktree ps --limit 500 --json` and `terminal list
# --json`:
#   - An agent's `paneKey` equals its terminal row's `<tabId>:<leafId>` on 15 of
#     15 agents that have one. Two `done` rows had no terminal (`terminalVerdict:
#     none`, `liveTerminalCount: 0`), and no row read `orphaned: true`.
#   - `done` is not an exit: 8 of the 10 `done` agents had a live terminal, and
#     idle coordinators read `done`.
#   - `terminal list --worktree id:<id> --limit 500 --json` scopes to one lane
#     (its `id:` selector worked); it refuses `--full`.
#
# H1 — L76, read on Orca 1.4.246 (WSL), 2026-11-03, in Orca's installed code
# (resources/app.asar.unpacked/out/shared/hook-command-source-policy.js,
# orca-hook-setup-config.js, setup-agent-startup-policy.js; app.asar
# out/main/index.js functions `To`, `ide`, `ade`, `Kde`), read-only. No Orca
# setting was changed.
#   - Each script (setup, archive) resolves on its own. The source policy is
#     hookSettings.commandSourcePolicy when it is `local-only`, `run-both` or
#     `shared-only`. When it is UNSET and the saved local script for that hook
#     is non-empty after trim, it is `local-only`. Otherwise `shared-only`.
#   - `local-only` runs the trimmed local script, or nothing when it is empty;
#     orca.yaml's script never runs. `run-both` runs orca.yaml's, then the
#     local one. `shared-only` runs orca.yaml's only.
#   - So a shadow is: resolved `local-only` with a local script that differs
#     from orca.yaml's (after trim; both empty is no shadow, as nothing runs
#     either way), or `run-both` with a non-empty local script.
#   - Start policy: the setup runner waits when
#     `[saved, orca.yaml].includes("wait-for-setup")`. Either side's
#     `wait-for-setup` wins, so a saved `start-immediately` never overrides
#     orca.yaml's `wait-for-setup`. No check for it is needed.
#   - `repo show --repo id:<repoId> --json` returns the same `hookSettings`
#     object as the `repo list` row this script reads (compared for this repo).
#     Every one of the 16 `repo list` rows read on 2026-11-03 carried
#     `hookSettings.scripts`, so a row without it is refused, not defaulted.
#   - The check decides from what the CLI returns. Orca's Settings UI can show
#     a different source: kcprimetime's showed "orca.yaml" while `repo show`
#     still read `commandSourcePolicy: local-only` with an empty local setup
#     (reported by its coord@main). After a create, the proof of what ran is
#     `.git/worktrees/<lane>/orca/setup-runner.sh` (absent when nothing ran).
#     The CLI has no setter (`repo set` takes only
#     --external-worktree-visibility): the fix is in Orca's Settings.
#   - Field evidence (reported, not measured here): kcprimetime's lanes had
#     `set -e; npm install` (the local script) in
#     `.git/worktrees/<lane>/orca/setup-runner.sh`. This repo has no setup in
#     either source, so its lanes have no runner file to compare.
#
# STATED LIMITS:
#   - H1 is read from minified code of one Orca version. A later Orca can
#     change the rule: re-read it when Orca updates. The orca.yaml reader takes
#     only plain, single- or double-quoted scalars under a block `scripts:`
#     map; any other shape refuses. It does not detect YAML that Orca rejects
#     as a whole (Orca then runs no orca.yaml script).
#   - Under resolved `local-only`, Orca also runs no `defaultTabs` command from
#     orca.yaml (H1, `ode`). A matching local setup passes here anyway; the
#     tabs open without their commands.
#   - The settings are read before `create`; an operator who edits them
#     during the create is not seen.
#   - The setup result is not proved (above). A worker started with
#     `worker-start` under a `wait-for-setup` policy waits for it; under
#     `start-immediately` it does not. The summary names the policy.
#   - Check-then-create is not atomic: two coordinators creating one <lane> at
#     once can both pass step 1. One coord@main per repo makes it rare; the
#     basename check in step 3 then stops the second.
#   - `rm` runs the repo's archive hook with Orca's own bound; the script
#     bounds the call at 300 s. Worst case about 575 s of bounded calls:
#     four reads at 2 x 17 s, the fetch 62 s, the trunk read 12 s, the reflog
#     check 62 s, rm 302 s; local git work (measured 2-10 s on the 2026-11-01
#     lanes) comes on top. The `terminal list` read is not in that sum: it
#     runs only on the way to `kept`, so `rm` never follows it. Run the block
#     with a tool timeout of 10 minutes. A call the bound killed reads as
#     "removal not proved"; Orca's hook may still be running on the server
#     then.
#   - `create` worst case about 562 s of bounded calls, inside that same 10
#     minutes: repo list 34 s, the step 0 fetch 62 s, worktree list 34 s,
#     create 182 s, step 2b 154 s (its last read starts before 120 s and is
#     bounded at 2 x 17 s), the re-fetch 62 s, show 34 s; local git work comes
#     on top. A new bounded call in create must be counted against this.
#   - Step 2b can end before Orca does (L79 saw "minutes"), and nothing stops
#     a session that starts another create while the lane is absent: the
#     Ending line is the only guard, and Orca then suffixes the second lane.
#   - The trunk override is read from `trunk:` under `## Conventions`, as a
#     plain or bulleted line. Any other spelling reads as no override, which
#     falls to origin's default and can only keep more lanes.
#   - The archive hook's output is never relayed (repo rule: relayed content
#     is stripped); the failure line gives its exit code only.
#   - The live-agent check sees agents Orca knows (`worktree ps`). A session
#     started from a plain terminal is not seen, and the checks and the
#     `rm` are not atomic.
#   - A reflog commit orca-lane-reflog.sh cannot show landed is refused;
#     the operator decides. That script states its own limits.
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
unset cepa_ln_f_cli cepa_ln_f_action cepa_ln_f_lane cepa_ln_f_base cepa_ln_f_confirm
cepa_ln_seen=" "
while IFS= read -r cepa_ln_line || [ -n "$cepa_ln_line" ]; do
  cepa_ln_line=${cepa_ln_line%$'\r'}
  [ -n "$cepa_ln_line" ] || break
  [[ $cepa_ln_line =~ ^([a-z]+):(\ (.*))?$ ]] || refuse "a heredoc line is not a <name>: <value> field"
  cepa_ln_k=${BASH_REMATCH[1]} cepa_ln_v=${BASH_REMATCH[3]}
  cepa_ln_v=${cepa_ln_v%"${cepa_ln_v##*[![:space:]]}"}
  case "$cepa_ln_k" in cli|action|lane|base|confirm) ;; *) refuse "a field name is not cli, action, lane, base or confirm" ;; esac
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
    [[ $cepa_ln_seen != *" base "* ]] || refuse "name takes no base field"
    [[ $cepa_ln_seen != *" confirm "* ]] || refuse "name takes no confirm field" ;;
  rm)
    [[ $cepa_ln_seen == *" lane "* ]] || refuse "the lane field is missing"
    [[ $cepa_ln_seen != *" base "* ]] || refuse "rm takes no base field"
    [[ $cepa_ln_seen == *" confirm "* ]] || refuse "rm needs a confirm field that repeats the lane" ;;
  create)
    [[ $cepa_ln_seen == *" lane "* ]] || refuse "the lane field is missing"
    [[ $cepa_ln_seen == *" base "* ]] || refuse "the base field is missing"
    [[ $cepa_ln_seen != *" confirm "* ]] || refuse "create takes no confirm field" ;;
esac
cepa_ln_wt_re='^[A-Za-z0-9_]+(-[A-Za-z0-9_]+)*$'
if [[ $cepa_ln_seen == *" lane "* ]]; then
  cepa_ln_lane=$cepa_ln_f_lane
  [[ $cepa_ln_lane =~ $cepa_ln_wt_re ]] && [ "${#cepa_ln_lane}" -le 64 ] \
    || refuse "the lane is not a <wt> name ([A-Za-z0-9_] runs joined by single -, at most 64)"
  [ "$cepa_ln_lane" != main ] || refuse "the lane may not be main (reserved for the main checkout)"
fi
# rm's confirm repeats the lane (review finding #17): a removal names its lane
# twice, so one mistyped or misfilled value cannot select a lane.
if [ "$cepa_ln_action" = rm ]; then
  [ "$cepa_ln_f_confirm" = "$cepa_ln_lane" ] || refuse "the confirm field does not repeat the lane"
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
elif mode == "hook":
    # L76: does Orca run the orca.yaml scripts.<which>, or a saved local one?
    # the Orca 1.4.246 resolver (header, H1) is mirrored here. Any shape it
    # does not name exits 1: UNKNOWN, so the caller refuses.
    main, distro, which, yf = args
    if not isinstance(r, dict) or not isinstance(r.get("repos"), list):
        sys.exit(1)
    hit = [x for x in r["repos"] if isinstance(x, dict) and linux(x.get("path"), distro) == main]
    if len(hit) != 1:
        sys.exit(1)
    hs = hit[0].get("hookSettings")
    if not isinstance(hs, dict) or not isinstance(hs.get("scripts"), dict):
        sys.exit(1)
    loc = hs["scripts"].get(which, "")
    if not isinstance(loc, str):
        sys.exit(1)
    # Orca trims with JS String.prototype.trim; Python strip() takes another
    # set (it strips \x1c-\x1f and \x85, keeps \ufeff), so use JS set.
    JS_WS = "\t\n\x0b\x0c\r \xa0\u1680\u2028\u2029\u202f\u205f\u3000\ufeff" + "".join(map(chr, range(0x2000, 0x200b)))
    loc = loc.strip(JS_WS)
    pol = hs.get("commandSourcePolicy")
    if pol is not None and pol not in ("local-only", "run-both", "shared-only"):
        sys.exit(1)
    eff = pol or ("local-only" if loc else "shared-only")
    if eff == "shared-only":
        print("ok")
        sys.exit(0)

    def ymlscript(text):
        # Only the plain shapes the lane-stack contract uses. Anything else
        # (block scalar, flow map, continuation, duplicate, tab, a YAML
        # null/bool/number, and any top-level line that is not a plain key,
        # so a BOM, a quoted key and an indented document) is UNKNOWN: a
        # skipped spelling must never read as "no script" (PR #133 review).
        found, inside, child, seen, top = None, False, None, False, False
        for l in text.split("\n"):
            l = l.rstrip("\r")
            if len(l) > 4096:
                sys.exit(1)
            s = l.strip()
            if not s or s.startswith("#"):
                continue
            ind = len(l) - len(l.lstrip(" "))
            if l[ind:ind + 1] == "\t":
                sys.exit(1)
            if ind == 0:
                inside = False
                if s == "---" and not top:
                    continue
                if not re.match(r"[A-Za-z_][A-Za-z0-9_-]*\s*:(\s|$)", s):
                    sys.exit(1)
                top = True
                if re.match(r"scripts\s*:", s):
                    rest = s.split(":", 1)[1].strip()
                    if seen or (rest and not rest.startswith("#")):
                        sys.exit(1)
                    seen, inside, child = True, True, None
                continue
            if not top:
                sys.exit(1)
            if not inside:
                continue
            child = ind if child is None else child
            m = re.fullmatch(r"([A-Za-z_][A-Za-z0-9_-]*)\s*:(?:\s+(.*))?", s)
            if ind != child or not m:
                sys.exit(1)
            if m.group(1) != which:
                continue
            if found is not None:
                sys.exit(1)
            v = (m.group(2) or "").strip()
            if not v or v.startswith("#"):
                found = ""
            elif v[0] == "\x27":
                q = re.fullmatch(r"\x27((?:[^\x27]|\x27\x27)*)\x27(?:\s+#.*)?", v)
                if not q:
                    sys.exit(1)
                found = q.group(1).replace("\x27\x27", "\x27")
            elif v[0] == "\"":
                q = re.fullmatch(r"\"([^\"\\\\]*)\"(?:\s+#.*)?", v)
                if not q:
                    sys.exit(1)
                found = q.group(1)
            elif v[0] in "|>[{&*!@`%":
                sys.exit(1)
            else:
                v = re.sub(r"\s+#.*$", "", v)
                if ": " in v or v.endswith(":"):
                    sys.exit(1)
                if re.fullmatch(r"(?i)~|null|true|false|yes|no|on|off|[-+]?[0-9][0-9._eExXoObB+-]*|[-+]?\.(inf|nan)", v):
                    sys.exit(1)
                found = v
        return (found or "").strip(JS_WS)

    try:
        y = ymlscript(open(yf, encoding="utf-8").read()) if yf else ""
    except (OSError, UnicodeError):
        sys.exit(1)
    named = "commandSourcePolicy %s" % (pol or "unset (Orca reads it as local-only while a local %s script is saved)" % which)
    if eff == "run-both" and loc:
        print("shadow: %s runs the local %s script as well as the orca.yaml one" % (named, which))
    elif eff == "local-only" and loc != y:
        print("shadow: %s runs the local %s script (%s), not the orca.yaml one (%s)"
              % (named, which, "empty" if not loc else "differs", "empty" if not y else "present"))
    else:
        print("ok")
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
elif mode == "terms":
    # L77 item 3: which terminals hold the finished agents of this lane. The
    # paneKey of an agent is the tabId:leafId of its terminal (header, T1).
    # Prints the live count, the count of finished agents with no terminal
    # row, then the handles.
    wid, tf = args
    if not isinstance(r, dict):
        sys.exit(1)
    rows = [w for w in complete(r, "worktrees") if isinstance(w, dict) and w.get("worktreeId") == wid]
    if len(rows) != 1 or not isinstance(rows[0].get("agents"), list):
        sys.exit(1)
    try:
        t = json.load(open(tf))
    except Exception:
        sys.exit(1)
    tr = t.get("result") if isinstance(t, dict) and t.get("ok") is True else None
    if not isinstance(tr, dict):
        sys.exit(1)
    terms = [x for x in complete(tr, "terminals") if isinstance(x, dict) and x.get("worktreeId") == wid]
    panes = {}
    for x in terms:
        h = x.get("handle")
        if not (isinstance(h, str) and re.fullmatch(r"term_[A-Za-z0-9-]{1,64}", h)):
            sys.exit(1)
        panes["%s:%s" % (x.get("tabId"), x.get("leafId"))] = h
    live, noterm, hs = 0, 0, []
    for a in rows[0]["agents"]:
        if not isinstance(a, dict) or a.get("state") != "done":
            live += 1
        elif a.get("paneKey") not in panes:
            noterm += 1
        elif panes[a["paneKey"]] not in hs:
            hs.append(panes[a["paneKey"]])
    for x in terms:
        if x.get("orphaned") is True and x["handle"] not in hs:
            hs.append(x["handle"])
    print(live, noterm, *hs)
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
  # A skip is not a pass (review finding #30): a caller that reads only the
  # last lines still sees it.
  [ "$cepa_ln_skip" = 0 ] || { echo "Ending first line: Needed from you: name the $cepa_ln_skip skipped lane(s) above in Orca's sidebar, or say to leave them"; exit 1; }
  exit 0
fi

# L76: the hook check of $2 (setup or archive) against the orca.yaml in
# tree-ish $1. Prints `ok` or `shadow: …`; returns 1 when UNKNOWN. Absence is
# read positively (PR #133 review): ls-tree must succeed, and an entry must be
# a regular blob, so a failed read is never "no orca.yaml".
cepa_ln_hookat() {
  local t yf=
  t=$(git ls-tree "$1" -- orca.yaml 2>/dev/null) || return 1
  if [ -n "$t" ]; then
    [[ $t == "100644 blob "*$'\t'orca.yaml ]] || return 1
    yf="$cepa_ln_tmp/orca.yaml"
    git cat-file blob "$1:orca.yaml" >"$yf" 2>/dev/null || return 1
  fi
  cepa_ln_py hook "$cepa_ln_tmp/repos.json" "$cepa_ln_main" "$cepa_ln_distro" "$2" "$yf"
}

# create step 0 (review finding #28 and L76): Orca fetches the base itself,
# so the local origin/<base> can be older than the lane and its orca.yaml.
# Fetched before the lists are read, so no slow fetch sits between those
# reads and `worktree create` (PR #133 review).
if [ "$cepa_ln_action" = create ]; then
  timeout -k 2 60 git fetch -q origin "+refs/heads/$cepa_ln_base:refs/remotes/origin/$cepa_ln_base" </dev/null >/dev/null 2>&1 \
    || { cepa_ln_lrc=0
         timeout -k 2 10 git ls-remote -q --exit-code origin "refs/heads/$cepa_ln_base" </dev/null >/dev/null 2>&1 || cepa_ln_lrc=$?
         [ "$cepa_ln_lrc" != 2 ] || kept "$cepa_ln_lane unchanged — origin has no branch $cepa_ln_base" "check the base field"
         kept "$cepa_ln_lane unchanged — git fetch of origin/$cepa_ln_base failed, so the lane's orca.yaml and base are unknown" \
              "check the network and the origin remote, then ask this session to run create again"; }
fi
cepa_ln_all=$(cepa_ln_rows) || kept "${cepa_ln_lane} unchanged — worktree list was not a complete read of this repo" \
  "check Orca's worktree list for this repo, then ask this session to run the block again"
cepa_ln_gwl=$(git worktree list --porcelain 2>/dev/null) || kept "$cepa_ln_lane unchanged — git worktree list failed" \
  "check git worktree list in the main checkout"

# create step 2b (L79): read Orca's list until the lane shows, in the shape step
# 3 wants. At most 12 reads, 10 s apart, the last one starting before 120 s;
# the header's worst case counts that. An incomplete read is no evidence. A row
# that is not settled yet (not fixed, or not named <lane>) is read again, and
# goes to step 3 as it stands when the time ends. Returns 0 with c_* set.
cepa_ln_poll() {
  local t0 rows hits
  cepa_ln_pn=0 cepa_ln_pgood=0
  t0=$(date +%s)
  while :; do
    cepa_ln_pn=$((cepa_ln_pn + 1))
    if rows=$(cepa_ln_rows); then
      cepa_ln_pgood=$((cepa_ln_pgood + 1))
      hits=0 c_id=
      while IFS=$'\t' read -r w_id w_path w_base w_mode w_name w_main w_br; do
        [ -n "$w_id" ] || continue
        [ "$w_base" = "$cepa_ln_lane" ] || [ "$w_name" = "$cepa_ln_lane" ] || continue
        hits=$((hits + 1))
        c_id=$w_id c_path=$w_path c_name=$w_name c_mode=$w_mode
      done <<<"$rows"
      [ "$hits" -le 1 ] \
        || failed "worktree create gave no result, and Orca's list now shows $hits worktrees named $cepa_ln_lane; all are kept" \
                  "inspect the $cepa_ln_lane rows in Orca's worktree list and say which lane to keep"
      [ "$hits" = 0 ] || [ "$c_mode $c_name" != "fixed $cepa_ln_lane" ] || return 0
    fi
    [ "$cepa_ln_pn" -lt 12 ] && [ $(($(date +%s) - t0 + 10)) -lt 120 ] || break
    sleep 10
  done
  [ -n "${c_id:-}" ]
}

# ---------------------------------------------------------------- create
if [ "$cepa_ln_action" = create ]; then
  cepa_ln_park="chore/$cepa_ln_lane/park"
  # Resume (review finding #4): a create that took effect but stopped before
  # its park finished leaves a lane that still has the park branch. Exactly
  # that shape is resumed; any other worktree with the name is refused.
  cepa_ln_taken=0 cepa_ln_resume=
  while IFS=$'\t' read -r w_id w_path w_base w_mode w_name w_main w_br; do
    [ -n "$w_id" ] || continue
    [ "$w_base" = "$cepa_ln_lane" ] || [ "$w_name" = "$cepa_ln_lane" ] || continue
    cepa_ln_taken=$((cepa_ln_taken + 1))
    t_id=$w_id t_path=$w_path t_base=$w_base t_mode=$w_mode t_name=$w_name t_main=$w_main
  done <<<"$cepa_ln_all"
  if [ "$cepa_ln_taken" -gt 0 ]; then
    cepa_ln_why=
    if [ "$cepa_ln_taken" != 1 ]; then cepa_ln_why="$cepa_ln_taken worktrees have that name"
    elif [ "$t_main" != 0 ] || [ "$t_base" != "$cepa_ln_lane" ] || [ "$t_name" != "$cepa_ln_lane" ] || [ "$t_mode" != fixed ]; then
      cepa_ln_why="it is not a lane named $cepa_ln_lane (fixed)"
    elif ! git show-ref --verify -q "refs/heads/$cepa_ln_park"; then cepa_ln_why="no $cepa_ln_park branch, so no partial create to resume"
    else
      case $'\n'"$cepa_ln_gwl"$'\n' in *$'\n'"worktree $t_path"$'\n'*) ;; *) cepa_ln_why="$t_path is not in git worktree list" ;; esac
    fi
    if [ -z "$cepa_ln_why" ]; then
      cepa_ln_top=$(git -C "$t_path" rev-parse --show-toplevel 2>/dev/null) || cepa_ln_top=
      cepa_ln_br=$(git -C "$t_path" symbolic-ref -q --short HEAD 2>/dev/null) || cepa_ln_br=
      cepa_ln_head=$(git -C "$t_path" rev-parse --verify -q HEAD 2>/dev/null) || cepa_ln_head=
      if [ "$cepa_ln_top" != "$t_path" ]; then cepa_ln_why="$t_path is not its own git toplevel"
      elif [ "$cepa_ln_br" != "$cepa_ln_park" ] && { [ -n "$cepa_ln_br" ] \
             || [ "$cepa_ln_head" != "$(git rev-parse -q --verify "refs/heads/$cepa_ln_park" 2>/dev/null)" ]; }; then
        cepa_ln_why="it is neither on $cepa_ln_park nor detached at its tip"
      fi
    fi
    [ -z "$cepa_ln_why" ] || kept "not created — Orca already lists a worktree named $cepa_ln_lane ($t_path), and it is no partial create to resume: $cepa_ln_why" \
                                  "choose another lane name, or use the existing lane $cepa_ln_lane"
    cepa_ln_resume=1 c_id=$t_id c_path=$t_path
  else
    while IFS= read -r g; do
      case "$g" in "worktree "*) [ "${g##*/}" != "$cepa_ln_lane" ] \
        || kept "not created — git worktree list already has a worktree named $cepa_ln_lane (${g#worktree })" \
                "choose another lane name, or use the existing lane $cepa_ln_lane" ;; esac
    done <<<"$cepa_ln_gwl"
    ! git show-ref --verify -q "refs/heads/$cepa_ln_park" \
      || kept "not created — branch $cepa_ln_park already exists, and Orca would suffix the new one" \
              "delete branch $cepa_ln_park if it is a leftover, or choose another lane name"
    # L76: Orca reads scripts.setup from the new lane's orca.yaml (the base's,
    # U1), unless the repo's saved hook settings shadow it (H1).
    cepa_ln_hook=$(cepa_ln_hookat "refs/remotes/origin/$cepa_ln_base" setup) \
      || kept "not created — Orca's saved hook settings for this repo, or orca.yaml's scripts.setup, have a shape this reader does not know, so which setup Orca would run is unknown" \
              "check Settings > Repositories > this repo's hooks in Orca, and orca.yaml's scripts.setup, then ask again"
    [ "$cepa_ln_hook" = ok ] \
      || kept "not created — Orca's saved hook settings shadow orca.yaml: ${cepa_ln_hook#shadow: }" \
              "in Orca, open Settings > Repositories > this repo's hooks and make the setup command come from orca.yaml (or make the local setup equal orca.yaml's scripts.setup), then ask again"
    cepa_ln_crc=0 cepa_ln_new=
    cepa_ln_orca "$cepa_ln_tmp/create.json" 0 180 worktree create --repo "id:$cepa_ln_rid" --name "$cepa_ln_lane" \
        --branch "$cepa_ln_park" --base-branch "origin/$cepa_ln_base" --no-parent --setup inherit --json \
      || cepa_ln_crc=1
    [ "$cepa_ln_crc" != 0 ] || cepa_ln_new=$(cepa_ln_py created "$cepa_ln_tmp/create.json" "$cepa_ln_rid" "$cepa_ln_distro") || cepa_ln_new=
    if [ -n "$cepa_ln_new" ]; then
      IFS=$'\t' read -r c_id c_path c_name c_mode <<<"$cepa_ln_new"
    else
      # L79: only a definite Orca error is a failed create. Orca keeps creating
      # after its CLI gives up, so a timeout, no JSON, or the bound's kill says
      # nothing about the lane: step 2b reads Orca's list instead.
      cepa_ln_cerr=$(cepa_ln_py err "$cepa_ln_tmp/create.json") || cepa_ln_cerr=
      case "$cepa_ln_crc:$cepa_ln_cerr" in
        *:runtime_timeout) cepa_ln_cwhy=runtime_timeout ;;
        *:) cepa_ln_cwhy="no JSON; the 180 s bound may have killed it" ;;
        "1:?") cepa_ln_cwhy="no error code" ;;
        0:*) failed "worktree create returned a shape this reader does not know; the lane, if made, is kept" ;;
        *) failed "worktree create failed ($cepa_ln_cerr)" "check Orca's worktree list for $cepa_ln_lane, then say how to proceed" ;;
      esac
      echo "ORCA lane: worktree create gave no result ($cepa_ln_cwhy); Orca may still be creating $cepa_ln_lane, so reading its list for up to 120 s"
      cepa_ln_poll \
        || failed "worktree create gave no result ($cepa_ln_cwhy), and Orca's list shows no lane $cepa_ln_lane after up to 120 s ($cepa_ln_pgood of $cepa_ln_pn reads complete); a lane may still appear, because Orca keeps creating after its CLI gives up" \
                  "do not start another create: re-check Orca's worktree list for $cepa_ln_lane in a few minutes; when it lists $cepa_ln_lane, ask this session to resume it; if it stays absent, say how to proceed"
      echo "ORCA lane: Orca's list shows $cepa_ln_lane at $c_path; resuming from step 3"
    fi
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
  fi
  [ -n "$cepa_ln_head" ] || failed "the new lane's HEAD is unreadable; it is kept at $c_path"
  # Review finding #28: Orca fetched the base itself, after step 0, so the
  # local origin/<base> can be older than the lane. Re-read it; a failed fetch
  # leaves the old ref, which can only fail closed (the lane is kept, and a
  # re-run resumes: the lane exists, so step 2b's rule does not apply).
  cepa_ln_fetch=
  timeout -k 2 60 git fetch -q origin "+refs/heads/$cepa_ln_base:refs/remotes/origin/$cepa_ln_base" </dev/null >/dev/null 2>&1 \
    || cepa_ln_fetch="; the re-fetch of origin/$cepa_ln_base failed, so that count may be stale"
  cepa_ln_ahead=$(git rev-list --count "refs/remotes/origin/$cepa_ln_base..refs/heads/$cepa_ln_park" 2>/dev/null) || cepa_ln_ahead=
  [ "$cepa_ln_ahead" = 0 ] \
    || failed "$cepa_ln_park has ${cepa_ln_ahead:-unknown} commit(s) not on origin/$cepa_ln_base, so it was not deleted; the lane is kept at $c_path$cepa_ln_fetch" \
              "check $cepa_ln_park, then ask this session to run create again: it resumes"
  # The same commit, so detaching changes no file under a running setup.
  if [ -n "$cepa_ln_br" ]; then
    git -C "$c_path" checkout -q --detach "$cepa_ln_head" 2>/dev/null \
      || failed "detaching the lane at $cepa_ln_head failed; it is kept at $c_path on $cepa_ln_park" \
                "check $c_path (an index.lock from a running setup?), then ask this session to run create again: it resumes"
  fi
  git branch -D "$cepa_ln_park" >/dev/null 2>&1 \
    || failed "the lane is parked at $cepa_ln_head, but deleting $cepa_ln_park failed" \
              "ask this session to run create again (it resumes), or delete branch $cepa_ln_park by hand"
  cepa_ln_orca "$cepa_ln_tmp/show.json" 1 15 worktree show --worktree "id:$c_id" --json \
    || failed "the lane is created and parked at $c_path, but worktree show failed, so its name is not proved" \
              "check that lane $cepa_ln_lane shows its name in Orca's sidebar"
  cepa_ln_shown=$(cepa_ln_py shown "$cepa_ln_tmp/show.json" "$c_id") || cepa_ln_shown=
  [ "$cepa_ln_shown" = "$cepa_ln_lane fixed" ] \
    || failed "the lane is created and parked at $c_path, but worktree show reports '${cepa_ln_shown:-an unknown shape}', not '$cepa_ln_lane fixed'" \
              "check that lane $cepa_ln_lane shows its name in Orca's sidebar"
  # PR #133 review: Orca used the lane's own orca.yaml (the base at Orca's
  # fetch, U1), which differs from the one checked before create when origin
  # moved in between; a resume never ran that check. Re-check the file the
  # lane holds. Its setup has already run, so a shadow here is a failure.
  cepa_ln_hook=$(cepa_ln_hookat "$cepa_ln_head" setup) \
    || failed "the lane is created and parked at $c_path, but which setup Orca ran is unknown: Orca's saved hook settings, or the lane's orca.yaml scripts.setup, have a shape this reader does not know" \
              "read the lane's Setup tab, and check Settings > Repositories > this repo's hooks in Orca"
  [ "$cepa_ln_hook" = ok ] \
    || failed "the lane is created and parked at $c_path, but Orca's saved hook settings shadow its orca.yaml: ${cepa_ln_hook#shadow: }" \
              "fix the repo's hooks in Orca's Settings, then remove and re-create lane $cepa_ln_lane (orca-lane.sh rm, then create)"
  echo "ORCA lane: ${cepa_ln_resume:+resumed and }created $cepa_ln_lane at $c_path, parked detached at ${cepa_ln_head:0:12} (at or behind origin/$cepa_ln_base), named $cepa_ln_lane (fixed); setup policy $cepa_ln_policy — Orca reports no setup result, so read the lane's Setup tab before starting a worker"
  exit 0
fi

# ---------------------------------------------------------------- rm
# The trunk rm compares with (L77 items 1 and 5), read after the fetch. §8's
# rung 1 comes from the MAIN checkout's cepa.local.md, the only copy: the file
# is gitignored. Rungs 2-3 are origin/HEAD, else `git ls-remote --symref` (10 s
# bound). There is no rung 4: a guessed `main` is unknown here, and an override
# this reader cannot use is unknown too, with no fallback to the default.
# Sets cepa_ln_trunk (empty when unknown), cepa_ln_trunk_why, and cepa_ln_tip
# and cepa_ln_tiprev for the Ending lines that name origin/<base>.
cepa_ln_trunk_read() {
  local f="$cepa_ln_main/cepa.local.md" sec= l v hits=0 val=
  cepa_ln_trunk= cepa_ln_trunk_why="origin's default branch is unknown"
  if [ -f "$f" ]; then
    while IFS= read -r l || [ -n "$l" ]; do
      l=${l%$'\r'}
      case "$l" in
        '## Conventions'*) sec=1; continue ;;
        '#'*) sec= ;;
      esac
      [ -n "$sec" ] || continue
      [[ $l =~ ^[[:space:]]*([-*][[:space:]]+)?\`?trunk\`?:[[:space:]]*(.*)$ ]] || continue
      v=${BASH_REMATCH[2]}
      v=${v%"${v##*[![:space:]]}"}
      v=${v#\`} v=${v%\`}
      hits=$((hits + 1)) val=${v#origin/}
    done <"$f"
  fi
  if [ "$hits" -gt 1 ]; then
    cepa_ln_trunk_why="cepa.local.md gives trunk: $hits times"
  elif [ "$hits" = 1 ]; then
    if [[ $val =~ ^[A-Za-z0-9._/-]+$ ]] && git check-ref-format "refs/heads/$val" 2>/dev/null; then
      cepa_ln_trunk=$val
    else
      cepa_ln_trunk_why="cepa.local.md's trunk: is not a branch name"
    fi
  else
    v=$(git -C "$cepa_ln_main" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null) || v=
    v=${v#origin/}
    if [ -z "$v" ]; then
      v=$(timeout -k 2 10 git -C "$cepa_ln_main" ls-remote --symref origin HEAD </dev/null 2>/dev/null \
        | sed -n 's#^ref: refs/heads/\([^[:space:]]*\)[[:space:]]*HEAD$#\1#p' | head -n 1) || v=
    fi
    [[ $v =~ ^[A-Za-z0-9_][A-Za-z0-9._/-]{0,99}$ ]] && git check-ref-format "refs/heads/$v" 2>/dev/null && cepa_ln_trunk=$v
  fi
  cepa_ln_tip="origin/${cepa_ln_trunk:-<base>}" cepa_ln_tiprev=
  [ -z "$cepa_ln_trunk" ] || cepa_ln_tiprev=$(git rev-parse -q --verify "refs/remotes/origin/$cepa_ln_trunk^{commit}" 2>/dev/null) || cepa_ln_tiprev=
}

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
# L77 item 4: a failed `worktree rm` can delete tracked files before it stops,
# and this run has no memory of it, so an all-deletions status names that case.
if [ -n "$cepa_ln_st" ] && ! grep -qv '^ D ' <<<"$cepa_ln_st"; then
  kept "kept $cepa_ln_lane — it has changes (${cepa_ln_st%%$'\n'*}), all of them deleted tracked files; after a failed rm, that is Orca's partial removal, not an operator change" \
    "if an earlier rm of $cepa_ln_lane failed, restore the files (git -C $r_path restore .), then ask again; if not, commit, push or discard the changes"
fi
[ -z "$cepa_ln_st" ] || kept "kept $cepa_ln_lane — it has changes (${cepa_ln_st%%$'\n'*})" \
  "commit, push or discard the changes in $cepa_ln_lane, then ask again"
# Origin refs are re-read first: a remote-tracking ref of a branch the
# remote already deleted would otherwise vouch for unpushed work.
timeout -k 2 60 git fetch -q --prune origin </dev/null >/dev/null 2>&1 \
  || kept "kept $cepa_ln_lane — git fetch --prune origin failed, so which commits origin holds is unknown" \
          "check the network and the origin remote, then ask again"
cepa_ln_trunk_read
# HEAD, then cepa:autonomy §11b's plain reflog test (owned there).
cepa_ln_head=$(git -C "$r_path" rev-parse --verify -q HEAD 2>/dev/null) || cepa_ln_head=
[ -n "$cepa_ln_head" ] || kept "kept $cepa_ln_lane — HEAD unreadable" "inspect $r_path"
cepa_ln_on=$(git for-each-ref --contains "$cepa_ln_head" --format='%(refname)' refs/remotes/origin/ 2>/dev/null) || cepa_ln_on=
[ -n "$cepa_ln_on" ] || kept "kept $cepa_ln_lane — HEAD $cepa_ln_head is on no origin ref" \
  "push or discard the commit in $cepa_ln_lane, then ask again"
cepa_ln_refl=$(git -C "$r_path" log -g --format=%H HEAD 2>/dev/null) \
  || kept "kept $cepa_ln_lane — HEAD reflog unreadable" "inspect $r_path"
# L77 item 2: an expired reflog is empty, and empty proves nothing. A checkout
# that does not move HEAD writes no entry (measured 2026-11-04), so a lane at
# the tip has to move first.
if [ -z "$cepa_ln_refl" ]; then
  cepa_ln_step="git -C $r_path checkout --detach $cepa_ln_tip"
  [ "$cepa_ln_head" != "$cepa_ln_tiprev" ] \
    || cepa_ln_step="git -C $r_path checkout --detach $cepa_ln_tip~1, then $cepa_ln_step"
  kept "kept $cepa_ln_lane — HEAD reflog is empty (expired?), so which commits it held is unknown" \
    "re-park $cepa_ln_lane at $cepa_ln_tip to write a landed entry ($cepa_ln_step), then ask again"
fi
# shellcheck disable=SC2086 # the reflog is a list of SHAs, one word each
cepa_ln_lost=$(git rev-list $(sort -u <<<"$cepa_ln_refl") --not --remotes=origin 2>/dev/null) \
  || kept "kept $cepa_ln_lane — git rev-list over the HEAD reflog failed" "inspect $r_path"
# A reused lane's reflog holds the squash-merged commits of deleted branches
# (L58): orca-lane-reflog.sh owns the test that extends §11b's here. It is
# bounded, and only exit 0 with a `landed:` line passes (PR #123 review: a
# truncated or stub helper exits 0 with no output).
cepa_ln_landed=
if [ -n "$cepa_ln_lost" ]; then
  cepa_ln_rh="$(dirname "${BASH_SOURCE[0]}")/orca-lane-reflog.sh"
  [ -f "$cepa_ln_rh" ] || kept "kept $cepa_ln_lane — HEAD reflog holds a commit no origin ref has (${cepa_ln_lost%%$'\n'*}), and orca-lane-reflog.sh is missing" \
    "reinstall the cepa plugin, then ask again"
  cepa_ln_rrc=0
  cepa_ln_rout=$(timeout -k 2 60 bash "$cepa_ln_rh" "$r_path" ${cepa_ln_trunk:+"$cepa_ln_trunk"} </dev/null 2>/dev/null) || cepa_ln_rrc=$?
  cepa_ln_rlast=$(tail -n 1 <<<"$cepa_ln_rout" | tr -d '\000-\037\177' | cut -c1-400)
  [ "$cepa_ln_rrc" != 0 ] || [[ $cepa_ln_rlast == "landed: "* ]] || cepa_ln_rrc=99
  case "$cepa_ln_rrc" in
    0) cepa_ln_landed=$cepa_ln_rlast ;;
    1) kept "kept $cepa_ln_lane — HEAD reflog holds a commit that is on no origin ref and not landed ($cepa_ln_rlast)" \
         "push or recover that commit from $cepa_ln_lane's reflog, then ask again; if it was landed some other way, say so, and the operator decides whether to expire that lane's reflog" ;;
    *) kept "kept $cepa_ln_lane — HEAD reflog holds a commit no origin ref has, and whether it landed is unknown (${cepa_ln_rlast:-no output})" \
         "check gh auth status and the network, then ask again" ;;
  esac
fi
cepa_ln_orca "$cepa_ln_tmp/ps.json" 1 15 worktree ps --limit 500 --json \
  || kept "kept $cepa_ln_lane — worktree ps failed, so a live agent cannot be ruled out" "check $cepa_ln_lane for a live agent"
cepa_ln_agents=$(cepa_ln_py agents "$cepa_ln_tmp/ps.json" "$r_id") \
  || kept "kept $cepa_ln_lane — worktree ps was not a complete read, so a live agent cannot be ruled out" \
          "check $cepa_ln_lane for a live agent"
# L77 item 3: a done agent still blocks (`done` also marks an idle session that
# is alive, so closing it is the operator's call), but the Ending line names
# the handles. This read runs only here, on the way to `kept`: no rm follows it.
if [ "$cepa_ln_agents" != 0 ]; then
  cepa_ln_end="close the agent in $cepa_ln_lane, then ask again"
  if cepa_ln_orca "$cepa_ln_tmp/term.json" 1 15 terminal list --worktree "id:$r_id" --limit 500 --json \
     && cepa_ln_tl=$(cepa_ln_py terms "$cepa_ln_tmp/ps.json" "$r_id" "$cepa_ln_tmp/term.json"); then
    read -r cepa_ln_live cepa_ln_noterm cepa_ln_hs <<<"$cepa_ln_tl"
    if [ "$cepa_ln_live" = 0 ]; then
      cepa_ln_end="clear the finished agent row(s) of $cepa_ln_lane in Orca (they have no terminal), then ask again"
      if [ -n "$cepa_ln_hs" ]; then
        cepa_ln_end="every agent on $cepa_ln_lane is finished (state done), but its terminal is open: check, then close each with $cepa_ln_cli terminal close --terminal <handle>: $cepa_ln_hs"
        [ "$cepa_ln_noterm" = 0 ] || cepa_ln_end+="; also clear $cepa_ln_noterm agent row(s) with no terminal in Orca"
        cepa_ln_end+="; then ask again"
      fi
    fi
  fi
  kept "kept $cepa_ln_lane — $cepa_ln_agents agent(s) on it in worktree ps" "$cepa_ln_end"
fi
# Orca runs the archive hook from the MAIN checkout's working-tree orca.yaml
# (U1). Review finding #16: the file Orca will read must be the one the
# resolved trunk holds on origin (L77 item 5: the main checkout can follow
# `dev` while origin's default is `main`).
cepa_ln_oy=$(git -C "$cepa_ln_main" status --porcelain --untracked-files=all --ignored -- orca.yaml 2>/dev/null) \
  || kept "kept $cepa_ln_lane — git status of the main checkout's orca.yaml failed" "inspect $cepa_ln_main/orca.yaml"
[ -z "$cepa_ln_oy" ] || kept "kept $cepa_ln_lane — the main checkout's orca.yaml is not committed as it is (${cepa_ln_oy%%$'\n'*}); Orca would run its archive hook from that file" \
  "commit and push orca.yaml, or restore it, in the main checkout, then ask again"
[ ! -L "$cepa_ln_main/orca.yaml" ] || kept "kept $cepa_ln_lane — the main checkout's orca.yaml is a symlink" "inspect $cepa_ln_main/orca.yaml"
if [ -e "$cepa_ln_main/orca.yaml" ]; then
  [ -n "$cepa_ln_trunk" ] \
    || kept "kept $cepa_ln_lane — the trunk is unknown ($cepa_ln_trunk_why), so whether origin holds the main checkout's orca.yaml is unknown" \
            "check trunk: in cepa.local.md, the network and the origin remote, then ask again"
  cepa_ln_yw=$(git -C "$cepa_ln_main" hash-object -- orca.yaml 2>/dev/null) || cepa_ln_yw=
  cepa_ln_yo=$(git -C "$cepa_ln_main" rev-parse -q --verify "refs/remotes/origin/$cepa_ln_trunk:orca.yaml" 2>/dev/null) || cepa_ln_yo=
  [ -n "$cepa_ln_yw" ] && [ "$cepa_ln_yw" = "$cepa_ln_yo" ] \
    || kept "kept $cepa_ln_lane — the main checkout's orca.yaml is not the one origin/$cepa_ln_trunk holds; Orca would run an archive hook origin does not hold" \
            "push orca.yaml to $cepa_ln_trunk, or restore it in the main checkout, then ask again"
fi
# L76: the same saved hook settings decide whether that archive hook runs (H1).
cepa_ln_yf=
[ ! -e "$cepa_ln_main/orca.yaml" ] || cepa_ln_yf="$cepa_ln_main/orca.yaml"
cepa_ln_hook=$(cepa_ln_py hook "$cepa_ln_tmp/repos.json" "$cepa_ln_main" "$cepa_ln_distro" archive "$cepa_ln_yf") \
  || kept "kept $cepa_ln_lane — Orca's saved hook settings for this repo, or orca.yaml's scripts.archive, have a shape this reader does not know, so which archive hook Orca would run is unknown" \
          "check Settings > Repositories > this repo's hooks in Orca, and orca.yaml's scripts.archive, then ask again"
[ "$cepa_ln_hook" = ok ] \
  || kept "kept $cepa_ln_lane — Orca's saved hook settings shadow orca.yaml: ${cepa_ln_hook#shadow: }" \
          "in Orca, open Settings > Repositories > this repo's hooks and make the archive command come from orca.yaml (or make the local archive equal orca.yaml's scripts.archive), then ask again"
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
cepa_ln_orca "$cepa_ln_tmp/rm.json" 0 300 worktree rm --worktree "id:$r_id" --run-hooks --json || true
cepa_ln_res=$(cepa_ln_py rmres "$cepa_ln_tmp/rm.json") || cepa_ln_res="unknown"
case "$cepa_ln_res" in
  removed|unknown) ;;
  "worktree_archive_hook_failed "*)
    read -r _ cepa_ln_x <<<"$cepa_ln_res"
    cepa_ln_end="fix the repo's archive hook and ask again; deleting anyway is the operator's own orca worktree rm --allow-failed-archive-hook, never this script's"
    # L77 item 6: a hook that exits 2 is often make with no such target, and
    # a pre-scheme lane's checkout lacks it. Moving to the tip can help only
    # a lane that is not there. The lane passed the clean and reflog guards.
    [ "$cepa_ln_x" != 2 ] || [ "$cepa_ln_head" = "$cepa_ln_tiprev" ] \
      || cepa_ln_end="exit 2 can mean this lane's checkout predates the hook's target: re-park the clean lane (git -C $r_path checkout --detach $cepa_ln_tip), then ask again; if it still exits 2, $cepa_ln_end"
    failed "the archive hook failed (exit $cepa_ln_x; its output is not relayed — read it in Orca); Orca removed nothing, and $cepa_ln_lane is kept" "$cepa_ln_end" ;;
  *)
    # L77 item 4: guard 2 read the lane clean, so a deletion now is Orca's.
    cepa_ln_gone=$(git -C "$r_path" status --porcelain 2>/dev/null | sed -n 's/^ D //p')
    [ -n "$cepa_ln_gone" ] || failed "worktree rm failed (${cepa_ln_res%% *}); $cepa_ln_lane may be kept" "check lane $cepa_ln_lane in Orca"
    failed "worktree rm failed (${cepa_ln_res%% *}), and Orca's partial removal deleted $(grep -c . <<<"$cepa_ln_gone") tracked path(s) in $cepa_ln_lane ($(head -n 5 <<<"$cepa_ln_gone" | tr '\n' ' ' | cut -c1-300)); the lane was clean before rm, so these are not operator changes" \
           "restore them (git -C $r_path restore .), then ask again" ;;
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
echo "ORCA lane: removed $cepa_ln_lane ($r_path) — absent from Orca's list and git worktree list; $cepa_ln_ni ignored path(s) deleted; $cepa_ln_bmsg${cepa_ln_landed:+; reflog $cepa_ln_landed}"
exit 0
