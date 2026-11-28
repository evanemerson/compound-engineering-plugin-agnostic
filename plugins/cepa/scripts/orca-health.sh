#!/usr/bin/env bash
# cepa Orca health — a coordinator's per-turn check for a failed send and a
# hung session (punch-list L34). `cepa:autonomy` §12b rule 8 owns WHEN it runs
# and what the session does with an alert; this script owns WHAT counts as one.
# It reads; it never sends, nudges, stops or releases anything.
#
# Usage: orca-health.sh <cli> [repo:<repo>] [<run>]         report alerts
#        orca-health.sh <cli> [repo:<repo>] ack <key>...    mark alerts as shown to the operator
#   <cli>  §12a's printed `cli=` value, checked as orca-send.sh checks it.
#   <repo> optional, for BOT MODE (below): the repo a session outside any
#          git checkout coordinates. Inside a checkout it must name that
#          checkout's repo.
#   <run>  optional: the session's named Run (§12b rule 2 defines it),
#          `run_` then [A-Za-z0-9_], read with `run-show`. Without it, the
#          script reads this pane's `run-current` and checks that Run only
#          when its `coordinator_handle` is ORCA_TERMINAL_HANDLE (it is then
#          the named Run); a Run held elsewhere is not checked, only noted.
#          From a chat (BOT MODE) a run-current Run with no recorded holder
#          is the chat's own and is checked.
#          `run-current` is per pane (Orca 1.4.245, 2026-11-01, read only:
#          from a worker's pane it returned `"run": null` while another
#          pane held a Run; `--from` with an invented handle returned
#          `stable_pane_required`), so this never checks another pane's Run
#          (punch-list L46).
#   <key>  the text between `ORCA alert: ` and ` — ` on an alert line.
#
# Prints one `ORCA alert: <key> — <text>` line per alert not yet acked, then a
# summary line. Exit codes:
#   0  `ORCA health: ok — …` (no alert), or `ORCA health: unknown — …` (only
#      acked orca-unreadable alerts: still not read, already asked).
#   1  alerts, then `ORCA health: <n> alert(s) — ask the operator (§12b rule 8)`
#      and `Ending first line: Needed from you: check the Orca alerts below`.
#   4  `ORCA health refused: <reason>` — an argument failed its check.
#   An ack prints `ORCA ack: <key>` per key and exits 0; 1 when a marker could
#   not be written or an alert file is gone; 4 on a bad key.
#
# ORCA 1.4.246 SHORT OUTPUT (punch-list L72). Measured on Orca 1.4.246 (WSL),
# 2026-11-02, read only, each read with and without `--full`. Without it,
# each of these `orchestration` reads prints a concise view: `run-list` rows hold only
# `id` and `objective`; `run-show` holds `runId`, `objective`, `removedWork`
# (no `run` object); `run-current` holds `runId`, `objective`; `worker-list`
# rows have no `projection`; `worker-show` has no `dispatch`, `worker` or
# `projection`; `inbox` rows name `from`/`to` (not `from_handle`/`to_handle`),
# cut the body to 200 chars, and carry no `thread_id` or `created_at`. With
# `--full` each prints the record this script reads. So every orchestration
# read here passes `--json --full`, and a reply in the short shape reads as
# an `orca-unreadable` alert, never `ok`. `terminal`, `worktree` and `repo` reads have no `--full` flag
# on 1.4.246 and still print the full record. Whether an older Orca (1.4.245
# or before) accepts `--full` was not measured: none was at hand to run.
# No script here reads `check`. Its short form, message rows included, is
# measured in `cepa:autonomy` §12b rule 8 (punch-list L73).
#
# WHAT IS AN ALERT. Each source and bound below was measured on Orca 1.4.245
# (WSL), 2026-10-31, on Run run_bf28fea0ea31's 16 settled dispatches and on
# probe terminals in the `roles` worktree (PR body, punch-list L34):
#   send-failed:<file>   orca-send.sh exit 4 or 5 wrote an alert file for this
#                        repo (or for no known repo). Orca has no record of a
#                        send it never stored, so this file is the only trace.
#                        Also a stored send whose nudge did not run to a
#                        decision (kind nudge_skipped, L65: an Orca call
#                        failed, its output was unreadable, or orca-nudge.sh
#                        could not run): stored, but unread until its target
#                        checks its inbox.
#   exited:<dispatch>    a live dispatch whose liveness verdict is `exited`:
#                        Orca's positive proof the agent stopped, and no
#                        worker_done came.
#   waiting:<dispatch>   a live dispatch whose observation.agentWait is set:
#                        the worker is parked on a prompt only a human can
#                        answer (Orca: "a waiting worker is healthy, not
#                        failed", but nobody sees it unless told).
#   stale:<dispatch>:<last life>  no life for 30 minutes or more. Life is
#                        the newest of the heartbeat
#                        (dispatch.lastHeartbeatAt, else dispatchedAt), the
#                        worker's terminal output and a commit on its branch
#                        (LIFE, below). The longest heartbeat gap a healthy
#                        worker on that Run left was 20.5 minutes, against a
#                        5-minute cadence. Orca's own liveness never reads
#                        heartbeats: an agent probe that sent none stayed
#                        `live` with no attention category. Not raised while
#                        the dispatch has attention `input` (a pending `ask`
#                        is itself a liveness signal) or is already `exited`
#                        or `waiting`.
#                        LIFE (punch-list L82: a worker in a long shell job
#                        sends no heartbeat, and each alert cost the operator
#                        a question). Both reads run only for a worker 30
#                        minutes or more past its heartbeat with no `input`
#                        category, and a read that fails or is unknown
#                        counts as no life, so the alert stays. The alert
#                        prints each signal's own state, `unread` when it
#                        could not be read.
#                        - Terminal output: `terminal.lastOutputAt` (epoch
#                          ms) in the `worker-show` reply this script already
#                          has, so it costs no Orca call and no time against
#                          THE TIME BOUND. Measured on Orca 1.4.249 (WSL),
#                          2026-11-05: 6 reads over a 72-second foreground
#                          job that printed nothing were each under 0.4
#                          seconds old (Claude Code redraws its timer); idle
#                          agent and shell terminals read 320 to 490 minutes
#                          old, so an agent at its prompt does not tick it.
#                          Refused: `terminal` absent or naming another
#                          handle, the field null or not an integer, or a
#                          time more than 180 seconds after this script
#                          started (a read can land 134 seconds after it, so
#                          a live terminal's time can pass `now`). Not
#                          counted once the dispatch reaches the `long:`
#                          bound: `long:` has a key with no time, so after
#                          its ack only `stale:` still watches an agent hung
#                          inside a turn whose timer redraws (PR #135 review).
#                        - A commit: `git log -1` on `terminal.branch`, only
#                          when `terminal.worktreePath` is a worktree of this
#                          repo with that branch checked out (`git worktree
#                          list`), so a same-named branch of another repo is
#                          not read, and only when the commit is not older
#                          than the dispatch, so the branch's base is not
#                          read as the worker's work. Local, 3 seconds a call
#                          and 10 seconds a run; a timeout ends the git reads.
#   long:<dispatch>      dispatched 180 minutes or more ago with no
#                        worker_done. The longest settled dispatch took 55.
#   failed:<dispatch>    (punch-list L60) a dispatch of the Run that settled
#                        `failed` with no worker_done row from it in the
#                        inbox window. Orca sends no message for it: on
#                        2026-11-02 tab31's start failed (stage
#                        agent_readiness, lastFailure terminal_exited, no
#                        heartbeat) and this script printed `ok` on every
#                        turn after. Read from the `worker-list` row
#                        (`projection.outcome` and `projection.stage.detail`),
#                        then `worker-show` of each one not yet acked, at most
#                        10 a run, for `dispatch.lastFailure` (shown only as
#                        a `[a-z_]` token or a sentence in LAST_FAILURES, else
#                        `an unrecognised failure`) and its handle. Measured
#                        on Orca 1.4.259, 2026-11-16, read only, with
#                        `worker-list --run run_5682a0ed1455 --json --full`
#                        and `worker-show --dispatch <id> --json --full`: its
#                        three failed dispatches read `failed` with details
#                        agent_readiness and process_exited. A worker that
#                        sent its own `worker_done --outcome failed` is rule
#                        5's, not an alert; a `succeeded` one still alerts. The first run on a Run asks once about every
#                        older failure; the ack keeps them quiet.
#   question:<msg>       a `question` to this Run's mailbox with no reply
#                        threaded on it after 10 minutes (an `ask` waits 10 by
#                        default). Orca shows it as attention `input`.
#   awaited:<msg>        a `question` this session sent (from_handle is
#                        ORCA_TERMINAL_HANDLE) with no reply after 30 minutes.
#   unbound:<run>:<hour> `run-show` reports the named Run with a
#                        `coordinator_handle` that is not ORCA_TERMINAL_HANDLE
#                        (punch-list L45: after the 2026-11-01 reboot it named
#                        the dead pre-reboot terminal, so Orca prompted a
#                        terminal that no longer existed). §12b rule 2's
#                        re-bind block (orca-rebind.sh) fixes it. Keyed by the
#                        UTC hour, so an ack silences it for that hour only.
#                        Not raised when the field is absent. From a
#                        terminal, a null holder raises it too (tab49's
#                        residual 1: up to 1.61.x it raised nothing): a chat
#                        or bot's Run reads so, Orca prompts no terminal for
#                        it, and the re-bind block asks before it takes one
#                        (orca-rebind.sh, THE NULL HOLDER). From a chat, a
#                        `term_` holder raises it and a null one does not.
#                        With no Run named, a terminal whose run-current Run
#                        has a null holder raises it too (PR #153 review: a
#                        note alone read `ok` while the Run went unchecked;
#                        up to 1.61.x it was orca-unreadable). A
#                        `structworker_` holder (orca-rebind.sh, THE
#                        STRUCTURED HOLDER) is read as a null one is.
#   HOST DISPATCHES (punch-list L89 g): a dispatch on an Orca host. orca-lab
#                        reported its `worker-list` row as `projection: null`
#                        (Orca 1.4.262, live WSL host). This run re-read
#                        `worker-list --run run_5d80668f22e7 --json --full`
#                        on Orca 1.4.262, 2026-11-17, read only: its 10 host
#                        rows have NO `projection` key, and carry `server`
#                        (`environmentId` `wsl:ubuntu-24.04`, `name`, `asOf`)
#                        beside `workerState` and `dispatchStatus`; its 3
#                        local rows have `projection` and no `server`. So a
#                        row with a `server` object whose `environmentId` is
#                        a string other than `local`, a valid dispatch id and
#                        no projection
#                        (absent or null) is skipped, never read as unknown:
#                        before this, one such row made every hourly run
#                        alert `orca-unreadable:worker-list`. So no alert here
#                        covers a host worker (exited, long, failed);
#                        `cepa:autonomy` §12b rule 3 says what a coordinator
#                        does instead. A row with no projection and no
#                        `server` (the 1.4.246 short shape), or a bad
#                        dispatch id, is still unreadable.
#   orca-unreadable:<what>:<hour>  an Orca call failed, timed out, was not
#                        started (THE TIME BOUND, below), or returned a shape
#                        this reader does not know; or the alert directory
#                        could not be read; or (`worker-cap`) more than 20
#                        dispatches are live, so only 20 are read with
#                        `worker-show`; or (`worker-pages`) worker-list has
#                        more than 10 pages. The Run's health is then
#                        unknown. Its key carries the UTC hour, so an ack
#                        silences it for that hour only, and while it is
#                        acked the summary reads `ORCA health: unknown — …`,
#                        never `ok`. The hour key stays for `worker-cap`: the
#                        dispatches past 20 are unwatched for as long as the
#                        cap holds, so it asks again each hour it still does.
#   WORKER-LIST PAGES (punch-list L94): `worker-list` returns at most 100
#                        rows, newest first, with `page` {limit, total,
#                        hasMore, nextCursor}; `--cursor <nextCursor>` reads
#                        the next page. Before this, a `hasMore: true` page
#                        raised `worker-cap` every hour on a Run of 113
#                        finished dispatches (orca-lab, msg_d8ae581e7f1c,
#                        Orca 1.4.262, run_9239ee3a4180: 100 rows, 0
#                        in_progress, total 113; sender-reported, not
#                        re-measured here). Now every page is read, up to 10
#                        (1000 rows; a Run of 113 costs 2 calls), so a failed
#                        row on a later page still alerts (L60) and only live
#                        rows count toward the cap. Re-measured on Orca
#                        1.4.262, 2026-11-19, read only, with `worker-list
#                        --run <run> --limit 5 --json --full`, then
#                        `--cursor <nextCursor>` until `hasMore` was false:
#                        run_ce7a15d01f88 (21 rows) and run_5682a0ed1455 (25
#                        rows) each took 5 pages and returned every row once;
#                        each call took about 0.7 seconds. The
#                        `--terminal-state` filter does not replace this: it
#                        filters terminal accounting, not the dispatch, and
#                        run_5682a0ed1455's three failed rows read
#                        `terminalState: retained`, so an
#                        `active|release_pending|release_unknown` read
#                        would miss them. Each page call is under THE TIME
#                        BOUND; one that fails or is not started makes the
#                        whole list unreadable. Each call passes `--limit
#                        100` (the most `worker-list --help` allows), so the
#                        page size is not Orca's default. STATED LIMIT: a Run
#                        past 1000 rows raises `worker-pages` each hour even
#                        when nothing is live, the L94 symptom at ten times
#                        the size.
#   outbox:<repo>:<newest file>  THE OUTBOX (punch-list L61): messages this
#                        checkout sent to `coord:<repo>` (orca-send.sh) that
#                        are still pending or were refused. One alert per
#                        target repo; the text carries the count, and the key
#                        the newest file name (#25), so an ack holds until a
#                        new file arrives. Whose: the alert-file rule below.
#   outbox:<repo>:(ambiguous|mismatch|unreadable|pruned):<alert file>
#                        orca-send.sh kept a coord: message pending because
#                        more than one live coord@main claimed <repo>, a live
#                        one sat outside <repo>'s main checkout (#17), or an
#                        Orca read failed (#24); or it pruned an unread file
#                        after 7 days (#18). From its alert file, by kind.
#   outbox:<repo>:unknown-shape:<sha1 of the name, 12 hex>  a file under the
#                        outbox that the writer could not have made: a name
#                        outside its pattern, a symlink or non-regular file,
#                        another owner, a mode other than 600, or a header in
#                        another shape. Never counted, never shown, never
#                        named unless the name is plain. Shown to the main
#                        checkout whose repo slugs to <repo> (`_root` and
#                        `_invalid`: every main checkout).
#   A main checkout's coordinator also gets a note in the summary when
#   messages wait in its own repo's outbox: rule 8's drain block shows them.
#   This script prints only counts and file names from the outbox, never a
#   header value or a body (the relay guard, design "Piece 1" decision 5).
#   A reader crash prints `ORCA health failed: the reader crashed (<type>)`
#   and then an orca-unreadable:reader alert, never a bare exit 1.
# WHOSE ALERTS. A linked worktree's coordinator sees only alert files its own
# worktree wrote; the main checkout's sees the whole repo's. The ok line
# counts the files it did not show. Acks are per worktree
# (<alert dir>/acked/<worktree>/), so one coordinator's ack never hides an
# alert from another.
# THE REPO-LESS FILE (punch-list L100). A file whose `repo` is `unknown` (a
# send from outside any checkout) was shown to every coordinator, and each
# had to ack it: orca-lab saw three such files asked in several tabs on
# 2026-11-21/22 (sender report). Now it is shown, unlabeled, to the session
# it names: its sender or target is this session's address, or its target is
# `run:<this session's Run>`. One that names another session (a known
# sender, or a target that is another session's address or `run:`) is not
# shown for its first hour, so that session answers it; after the hour, or
# when its time is in the future, it is shown to every coordinator, so a file
# whose session is gone is never lost. One that names no session is shown to
# every coordinator, labeled `no repo recorded; …`. An ack of a repo-less
# file is also written under <alert dir>/acked/_shared/, and that marker
# hides it in every coordinator: one ack, never one per tab. Every ack also
# writes this worktree's own marker, so an ack always holds where it was
# given, even for a file the reader cannot parse (PR #153 review). The ack
# reads the file's last `repo=` line, and the reader splits lines on `\n`
# only, as the ack's `sed` does, so a reason that quotes `repo=unknown`
# changes nothing. A worktree named `_shared` or `bot@…` acks as `unknown`,
# never into the shared or a bot's directory.
# BOT MODE (punch-list L103 C4). orca-lab measured from an Orca bot on Orca
# 1.4.280, 2026-11-27 (sender report, not re-run here; evanemerson/orca-lab
# docs/research/2026-11-23-bot-coordinator-pilot.md M6): its cwd is
# ~/.orca/bots/<name>, not a git checkout; ORCA_TERMINAL_HANDLE is unset;
# this script showed 180 alerts of every repo, raised
# `orca-unreadable:run-current` though `run-current` returned the bot's Run
# (its `coordinator_handle` is null, which the reader refused), and turned
# the own-question check off. So:
#   - Identity: a `term_` ORCA_TERMINAL_HANDLE, else, when it is empty,
#     `orca_session_id:<ORCA_AGENT_SESSION_ID>` with ORCA_STRUCTURED_SESSION=1
#     (orca-send.sh's rule, L103 C1; Orca writes a chat's mail from that
#     address, chat probe P1). The own-question (`awaited`) check and the
#     repo-less rule key on it.
#   - Run: with no Run named, `run-current` is read as before (no
#     `--terminal`: P1 measured that Orca picks a chat's own Run). A null
#     holder is a known shape: from a chat it is that chat's Run and is
#     checked; from a terminal it is noted, never unreadable.
#   - Repo: outside a git checkout, the repo is the `repo:` argument, else the
#     bot home's own name when it is `<repo>-bot` (the real path of the cwd
#     is exactly $HOME/.orca/bots/<repo>-bot; orca-send.sh's `coord:<repo>`
#     looks for that name, L103 C2). The session then sees that repo's files
#     as its main checkout's coordinator does, and its acks go under
#     acked/bot@<repo>/. With neither, it shows no file of a named repo, and
#     raises `orca-unreadable:repo:<hour>` naming how many it did not read:
#     never every repo's alerts.
#   - Not measured: which mailbox `inbox` lists from a chat (the inbox window
#     is read as from a terminal, and a chat's summary line says so); and a stale worker's commit read (LIFE)
#     needs this repo's `git worktree list`, which a bot home has none of, so
#     it reads `unread` there.
# THE REASON. An alert file's reason is shown only when it matches one that
# orca-send.sh writes (REASONS, below); any other text prints as
# `an unrecognised reason`, so a file another process planted cannot put
# words into the operator question (§12c). The gate checks that every literal
# reason in orca-send.sh is in that list.
# NOT an alert: liveness `unverifiable`. Orca's guide calls it absence, never
# proof, and every settled shell or released worker reads that way.
# An `escalation` sets no attention category (measured), so it is read from
# the inbox by rule 5, not here.
#
# ACKS are empty marker files named by key in <alert dir>/acked/<worktree>/;
# an alert file stays where it is. `ORCA ack:` prints only after the marker
# is written; a send-failed key with no such file prints `ORCA ack failed`.
# A stale key carries the last life and a waiting key the UTC hour, so a
# worker that shows life again and goes quiet again, or stays parked, alerts
# again.
#
# STATED LIMITS:
#   - It runs only when the coordinator runs a turn. An idle coordinator runs
#     none (rule 8's limit), so an idle Run is still unwatched.
#   - The alert files are on this machine. A send from another machine or
#     another Orca host leaves no file here.
#   - Its Run is the named one, or this pane's Run when this terminal holds
#     it. A session with neither gets only the file and awaited alerts.
#   - From a chat, a named Run with a null holder is not proven to be this
#     chat's: Orca records no chat as a holder, so another chat's Run reads
#     the same, and raises no `unbound`.
#   - A repo-less file that names a session no coordinator runs as waits its
#     first hour unseen.
#   - The inbox window is 200 rows, newest first (the whole store was 245 rows
#     on 2026-10-31). An older question is not seen, and a worker_done older
#     than the window does not clear its failed dispatch (one extra question).
#   - The bounds are fixed here, from one Run's history. A worker with a
#     longer honest gap will alert: one whose turn ended while a background
#     job runs (the mutation sweep runs ~43 min) sends no heartbeat, prints
#     nothing and has no `input` category. That costs one question; a missed
#     hang costs the session.
#   - Terminal output proves a program drew to the screen, not that it makes
#     progress. An agent hung inside a turn whose timer still redraws reads
#     as live until 180 minutes after its dispatch. `check --wait` in the
#     foreground likely reads the same way; that was not measured.
#   - A commit on the base branch made after the dispatch reads as life for
#     up to 30 minutes when the worker branched from it. A worker can also
#     date a commit up to 180 seconds ahead.
#   - A worker honest past 180 minutes alerts `stale:` beside `long:`, with
#     its terminal output `not counted`.
#   - The stale key follows the newest life that was read, so a read that
#     fails after an ack can move the key back and ask once more about the
#     same silence. An extra question, never a lost alert.
#   - A send that failed and then succeeded on a rerun still leaves its alert
#     file; the operator acks it.
#   - `now` is this machine's clock and the Orca times are read as UTC (both
#     formats agreed on the measured Run). A skewed WSL clock shifts every
#     age; a time in the future reads as age 0, not as an alert.
set -u

cepa_h_cli=${1-}
cepa_h_dir=${CEPA_ORCA_ALERT_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/cepa/orca-alerts}

refuse() { echo "ORCA health refused: $1"; exit 4; }

[ $# -ge 1 ] || refuse "usage: orca-health.sh <cli> [repo:<repo>] [<run>] or <cli> [repo:<repo>] ack <key>..."
case "$cepa_h_cli" in
  ''|-*|*[!A-Za-z0-9._/-]*) refuse "the cli is not a plain command name" ;;
  /*) [ "$cepa_h_cli" = "${ORCA_CLI_COMMAND:-}" ] || refuse "a cli path must equal ORCA_CLI_COMMAND" ;;
  */*) refuse "a cli path must be absolute and equal ORCA_CLI_COMMAND" ;;
esac
case "${cepa_h_cli##*/}" in
  orca-ide|orca-dev) ;;
  orca) [ "$(uname -s 2>/dev/null || echo Linux)" != Linux ] || case "$cepa_h_cli" in
    /*/linux-orca-cli-shim/orca|/*/cli/bin/orca)
      cepa_h_l=; [ ! -f "$cepa_h_cli" ] || { IFS= read -r cepa_h_l <"$cepa_h_cli"; } 2>/dev/null || :
      case "$cepa_h_l" in
        '#!/usr/bin/env bash'|'#!/usr/bin/env sh') ;;
        *) refuse "an orca path on Linux is not an Orca launcher" ;;
      esac ;;
    /*) refuse "an orca path on Linux is not an Orca launcher" ;;
    *) refuse "bare orca on Linux is the screen reader" ;;
  esac ;;
  *) refuse "the cli does not name an Orca CLI" ;;
esac
[[ $cepa_h_dir == /* ]] || refuse "the alert directory is not an absolute path"
# BOT MODE (header): an optional `repo:<repo>` right after <cli>.
cepa_h_argrepo=
if [ $# -ge 2 ] && [[ $2 == repo:* ]]; then
  [[ $2 =~ ^repo:[A-Za-z0-9._@-]{1,100}$ ]] || refuse "the repo: argument is not repo: followed by [A-Za-z0-9._@-]"
  cepa_h_argrepo=${2#repo:}
  set -- "$1" "${@:3}"
fi

# This session's own address (BOT MODE, header): its term_ handle, else a
# chat's `orca_session_id:<id>` (orca-send.sh's rule, L103 C1), else none.
cepa_h_me=${ORCA_TERMINAL_HANDLE:-}
if [ -z "$cepa_h_me" ]; then
  [ "${ORCA_STRUCTURED_SESSION:-}" = 1 ] && [[ ${ORCA_AGENT_SESSION_ID:-} =~ ^[0-9a-f-]{36}$ ]] \
    && cepa_h_me=orca_session_id:$ORCA_AGENT_SESSION_ID
elif ! [[ $cepa_h_me =~ ^term_[0-9a-f-]{36}$ ]]; then
  cepa_h_me=
fi

# This checkout: the repo (as rule 6 names it), the worktree's directory name,
# and whether it is the main checkout. A linked worktree's coordinator sees
# only its own worktree's alert files; the main checkout's sees the repo's.
# One git call: its three lines are the common dir, the git dir and the top.
cepa_h_common= cepa_h_gitdir= cepa_h_wt=
{ IFS= read -r cepa_h_common && IFS= read -r cepa_h_gitdir && IFS= read -r cepa_h_wt; } < <(
  git rev-parse --path-format=absolute --git-common-dir --git-dir --show-toplevel 2>/dev/null) || :
cepa_h_norepo=0
case "$cepa_h_common" in /*/.git) cepa_h_repo=${cepa_h_common%/.git} cepa_h_repo=${cepa_h_repo##*/} ;; *) cepa_h_repo=unknown ;; esac
[[ $cepa_h_repo =~ ^[A-Za-z0-9._@-]{1,100}$ ]] || cepa_h_repo=unknown
cepa_h_wt=${cepa_h_wt##*/}
[[ $cepa_h_wt =~ ^[A-Za-z0-9._@-]{1,100}$ ]] || cepa_h_wt=unknown
cepa_h_main=0
[ -n "$cepa_h_gitdir" ] && [ "$cepa_h_gitdir" = "$cepa_h_common" ] && cepa_h_main=1
case "$cepa_h_common" in
  /*/.git)
    [ -z "$cepa_h_argrepo" ] || [ "$cepa_h_argrepo" = "$cepa_h_repo" ] \
      || refuse "the repo: argument names another repo than this checkout's"
    # A worktree named like the shared or a bot's ack directory acks as
    # unknown, never into theirs (PR #153 review).
    case "$cepa_h_wt" in _shared|bot@*) cepa_h_wt=unknown ;; esac ;;
  *)
    # No git checkout (a bot home or a chat scratch dir): the repo is the
    # repo: argument, else the bot home's name, else none (BOT MODE).
    cepa_h_repo=$cepa_h_argrepo
    if [ -z "$cepa_h_repo" ]; then
      cepa_h_bots=$(cd "$HOME/.orca/bots" 2>/dev/null && pwd -P) || cepa_h_bots=
      cepa_h_here=$(pwd -P 2>/dev/null) || cepa_h_here=
      cepa_h_bn=${cepa_h_here##*/}
      if [ -n "$cepa_h_bots" ] && [ "$cepa_h_here" = "$cepa_h_bots/$cepa_h_bn" ] \
          && [[ $cepa_h_bn =~ ^[A-Za-z0-9_][A-Za-z0-9._-]{0,104}-bot$ ]] \
          && [[ ${cepa_h_bn%-bot} =~ ^[A-Za-z0-9._@-]{1,100}$ ]]; then
        cepa_h_repo=${cepa_h_bn%-bot}
      fi
    fi
    if [ -n "$cepa_h_repo" ]; then
      # A bot coordinates its repo as its main checkout's coordinator does.
      cepa_h_main=1 cepa_h_wt=bot@$cepa_h_repo
    else
      cepa_h_repo=unknown cepa_h_norepo=1
    fi ;;
esac
# Acks are this worktree's own: one coordinator's ack never hides an alert
# from another. A repo-less alert file's ack is shared (L100, header).
cepa_h_acked="$cepa_h_dir/acked/$cepa_h_wt"
cepa_h_shared="$cepa_h_dir/acked/_shared"

cepa_h_want=
if [ $# -ge 2 ] && [ "$2" != ack ]; then
  [ $# -eq 2 ] || refuse "usage: orca-health.sh <cli> [repo:<repo>] [<run>] or <cli> [repo:<repo>] ack <key>..."
  [[ $2 =~ ^run_[A-Za-z0-9_]{1,64}$ ]] || refuse "the run is not run_ followed by [A-Za-z0-9_]"
  cepa_h_want=$2
elif [ $# -ge 2 ]; then
  [ $# -ge 3 ] || refuse "usage: orca-health.sh <cli> [repo:<repo>] [<run>] or <cli> [repo:<repo>] ack <key>..."
  shift 2
  for k in "$@"; do
    [[ $k =~ ^(send-failed:[0-9]{1,12}-[A-Za-z0-9]{1,20}\.alert|outbox:[A-Za-z0-9_-]{1,100}:([0-9]{8}T[0-9]{6}Z-[A-Za-z0-9]{8}\.md|(ambiguous|mismatch|unreadable|pruned):[0-9]{1,12}-[A-Za-z0-9]{1,20}\.alert|unknown-shape:[0-9a-f]{12})|(exited|failed|long|question|awaited):[A-Za-z0-9_]{1,64}|(waiting|stale):[A-Za-z0-9_]{1,64}:[0-9]{1,12}|unbound:run_[A-Za-z0-9_-]{1,64}:[0-9]{1,12}|orca-unreadable:[a-z-]{1,20}:[0-9]{1,12})$ ]] \
      || refuse "not an alert key: $(printf '%s' "${k:0:80}" | tr -c 'A-Za-z0-9_.:-' '?')"
  done
  mkdir -p "$cepa_h_acked" 2>/dev/null || { echo "ORCA ack failed: the ack directory could not be made"; exit 1; }
  cepa_h_bad=0
  for k in "$@"; do
    cepa_h_af=
    [[ $k == send-failed:* ]] && cepa_h_af=${k#send-failed:}
    [[ $k =~ ^outbox:[^:]+:(ambiguous|mismatch|unreadable|pruned):(.+)$ ]] && cepa_h_af=${BASH_REMATCH[2]}
    # L100: an alert file with no known repo is acked once for every
    # coordinator (its marker goes under acked/_shared/).
    # The marker always goes under this worktree's directory, so the ack
    # holds here whatever the file says. One that reads repo-less (its last
    # repo= line, as the reader keeps it) also goes under _shared/, where
    # every coordinator reads it (PR #153 review: a reader and an ack that
    # disagree must never leave an ack that does not hold).
    cepa_h_frepo=
    [ -z "$cepa_h_af" ] || [ ! -f "$cepa_h_dir/$cepa_h_af" ] \
      || cepa_h_frepo=$(sed -n 's/^repo=//p' "$cepa_h_dir/$cepa_h_af" 2>/dev/null | tail -n 1)
    cepa_h_share=1
    [ "$cepa_h_frepo" != unknown ] \
      || { mkdir -p "$cepa_h_shared" 2>/dev/null && : >"$cepa_h_shared/$k" 2>/dev/null; } || cepa_h_share=0
    if [ -n "$cepa_h_af" ] && [ ! -f "$cepa_h_dir/$cepa_h_af" ]; then
      echo "ORCA ack failed: $k — no such alert file"; cepa_h_bad=1
    elif [ "$cepa_h_share" = 0 ]; then
      echo "ORCA ack failed: $k — the shared ack marker could not be written"; cepa_h_bad=1
    elif : >"$cepa_h_acked/$k" 2>/dev/null; then
      echo "ORCA ack: $k"
    else
      echo "ORCA ack failed: $k — the ack marker could not be written"; cepa_h_bad=1
    fi
  done
  exit "$cepa_h_bad"
fi

command -v "$cepa_h_cli" >/dev/null 2>&1 || refuse "$cepa_h_cli is not on PATH"
command -v timeout >/dev/null 2>&1 || refuse "no timeout command to bound the Orca calls"
command -v python3 >/dev/null 2>&1 || refuse "no python3 to read the Orca output"
cepa_h_now=$(date +%s 2>/dev/null) || cepa_h_now=
[[ $cepa_h_now =~ ^[0-9]{1,12}$ ]] || refuse "date gave no clock"
cepa_h_tmp=$(mktemp -d 2>/dev/null) || refuse "mktemp failed"
trap 'rm -rf "$cepa_h_tmp"' EXIT

# THE TIME BOUND. Each call is bounded at 15 seconds plus a 2-second kill and
# retried once on the WSL interop error (orca-send.sh's rule). No call starts
# 90 seconds or more after the script did, and none starts after a call timed
# out: a wedged Orca would only stack more 17-second waits. A call that is not
# started counts as failed, so it raises orca-unreadable, never `ok`. Worst
# case about 90 + 34 = 124 seconds, plus the 10-second git budget (LIFE): run
# the block with a tool timeout of at least 3 minutes.
cepa_h_wedged=0
cepa_h_orca() {
  local out=$1 try rc e t
  shift
  for try in 1 2; do
    t=$(date +%s 2>/dev/null) || t=
    [[ $t =~ ^[0-9]{1,12}$ ]] && [ $((t - cepa_h_now)) -lt 90 ] && [ "$cepa_h_wedged" = 0 ] || return 1
    timeout -k 2 15 "$cepa_h_cli" "$@" </dev/null >"$out" 2>"$cepa_h_tmp/err" && return 0
    rc=$?
    if [ "$rc" = 124 ] || [ "$rc" = 137 ]; then cepa_h_wedged=1; return 1; fi
    [ "$try" = 1 ] || return 1
    { e=$(<"$cepa_h_tmp/err"); } 2>/dev/null || return 1
    [[ $e == *UtilAcceptVsock* && $e == *"accept4 failed 110"* ]] || return 1
  done
  return 1
}

# Each read writes its result to a file, or a `.fail` marker beside it. The
# two small readers exit non-zero on any shape they do not know, so a changed
# Orca reads as unreadable, never as an empty Run. The named Run is read by
# id; it must be there and be that Run.
cepa_h_run=
if [ -n "$cepa_h_want" ]; then
  if cepa_h_orca "$cepa_h_tmp/run.json" orchestration run-show --id "$cepa_h_want" --json --full; then
    cepa_h_run=$(python3 -I -c '
import json, sys
d = json.load(open(sys.argv[1]))
r = d["result"]["run"] if d.get("ok") is True else sys.exit(1)
if not isinstance(r, dict) or r["id"] != sys.argv[2]:
    sys.exit(1)
print(r["id"])
' "$cepa_h_tmp/run.json" "$cepa_h_want" 2>/dev/null) || { cepa_h_run=; : >"$cepa_h_tmp/run.fail"; }
  else
    : >"$cepa_h_tmp/run.fail"
  fi
else
  # No Run named: this pane's run-current Run counts only when this
  # terminal holds it. Another holder is noted, never checked. A null holder
  # is a known shape (BOT MODE, header): a chat's own Run, checked from that
  # chat, and only noted from a terminal.
  if cepa_h_orca "$cepa_h_tmp/run.json" orchestration run-current --json --full; then
    cepa_h_run=$(python3 -I -c '
import json, re, sys
d = json.load(open(sys.argv[1]))
r = d["result"]["run"] if d.get("ok") is True else sys.exit(1)
if r is None:
    sys.exit(0)
i, h = r["id"], r["coordinator_handle"]
if not (isinstance(i, str) and re.fullmatch(r"run_[A-Za-z0-9_-]{1,64}", i)):
    sys.exit(1)
chat = sys.argv[2].startswith("orca_session_id:")
# A structured session holds with a structworker_ handle (orca-rebind.sh,
# THE STRUCTURED HOLDER): read as a null holder is.
if h is None or isinstance(h, str) and re.fullmatch(r"structworker_[0-9a-f-]{36}", h):
    if chat:
        print(i)
    else:
        open(sys.argv[3], "w").write("%s %s" % (i, h or "-"))
    sys.exit(0)
if not (isinstance(h, str) and re.fullmatch(r"term_[0-9a-f-]{36}", h)):
    sys.exit(1)
if h == sys.argv[2]:
    print(i)
else:
    open(sys.argv[3], "w").write("%s %s" % (i, h))
' "$cepa_h_tmp/run.json" "$cepa_h_me" "$cepa_h_tmp/run.other" 2>/dev/null) \
      || { cepa_h_run=; : >"$cepa_h_tmp/run.fail"; : >"$cepa_h_tmp/run.current"; }
  else
    : >"$cepa_h_tmp/run.fail"; : >"$cepa_h_tmp/run.current"
  fi
fi
mkdir -p "$cepa_h_tmp/show"
if [ -n "$cepa_h_run" ]; then
  cepa_h_ids=
  # L94: worker-list pages hold 100 rows, newest first, and finished rows
  # fill them, so every page is read (WORKER-LIST PAGES, header) up to 10.
  cepa_h_pg=0 cepa_h_cur= cepa_h_wlok=1 cepa_h_wf=() cepa_h_seen=" "
  while :; do
    if [ "$cepa_h_pg" -ge 10 ]; then : >"$cepa_h_tmp/pages"; break; fi
    cepa_h_pg=$((cepa_h_pg + 1))
    cepa_h_wl=(orchestration worker-list --run "$cepa_h_run" --limit 100 --json --full)
    [ -z "$cepa_h_cur" ] || cepa_h_wl+=(--cursor "$cepa_h_cur")
    cepa_h_orca "$cepa_h_tmp/workers.$cepa_h_pg.json" "${cepa_h_wl[@]}" || { cepa_h_wlok=0; break; }
    cepa_h_wf+=("$cepa_h_tmp/workers.$cepa_h_pg.json")
    # The next cursor, or nothing on the last page. A page with no `page`
    # object is the last one only when it holds under 100 rows (an Orca that
    # does not page); a full one, `hasMore` absent or not a boolean, or a
    # cursor outside base64url or starting with `-` (it would read as an
    # option), is unreadable. So is a cursor seen before: a loop.
    cepa_h_cur=$(python3 -I -c '
import json, re, sys
d = json.load(open(sys.argv[1]))
p = d["result"].get("page") if d.get("ok") is True and isinstance(d.get("result"), dict) else sys.exit(1)
if p is None:
    sys.exit(0 if len(d["result"].get("workers") or []) < 100 else 1)   # the row reader checks the shape
m = p["hasMore"]
if m is False:
    sys.exit(0)
c = p["nextCursor"]
if m is not True or not (isinstance(c, str) and re.fullmatch(r"[A-Za-z0-9_][A-Za-z0-9_=-]{0,4095}", c)):
    sys.exit(1)
print(c)
' "$cepa_h_tmp/workers.$cepa_h_pg.json" 2>/dev/null) || { cepa_h_wlok=0; break; }
    [ -n "$cepa_h_cur" ] || break
    [[ $cepa_h_seen != *" $cepa_h_cur "* ]] || { cepa_h_wlok=0; break; }
    cepa_h_seen+="$cepa_h_cur "
  done
  if [ "$cepa_h_wlok" = 1 ] && cepa_h_ids=$(python3 -I -c '
import json, re, sys
rows = []
for f in sys.argv[4:]:
    d = json.load(open(f))
    r = d["result"]["workers"] if d.get("ok") is True else sys.exit(1)
    if not isinstance(r, list):
        sys.exit(1)
    rows += r
ids, failed, byid = [], [], {}
for w in rows:
    # L89 g: a dispatch started on an Orca host (`worker-start --on`) lists
    # with no projection and a `server` object naming its environment. The
    # local Orca projects nothing for it, so it is not read here (header,
    # HOST DISPATCHES); any other row without a projection is still unknown.
    sv = w.get("server") if isinstance(w, dict) else None
    if isinstance(sv, dict) and isinstance(sv.get("environmentId"), str) and sv["environmentId"] != "local" \
            and w.get("projection") is None \
            and isinstance(w.get("dispatchId"), str) and re.fullmatch(r"ctx_[0-9a-f]{6,32}", w["dispatchId"]):
        continue
    i, o = w["dispatchId"], w["projection"]["outcome"]
    if not (isinstance(i, str) and re.fullmatch(r"ctx_[0-9a-f]{6,32}", i) and isinstance(o, str)):
        sys.exit(1)
    # A row read on two pages (it moved as new ones came in) counts once, as
    # its most settled copy: failed, then another outcome, then in_progress.
    rank = {"in_progress": 0, "failed": 2}.get(o, 1)
    if i not in byid or rank > byid[i][0]:
        byid[i] = (rank, w)
for i, (_, w) in byid.items():
    o = w["projection"]["outcome"]
    if o == "in_progress":
        ids.append(i)
    elif o == "failed":
        # L60: where it failed, as Orca names the stage.
        det = (w["projection"].get("stage") or {}).get("detail")
        failed.append("%s %s" % (i, det if isinstance(det, str) and re.fullmatch(r"[a-z_]{1,40}", det) else "unknown"))
# L94: the cap counts live rows only; finished rows on more pages never do.
if len(ids) > 20:
    open(sys.argv[2], "w").close()
open(sys.argv[3], "w").write("".join(x + "\n" for x in failed))
print(" ".join(ids[:20]))
' _ "$cepa_h_tmp/capped" "$cepa_h_tmp/failed.ids" "${cepa_h_wf[@]}" 2>/dev/null); then
    for d in $cepa_h_ids; do
      cepa_h_orca "$cepa_h_tmp/show/$d.json" orchestration worker-show --dispatch "$d" --json --full \
        || : >"$cepa_h_tmp/show/$d.fail"
    done
    # L60: a failed dispatch not yet acked is read for its last failure, at
    # most 10 of them a run (THE TIME BOUND still applies).
    mkdir -p "$cepa_h_tmp/fshow"
    cepa_h_nf=0
    while read -r cepa_h_fd _; do
      [ ! -e "$cepa_h_acked/failed:$cepa_h_fd" ] || continue
      cepa_h_nf=$((cepa_h_nf + 1))
      [ "$cepa_h_nf" -le 10 ] || break
      cepa_h_orca "$cepa_h_tmp/fshow/$cepa_h_fd.json" orchestration worker-show --dispatch "$cepa_h_fd" --json --full \
        || : >"$cepa_h_tmp/fshow/$cepa_h_fd.fail"
    done <"$cepa_h_tmp/failed.ids"
  else
    : >"$cepa_h_tmp/workers.fail"
  fi
fi
cepa_h_orca "$cepa_h_tmp/inbox.json" orchestration inbox --limit 200 --json --full || : >"$cepa_h_tmp/inbox.fail"

cepa_h_obox=${CEPA_ORCA_OUTBOX_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/cepa/outbox}
python3 -I - "$cepa_h_tmp" "$cepa_h_dir" "$cepa_h_now" "$cepa_h_run" "$cepa_h_repo" \
  "$cepa_h_me" "$cepa_h_wt" "$cepa_h_main" "$cepa_h_acked" "$cepa_h_obox" "$cepa_h_norepo" "$cepa_h_shared" <<'PY'
import calendar, json, os, re, subprocess, sys, time

def _crash(t, v, tb):
    # An uncaught error must not exit 1, which means "alerts".
    print("ORCA health failed: the reader crashed (%s)" % t.__name__, flush=True)
    os._exit(3)
sys.excepthook = _crash
tmp, adir, now, run, repo, me, wt, main, acked_dir, obox, norepo, shared_dir = sys.argv[1:13]
now, main, norepo = int(now), main == "1", norepo == "1"
HB_STALE, RUN_LONG, Q_WAIT, AWAIT = 30, 180, 10, 30   # minutes
LIFE_AHEAD, GIT_WAIT = 180, 3   # seconds
SAFE = re.compile(r"[A-Za-z0-9_.:@-]{1,120}")
# 1.61.0 (punch-list L98, L103 C1): a bot address and a chat recipient.
ADDR = (r"(term_[0-9a-f-]{36}|run:[A-Za-z0-9_-]{1,64}|dispatch:[A-Za-z0-9_-]{1,64}|coord:[A-Za-z0-9_-]{1,100}"
        r"|bot:[A-Za-z0-9_][A-Za-z0-9._-]{0,104}|orca_session_id:[0-9a-f-]{36})")
MID = r"msg_[0-9a-f]{6,32}"
# The reason field is shown only when it is one orca-send.sh writes (security
# review of PR #109): any other text is replaced, so an alert file planted by
# another process cannot put words into the operator question.
REASONS = [re.compile(x) for x in (
    r"the (subject|body) is empty", r"the (subject|body) starts with --, which Orca reads as a flag",
    r"the message size could not be measured",
    r"subject and body are \d{1,9} bytes; the limit is 28000 \(WSL command-line limit\)",
    r"the cli is not a plain command name", r"the cli does not name an Orca CLI",
    r"a cli path must (be absolute and )?equal ORCA_CLI_COMMAND", r"bare orca on Linux is the screen reader",
    r"an orca path on Linux is not an Orca launcher",
    r"[A-Za-z0-9._/-]{1,200} is not on PATH",
    r"orca-send\.sh takes no arguments; its fields go on stdin",
    r"a heredoc line is not a <name>: <value> field",
    r"a field name is not cli, target, type, nudge, outcome, task, session, on or file",
    # 1.56.0 (punch-list L88): the host target.
    r"an on: server goes only with a term_ target", r"the on: server is not an Orca server id or name",
    r"the (cli|target|type|nudge|outcome|task|session|on|file) field is (given twice|missing)",
    # 1.44.0 (punch-list L41): the message is in a file, never in the heredoc.
    r"the heredoc holds a message after its fields; the message goes in the file the file: field names",
    r"the message file is not an absolute path to a cepa-send-<name>\.txt file",
    r"the message file is not a regular file this user owns", r"the message file is inside the repo",
    # 1.51.0 (punch-list L47): a path to no file says how to retry.
    r"the message file does not exist; orca-send\.sh removes each message file once it reads it, "
    r"so a retry needs a new file \(or the path is wrong\)",
    r"the message file could not be (read|removed)", r"the message file's directory could not be resolved",
    r"the session name holds a character outside \[A-Za-z0-9\._@-\]",
    r"a worker_done takes outcome and task fields, not nudge",
    r"only a worker_done takes outcome and task fields",
    r"the target is not a term_ handle, run: or dispatch: address", r"a reply's target is not a msg_ message id",
    # 1.61.0 (punch-list L97, L103 C1): bot: targets and reply threads. The
    # line above is kept for one release, for an alert from 1.60.x.
    r"the target is not a term_ handle, run:, dispatch: or bot: address",
    r"the reply is threaded on " + MID + r", and the re-read does not show " + MID + r" in that thread",
    MID + r" is stored for orca_session_id:[0-9a-f-]{36}, which is not an open chat of bot:[A-Za-z0-9_][A-Za-z0-9._-]{0,104}",
    r"the chats of bot:[A-Za-z0-9_][A-Za-z0-9._-]{0,104} could not be read, so " + MID + r" is unconfirmed",
    r"the reply names no recipient for bot:[A-Za-z0-9_][A-Za-z0-9._-]{0,104}",
    r"more than one bot is named [A-Za-z0-9_-]{1,100}-bot",
    r"a worker_done target is not dispatch:ctx_<id>",
    r"the task id is not task_<id>", r"the worker_done outcome is not succeeded or failed",
    r"the type is not status, question, handoff, escalation, merge_ready, reply or worker_done",
    r"the nudge field is not nudge or no-nudge",
    # Written before 1.51.0, which sends `nudge` to a run: or dispatch: target
    # as no-nudge (punch-list L47); kept for one release, as the pre-1.43.0
    # and pre-1.44.0 groups were, so an alert from a session still on 1.50.x
    # or earlier is shown, not read as an unrecognised reason.
    r"only a term_ handle is nudged",
    r"no timeout command to bound the Orca calls", r"no python3 to read the Orca output", r"mktemp failed",
    r"no request id could be made", r"the send output could not be read",
    r"the send exited \d{1,3}( and printed (nothing|no JSON))?", r"the send printed JSON of an unexpected shape",
    r'Orca did not return "ok": true( \([a-z_]{1,40}\))?', r"the reply has no result\.message\.id",
    r"the reply names no valid recipient", r"the reply is not threaded on " + MID,
    r"Orca did not record the dispatch as (completed|failed)",
    MID + r" is not in the inbox for " + ADDR,
    r"the inbox could not be (parsed|re-read), so " + MID + r" is unconfirmed",
    # 1.54.0 (punch-list L61): the coord: address and its outbox.
    r"the coord: repo is not slug\(<repo>\) \(autonomy §5\)",
    r"an escalation cannot go to a coord: address; it keeps its Run path",
    r"the outbox directory is not an absolute path", r"the outbox directory could not be made",
    r"the outbox directory is not a directory this user owns", r"the outbox file could not be written",
    r"the (Run list|terminal list) could not be read", r"worktree ps could not be read",
    r"the Run list has more than 20 pages", r"the terminal list or worktree ps was truncated",
    r"the Orca output has a shape this reader does not know",
    r"more than one live coord@main claims [A-Za-z0-9_-]{1,100}: term_[0-9a-f-]{36}( term_[0-9a-f-]{36}){1,9}",
    r"a live session claims coord@main of [A-Za-z0-9_-]{1,100} outside its main checkout: "
    r"term_[0-9a-f-]{36}( term_[0-9a-f-]{36}){0,9}",
    r"an outbox file was pruned unread after 7 days: [A-Za-z0-9_-]{1,100}(/refused)?/"
    r"[0-9]{8}T[0-9]{6}Z-[A-Za-z0-9]{8}\.md",
    # 1.57.0 (punch-list L65): orca-nudge.sh's skip and fail reasons, and
    # orca-send.sh's own nudge-file reasons, relayed as a nudge_skipped alert.
    # (no timeout, no python3 and mktemp failed are listed above.)
    r"(terminal show|worktree ps) failed or timed out", r"terminal send exited non-zero or timed out",
    r'terminal send did not return "ok": true', r"the Orca output (could not be read|is not JSON|has an unexpected shape)",
    r'an Orca call did not return "ok": true', r"terminal show did not describe this handle",
    r"date gave no clock for the wait", r"sleep failed in the wait",
    r"orca-nudge\.sh not found beside orca-send\.sh", r"orca-nudge\.sh exited [0-3] and printed nothing",
    r"orca-nudge\.sh would not start \(exit \d{1,3}\)")]
# This session's address: a term_ handle, or a chat's orca_session_id:
# (BOT MODE, header).
if not re.fullmatch(r"term_[0-9a-f-]{36}|orca_session_id:[0-9a-f-]{36}", me):
    me = ""
chat = me.startswith("orca_session_id:")
hour = now // 3600
alerts, notes = [], []

def alert(key, text):
    alerts.append((key, text))

def unreadable(what, text=None):
    alert("orca-unreadable:%s:%d" % (what, hour),
          text or "Orca %s failed or was not readable, so this Run's health is unknown" % what.replace("-", " "))

def listdir(p, what):
    try:
        return sorted(os.listdir(p))
    except FileNotFoundError:
        return []
    except OSError:
        unreadable(what, "the %s could not be read, so its alerts are unknown" % what.replace("-", " "))
        return []

acked = set(listdir(acked_dir, "ack-dir"))
# L100: one ack of a repo-less alert file counts in every coordinator.
shared = set(listdir(shared_dir, "ack-dir"))

def ts(s):
    # "2026-10-31T20:36:22Z" or "2026-10-31 20:35:34", both UTC (the two
    # agreed on every row of the measured Run).
    if not isinstance(s, str):
        return None
    m = re.fullmatch(r"(\d{4})-(\d\d)-(\d\d)[T ](\d\d):(\d\d):(\d\d)(?:\.\d+)?Z?", s)
    try:
        return calendar.timegm(tuple(int(x) for x in m.groups()) + (0, 0, 0)) if m else None
    except (ValueError, OverflowError):
        return None

def mins(t):
    return (now - t) // 60

def hhmm(t):
    return time.strftime("%H:%M UTC", time.gmtime(t))

def load(name):
    p = os.path.join(tmp, name)
    if os.path.exists(p[:-5] + ".fail"):
        return None
    try:
        d = json.load(open(p))
    except Exception:
        return None
    return d if isinstance(d, dict) and d.get("ok") is True else None

# LIFE (header): a stale candidate's newest terminal output or commit.
WSL_PATH = re.compile(r"\\\\wsl(?:\.localhost|\$)\\[^\\]+(\\.*)")
git_left = [10.0]
trees = {}

def git(*args):
    # stdout, or None. A timeout ends every later git read of this run.
    if git_left[0] <= 0:
        return None
    t0 = time.time()
    try:
        g = subprocess.run(["git"] + list(args), stdin=subprocess.DEVNULL, capture_output=True, text=True,
                           timeout=min(GIT_WAIT, git_left[0]))
    except subprocess.TimeoutExpired:
        git_left[0] = 0
        return None
    except (OSError, ValueError):
        return None
    git_left[0] -= time.time() - t0
    return g.stdout if g.returncode == 0 else None

def worktree_refs():
    # This repo's worktrees: path -> the branch checked out there. One read.
    if "read" not in trees:
        trees["read"] = {}
        path = None
        for l in (git("worktree", "list", "--porcelain") or "").splitlines():
            if l.startswith("worktree "):
                path = l[len("worktree "):]
            elif l.startswith("branch ") and path:
                trees["read"][path] = l[len("branch "):]
    return trees["read"]

def ago(t):
    return "%d minutes ago" % max(mins(t), 0)

def life(term, handle, start):
    # (newest proof of life or None, the terminal's state, the commit's state).
    out_txt = commit_txt = "unread"
    if not isinstance(term, dict) or not isinstance(handle, str) or term.get("handle") != handle:
        return None, out_txt, commit_txt
    limit, best = now + LIFE_AHEAD, None
    out = term.get("lastOutputAt")
    if type(out) is int and 0 < out // 1000 <= limit:
        if mins(start) < RUN_LONG:
            best, out_txt = out // 1000, ago(out // 1000)
        else:
            out_txt = "not counted past %d minutes" % RUN_LONG
    ref, path = term.get("branch"), term.get("worktreePath")
    m = WSL_PATH.fullmatch(path) if isinstance(path, str) else None
    path = m.group(1).replace("\\", "/") if m else path
    if isinstance(ref, str) and isinstance(path, str) and worktree_refs().get(path) == ref:
        t = (git("log", "-1", "--format=%ct", ref, "--") or "").strip()
        if re.fullmatch(r"[0-9]{1,12}", t) and int(t) <= limit:
            commit_txt = "none since its dispatch"
            if start <= int(t):
                best, commit_txt = max(best or 0, int(t)), ago(int(t))
    return best, out_txt, commit_txt

# 1. Alert files from orca-send.sh.
FIELD = {"kind": r"send_(refused|failed|unproven)|nudge_skipped|outbox_(ambiguous|mismatch|unreadable|pruned)", "time": r"\d{1,12}", "repo": r"[A-Za-z0-9._@-]{1,100}",
         "worktree": r"[A-Za-z0-9._@-]{1,100}", "sender": r"term_[0-9a-f-]{36}|orca_session_id:[0-9a-f-]{36}|unknown",
         "target": r"(msg_[0-9a-f]{6,32}|%s)|invalid" % ADDR[1:-1],
         "type": r"[a-z_]{1,20}", "reason": r"[ -~]{0,300}"}
other = norepo_hidden = 0
REPOLESS = " (no repo recorded; shown to every coordinator, and one ack clears it in all of them, L100)"
for n in listdir(adir, "alert-dir"):
    if not re.fullmatch(r"\d{1,12}-[A-Za-z0-9]{1,20}\.alert", n):
        continue
    key = "send-failed:" + n
    try:
        # Split on \n only, as the ack path's sed does (PR #153 review).
        lines = open(os.path.join(adir, n), encoding="ascii").read().split("\n")
        f = dict(l.split("=", 1) for l in lines[1:] if "=" in l)
        shaped = lines[:1] == ["cepa-orca-alert 1"] and all(re.fullmatch(FIELD[k], f.get(k, "")) for k in FIELD)
    except Exception:
        shaped = False
    if not shaped:
        if key not in acked:
            alert(key, "an alert file in an unknown shape: %s" % n)
        continue
    label = ""
    if f["repo"] == "unknown":
        # L100 (header, WHOSE ALERTS): shown to the session it names; one that
        # names another session waits an hour for it; any other is shown to
        # every coordinator, labeled, and one ack (under acked/_shared/)
        # clears it in all of them.
        names_me = bool(me) and me in (f["sender"], f["target"]) or bool(run) and f["target"] == "run:" + run
        names_other = f["sender"] != "unknown" or re.match(r"(run:|term_|orca_session_id:|bot:)", f["target"]) is not None
        if not names_me and names_other and 0 <= now - int(f["time"]) < 3600:
            other += 1
            continue
        if not names_me:
            label = REPOLESS
    elif norepo:
        # No checkout and no repo named (BOT MODE): never every repo's files.
        norepo_hidden += 1
        continue
    else:
        # Repo unknown on the reader's side (a checkout whose name has no
        # plain form): shown, never dropped.
        mine = repo == "unknown" or f["repo"] == repo
        if mine and not main and repo != "unknown":
            mine = f["worktree"] == wt
        if not mine:
            other += 1
            continue
    if f["kind"].startswith("outbox_"):
        cls = f["kind"][len("outbox_"):]
        orepo = f["target"][len("coord:"):] if f["target"].startswith("coord:") else "_invalid"
        key = "outbox:%s:%s:%s" % (orepo, cls, n)
        if key in acked or f["repo"] == "unknown" and key in shared:
            continue
        oreason = f["reason"] if any(r.fullmatch(f["reason"]) for r in REASONS) else "an unrecognised reason"
        what = {"ambiguous": "kept a %s to %s pending, not sent (%s)",
                "mismatch": "kept a %s to %s pending, not sent (%s)",
                "unreadable": "kept a %s to %s pending: orca-unreadable (%s)",
                "pruned": "found a %s file for %s too old (%s)"}[cls]
        alert(key, "%s: orca-send.sh %s, at %s, from %s%s" % (
            f["worktree"], what % (f["type"], f["target"], oreason), hhmm(int(f["time"])), f["sender"], label))
        continue
    if key in acked or f["repo"] == "unknown" and key in shared:
        continue
    what = {"send_refused": "was refused before any Orca call",
            "send_failed": "stored nothing",
            "send_unproven": "was not proven stored",
            "nudge_skipped": "was stored, but not nudged"}[f["kind"]]
    why = f["reason"] if any(r.fullmatch(f["reason"]) for r in REASONS) else "an unrecognised reason"
    alert(key, "%s: a %s send to %s %s (%s), at %s, from %s%s" % (
        f["worktree"], f["type"], f["target"], what, why, hhmm(int(f["time"])), f["sender"], label))
if other:
    notes.append("%d alert file%s for other worktrees, repos or sessions not shown" % (other, "" if other == 1 else "s"))

# 1b. THE OUTBOX (punch-list L61). Only counts and file names are printed,
# never a header value or a body. A file counts only in the writer's exact
# shape: its name, a regular file (not a symlink) this user owns, mode 600,
# and the header orca-send.sh writes. Any other entry is unknown-shape.
import hashlib, stat
OSLUG = re.compile(r"[A-Za-z0-9_](?:[A-Za-z0-9_]|-(?!-)){0,98}[A-Za-z0-9_]|[A-Za-z0-9_]")
ONAME = re.compile(r"(\d{8}T\d{6}Z)-[A-Za-z0-9]{8}(\.to-term_[0-9a-f-]{36}|\.drained)?\.md")
OHEAD = [("time", r"\d{1,12}"), ("repo", r"[A-Za-z0-9._@-]{1,100}"), ("worktree", r"[A-Za-z0-9._@-]{1,100}"),
         ("sender", r"term_[0-9a-f-]{36}|orca_session_id:[0-9a-f-]{36}|unknown"),
         ("target", r"coord:[A-Za-z0-9_-]{1,100}|invalid"),
         ("type", r"[a-z_]{1,20}"), ("session", r"([A-Za-z0-9._@][A-Za-z0-9._@-]{0,99})?")]

def oslug(x):
    return re.sub(r"-+", "-", re.sub(r"[^A-Za-z0-9_-]", "-", x)).strip("-")

def ofile(path, sub, status):
    # The parsed header, or None for a file the writer could not have made.
    n = os.path.basename(path)
    m = ONAME.fullmatch(n)
    if not m or (m.group(2) is None) != (status != "delivered"):
        return None
    try:
        st = os.lstat(path)
        if not stat.S_ISREG(st.st_mode) or st.st_uid != os.getuid() or stat.S_IMODE(st.st_mode) != 0o600 \
                or st.st_size > 65536:
            return None
        lines = open(path, encoding="utf-8", errors="replace").read().split("\n")
    except OSError:
        return None
    if lines[:1] != ["cepa-outbox 1"] or len(lines) < 10 or lines[8] != "---":
        return None
    h = {}
    for (k, rx), l in zip(OHEAD, lines[1:8]):
        if not l.startswith(k + "=") or not re.fullmatch(rx, l[len(k) + 1:]):
            return None
        h[k] = l[len(k) + 1:]
    if h["target"] != ("invalid" if sub == "_invalid" else "coord:" + sub):
        return None
    return h

def unknown(where, name):
    k = "outbox:%s:unknown-shape:%s" % (where, hashlib.sha1(name.encode("utf-8", "replace")).hexdigest()[:12])
    plain = name if re.fullmatch(r"[A-Za-z0-9._-]{1,120}", name) else "a name that is not plain text"
    return k, "a file in the outbox that orca-send.sh did not write (%s/%s); it is never shown or counted" % (
        where, plain)

me_slug = oslug(repo) if repo != "unknown" else ""
inbound = 0
# Only an outbox that does not exist is empty: a symlink, a file or a
# directory that cannot be read is unreadable, never `ok` (review).
try:
    _st = os.lstat(obox)
    if not stat.S_ISDIR(_st.st_mode) or _st.st_uid != os.getuid():
        raise PermissionError(obox)
    osubs = sorted(os.listdir(obox))
except FileNotFoundError:
    osubs = []
except OSError:
    unreadable("outbox-dir", "the outbox directory could not be read, so its alerts are unknown")
    osubs = []
for sub in osubs:
    sp = os.path.join(obox, sub)
    see_unknown = main and (sub in ("_invalid",) or sub == me_slug)
    if not (sub == "_invalid" or OSLUG.fullmatch(sub)) or os.path.islink(sp) or not os.path.isdir(sp):
        if main:
            k, t = unknown("_root", sub)
            if k not in acked:
                alert(k, t)
        continue
    mine_n, pend, refd, newest = 0, 0, 0, ""
    for status, d in (("pending", sp), ("refused", os.path.join(sp, "refused")),
                      ("delivered", os.path.join(sp, "delivered"))):
        if status != "pending" and (os.path.islink(d) or (os.path.exists(d) and not os.path.isdir(d))):
            if see_unknown:
                k, t = unknown(sub, status)
                if k not in acked:
                    alert(k, t)
            continue
        for n in listdir(d, "outbox-dir"):
            p = os.path.join(d, n)
            if status == "pending" and n in ("refused", "delivered") and os.path.isdir(p) and not os.path.islink(p):
                continue
            if n.startswith(".new."):
                continue   # a write in progress (orca-send.sh links it to its name)
            h = ofile(p, sub, status)
            if h is None:
                if see_unknown:
                    k, t = unknown(sub, n)
                    if k not in acked:
                        alert(k, t)
                continue
            if status == "pending" and main and sub == me_slug:
                inbound += 1
            if status == "delivered":
                continue
            if norepo and h["repo"] != "unknown":
                norepo_hidden += 1   # BOT MODE: never every repo's outbox
                continue
            ours = repo == "unknown" or h["repo"] in (repo, "unknown")
            if ours and not main and repo != "unknown":
                ours = h["worktree"] == wt
            if not ours:
                continue
            mine_n += 1
            pend += status == "pending"
            refd += status == "refused"
            newest = max(newest, n)
    if mine_n:
        k = "outbox:%s:%s" % (sub, newest)
        if k not in acked:
            alert(k, "%d message%s to %s not delivered (%d pending, %d refused); newest %s" % (
                mine_n, "" if mine_n == 1 else "s", "coord:" + sub if sub != "_invalid" else "an invalid coord: address",
                pend, refd, newest))
if norepo_hidden:
    unreadable("repo", "this session is in no git checkout and names no repo (a repo: argument, or a bot home "
                       "named <repo>-bot), so %d alert or outbox file%s of named repos were not read (BOT MODE)"
               % (norepo_hidden, "" if norepo_hidden == 1 else "s"))
if inbound:
    notes.append("%d outbox message%s for coord:%s wait; rule 8's drain block shows them"
                 % (inbound, "" if inbound == 1 else "s", me_slug))

# 2. The named Run's live dispatches (or this pane's Run held here).
if os.path.exists(os.path.join(tmp, "run.fail")):
    unreadable("run-current" if os.path.exists(os.path.join(tmp, "run.current")) else "run-show")
try:
    oid, oh = open(os.path.join(tmp, "run.other")).read().split()
    k = "unbound:%s:%d" % (oid, hour)
    if (oh == "-" or oh.startswith("structworker_")) and not chat:
        # PR #153 review: before 1.62.0 this read as orca-unreadable; a note
        # alone would read ok while the Run's workers go unchecked.
        if k not in acked:
            alert(k, "this pane's Run %s %s, not this terminal, so its workers are not checked; run the re-bind "
                     "block (§12b rule 2), which asks before it takes it"
                  % (oid, "has no recorded holder (a chat or bot's Run reads so)" if oh == "-"
                     else "is held by the structured session %s" % oh))
    else:
        notes.append("this %s's Run %s is held by %s, not this %s; not checked (§12b rule 2)"
                     % ("chat" if chat else "pane", oid, oh, "chat" if chat else "terminal"))
except (OSError, ValueError):
    pass
if run and me:
    # L45: the Run's record names the terminal Orca prompts. A restarted
    # coordinator's Run still names the dead one until it re-binds.
    rr = ((load("run.json") or {}).get("result") or {}).get("run") or {}
    holder = rr.get("coordinator_handle") if isinstance(rr, dict) else None
    k = "unbound:%s:%d" % (run, hour)
    # From a terminal a structworker_ holder is another session's, as a
    # term_ one is; from a chat it may be the chat itself (THE STRUCTURED
    # HOLDER, orca-rebind.sh), so it raises nothing there.
    hold_rx = r"term_[0-9a-f-]{36}" if chat else r"(term|structworker)_[0-9a-f-]{36}"
    if isinstance(holder, str) and re.fullmatch(hold_rx, holder) and holder != me and k not in acked:
        alert(k, "Run %s is bound to %s, not this %s, so Orca prompts that terminal; "
                 "run the re-bind block (§12b rule 2)" % (run, holder, "chat" if chat else "terminal"))
    elif holder is None and isinstance(rr, dict) and "coordinator_handle" in rr and not chat and k not in acked:
        # tab49 residual 1: a null holder is a chat or bot's Run shape, so
        # Orca prompts no terminal for it (orca-rebind.sh, THE NULL HOLDER).
        alert(k, "Run %s has no recorded holder (a chat or bot's Run reads so), not this terminal, so Orca "
                 "prompts no terminal for it; run the re-bind block (§12b rule 2), which asks before it takes it" % run)
if run:
    if os.path.exists(os.path.join(tmp, "workers.fail")):
        unreadable("worker-list")
    if os.path.exists(os.path.join(tmp, "capped")):
        unreadable("worker-cap", "more than 20 dispatches are live; only 20 were read")
    if os.path.exists(os.path.join(tmp, "pages")):
        unreadable("worker-pages", "worker-list has more than 10 pages; dispatches past them were not read")
    for n in listdir(os.path.join(tmp, "show"), "show-dir"):
        if n.endswith(".fail"):
            unreadable("worker-show")
            continue
        d = load(os.path.join("show", n))
        r = d.get("result") if d else None
        disp = r.get("dispatch") if isinstance(r, dict) else None
        p = r.get("projection") if isinstance(r, dict) else None
        did = disp.get("id") if isinstance(disp, dict) else None
        start = ts(disp.get("dispatchedAt")) if isinstance(disp, dict) else None
        if did != n[:-5] or not isinstance(p, dict) or not isinstance(p.get("outcome"), str) or start is None:
            unreadable("worker-show")
            continue
        if p["outcome"] != "in_progress":
            continue   # settled between worker-list and worker-show
        cats = (p.get("attention") or {}).get("categories") or []
        verdict = (p.get("liveness") or {}).get("verdict")
        wait = (r.get("observation") or {}).get("agentWait")
        handle = (r.get("worker") or {}).get("agentTerminalHandle") or disp.get("assigneeHandle")
        who = did + (" (%s)" % handle if isinstance(handle, str) and re.fullmatch(r"term_[0-9a-f-]{36}", handle) else "")
        if verdict == "exited":
            k = "exited:" + did
            if k not in acked:
                alert(k, "worker %s exited with no worker_done" % who)
            continue
        if wait:
            # Keyed by the hour, so a worker still parked an hour later asks again.
            k = "waiting:%s:%d" % (did, hour)
            if k not in acked:
                alert(k, "worker %s is parked on a prompt only a human can answer" % who)
            continue
        hb = ts(disp.get("lastHeartbeatAt"))
        if hb is None and disp.get("lastHeartbeatAt") is not None:
            unreadable("worker-show")   # a heartbeat time in a shape this reader cannot date
            continue
        last = hb if hb is not None else start
        out_txt = commit_txt = "unread"
        if "input" not in cats and mins(last) >= HB_STALE:
            seen, out_txt, commit_txt = life(r.get("terminal"), handle, start)
            last = max(last, seen or 0)
        k = "stale:%s:%d" % (did, last)
        if "input" not in cats and mins(last) >= HB_STALE and k not in acked:
            alert(k, "worker %s shows no life for %d minutes (bound %d): heartbeat %s, terminal output %s, commit %s" % (
                who, mins(last), HB_STALE, ago(hb) if hb is not None else "none since its dispatch", out_txt, commit_txt))
        k = "long:" + did
        if mins(start) >= RUN_LONG and k not in acked:
            alert(k, "worker %s has run %d minutes with no worker_done (bound %d)" % (who, mins(start), RUN_LONG))

# 3. Questions, from the inbox.
inbox = load("inbox.json")
rows = (inbox.get("result") or {}).get("messages") if inbox else None
if not isinstance(rows, list):
    unreadable("inbox")
    rows = []
# A row in Orca 1.4.246's concise shape (no --full: `from`/`to`, no
# created_at or thread_id) would skip every question check and read `ok`
# (L72). Any row that is not an object with the full fields makes the inbox
# unreadable.
if any(not isinstance(x, dict)
       or not all(k in x for k in ("id", "type", "from_handle", "to_handle", "thread_id", "created_at"))
       for x in rows):
    unreadable("inbox")
    rows = []
if len(rows) >= 200:
    notes.append("inbox window full: questions older than 200 rows not read")
if chat:
    notes.append("inbox read as from a terminal: which mailbox a chat's inbox lists is not measured")
if not me:
    notes.append("own-question check off: no term_ handle in ORCA_TERMINAL_HANDLE and no chat identity "
                 "(ORCA_STRUCTURED_SESSION=1 with ORCA_AGENT_SESSION_ID)")
sender = {x.get("id"): x.get("from_handle") for x in rows if isinstance(x.get("id"), str)}
answered = set()
for x in rows:
    t = x.get("thread_id")
    # A reply is a row on the thread that the question's own sender did not write.
    if isinstance(t, str) and t != x.get("id") and x.get("from_handle") != sender.get(t):
        answered.add(t)
for x in rows:
    mid, t = x.get("id"), ts(x.get("created_at"))
    if x.get("type") != "question" or t is None or mid in answered \
            or not (isinstance(mid, str) and re.fullmatch(MID, mid)):
        continue
    if run and x.get("to_handle") == "run:" + run and mins(t) >= Q_WAIT:
        k = "question:" + mid
        if k not in acked:
            alert(k, "worker question %s has waited %d minutes for your reply (bound %d)" % (mid, mins(t), Q_WAIT))
    elif me and x.get("from_handle") == me and mins(t) >= AWAIT:
        k = "awaited:" + mid
        to = x.get("to_handle")
        to = to if isinstance(to, str) and SAFE.fullmatch(to) else "its recipient"
        if k not in acked:
            alert(k, "your question %s to %s has had no reply for %d minutes (bound %d)" % (mid, to, mins(t), AWAIT))

# 4. Failed dispatches (L60). The sentences Orca 1.4.259 wrote as
# dispatch.lastFailure (worker-show of run_5682a0ed1455's failed dispatches).
LAST_FAILURES = ("Agent process stop was requested but never confirmed",)
# A dispatch that failed at start (or whose agent
# exited) settles as `failed` with no worker_done, and Orca sends no message
# for it. One the worker reported itself has a worker_done row in the inbox
# window, which rule 5 already shows.
if run and not os.path.exists(os.path.join(tmp, "workers.fail")):
    reported = set()
    for x in rows:
        if x.get("type") == "worker_done" and isinstance(x.get("payload"), str):
            try:
                pl = json.loads(x["payload"])
            except ValueError:
                continue
            # Only the worker's own failed report: a `succeeded` one for a
            # dispatch Orca settled failed still alerts (PR #138 review).
            if isinstance(pl, dict) and isinstance(pl.get("dispatchId"), str) and pl.get("outcome") == "failed":
                reported.add(pl["dispatchId"])
    try:
        flines = open(os.path.join(tmp, "failed.ids")).read().split("\n")
    except OSError:
        flines = []
    for line in flines:
        if not line:
            continue
        did, det = line.split(" ", 1)
        k = "failed:" + did
        if k in acked or did in reported:
            continue
        fs = load(os.path.join("fshow", did + ".json"))
        disp = ((fs or {}).get("result") or {}).get("dispatch")
        if not isinstance(disp, dict) or disp.get("id") != did:
            why, handle = "last failure unread", None
        else:
            lf = disp.get("lastFailure")
            # Orca's own text, shown only as a token or a sentence Orca was
            # measured to write (§12c: a shape, never free prose).
            why = "last failure: " + (lf if isinstance(lf, str) and (re.fullmatch(r"[a-z_]{1,40}", lf) or lf in LAST_FAILURES)
                                      else "an unrecognised failure")
            handle = disp.get("assigneeHandle")
        who = did + (" (%s)" % handle if isinstance(handle, str) and re.fullmatch(r"term_[0-9a-f-]{36}", handle) else "")
        alert(k, "worker %s failed at stage %s with no worker_done (%s); Orca sends no message for it" % (who, det, why))

seen, hidden = set(), set()
for k, text in alerts:
    if k.startswith("orca-unreadable:") and k in acked:
        hidden.add(k)   # acked this hour: not asked again, and never read as ok
        continue
    if k in seen:
        continue
    seen.add(k)
    print("ORCA alert: %s — %s" % (k, text))
tail = " (%s)" % "; ".join(notes) if notes else ""
if hidden and not seen:
    print("ORCA health: unknown — %s still unreadable (acked this hour)%s" % (", ".join(sorted(hidden)), tail))
    sys.exit(0)
if seen:
    print("ORCA health: %d alert%s — ask the operator (§12b rule 8)%s" % (len(seen), "" if len(seen) == 1 else "s", tail))
    print("Ending first line: Needed from you: check the Orca alerts below")
    sys.exit(1)
print("ORCA health: ok — %s%s" % ("Run %s checked" % run if run else "no Run named or held here; alert files and own questions checked", tail))
PY
cepa_h_rc=$?
# Any other exit is the reader's own failure: an alert, never a quiet pass.
if [ "$cepa_h_rc" -gt 1 ]; then
  echo "ORCA alert: orca-unreadable:reader:$((cepa_h_now / 3600)) — the health reader failed (exit $cepa_h_rc), so this Run's health is unknown"
  echo "ORCA health: 1 alert — ask the operator (§12b rule 8)"
  echo "Ending first line: Needed from you: check the Orca alerts below"
  exit 1
fi
exit "$cepa_h_rc"
