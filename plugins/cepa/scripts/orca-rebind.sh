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
# `run-current` IS SERVER-WIDE (coord@main, Orca 1.4.245, 2026-11-01, read
# only): `orca-ide orchestration run-current --json` returned the same Run
# from /tmp, from the cepa checkout, and with ORCA_TERMINAL_HANDLE unset. It
# names no checkout and no terminal, so every repo's coordinator sees the
# same "current" Run. This script therefore never takes a Run because
# `run-current` reports it, and never uses it as proof of a binding
# (punch-list L46, operator's choice in #116).
#
# Usage: orca-rebind.sh  <stdin      (it takes no arguments)
#   stdin is FIELD lines only, inside the session's quoted heredoc
#   (`<<'CEPA_FIELDS'`), so no value is ever inside a quoted shell string:
#     cli: <cli>     §12a's printed `cli=` value, checked as orca-send.sh
#                    checks it.
#     run: <run id>  the Run this session named: its prompt's `Orca Run:`
#                    line (`/cepa:handoff`), or one the operator confirmed.
#                    `run_` then [A-Za-z0-9_] only. Without it nothing is
#                    re-bound.
#     confirm: <run id>  optional, and only beside an equal `run:`: the
#                    operator said this session coordinates that Run, after
#                    an ownership `ask`. It lifts that ask only; the
#                    live-holder check still runs.
#   A field line is `<name>: <value>`, each name at most once. An empty line
#   ends the fields; only empty lines may follow. Any other line is refused.
#
# What it does, in order:
#   1. `run-current`. With no `run:` field, it only reports: a Run bound here
#      is `ok`, none is `ok`, and a Run bound elsewhere asks whether it is
#      this session's (it may be another repo's). It never calls `run-use`.
#   2. With `run:`, `run-current` must report that same Run, or a
#      `confirm:` line must name it; otherwise it asks (#113 finding 12:
#      `run-show` has no repo or worktree field either, measured below).
#   3. `run-show --id <run>` gives the holder and `consumer_generation`. A
#      Run held by this terminal is `ok`.
#   4. The holder must be absent from `terminal list`. A Run held by a live
#      terminal is never taken: that is a live coordinator, and `run-use`
#      would take its Run away. Then `run-show` once more, right before
#      `run-use`: the holder and generation must still be step 3's, or it
#      asks. A session that re-bound the Run during the `terminal list` call
#      is then not taken (PR #116 review).
#   5. `run-use --id <run>`, then `run-show` again. It counts only when
#      `run-show` reports this terminal with `consumer_generation` exactly
#      one above step 3's. Two sessions that re-bind at once cannot both see
#      the same generation bound to themselves, so at most one prints `done`
#      (#113 finding 11). The re-read runs even when `run-use` failed, so a
#      `run-use` whose output was lost (the WSL interop error) but that took
#      effect counts.
#
# Prints one summary line, and on exit 1 or 3 a second line,
# `Ending first line: Needed from you: …`. Exit codes:
#   0  `ORCA rebind: ok — …` (already bound, or nothing named) or
#      `ORCA rebind: done — <run> moved from <old> to this terminal`.
#   1  `ORCA rebind: ask — …`: no `run:` while run-current reports a Run
#      bound elsewhere, a `run:` Run that run-current does not report and no
#      `confirm:` names, a live holder, a holder that could not be checked,
#      or a Run that moved before `run-use`. Nothing was changed.
#   3  `ORCA rebind failed: …`: an Orca read failed, `run-use` did not move
#      the Run, or the generation did not rise by exactly 1. A mismatch after
#      `run-use` is reported here, never ignored.
#   4  `ORCA rebind refused: <reason>` — a field or the environment failed
#      its check. No Orca call was made.
#
# Measured on Orca 1.4.245 (WSL), 2026-11-01: `run-use --help`, `run-current
# --help`, `run-show --json` (result.run.{id, objective, coordinator_handle,
# consumer_generation, legacy, created_at, updated_at}: no repo or worktree
# field; re-measured for L46) and `terminal list --json` (result.terminals[].handle,
# totalCount, truncated, hostScope.omittedHostIds: a list with any omitted
# host reads as unknown, never as "gone"). An id Orca itself returns may also
# hold `-` (orca-health.sh accepts it too); a `run:` field may not. No throwaway Run was made to probe `run-use`:
# Orca 1.4.245 has no verb that closes a Run (`reset` clears every Run's
# state), so a probe Run could not be removed. The `run-use` result itself
# is not parsed: the re-read is the proof. `run-use --from <handle>` has no
# help text; `run-current` and `send` carry the same flag for the caller's
# own handle, so it is not read as a compare-and-swap and is not passed.
# `run-current` with a bound Run was not measurable from a worker (it
# returns `"run": null`), so the generation is read from `run-show`.
#
# STATED LIMITS:
#   - `run-use --help`: "A worker cannot bind its own or ancestor Run". A
#     dispatched worker that runs this gets `ok — no Run` or a failed
#     `run-use`, never a stolen Run.
#   - `terminal list` lists one Orca server's terminals. A Run held by a
#     terminal on a paired server that list does not cover reads as absent
#     here; a host the list says it omitted reads as unknown (exit 1).
#   - Two sessions that re-bind the same Run at the same moment: at most one
#     prints `done`. `done` is a fact about the re-read, not about later: a
#     session whose `run-use` lands after it takes the Run, and prints
#     `failed`, so one session can print `done` while the other holds the
#     Run; both can also print `failed` while one holds it. The `failed`
#     line says so, and the loser's next rule 8 health check raises
#     `unbound`. The recheck before `run-use` narrows the window to one
#     call; Orca exposes no compare-and-swap, so it cannot close it.
#   - `consumer_generation` rising by exactly 1 per `run-use` was measured
#     once (2 -> 3, L45). If Orca also raises it for other events, a lone
#     re-bind prints `failed` with this terminal holding the Run; a rerun
#     then prints `ok`. That fails closed.
#   - A `run-use` the 15-second bound killed may still take effect on the
#     server after the re-read: the script prints `failed` and a rerun
#     prints `ok`.
#   - Worst case about 190 seconds (each of five reads 2 x 17, run-use 17):
#     run the block with a tool timeout of at least 4 minutes.
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
  echo "Ending first line: Needed from you: check which terminal holds the Run (orchestration run-show --id <run>), close it if it is dead, then ask this session to run the re-bind again"
  exit 3
}

[ $# -eq 0 ] || refuse "orca-rebind.sh takes no arguments; its fields go on stdin"
unset cepa_rb_f_cli cepa_rb_f_run cepa_rb_f_confirm
cepa_rb_seen=" "
while IFS= read -r cepa_rb_line || [ -n "$cepa_rb_line" ]; do
  cepa_rb_line=${cepa_rb_line%$'\r'}
  [ -n "$cepa_rb_line" ] || break
  [[ $cepa_rb_line =~ ^([a-z]+):(\ (.*))?$ ]] || refuse "a heredoc line is not a <name>: <value> field"
  cepa_rb_k=${BASH_REMATCH[1]} cepa_rb_v=${BASH_REMATCH[3]}
  cepa_rb_v=${cepa_rb_v%"${cepa_rb_v##*[![:space:]]}"}
  case "$cepa_rb_k" in cli|run|confirm) ;; *) refuse "a field name is not cli, run or confirm" ;; esac
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
cepa_rb_confirm=${cepa_rb_f_confirm-}
[ -z "$cepa_rb_confirm" ] || [ "$cepa_rb_confirm" = "$cepa_rb_want" ] \
  || refuse "the confirm field must equal the run field"
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
# changed Orca reads as a failed read, never as "no Run". With a second
# argument `gen` it reads `run-show`: the Run must be there, and it prints
# `<id> <handle> <consumer_generation>`, an integer from 0 below 10^9.
cepa_rb_read_run() {
  python3 -I -c '
import json, re, sys
d = json.load(open(sys.argv[1]))
r = d["result"]["run"] if d.get("ok") is True else sys.exit(1)
gen = sys.argv[2:] == ["gen"]
if r is None:
    sys.exit(1 if gen else 0)
i, h = r["id"], r["coordinator_handle"]
if not (isinstance(i, str) and re.fullmatch(r"run_[A-Za-z0-9_-]{1,64}", i)):
    sys.exit(1)
if not (isinstance(h, str) and re.fullmatch(r"term_[0-9a-f-]{36}", h)):
    sys.exit(1)
if not gen:
    print(i, h)
    sys.exit(0)
g = r["consumer_generation"]
if type(g) is not int or not 0 <= g < 10 ** 9:
    sys.exit(1)
print(i, h, g)
' "$@" 2>/dev/null
}

cepa_rb_orca "$cepa_rb_tmp/cur.json" 1 orchestration run-current --json || failed "run-current failed"
cepa_rb_cur=$(cepa_rb_read_run "$cepa_rb_tmp/cur.json") || failed "run-current returned a shape this reader does not know"
cepa_rb_cur_id=${cepa_rb_cur% *} cepa_rb_cur_h=${cepa_rb_cur#* }
[ -n "$cepa_rb_cur" ] || cepa_rb_cur_id= cepa_rb_cur_h=

# No Run named: report only. run-current is server-wide, so its Run may be
# another repo's; it is never taken on that evidence.
if [ -z "$cepa_rb_want" ]; then
  if [ -z "$cepa_rb_cur_id" ]; then
    echo "ORCA rebind: ok — no Run named and run-current reports none"
    exit 0
  fi
  if [ "$cepa_rb_cur_h" = "$cepa_rb_me" ]; then
    echo "ORCA rebind: ok — $cepa_rb_cur_id is bound to this terminal"
    exit 0
  fi
  ask "this session named no Run; run-current reports $cepa_rb_cur_id, held by $cepa_rb_cur_h, but run-current is server-wide, so it may be another repo's Run; nothing was changed" \
    "say whether this session coordinates $cepa_rb_cur_id (then it runs the re-bind again with run: $cepa_rb_cur_id and confirm: $cepa_rb_cur_id lines)"
fi
cepa_rb_run=$cepa_rb_want
# A named Run is taken only when run-current agrees, or the operator
# confirmed it (#113 finding 12; run-show has no repo or worktree field).
if [ "$cepa_rb_cur_id" != "$cepa_rb_run" ] && [ "$cepa_rb_confirm" != "$cepa_rb_run" ]; then
  ask "run-current reports ${cepa_rb_cur_id:-no Run}, not $cepa_rb_run, and Orca records no repo or worktree for a Run, so whether this session coordinates $cepa_rb_run is unproven; nothing was changed" \
    "say whether this session coordinates $cepa_rb_run (then it runs the re-bind again with a confirm: $cepa_rb_run line)"
fi
# The named Run's holder and generation, from run-show (exact by id).
cepa_rb_orca "$cepa_rb_tmp/show.json" 1 orchestration run-show --id "$cepa_rb_run" --json \
  || failed "run-show for $cepa_rb_run failed"
cepa_rb_shown=$(cepa_rb_read_run "$cepa_rb_tmp/show.json" gen) \
  || failed "run-show returned a shape this reader does not know"
read -r cepa_rb_s_id cepa_rb_old cepa_rb_gen <<<"$cepa_rb_shown"
[ "$cepa_rb_s_id" = "$cepa_rb_run" ] || failed "run-show did not return $cepa_rb_run"
if [ "$cepa_rb_old" = "$cepa_rb_me" ]; then
  echo "ORCA rebind: ok — $cepa_rb_run is bound to this terminal"
  exit 0
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
# A host Orca left out of the list could hold the terminal (PR #113 review).
if r["hostScope"]["omittedHostIds"] != []:
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
# The Run must not have moved while terminal list ran: another session that
# re-bound it in that window is live now, and is never taken.
cepa_rb_orca "$cepa_rb_tmp/recheck.json" 1 orchestration run-show --id "$cepa_rb_run" --json \
  || failed "run-show for $cepa_rb_run failed on the recheck before run-use; nothing was changed"
cepa_rb_recheck=$(cepa_rb_read_run "$cepa_rb_tmp/recheck.json" gen) \
  || failed "run-show returned a shape this reader does not know on the recheck before run-use; nothing was changed"
if [ "$cepa_rb_recheck" != "$cepa_rb_shown" ]; then
  ask "$cepa_rb_run moved while this session checked it (run-show now reports $cepa_rb_recheck, was $cepa_rb_shown); nothing was changed" \
    "say whether this session should still coordinate $cepa_rb_run (then it runs the re-bind again)"
fi

cepa_rb_use=0
cepa_rb_orca "$cepa_rb_tmp/use.json" 0 orchestration run-use --id "$cepa_rb_run" --json || cepa_rb_use=$?
# The proof is run-show alone: run-current is server-wide, so it cannot
# say which terminal this binding is for.
cepa_rb_orca "$cepa_rb_tmp/after-show.json" 1 orchestration run-show --id "$cepa_rb_run" --json \
  || failed "run-use ran (exit $cepa_rb_use) but the re-read of run-show failed, so whether one re-bind or two moved the Run is unproven"
cepa_rb_gen_after=$(cepa_rb_read_run "$cepa_rb_tmp/after-show.json" gen) \
  || failed "run-use ran (exit $cepa_rb_use) but run-show then returned a shape this reader does not know"
cepa_rb_gen_want="$cepa_rb_run $cepa_rb_me $((cepa_rb_gen + 1))"
if [ "$cepa_rb_gen_after" = "$cepa_rb_gen_want" ]; then
  echo "ORCA rebind: done — $cepa_rb_run moved from $cepa_rb_old to this terminal"
  exit 0
fi
read -r cepa_rb_a_id cepa_rb_a_h cepa_rb_a_gen <<<"$cepa_rb_gen_after"
if [ "$cepa_rb_a_id" = "$cepa_rb_run" ] && [ "$cepa_rb_a_h" = "$cepa_rb_me" ]; then
  failed "after run-use (exit $cepa_rb_use), this terminal holds $cepa_rb_run, but consumer_generation is $cepa_rb_a_gen, not $((cepa_rb_gen + 1)): another session may have re-bound it at the same moment (and may have printed done), or Orca raised the generation for another reason"
fi
failed "after run-use (exit $cepa_rb_use), run-show reports $cepa_rb_gen_after, not $cepa_rb_gen_want (consumer_generation one above $cepa_rb_gen): another session may have re-bound $cepa_rb_run at the same moment"
