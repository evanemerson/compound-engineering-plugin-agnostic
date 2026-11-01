#!/usr/bin/env bash
# cepa Orca re-bind — moves a coordinator's Run to this terminal after a
# restart, and proves it moved (punch-list L45). `cepa:autonomy` §12b rule 2
# owns WHEN a coordinator runs it (its first turn, and on rule 8's `unbound`
# alert); this script owns HOW the re-bind is done and counted.
#
# Why: a Run remembers the terminal that bound it. After the 2026-11-01
# reboot, `run-current` showed Run run_5682a0ed1455 with `coordinator_handle`
# = the dead pre-reboot terminal, so Orca's prompt for every `worker_done` and
# `ask` went to a terminal that no longer existed. `run-use --id <run>` moved
# it to the new terminal (`consumer_generation` 2 -> 3).
#
# Usage: orca-rebind.sh  <stdin      (it takes no arguments)
#   stdin is FIELD lines only, inside the session's quoted heredoc
#   (`<<'CEPA_FIELDS'`), so no value is ever inside a quoted shell string:
#     cli: <cli>     §12a's printed `cli=` value, checked as orca-send.sh
#                    checks it.
#     run: <run id>  optional: the Run id a hand-off carried (`/cepa:handoff`).
#                    `run_` then [A-Za-z0-9_] only. Without it, the Run is
#                    the one `run-current` reports for this terminal.
#   A field line is `<name>: <value>`, each name at most once. An empty line
#   ends the fields; only empty lines may follow. Any other line is refused.
#
# What it does, in order:
#   1. `run-current`. When it reports a Run bound to ORCA_TERMINAL_HANDLE (and
#      it is the `run:` Run, when one is given), there is nothing to do.
#   2. A `run:` Run that differs from the `run-current` Run is never re-bound:
#      which one this coordinator owns is the operator's call.
#   3. The terminal that holds the Run (`run-current`'s, or `run-show`'s for
#      a `run:` Run that `run-current` does not report) must be absent from
#      `terminal list`. A Run held by a live terminal is never taken: that is
#      a live coordinator, and `run-use` would take its Run away.
#   4. `run-use --id <run>`, then `run-current` again. It counts only when the
#      re-read reports that Run with `coordinator_handle` = this terminal.
#      The re-read runs even when `run-use` failed, so a `run-use` whose
#      output was lost (the WSL interop error) but that took effect counts.
#
# Prints one summary line, and on exit 1 or 3 a second line,
# `Ending first line: Needed from you: …`. Exit codes:
#   0  `ORCA rebind: ok — …` (already bound, or no Run) or
#      `ORCA rebind: done — <run> moved from <old> to this terminal`.
#   1  `ORCA rebind: ask — …`: the Runs differ, the holder is live, or the
#      holder could not be checked. Nothing was changed.
#   3  `ORCA rebind failed: …`: an Orca read failed, or `run-use` did not
#      move the Run. A mismatch after `run-use` is reported here, never
#      ignored.
#   4  `ORCA rebind refused: <reason>` — a field or the environment failed
#      its check. No Orca call was made.
#
# Measured on Orca 1.4.245 (WSL), 2026-11-01: `run-use --help`, `run-current
# --help`, `run-show --json` (result.run.{id,coordinator_handle,
# consumer_generation}) and `terminal list --json` (result.terminals[].handle,
# totalCount, truncated). No throwaway Run was made to probe `run-use`:
# Orca 1.4.245 has no verb that closes a Run (`reset` clears every Run's
# state), so a probe Run could not be removed. The `run-use` result itself
# is not parsed: the re-read is the proof.
#
# STATED LIMITS:
#   - `run-use --help`: "A worker cannot bind its own or ancestor Run". A
#     dispatched worker that runs this gets `ok — no Run` or a failed
#     `run-use`, never a stolen Run.
#   - `terminal list` lists one Orca server's terminals. A Run held by a
#     terminal on another paired server reads as absent here.
#   - It does not wait for or prove Orca's prompts reach the new terminal;
#     it proves the Run's record names it.
set -u

refuse() { echo "ORCA rebind refused: $1"; exit 4; }
ask() {
  echo "ORCA rebind: ask — $1"
  echo "Ending first line: Needed from you: $2"
  exit 1
}
failed() {
  echo "ORCA rebind failed: $1"
  echo "Ending first line: Needed from you: re-bind the Run by hand (orchestration run-use) and check run-current"
  exit 3
}

[ $# -eq 0 ] || refuse "orca-rebind.sh takes no arguments; its fields go on stdin"
unset cepa_rb_f_cli cepa_rb_f_run
cepa_rb_seen=" "
while IFS= read -r cepa_rb_line || [ -n "$cepa_rb_line" ]; do
  cepa_rb_line=${cepa_rb_line%$'\r'}
  [ -n "$cepa_rb_line" ] || break
  [[ $cepa_rb_line =~ ^([a-z]+):(\ (.*))?$ ]] || refuse "a heredoc line is not a <name>: <value> field"
  cepa_rb_k=${BASH_REMATCH[1]} cepa_rb_v=${BASH_REMATCH[3]}
  cepa_rb_v=${cepa_rb_v%"${cepa_rb_v##*[![:space:]]}"}
  case "$cepa_rb_k" in cli|run) ;; *) refuse "a field name is not cli or run" ;; esac
  [[ $cepa_rb_seen != *" $cepa_rb_k "* ]] || refuse "the $cepa_rb_k field is given twice"
  cepa_rb_seen+="$cepa_rb_k "
  printf -v "cepa_rb_f_$cepa_rb_k" '%s' "$cepa_rb_v"
done
{ cepa_rb_rest=$(cat); } 2>/dev/null
[ -z "${cepa_rb_rest//[[:space:]]/}" ] || refuse "the heredoc holds a line after its fields"

[[ $cepa_rb_seen == *" cli "* ]] || refuse "the cli field is missing"
cepa_rb_cli=$cepa_rb_f_cli
case "$cepa_rb_cli" in
  ''|-*|*[!A-Za-z0-9._/-]*) refuse "the cli is not a plain command name" ;;
  /*) [ "$cepa_rb_cli" = "${ORCA_CLI_COMMAND:-}" ] || refuse "a cli path must equal ORCA_CLI_COMMAND" ;;
  */*) refuse "a cli path must be absolute and equal ORCA_CLI_COMMAND" ;;
esac
case "${cepa_rb_cli##*/}" in
  orca-ide|orca-dev) ;;
  orca) [ "$(uname -s 2>/dev/null)" != Linux ] || refuse "bare orca on Linux is the screen reader" ;;
  *) refuse "the cli does not name an Orca CLI" ;;
esac
# An empty `run:` is no Run, as an absent one is.
cepa_rb_want=${cepa_rb_f_run-}
[ -z "$cepa_rb_want" ] || [[ $cepa_rb_want =~ ^run_[A-Za-z0-9_]{1,64}$ ]] \
  || refuse "the run field is not run_ followed by [A-Za-z0-9_]"
cepa_rb_me=${ORCA_TERMINAL_HANDLE:-}
[[ $cepa_rb_me =~ ^term_[0-9a-f-]{36}$ ]] || refuse "ORCA_TERMINAL_HANDLE is not a term_ handle"
command -v "$cepa_rb_cli" >/dev/null 2>&1 || refuse "$cepa_rb_cli is not on PATH"
command -v timeout >/dev/null 2>&1 || refuse "no timeout command to bound the Orca calls"
command -v python3 >/dev/null 2>&1 || refuse "no python3 to read the Orca output"
cepa_rb_tmp=$(mktemp -d 2>/dev/null) || refuse "mktemp failed"
trap 'rm -rf "$cepa_rb_tmp"' EXIT

# One Orca call, bounded at 15 seconds plus a 2-second kill. A read is retried
# once on the WSL interop error (orca-send.sh's rule); `run-use` is not
# retried, because the re-read after it is the proof either way.
cepa_rb_orca() {
  local out=$1 retry=$2 try e
  shift 2
  for try in 1 2; do
    timeout -k 2 15 "$cepa_rb_cli" "$@" </dev/null >"$out" 2>"$cepa_rb_tmp/err" && return 0
    [ "$retry" = 1 ] && [ "$try" = 1 ] || return 1
    { e=$(<"$cepa_rb_tmp/err"); } 2>/dev/null || return 1
    [[ $e == *UtilAcceptVsock* && $e == *"accept4 failed 110"* ]] || return 1
  done
  return 1
}

# Reads `{"ok": true, "result": {"run": null | {id, coordinator_handle}}}` and
# prints `<id> <handle>`, or nothing for no Run. Any other shape exits 1, so a
# changed Orca reads as a failed read, never as "no Run".
cepa_rb_read_run() {
  python3 -I -c '
import json, re, sys
d = json.load(open(sys.argv[1]))
r = d["result"]["run"] if d.get("ok") is True else sys.exit(1)
if r is None:
    sys.exit(0)
i, h = r["id"], r["coordinator_handle"]
if not (isinstance(i, str) and re.fullmatch(r"run_[A-Za-z0-9_]{1,64}", i)):
    sys.exit(1)
if not (isinstance(h, str) and re.fullmatch(r"term_[0-9a-f-]{36}", h)):
    sys.exit(1)
print(i, h)
' "$1" 2>/dev/null
}

cepa_rb_orca "$cepa_rb_tmp/cur.json" 1 orchestration run-current --json || failed "run-current failed"
cepa_rb_cur=$(cepa_rb_read_run "$cepa_rb_tmp/cur.json") || failed "run-current returned a shape this reader does not know"
cepa_rb_cur_id=${cepa_rb_cur% *} cepa_rb_cur_h=${cepa_rb_cur#* }
[ -n "$cepa_rb_cur" ] || cepa_rb_cur_id= cepa_rb_cur_h=

if [ -n "$cepa_rb_cur_id" ] && [ -n "$cepa_rb_want" ] && [ "$cepa_rb_cur_id" != "$cepa_rb_want" ]; then
  ask "this terminal's Run is $cepa_rb_cur_id, the hand-off names $cepa_rb_want; nothing was changed" \
    "say which Run this coordinator owns, $cepa_rb_cur_id or $cepa_rb_want"
fi
if [ -n "$cepa_rb_cur_id" ] && [ "$cepa_rb_cur_h" = "$cepa_rb_me" ]; then
  echo "ORCA rebind: ok — $cepa_rb_cur_id is bound to this terminal"
  exit 0
fi
cepa_rb_run=${cepa_rb_cur_id:-$cepa_rb_want}
if [ -z "$cepa_rb_run" ]; then
  echo "ORCA rebind: ok — no Run to re-bind (run-current reports none and no run field was given)"
  exit 0
fi
cepa_rb_old=$cepa_rb_cur_h
if [ -z "$cepa_rb_old" ]; then
  cepa_rb_orca "$cepa_rb_tmp/show.json" 1 orchestration run-show --id "$cepa_rb_run" --json \
    || failed "run-show for $cepa_rb_run failed"
  cepa_rb_shown=$(cepa_rb_read_run "$cepa_rb_tmp/show.json") \
    || failed "run-show returned a shape this reader does not know"
  [ "${cepa_rb_shown% *}" = "$cepa_rb_run" ] || failed "run-show did not return $cepa_rb_run"
  cepa_rb_old=${cepa_rb_shown#* }
  if [ "$cepa_rb_old" = "$cepa_rb_me" ]; then
    echo "ORCA rebind: ok — $cepa_rb_run is bound to this terminal"
    exit 0
  fi
fi

# The holder must be gone. Its absence from `terminal list` is the proof
# (a closed terminal is proven by its absence, never by `"ok": true`).
cepa_rb_orca "$cepa_rb_tmp/terms.json" 1 terminal list --json \
  || ask "terminal list failed, so whether $cepa_rb_old is still open is unknown; nothing was changed" \
         "check whether terminal $cepa_rb_old is still open"
cepa_rb_live=$(python3 -I -c '
import json, sys
d = json.load(open(sys.argv[1]))
r = d["result"] if d.get("ok") is True else sys.exit(1)
t = r["terminals"]
if not isinstance(t, list) or r.get("truncated") is not False or r.get("totalCount") != len(t):
    sys.exit(1)
hs = [x["handle"] for x in t]
print("live" if sys.argv[2] in hs else "gone")
' "$cepa_rb_tmp/terms.json" "$cepa_rb_old" 2>/dev/null) || cepa_rb_live=
case "$cepa_rb_live" in
  gone) ;;
  live) ask "$cepa_rb_run is held by $cepa_rb_old, which is still open; a live coordinator's Run is never taken" \
            "say whether terminal $cepa_rb_old or this one coordinates $cepa_rb_run" ;;
  *) ask "terminal list returned a partial or unknown shape, so whether $cepa_rb_old is still open is unknown; nothing was changed" \
         "check whether terminal $cepa_rb_old is still open" ;;
esac

cepa_rb_use=0
cepa_rb_orca "$cepa_rb_tmp/use.json" 0 orchestration run-use --id "$cepa_rb_run" --json || cepa_rb_use=$?
cepa_rb_orca "$cepa_rb_tmp/after.json" 1 orchestration run-current --json \
  || failed "run-use ran (exit $cepa_rb_use) but the re-read of run-current failed, so the binding is unproven"
cepa_rb_after=$(cepa_rb_read_run "$cepa_rb_tmp/after.json") \
  || failed "run-use ran (exit $cepa_rb_use) but run-current then returned a shape this reader does not know"
if [ "$cepa_rb_after" = "$cepa_rb_run $cepa_rb_me" ]; then
  echo "ORCA rebind: done — $cepa_rb_run moved from $cepa_rb_old to this terminal"
  exit 0
fi
failed "after run-use (exit $cepa_rb_use), run-current reports ${cepa_rb_after:-no Run}, not $cepa_rb_run bound to this terminal"
