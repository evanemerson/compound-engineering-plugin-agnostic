#!/usr/bin/env bash
# cepa Orca send — sends one orchestration message, proves Orca stored it, and
# only then runs the guarded nudge (orca-nudge.sh, beside this file).
# `cepa:autonomy` §12b rule 1 owns WHEN a session sends and whom it nudges;
# this script owns HOW a send is counted. A send counts only when Orca returns
# `"ok": true` with `result.message.id` shaped `msg_…`, AND a re-read of the
# inbox finds that id. Nothing else counts: not exit 0, not an `"id"` field.
#
# Usage: orca-send.sh  <stdin      (it takes no arguments)
#   Every value comes on stdin, inside the session's quoted heredoc
#   (`<<'CEPA_FIELDS'`), so no value is ever inside a quoted shell string
#   (punch-list L38, review finding #19: the four values used to be quoted
#   arguments, which bash parsed before the script could check them).
#   stdin is FIELD lines only. The message is in a file (`file:`), never in
#   the heredoc (punch-list L41, below):
#     cli: <cli>            §12a's printed `cli=` value, checked as
#                           orca-nudge.sh checks it.
#     target: <target>      a `term_` handle, or a `run:<id>` / `dispatch:<id>`
#                           address; for a reply, the question's msg_ id; or
#                           `coord:<repo>`, the live coord@main of <repo>
#                           (THE COORD ADDRESS, below; status, question,
#                           handoff and merge_ready only).
#     type: <type>          status, question, handoff, escalation, merge_ready,
#                           reply or worker_done. Orca refuses `escalation`
#                           from a sender with no Dispatch. heartbeat is not
#                           sent here: the preamble's own command sends it.
#     nudge: <nudge>        `nudge` for a target that is not a Run coordinator
#                           (a `term_` handle, or a reply); `no-nudge` for a
#                           Run coordinator. Every type but worker_done. A
#                           `run:` or `dispatch:` target with `nudge` is sent
#                           as `no-nudge`, never refused: Orca delivers to
#                           that mailbox itself, so there is nothing to nudge.
#                           After `Orca send stored` the script then prints
#                           `Orca nudge not needed: <target> is a mailbox Orca
#                           delivers; sent as no-nudge` (punch-list L47).
#     outcome: <outcome>    worker_done only: succeeded or failed.
#     task: <task id>       worker_done only: the preamble's task_<id>.
#     session: <name>       optional: the target's session name, as §10a
#                           writes it (`coord@main`, `tab3@roles`). The ending
#                           line then names that session beside the handle
#                           (review finding #21). An empty value is no name.
#     file: <path>          the message file: an absolute path whose last part
#                           is `cepa-send-<name>.txt`, a regular file this
#                           user owns, outside the current repo. The session
#                           writes it with its file-write tool right before
#                           the run, under a name used once (§12b rule 1:
#                           the session's name and a count). The fields are
#                           read first, then the path is checked; a path that
#                           fails is refused and kept. A path that passes is
#                           read and removed before any value is checked, so
#                           each file serves one run and is never re-sent.
#                           A path to no file is refused with a reason that
#                           says so: a retry after a refusal needs a new file
#                           (punch-list L47: a sender re-ran the block on a
#                           file the first run had already removed).
#   A field line is `<name>: <value>`, one per line, each name at most once,
#   in any order. Trailing spaces and a CR are dropped from a value. Any
#   other line is refused, so a block that lost a field name is never read.
#   An empty line ends the fields; after it only empty lines may follow. A
#   block from before 1.44.0 (fields, an empty line, then the message) is
#   refused on its message line, loudly (exit 4), as #110 refused the
#   positional block: the session restarts to load the new rule 1.
#   reply (§12b rule 7, punch-list L35): <target> is the question's message
#             id. The message is the answer body only, with no subject line.
#             With `nudge`, the script nudges the handle Orca addressed the
#             reply to (the asker), never a handle the session names; a reply
#             that Orca stored in a `run:` or `dispatch:` mailbox gets no
#             nudge.
#   worker_done (§12b rule 3, punch-list L35): a dispatched worker's final
#             report, with the preamble's Dispatch (`target: dispatch:ctx_…`)
#             and Task IDs. It counts only when Orca also returns
#             `result.lifecycle` with that dispatch and task and the action
#             the outcome asks for (`succeeded` → `completed`, `failed` →
#             `failed`). It is never nudged.
#   message   the file's text: line 1 is the subject; every line after it is
#             the body. Trailing newlines of the body are dropped.
#             WHY A FILE (punch-list L41, PR #110 review finding #3). Up to
#             1.43.0 the message sat in the heredoc after the fields. A
#             message line that was exactly the delimiter ended the heredoc,
#             and the lines after it ran as shell commands; bodies carry
#             relayed repo content, so that was an injection path guarded only
#             by prose ("indent such a line"). A per-send delimiter the
#             session invents was weighed and not taken: a model repeats its
#             "random" token, and the likely body that holds the delimiter is
#             a quoted copy of an earlier block, which carries that same
#             token. The file never passes through the shell, so no line of
#             it can end anything. The heredoc keeps only field lines: each
#             starts `<name>: `, so none can equal `CEPA_FIELDS`.
#
# Prints one result line, then the nudge's lines when it runs. Exit codes:
#   0  Orca send stored: <msg id> for <recipient>, then either orca-nudge.sh's
#      `Orca nudge sent to <handle>`, this script's `Orca nudge not needed:
#      <reason>` (stored in a Run mailbox, or `nudge` given for a `run:` or
#      `dispatch:` target and sent as `no-nudge`), or nothing more
#      (`no-nudge`).
#   1, 2, 3  stored, then the nudge skipped, refused or failed: orca-nudge.sh's
#      own lines, its `Ending first line:` included, or this script's own
#      skip (stored for another handle; orca-nudge.sh missing or would not
#      start). The message stands. A reply also exits 1, with
#      `Orca reply misaddressed: …` in place of `Orca send stored` and no
#      nudge, when it came back to this session (ORCA_TERMINAL_HANDLE): Orca
#      addressed it to that handle, or the message it names is in the
#      re-read window with this session as its sender. The asker never gets
#      it.
#   4  Orca send refused: <reason>   — an argument failed its check; no call.
#      A `coord:` message is then kept as refused in the outbox.
#   6  Orca send pending: <reason>; kept in the outbox as <repo>/<file>
#      — a `coord:` target with no one live coord@main to send to, or a Run
#      list that could not be read. Nothing was sent; the receiver's drain
#      (§12b rule 8) is the only path that delivers it. Then the ending line.
#   5  Orca send failed: no message stored — <reason>
#      Orca send failed: not proven stored — <reason>   — Orca returned
#      `"ok": true` and a msg_ id, but the recipient, the reply's thread or
#      the worker_done lifecycle did not match. It may be stored: a rerun can
#      duplicate it.
#   On 4 and 5 it then prints one line about the alert file (THE ALERT,
#   below): `Orca alert recorded: <file> (orca-health.sh reports it)`, or
#   `Orca alert not recorded: <reason>`. Last, it prints:
#   Ending first line: Needed from you: paste the block below into <target>
#   <target> is printed only when it passes the target check; any other value
#   prints `the target session`. With a `session:` field, the line names
#   `<session> (<target>)`, or `<session>` alone when the target failed its
#   check. Every `tell <handle> to check its Orca inbox` line for the target
#   names `<session> (<handle>)` the same way, the nudge's own line included.
#
# WHY (punch-list L33, measured 2026-10-31 on Orca 1.4.245, WSL, probe
# terminals in the `roles` worktree). A worker counted two sends as stored by
# grepping `"id"`. Every reply has a top-level `"id"`: a stored message's reply
# has a UUID there, a REFUSED one has `"id": "local"` or a UUID, so the grep
# matches both. Measured ways a send stores nothing:
#   - `--type worker_done` from a sender with no Dispatch: exit 1,
#     `"ok": false`, `missing_task_id` / `invalid_argument`. Behind a pipe the
#     exit code is the grep's, 0. (`escalation` and `ask` likewise:
#     `sender_not_assignee`, `dispatch_inactive`.)
#   - a command line of about 32 KB or more: subject+body of 31,500 chars
#     stored, 32,500 did not. WSL starts the Windows CLI through
#     powershell.exe, which fails `Invalid argument`: exit 1, EMPTY stdout.
#   - a body or subject that starts with `--`: `invalid_argument`.
#   - the WSL interop error (`UtilAcceptVsock` … `accept4 failed 110`):
#     non-zero exit, empty stdout (L26 re-probe).
# A `legacy_terminal_recipient` warning came with every stored send to a
# `term_` handle; a warning alone never means "not stored", and never "stored".
#
# THE RE-READ. `orchestration inbox --limit 200 --json` lists rows for every
# recipient, newest first (measured 2026-10-31: `--limit 3` returned sequences
# 180, 179, 178 of 180, and rows addressed to other sessions were listed), so
# a message stored seconds ago is inside the window. The id must be there with the `to_handle` the send
# reported. Orca can store a send for another mailbox than the one named: a
# send to a Run coordinator's `term_` handle was stored for `run:<id>`
# (msg_6d1566506a61). Such a row is a Run mailbox, which Orca prompts, so it
# gets no nudge.
#
# THE VSOCK RETRY follows orca-nudge.sh's rule: one retry, only on a non-zero
# exit whose stderr holds both `UtilAcceptVsock` and `accept4 failed 110`;
# never after a timeout. The retry is the same call with the same
# `--retry-request` id, which the script chose, so if the first try stored,
# Orca replays its result (same `msg_…`, `replayed: true`) and stores nothing
# more (measured L35, Orca 1.4.245). Different input under the same id is
# refused (`request_mismatch`).
#
# TIME BUDGET. Each Orca call is bounded at 15 s plus a 2 s kill, so with its
# retry a call takes at most 34 s: the send and the re-read take at most 68 s,
# plus the nudge's own bound (about 220 s, its header): about 290 s in all.
# A session that runs the block again after a failure makes a new request id,
# so that second run can still store a duplicate (§12b rule 1 accepts it).
#
# THE COORD ADDRESS (punch-list L61; design 2026-11-02 "Piece 1", Builder-check
# 1-5, plan-review #9, #10, #17, #18, #23-#25). A peer that addressed another
# repo's coordinator by its `term_` handle lost the message when that
# coordinator restarted (artist360 2026-10-31: `merged #N` to a closed tab).
# `coord:<repo>` names the role, and the script resolves it at send time:
#   - <repo> is §12b rule 6's <repo> (the main checkout's directory name) as
#     autonomy §5 `slug(x)` writes it. It is checked FIRST, right after the
#     message file is read: it must equal slug(<repo>) (so it is not empty,
#     `.`, `..`, and does not start with `-`).
#   - THE OUTBOX. A `coord:` message is written to disk before any other
#     check and before any send: <outbox>/<repo>/<UTC time>-<rand>.md, mode
#     600, directories mode 700. <outbox> is CEPA_ORCA_OUTBOX_DIR, else
#     ${XDG_STATE_HOME:-$HOME/.local/state}/cepa/outbox: on this machine,
#     never in a repo. A <repo> that fails its check is kept in the fixed
#     directory <outbox>/_invalid/, never under a path built from the target.
#     The name is made unique by mktemp and claimed with a hard link, which
#     fails rather than overwrite, so two senders never share a file. The
#     status is the directory: <repo>/ is pending, <repo>/refused/ refused
#     (exit 4, never delivered by anyone), <repo>/delivered/ delivered.
#     Format: `cepa-outbox 1`, then time=, repo=, worktree=, sender=,
#     target=, type=, session= (each checked or replaced, as the alert's
#     are), then a `---` line, then the message file's text.
#   - THE RESOLVER. `run-list` is read page by page (`nextCursor` until null,
#     at most 20 pages of 100). A Run counts when its objective is
#     `<word> coord@main` followed by the end, a space or `:`, where
#     slug(<word>) is <repo> (so `artist360` never matches `artist360-docs
#     coord@main`, and `foo.bar coord@main` is coord:foo-bar). Its coordinator_handle is
#     live only when `terminal list` shows it AND `worktree ps` has exactly
#     one agent row on that terminal's pane with `hasLivePty: true` (an open
#     tab whose Claude died has no live pty; measured 2026-11-02: rows of
#     closed tabs carry no hasLivePty). A live handle counts only when its
#     terminal's worktree is a main checkout (`isMainWorktree`) whose
#     directory name slugs to <repo>; a live one elsewhere is a mismatch.
#     One distinct live handle: send to it. None: pending. More than one:
#     pending and an `outbox_ambiguous` alert. Only mismatches: pending and
#     an `outbox_mismatch` alert. A read that fails, is truncated or has a
#     shape this reader does not know: pending and an `outbox_unreadable`
#     alert. Pending never retries: the receiver's drain is the one owner.
#   - Delivered = `Orca send stored` (the proof above) to a handle that was
#     live right before the send: the file moves to
#     <repo>/delivered/<name stem>.to-<handle>.md. Exit 5 leaves it pending
#     (it may have stored: a drained copy is then a duplicate, never a loss).
#   - RETENTION (#18). Every coord: send prunes outbox files older than 7
#     days by the time in their name, in every status. Pruning a pending or
#     refused file (one nobody acked) writes an `outbox_pruned` alert. A
#     sender never puts patient data in a coordinator message.
#   - The resolved handle then follows the nudge rules of a `term_` target.
#
# ORCA 1.4.246 SHORT OUTPUT (punch-list L72). Measured on Orca 1.4.246 (WSL),
# 2026-11-02, read only, each read with and without `--full`. Without it,
# every `orchestration` read prints a concise view: `run-list` rows hold only
# `id` and `objective`; `run-show` holds `runId`, `objective`, `removedWork`
# (no `run` object); `run-current` holds `runId`, `objective`; `worker-list`
# rows have no `projection`; `worker-show` has no `dispatch`, `worker` or
# `projection`; `inbox` rows name `from`/`to` (not `from_handle`/`to_handle`),
# cut the body to 200 chars, and carry no `thread_id` or `created_at`. With
# `--full` each prints the record this script reads. So every orchestration
# read here passes `--json --full`, and a reply in the short shape reads as
# unreadable (`outbox_unreadable`, or an
# unconfirmed send). `terminal`, `worktree` and `repo` reads have no `--full` flag
# on 1.4.246 and still print the full record. Whether an older Orca (1.4.245
# or before) accepts `--full` was not measured: none was at hand to run.
#
# STATED LIMITS:
#   - The outbox is on this machine, and every session runs as one user, so
#     a file's sender is a claim, never proven (review residual risk).
#   - A tab that closes in the seconds after a stored send leaves a
#     `delivered` file no coordinator read (Builder-check 4); a new
#     coord@main's drain shows such files for 7 days (#10).
#   - The misaddressed-reply check needs ORCA_TERMINAL_HANDLE. Unset, a reply
#     Orca stored in this session's own `dispatch:` mailbox reads as stored
#     unless the message it names is in the 200-row window.
#   - A row in the inbox is "stored", not "read". Reading is the nudge's job,
#     and rule 8's peek is the backstop.
#   - The size cap is 28,000 bytes of subject plus body, below the measured
#     limit. The Windows limit counts UTF-16 units of the whole command line,
#     so bytes over-count non-ASCII text: a cap in bytes is the safe side.
#   - If the inbox cannot be read or parsed, or the send timed out, the send is
#     reported failed even when it may have stored (the reason then says
#     "unconfirmed" or names the exit): a pasted copy then duplicates it. A duplicate is the accepted
#     cost; a lost message is not.
#   - The flags are from `orchestration send --help` and `inbox --help`
#     (Orca 1.4.245; `--full` from 1.4.246, see above). If Orca changes them,
#     the send fails loudly here.
set -u

cepa_send_cli= cepa_send_target= cepa_send_type= cepa_send_mode= cepa_send_task=
cepa_send_outcome= cepa_send_session=
# THE COORD ADDRESS state: the target repo, the outbox root, and this
# message's outbox file (empty until written).
cepa_send_coord= cepa_send_obox= cepa_send_oroot=

cepa_send_valid_target() {
  [[ $cepa_send_target =~ ^(term_[0-9a-f-]{36}|run:[A-Za-z0-9_-]{1,64}|dispatch:[A-Za-z0-9_-]{1,64}|coord:[A-Za-z0-9_-]{1,100})$ ]]
}
# autonomy §5 slug(x): every character outside [A-Za-z0-9_-] becomes `-`,
# each run of `-` collapses to one, leading and trailing `-` are stripped.
# (§5's short-SHA fallback for an empty result does not apply: an empty
# slug is simply no repo.)
cepa_send_slug() {
  local s
  s=$(LC_ALL=C; printf '%s' "$1" | tr -c 'A-Za-z0-9_-' '-' | tr -s '-')
  s=${s#-} s=${s%-}
  printf '%s' "$s"
}
# The target as the ending names it: `<session> (<address>)` when a session
# name passed its check, else the address alone.
cepa_send_who() {
  if [ -n "$cepa_send_session" ]; then echo "$cepa_send_session ($1)"; else echo "$1"; fi
}
cepa_send_ending() {
  local p="Ending first line: Needed from you: paste the block below into" s=$cepa_send_session
  if [ "$cepa_send_type" = reply ]; then
    if [[ $cepa_send_target =~ ^msg_[0-9a-f]{6,32}$ ]]; then
      echo "$p ${s:+$s, }the session that asked $cepa_send_target"
    else
      echo "$p ${s:-the session that asked}"
    fi
  elif [ "$cepa_send_type" = worker_done ]; then
    echo "$p ${s:+$s, }the Run coordinator"
  elif cepa_send_valid_target; then
    echo "$p $(cepa_send_who "$cepa_send_target")"
  else
    echo "$p ${s:-the target session}"
  fi
}
# THE ALERT (punch-list L34). Exit 4 and exit 5 print only into the sending
# session's own output, so a session that then ends its turn tells no one.
# Each of them also writes one alert file, which orca-health.sh (beside this
# script) reads at a coordinator's per-turn check (§12b rule 8) and turns into
# an operator question. One file per failure, never an append, so concurrent
# senders never share a write. Every field is checked or replaced before it is
# written; no Orca text goes in but the plain-word error code that is already
# in the reason. The directory is CEPA_ORCA_ALERT_DIR, else
# ${XDG_STATE_HOME:-$HOME/.local/state}/cepa/orca-alerts: on this machine,
# never in a repo. A file that cannot be written prints
# `Orca alert not recorded: <reason>`, and the exit code stays the same.
cepa_send_alert() {
  local kind=$1 why=$2 dir t repo wt me tgt typ tmp
  dir=${CEPA_ORCA_ALERT_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/cepa/orca-alerts}
  [[ $dir == /* ]] || { echo "Orca alert not recorded: the alert directory is not an absolute path"; return 0; }
  mkdir -p "$dir" 2>/dev/null || { echo "Orca alert not recorded: the alert directory could not be made"; return 0; }
  t=$(date +%s 2>/dev/null) || t=
  [[ $t =~ ^[0-9]{1,12}$ ]] || t=0
  repo=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || repo=
  case "$repo" in /*/.git) repo=${repo%/.git} repo=${repo##*/} ;; *) repo=unknown ;; esac
  [[ $repo =~ ^[A-Za-z0-9._@-]{1,100}$ ]] || repo=unknown
  wt=$(git rev-parse --show-toplevel 2>/dev/null) || wt=
  wt=${wt##*/}
  [[ $wt =~ ^[A-Za-z0-9._@-]{1,100}$ ]] || wt=unknown
  # A prune alert speaks for the file's own sender (cepa_send_alert_for).
  [ -z "${cepa_send_arepo-}" ] || repo=$cepa_send_arepo
  [ -z "${cepa_send_awt-}" ] || wt=$cepa_send_awt
  [[ $repo =~ ^[A-Za-z0-9._@-]{1,100}$ ]] || repo=unknown
  [[ $wt =~ ^[A-Za-z0-9._@-]{1,100}$ ]] || wt=unknown
  me=${ORCA_TERMINAL_HANDLE:-}
  [[ $me =~ ^term_[0-9a-f-]{36}$ ]] || me=unknown
  tgt=$cepa_send_target
  [[ $tgt =~ ^(msg_[0-9a-f]{6,32}|term_[0-9a-f-]{36}|run:[A-Za-z0-9_-]{1,64}|dispatch:[A-Za-z0-9_-]{1,64}|coord:[A-Za-z0-9_-]{1,100})$ ]] || tgt=invalid
  # A coord: repo that is not its own slug (`-x`, `a--b`) is no address.
  [[ $tgt != coord:* ]] || [ "$(cepa_send_slug "${tgt#coord:}")" = "${tgt#coord:}" ] || tgt=invalid
  typ=$cepa_send_type
  [[ $typ =~ ^[a-z_]{1,20}$ ]] || typ=invalid
  why=$(LC_ALL=C; printf '%s' "${why:0:300}" | tr -c ' -~' '?')
  tmp=$(mktemp "$dir/.new.XXXXXXXX" 2>/dev/null) || { echo "Orca alert not recorded: mktemp failed in the alert directory"; return 0; }
  if printf '%s\n' "cepa-orca-alert 1" "time=$t" "kind=$kind" "repo=$repo" "worktree=$wt" \
      "sender=$me" "target=$tgt" "type=$typ" "reason=$why" >"$tmp" 2>/dev/null \
      && mv -f "$tmp" "$dir/$t-${tmp##*.new.}.alert" 2>/dev/null; then
    echo "Orca alert recorded: $t-${tmp##*.new.}.alert (orca-health.sh reports it)"
  else
    rm -f "$tmp" 2>/dev/null
    echo "Orca alert not recorded: the alert file could not be written"
  fi
}
# THE OUTBOX: the status of a written file is its directory. A refused
# message moves to refused/ (never delivered); a failed one stays pending.
# Each line names the file by <repo>/<name>, never by its full path.
cepa_send_obox_note() {
  [ -n "$cepa_send_obox" ] || return 0
  local n=${cepa_send_obox##*/} d=${cepa_send_obox%/*}
  d=${d##*/}
  if [ "$1" = refused ] && [ "$d" != _invalid ]; then
    if ( umask 077 && mkdir -p "${cepa_send_obox%/*}/refused" ) 2>/dev/null \
        && mv -f "$cepa_send_obox" "${cepa_send_obox%/*}/refused/$n" 2>/dev/null; then
      echo "Orca outbox: kept as refused: $d/refused/$n"
    else
      echo "Orca outbox: could not mark refused; still pending: $d/$n"
    fi
  elif [ "$1" = refused ]; then
    echo "Orca outbox: kept as refused: _invalid/$n"
  else
    echo "Orca outbox: kept as pending: $d/$n (the receiver's drain delivers it)"
  fi
}
refuse() { echo "Orca send refused: $1"; cepa_send_obox_note refused; cepa_send_alert send_refused "$1"; cepa_send_ending; exit 4; }
fail() { echo "Orca send failed: no message stored — $1"; cepa_send_obox_note pending; cepa_send_alert send_failed "$1"; cepa_send_ending; exit 5; }
# Orca returned "ok": true and a msg_ id, but the reply did not match: the
# message may be stored, so the line never says it stored nothing.
unproven() { echo "Orca send failed: not proven stored — $1"; cepa_send_obox_note pending; cepa_send_alert send_unproven "$1"; cepa_send_ending; exit 5; }
# A coord: message with no one live coord@main to take it: kept, not sent.
# $1 is the alert kind (or empty: no alert), $2 the line's reason.
pending() {
  echo "Orca send pending: $2; kept in the outbox as ${cepa_send_obox#"$cepa_send_oroot"/}"
  [ -z "$1" ] || cepa_send_alert "$1" "$2"
  echo "Ending first line: Needed from you: nothing now; coord@main of $cepa_send_coord shows the message from the outbox on its next turn (§12b rule 8)"
  exit 6
}
# Writes this message to the outbox (THE COORD ADDRESS). $1 is the directory
# under the root: the checked repo, or _invalid. Fails closed: a copy that
# cannot be written is a refusal, and the reason says so.
cepa_send_obox_write() {
  local sub=$1 root d t stamp tmp me wt repo typ sess tg=coord:$1
  [ "$sub" != _invalid ] || tg=invalid
  root=${CEPA_ORCA_OUTBOX_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/cepa/outbox}
  [[ $root == /* ]] || refuse "the outbox directory is not an absolute path"
  d=$root/$sub
  ( umask 077 && mkdir -p "$d" ) 2>/dev/null || refuse "the outbox directory could not be made"
  [ -d "$root" ] && [ ! -L "$root" ] && [ -O "$root" ] && [ -d "$d" ] && [ ! -L "$d" ] && [ -O "$d" ] \
    || refuse "the outbox directory is not a directory this user owns"
  chmod 700 "$root" "$d" 2>/dev/null || refuse "the outbox directory could not be made"
  t=$(date +%s 2>/dev/null) || t=
  [[ $t =~ ^[0-9]{1,12}$ ]] || t=0
  stamp=$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null) || stamp=
  [[ $stamp =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || refuse "the outbox file could not be written"
  repo=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || repo=
  case "$repo" in /*/.git) repo=${repo%/.git} repo=${repo##*/} ;; *) repo=unknown ;; esac
  [[ $repo =~ ^[A-Za-z0-9._@-]{1,100}$ ]] || repo=unknown
  wt=$(git rev-parse --show-toplevel 2>/dev/null) || wt=
  wt=${wt##*/}
  [[ $wt =~ ^[A-Za-z0-9._@-]{1,100}$ ]] || wt=unknown
  me=${ORCA_TERMINAL_HANDLE:-}
  [[ ${me} =~ ^term_[0-9a-f-]{36}$ ]] || me=unknown
  typ=$cepa_send_type
  [[ $typ =~ ^[a-z_]{1,20}$ ]] || typ=invalid
  sess=${cepa_send_f_session-}
  [[ $sess =~ ^[A-Za-z0-9._@]([A-Za-z0-9._@-]{0,99})$ ]] || sess=
  tmp=$( umask 077 && mktemp "$d/.new.XXXXXXXX" 2>/dev/null ) || refuse "the outbox file could not be written"
  if printf '%s\n' "cepa-outbox 1" "time=$t" "repo=$repo" "worktree=$wt" "sender=$me" \
      "target=$tg" "type=$typ" "session=$sess" "---" "$cepa_send_msg" >"$tmp" 2>/dev/null \
      && chmod 600 "$tmp" 2>/dev/null \
      && ln "$tmp" "$d/$stamp-${tmp##*.new.}.md" 2>/dev/null; then
    rm -f "$tmp" 2>/dev/null
    cepa_send_oroot=$root cepa_send_obox=$d/$stamp-${tmp##*.new.}.md
  else
    rm -f "$tmp" 2>/dev/null
    refuse "the outbox file could not be written"
  fi
}
# RETENTION (#18): outbox files older than 7 days go, in every status. A
# pending or refused one goes only after its alert is recorded, and the alert
# carries the file's own repo= and worktree=, so the session that sent it
# sees it, not the one that happened to prune (review). Names that are not
# the writer's shape are left for orca-health.sh to report.
cepa_send_obox_prune() {
  local cut f n st sub r w
  cut=$(python3 -I -c 'import time; print(time.strftime("%Y%m%dT%H%M%SZ", time.gmtime(time.time() - 7 * 86400)))' 2>/dev/null) \
    || { echo "Orca outbox: prune skipped (no clock)"; return 0; }
  [[ $cut =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || { echo "Orca outbox: prune skipped (no clock)"; return 0; }
  for f in "$cepa_send_oroot"/*/*.md "$cepa_send_oroot"/*/refused/*.md "$cepa_send_oroot"/*/delivered/*.md; do
    [ -f "$f" ] && [ ! -L "$f" ] && [ -O "$f" ] || continue
    n=${f##*/}
    [[ $n =~ ^([0-9]{8}T[0-9]{6}Z)-[A-Za-z0-9]{8}(\.to-term_[0-9a-f-]{36}|\.drained)?\.md$ ]] || continue
    [[ ${BASH_REMATCH[1]} < $cut ]] || continue
    st=${f%/*} st=${st##*/}
    if [ "$st" != delivered ]; then
      if [ "$st" = refused ]; then sub=${f%/refused/*} sub=${sub##*/} n=refused/$n; else sub=$st; fi
      r=$(sed -n '3s/^repo=//p' "$f" 2>/dev/null) w=$(sed -n '4s/^worktree=//p' "$f" 2>/dev/null)
      cepa_send_alert_for outbox_pruned "coord:$sub" "an outbox file was pruned unread after 7 days: $sub/$n" "$r" "$w" \
        || { echo "Orca outbox: kept $sub/$n past 7 days: its prune alert could not be recorded"; continue; }
    fi
    rm -f -- "$f" 2>/dev/null || echo "Orca outbox: could not prune $st/${f##*/}"
  done
}
# An alert about another coord: target than this send's (a pruned file).
# $4 and $5 are that file's own repo= and worktree= (checked again in the
# writer). Returns non-zero when the alert was not recorded.
cepa_send_alert_for() {
  local keep=$cepa_send_target out
  cepa_send_target=$2 cepa_send_arepo=${4-} cepa_send_awt=${5-}
  out=$(cepa_send_alert "$1" "$3")
  cepa_send_target=$keep cepa_send_arepo= cepa_send_awt=
  [[ $out == "Orca alert recorded: "* ]]
}

[ $# -eq 0 ] || refuse "orca-send.sh takes no arguments; its fields go on stdin"
# THE FIELDS: `<name>: <value>` lines up to an empty line or the end of
# stdin. Each value is read by `read -r` from the heredoc, so bash never
# parses it as code. No field comes from the environment: only a line on
# stdin sets one.
unset cepa_send_f_cli cepa_send_f_target cepa_send_f_type cepa_send_f_nudge cepa_send_f_outcome \
  cepa_send_f_task cepa_send_f_session cepa_send_f_file
cepa_send_seen=" "
while IFS= read -r cepa_send_line || [ -n "$cepa_send_line" ]; do
  cepa_send_line=${cepa_send_line%$'\r'}
  [ -n "$cepa_send_line" ] || break
  # `session:` with no space is an empty value, as `session: ` is: editors
  # and models drop trailing spaces (PR #110 review).
  [[ $cepa_send_line =~ ^([a-z]+):(\ (.*))?$ ]] \
    || refuse "a heredoc line is not a <name>: <value> field"
  cepa_send_k=${BASH_REMATCH[1]} cepa_send_v=${BASH_REMATCH[3]}
  cepa_send_v=${cepa_send_v%"${cepa_send_v##*[![:space:]]}"}
  case "$cepa_send_k" in
    cli|target|type|nudge|outcome|task|session|file) ;;
    *) refuse "a field name is not cli, target, type, nudge, outcome, task, session or file" ;;
  esac
  [[ $cepa_send_seen != *" $cepa_send_k "* ]] || refuse "the $cepa_send_k field is given twice"
  cepa_send_seen+="$cepa_send_k "
  printf -v "cepa_send_f_$cepa_send_k" '%s' "$cepa_send_v"
  # A later bad line still names the target and type already read; the
  # ending prints the target only when it passes its check.
  case "$cepa_send_k" in
    target) cepa_send_target=$cepa_send_v ;;
    type) cepa_send_type=$cepa_send_v ;;
  esac
done
# Only empty lines may follow the fields. A message here is a block from
# before 1.44.0, or a message put in the wrong place: refused, never sent.
{ cepa_send_rest=$(cat); } 2>/dev/null
[ -z "${cepa_send_rest//[[:space:]]/}" ] \
  || refuse "the heredoc holds a message after its fields; the message goes in the file the file: field names"
# THE MESSAGE FILE (punch-list L41). The fields above are read first. Then
# the path is checked; a path that fails is refused and its file is kept.
# A path that passes is read and removed before any check of the values, so
# each file serves one run and a stale file is never sent. (PR #112 review.)
[[ $cepa_send_seen == *" file "* ]] || refuse "the file field is missing"
cepa_send_file=${cepa_send_f_file-}
[[ $cepa_send_file =~ ^(/[A-Za-z0-9._@+-]+)*/cepa-send-[A-Za-z0-9._@-]{1,64}\.txt$ \
   && $cepa_send_file != */./* && $cepa_send_file != */../* ]] \
  || refuse "the message file is not an absolute path to a cepa-send-<name>.txt file"
# A path to nothing is most often a retry on a file the last run removed
# (punch-list L47), so its reason says how to retry. A dangling symlink is
# not "nothing": it goes on to the regular-file check below. A directory this
# user cannot search makes `-e` false too, so it is refused first with its
# own reason, never as a file a run removed (PR #122 review).
[ -d "${cepa_send_file%/*}/" ] && [ -x "${cepa_send_file%/*}/" ] \
  || refuse "the message file's directory could not be resolved"
[ -e "$cepa_send_file" ] || [ -L "$cepa_send_file" ] \
  || refuse "the message file does not exist; orca-send.sh removes each message file once it reads it, so a retry needs a new file (or the path is wrong)"
[ -f "$cepa_send_file" ] && [ ! -L "$cepa_send_file" ] && [ -O "$cepa_send_file" ] \
  || refuse "the message file is not a regular file this user owns"
# Never inside this checkout, nor inside the main checkout that holds it
# (a linked worktree sits under the main one's .claude/worktrees). The check
# runs on the path as given AND on its physical path (the directory with
# every symlink resolved), so a symlinked directory cannot lead into a repo
# by another name. A symlinked /tmp (macOS) is fine: only where it leads
# counts. git's own paths are physical.
cepa_send_dir=$(cd -P -- "${cepa_send_file%/*}/" 2>/dev/null && pwd -P) || cepa_send_dir=
[ -n "$cepa_send_dir" ] || refuse "the message file's directory could not be resolved"
cepa_send_phys=${cepa_send_dir%/}/${cepa_send_file##*/}
cepa_send_top=$(git rev-parse --show-toplevel 2>/dev/null) || cepa_send_top=
cepa_send_main=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || cepa_send_main=
case "$cepa_send_main" in /*/.git) cepa_send_main=${cepa_send_main%/.git} ;; *) cepa_send_main= ;; esac
for cepa_send_k in "$cepa_send_top" "$cepa_send_main"; do
  [ -z "$cepa_send_k" ] || [[ $cepa_send_file != "$cepa_send_k"/* && $cepa_send_phys != "$cepa_send_k"/* ]] \
    || refuse "the message file is inside the repo"
done
# Removed even when the read fails, so a file never outlives the run that
# passed its path checks.
{ cepa_send_msg=$(cat -- "$cepa_send_file"); } 2>/dev/null
cepa_send_read=$?
rm -f -- "$cepa_send_file" 2>/dev/null
[ ! -e "$cepa_send_file" ] || refuse "the message file could not be removed"
[ "$cepa_send_read" = 0 ] || refuse "the message file could not be read"
# THE COORD ADDRESS: <repo> is checked first, and the message goes to the
# outbox before every other check, so a refusal below keeps its text.
if [[ ${cepa_send_f_target-} == coord:* ]]; then
  cepa_send_coord=${cepa_send_f_target#coord:}
  if [[ $cepa_send_coord =~ ^[A-Za-z0-9_-]{1,100}$ ]] && [ "$(cepa_send_slug "$cepa_send_coord")" = "$cepa_send_coord" ]; then
    cepa_send_obox_write "$cepa_send_coord"
    cepa_send_obox_prune
  else
    cepa_send_coord=
    cepa_send_obox_write _invalid
    refuse "the coord: repo is not slug(<repo>) (autonomy §5)"
  fi
fi
cepa_send_cli=${cepa_send_f_cli-} cepa_send_target=${cepa_send_f_target-} cepa_send_type=${cepa_send_f_type-}
cepa_send_task=${cepa_send_f_task-}
if [ -n "${cepa_send_f_session-}" ]; then
  [[ $cepa_send_f_session =~ ^[A-Za-z0-9._@][A-Za-z0-9._@-]{0,99}$ ]] \
    || refuse "the session name holds a character outside [A-Za-z0-9._@-]"
  cepa_send_session=$cepa_send_f_session
fi
for cepa_send_k in cli target type; do
  [[ $cepa_send_seen == *" $cepa_send_k "* ]] || refuse "the $cepa_send_k field is missing"
done
if [ "$cepa_send_type" = worker_done ]; then
  [[ $cepa_send_seen != *" nudge "* ]] || refuse "a worker_done takes outcome and task fields, not nudge"
  for cepa_send_k in outcome task; do
    [[ $cepa_send_seen == *" $cepa_send_k "* ]] || refuse "the $cepa_send_k field is missing"
  done
  cepa_send_mode=${cepa_send_f_outcome-}
else
  [[ $cepa_send_seen != *" outcome "* && $cepa_send_seen != *" task "* ]] \
    || refuse "only a worker_done takes outcome and task fields"
  [[ $cepa_send_seen == *" nudge "* ]] || refuse "the nudge field is missing"
  cepa_send_mode=${cepa_send_f_nudge-}
fi
case "$cepa_send_cli" in
  ''|-*|*[!A-Za-z0-9._/-]*) refuse "the cli is not a plain command name" ;;
  /*) [ "$cepa_send_cli" = "${ORCA_CLI_COMMAND:-}" ] || refuse "a cli path must equal ORCA_CLI_COMMAND" ;;
  */*) refuse "a cli path must be absolute and equal ORCA_CLI_COMMAND" ;;
esac
case "${cepa_send_cli##*/}" in
  orca-ide|orca-dev) ;;
  orca) [ "$(uname -s 2>/dev/null)" != Linux ] || refuse "bare orca on Linux is the screen reader" ;;
  *) refuse "the cli does not name an Orca CLI" ;;
esac
case "$cepa_send_type" in
  escalation)
    [[ $cepa_send_target != coord:* ]] || refuse "an escalation cannot go to a coord: address; it keeps its Run path"
    cepa_send_valid_target || refuse "the target is not a term_ handle, run: or dispatch: address" ;;
  status|question|handoff|merge_ready)
    cepa_send_valid_target || refuse "the target is not a term_ handle, run: or dispatch: address" ;;
  reply)
    [[ $cepa_send_target =~ ^msg_[0-9a-f]{6,32}$ ]] || refuse "a reply's target is not a msg_ message id" ;;
  worker_done)
    [[ $cepa_send_target =~ ^dispatch:ctx_[0-9a-f]{6,32}$ ]] || refuse "a worker_done target is not dispatch:ctx_<id>"
    [[ $cepa_send_task =~ ^task_[0-9a-f]{6,32}$ ]] || refuse "the task id is not task_<id>"
    case "$cepa_send_mode" in
      succeeded) cepa_send_outcome=completed ;;
      failed) cepa_send_outcome=failed ;;
      *) refuse "the worker_done outcome is not succeeded or failed" ;;
    esac
    cepa_send_outcome_arg=$cepa_send_mode
    cepa_send_mode=no-nudge ;;
  *) refuse "the type is not status, question, handoff, escalation, merge_ready, reply or worker_done" ;;
esac
# A `run:` or `dispatch:` target is a mailbox Orca delivers, so `nudge` there
# has nothing to do: it is sent as `no-nudge` and says so, never refused
# (punch-list L47). The target already passed its check above, and a
# worker_done already set no-nudge, so this reaches only a plain send.
cepa_send_downgraded=
case "$cepa_send_mode" in
  no-nudge) ;;
  nudge) [[ $cepa_send_target == term_* || $cepa_send_target == coord:* || $cepa_send_type == reply ]] \
           || { cepa_send_mode=no-nudge cepa_send_downgraded=1; } ;;
  *) refuse "the nudge field is not nudge or no-nudge" ;;
esac
command -v "$cepa_send_cli" >/dev/null 2>&1 || refuse "$cepa_send_cli is not on PATH"

# The subject is the file's first line, the body the rest. A reply has no
# subject: all of the file is its body.
if [ "$cepa_send_type" = reply ]; then
  cepa_send_subject= cepa_send_body=$cepa_send_msg
else
  cepa_send_subject=${cepa_send_msg%%$'\n'*}
  cepa_send_subject=${cepa_send_subject%$'\r'}
  cepa_send_body=
  [[ $cepa_send_msg != *$'\n'* ]] || cepa_send_body=${cepa_send_msg#*$'\n'}
fi
if [ "$cepa_send_type" != reply ]; then
  [ -n "${cepa_send_subject//[[:space:]]/}" ] || refuse "the subject is empty"
  [[ $cepa_send_subject != --* ]] || refuse "the subject starts with --, which Orca reads as a flag"
fi
[ -n "${cepa_send_body//[[:space:]]/}" ] || refuse "the body is empty"
[[ $cepa_send_body != --* ]] || refuse "the body starts with --, which Orca reads as a flag"
cepa_send_bytes=$(LC_ALL=C; printf '%s%s' "$cepa_send_subject" "$cepa_send_body" | wc -c)
cepa_send_bytes=${cepa_send_bytes//[!0-9]/}
[ -n "$cepa_send_bytes" ] || refuse "the message size could not be measured"
[ "$cepa_send_bytes" -le 28000 ] \
  || refuse "subject and body are $cepa_send_bytes bytes; the limit is 28000 (WSL command-line limit)"

command -v timeout >/dev/null 2>&1 || fail "no timeout command to bound the Orca calls"
command -v python3 >/dev/null 2>&1 || fail "no python3 to read the Orca output"
cepa_send_tmp=$(mktemp -d 2>/dev/null) || fail "mktemp failed"
trap 'rm -rf "$cepa_send_tmp"' EXIT

# One Orca call, bounded at 15 seconds plus a 2-second kill, its stdout to $1.
# Sets cepa_send_rc. Retried once, only on the WSL interop error.
cepa_send_orca() {
  local out=$1 try
  shift
  for try in 1 2; do
    timeout -k 2 15 "$cepa_send_cli" "$@" </dev/null >"$out" 2>"$cepa_send_tmp/err" && { cepa_send_rc=0; return 0; }
    cepa_send_rc=$?
    [ "$try" = 1 ] && [ "$cepa_send_rc" != 124 ] && [ "$cepa_send_rc" != 137 ] || return 1
    { cepa_send_e=$(<"$cepa_send_tmp/err"); } 2>/dev/null || return 1
    [[ $cepa_send_e == *UtilAcceptVsock* && $cepa_send_e == *"accept4 failed 110"* ]] || return 1
  done
  return 1
}

# Every call carries a request id the script chose, so the vsock retry
# replays the first try instead of storing a second message (measured L35:
# the same --retry-request returned the same msg_ id with `replayed: true`).
cepa_send_req=$(python3 -I -c 'import uuid; print(uuid.uuid4())' 2>/dev/null)
[[ $cepa_send_req =~ ^[0-9a-f-]{36}$ ]] || fail "no request id could be made"

# THE RESOLVER (header: THE COORD ADDRESS). Reads every run-list page, the
# terminal list and worktree ps, then prints one line: `SEND <handle>`, or
# `PENDING <kind> <reason>`. A read that fails is `PENDING outbox_unreadable`.
if [ -n "$cepa_send_coord" ]; then
  cepa_send_cur= cepa_send_pg=0
  while :; do
    cepa_send_pg=$((cepa_send_pg + 1))
    if [ -z "$cepa_send_cur" ]; then
      cepa_send_orca "$cepa_send_tmp/runs.$cepa_send_pg.json" orchestration run-list --limit 100 --json --full
    else
      cepa_send_orca "$cepa_send_tmp/runs.$cepa_send_pg.json" orchestration run-list --limit 100 \
        --cursor "$cepa_send_cur" --json --full
    fi || pending outbox_unreadable "the Run list could not be read"
    cepa_send_cur=$(python3 -I - "$cepa_send_tmp/runs.$cepa_send_pg.json" <<'PY' 2>/dev/null
import json, re, sys
d = json.load(open(sys.argv[1]))
r = d["result"] if d.get("ok") is True else sys.exit(1)
if not isinstance(r.get("runs"), list) or "nextCursor" not in r:
    sys.exit(1)
c = r["nextCursor"]
if c is None:
    print("END")
elif isinstance(c, str) and re.fullmatch(r"[A-Za-z0-9_=-]{1,512}", c) and r["runs"]:
    print(c)   # a cursor with no rows on its page is a short read
else:
    sys.exit(1)
PY
) || pending outbox_unreadable "the Run list could not be read"
    [ "$cepa_send_cur" != END ] || break
    [ "$cepa_send_pg" -lt 20 ] || pending outbox_unreadable "the Run list has more than 20 pages"
  done
  cepa_send_orca "$cepa_send_tmp/tlist.json" terminal list --limit 1000 --json \
    || pending outbox_unreadable "the terminal list could not be read"
  cepa_send_orca "$cepa_send_tmp/ps.json" worktree ps --json \
    || pending outbox_unreadable "worktree ps could not be read"
  cepa_send_res=$(python3 -I - "$cepa_send_tmp" "$cepa_send_pg" "$cepa_send_coord" <<'PY' 2>/dev/null
import json, re, sys
tmp, pages, repo = sys.argv[1], int(sys.argv[2]), sys.argv[3]
TERM = re.compile(r"term_[0-9a-f-]{36}")

def slug(x):
    x = re.sub(r"-+", "-", re.sub(r"[^A-Za-z0-9_-]", "-", x))
    return x.strip("-")

def load(n):
    d = json.load(open("%s/%s" % (tmp, n)))
    return d["result"] if d.get("ok") is True else sys.exit(1)

def main():
    runs = []
    for i in range(1, pages + 1):
        runs += load("runs.%d.json" % i)["runs"]
    # The objective's first word is rule 6's <repo>, the raw directory name;
    # it counts when its slug is the address (`foo.bar` for coord:foo-bar).
    obj = re.compile(r"(\S{1,100}) coord@main(?:$|[ :])")
    claimed = set()
    for r in runs:
        o, h = r["objective"], r["coordinator_handle"]
        m = obj.match(o) if isinstance(o, str) else None
        if m and slug(m.group(1)) == repo and isinstance(h, str) and TERM.fullmatch(h):
            claimed.add(h)
    tl, ps = load("tlist.json"), load("ps.json")
    if tl["truncated"] is not False or ps["truncated"] is not False:
        return "PENDING outbox_unreadable the terminal list or worktree ps was truncated"
    terms = {t["handle"]: t for t in tl["terminals"]}
    wts = {w["path"]: w for w in ps["worktrees"]}
    agents = [a for w in ps["worktrees"] for a in (w.get("agents") or [])]
    live, wrong = set(), set()
    for h in claimed:
        t = terms.get(h)
        if not t or t.get("connected") is not True:
            continue
        pane = "%s:%s" % (t["tabId"], t["leafId"])
        rows = [a for a in agents if a.get("paneKey") == pane]
        if len(rows) != 1 or rows[0].get("hasLivePty") is not True:
            continue
        w = wts.get(t["worktreePath"])
        base = t["worktreePath"].replace("\\", "/").rstrip("/").rsplit("/", 1)[-1]
        if w and w.get("isMainWorktree") is True and slug(base) == repo:
            live.add(h)
        else:
            wrong.add(h)
    if len(live) == 1:
        return "SEND " + live.pop()
    if len(live) > 1:
        return "PENDING outbox_ambiguous more than one live coord@main claims %s: %s" % (repo, " ".join(sorted(live)))
    if wrong:
        return "PENDING outbox_mismatch a live session claims coord@main of %s outside its main checkout: %s" % (
            repo, " ".join(sorted(wrong)))
    return "PENDING - no live coord@main for %s" % repo

try:
    print(main())
except Exception:
    print("PENDING outbox_unreadable the Orca output has a shape this reader does not know")
PY
) || cepa_send_res=
  case "$cepa_send_res" in
    'SEND '*) cepa_send_target=${cepa_send_res#SEND }
              [[ $cepa_send_target =~ ^term_[0-9a-f-]{36}$ ]] \
                || pending outbox_unreadable "the Orca output has a shape this reader does not know" ;;
    'PENDING - '*) pending "" "${cepa_send_res#PENDING - }" ;;
    'PENDING '*) cepa_send_res=${cepa_send_res#PENDING }
                 pending "${cepa_send_res%% *}" "${cepa_send_res#* }" ;;
    *) pending outbox_unreadable "the Orca output has a shape this reader does not know" ;;
  esac
  echo "Orca send resolved: coord:$cepa_send_coord is $cepa_send_target"
fi
case "$cepa_send_type" in
  reply)
    cepa_send_orca "$cepa_send_tmp/send.json" orchestration reply --id "$cepa_send_target" \
      --body "$cepa_send_body" --retry-request "$cepa_send_req" --json ;;
  worker_done)
    cepa_send_orca "$cepa_send_tmp/send.json" orchestration send --type worker_done \
      --subject "$cepa_send_subject" --body "$cepa_send_body" --task-id "$cepa_send_task" \
      --dispatch-id "${cepa_send_target#dispatch:}" --outcome "$cepa_send_outcome_arg" \
      --retry-request "$cepa_send_req" --json ;;
  *)
cepa_send_orca "$cepa_send_tmp/send.json" orchestration send --to "$cepa_send_target" \
  --type "$cepa_send_type" --subject "$cepa_send_subject" --body "$cepa_send_body" \
  --retry-request "$cepa_send_req" --json ;;
esac

# Prints `<msg id> <recipient>`, or `FAIL <reason>`. The reason holds no Orca
# text except an error code that is a plain word.
cepa_send_got=$(python3 -I - "$cepa_send_tmp/send.json" "$cepa_send_rc" "$cepa_send_target" \
  "$cepa_send_type" "$cepa_send_task" "$cepa_send_outcome" <<'PY' 2>/dev/null
import json, re, sys
path, rc, target = sys.argv[1], int(sys.argv[2]), sys.argv[3]
typ, task, action = sys.argv[4], sys.argv[5], sys.argv[6]
ADDR = r"(term_[0-9a-f-]{36}|run:[A-Za-z0-9_-]{1,64}|dispatch:[A-Za-z0-9_-]{1,64})"

def verdict():
    text = open(path, encoding="utf-8", errors="replace").read()
    if not text.strip():
        return "FAIL the send exited %d and printed nothing" % rc
    try:
        d = json.loads(text)
    except ValueError:
        return "FAIL the send exited %d and printed no JSON" % rc
    if not isinstance(d, dict):
        return "FAIL the send printed JSON of an unexpected shape"
    if d.get("ok") is not True:
        err = d.get("error") if isinstance(d.get("error"), dict) else {}
        code = err.get("code")
        tail = " (%s)" % code if isinstance(code, str) and re.fullmatch(r"[a-z_]{1,40}", code) else ""
        return 'FAIL Orca did not return "ok": true%s' % tail
    if rc != 0:
        return "FAIL the send exited %d" % rc
    r = d.get("result")
    m = r.get("message") if isinstance(r, dict) else None
    mid = m.get("id") if isinstance(m, dict) else None
    if not isinstance(mid, str) or not re.fullmatch(r"msg_[0-9a-f]{6,32}", mid):
        return "FAIL the reply has no result.message.id"
    to = m.get("to_handle")
    if typ == "reply":
        # A reply has no target handle to fall back on, and must answer the
        # question it names.
        if m.get("thread_id") != target:
            return "UNPROVEN the reply is not threaded on %s" % target
    elif to is None:
        to = target
    if typ == "worker_done":
        lc = r.get("lifecycle")
        if not isinstance(lc, dict) or lc.get("action") != action \
                or lc.get("dispatchId") != target[len("dispatch:"):] or lc.get("taskId") != task:
            return "UNPROVEN Orca did not record the dispatch as %s" % action
    if not isinstance(to, str) or not re.fullmatch(ADDR, to):
        return "UNPROVEN the reply names no valid recipient"
    return mid + " " + to

try:
    print(verdict())
except Exception:
    print("FAIL the send output could not be read")
PY
) || cepa_send_got=
case "$cepa_send_got" in
  '') fail "the send output could not be read" ;;
  'FAIL '*) fail "${cepa_send_got#FAIL }" ;;
  'UNPROVEN '*) unproven "${cepa_send_got#UNPROVEN }" ;;
esac
cepa_send_id=${cepa_send_got%% *}
cepa_send_to=${cepa_send_got#* }
[ -n "$cepa_send_to" ] && [ "$cepa_send_to" != "$cepa_send_got" ] || fail "the send output could not be read"

# THE RE-READ.
cepa_send_orca "$cepa_send_tmp/inbox.json" orchestration inbox --limit 200 --json --full \
  || fail "the inbox could not be re-read, so $cepa_send_id is unconfirmed"
cepa_send_q=
[ "$cepa_send_type" = reply ] && cepa_send_q=$cepa_send_target
python3 -I - "$cepa_send_tmp/inbox.json" "$cepa_send_id" "$cepa_send_to" "$cepa_send_q" \
  "${ORCA_TERMINAL_HANDLE:-}" <<'PY' >/dev/null 2>&1
import json, re, sys
try:
    d = json.load(open(sys.argv[1]))
    rows = d["result"]["messages"] if d.get("ok") is True else []
    # Orca 1.4.246's concise inbox (no --full) names `to`, not `to_handle`
    # (L72): a row without `to_handle` is a shape this reader does not know,
    # never "not stored".
    if not isinstance(rows, list) or not all(isinstance(x, dict) and "to_handle" in x for x in rows):
        sys.exit(2)
    found = any(isinstance(x, dict) and x.get("id") == sys.argv[2] and x.get("to_handle") == sys.argv[3]
                for x in rows)
    # A reply answers the sender of the message it names. It came back here
    # when Orca addressed it to this session's handle, or when that message's
    # row is in the window and this session sent it.
    q, me = sys.argv[4], sys.argv[5]
    if not re.fullmatch(r"term_[0-9a-f-]{36}", me):
        me = ""
    mine = bool(q and me) and (sys.argv[3] == me or any(
        isinstance(x, dict) and x.get("id") == q and x.get("from_handle") == me for x in rows))
except Exception:
    sys.exit(2)
sys.exit(3 if found and mine else 0 if found else 1)
PY
case $? in
  0) ;;
  3) echo "Orca reply misaddressed: $cepa_send_id stored for $cepa_send_to, but $cepa_send_target was sent by this session, so the reply came back to it"
     echo "Ending first line: Needed from you: check which session asked $cepa_send_target"
     exit 1 ;;
  1) fail "$cepa_send_id is not in the inbox for $cepa_send_to" ;;
  *) fail "the inbox could not be parsed, so $cepa_send_id is unconfirmed" ;;
esac

echo "Orca send stored: $cepa_send_id for $cepa_send_to"
# Delivered (Builder-check 4): the outbox file moves to delivered/, named
# with the handle it went to, so a new coord@main's drain can show it when
# that handle is gone (#10).
if [ -n "$cepa_send_obox" ]; then
  cepa_send_n=${cepa_send_obox##*/}
  if ( umask 077 && mkdir -p "${cepa_send_obox%/*}/delivered" ) 2>/dev/null \
      && mv -f "$cepa_send_obox" "${cepa_send_obox%/*}/delivered/${cepa_send_n%.md}.to-$cepa_send_target.md" 2>/dev/null; then
    echo "Orca outbox: delivered: $cepa_send_coord/delivered/${cepa_send_n%.md}.to-$cepa_send_target.md"
  else
    echo "Orca outbox: could not mark delivered; still pending: $cepa_send_coord/$cepa_send_n (a drain may show it again)"
  fi
fi
if [ "$cepa_send_type" = reply ]; then
  [ "$cepa_send_mode" = nudge ] || exit 0
  if [[ $cepa_send_to != term_* ]]; then
    echo "Orca nudge not needed: Orca stored it in $cepa_send_to, a mailbox Orca delivers"
    exit 0
  fi
  cepa_send_target=$cepa_send_to
fi
# A downgraded send that Orca stored for a term_ handle other than the target
# reached a mailbox Orca does not prompt: it says so, as a rerouted nudge
# send does below, never "not needed" (PR #122 review).
if [ -n "$cepa_send_downgraded" ]; then
  if [ "$cepa_send_to" != "$cepa_send_target" ] && [[ $cepa_send_to == term_* ]]; then
    echo "Orca nudge skipped: Orca stored it for $cepa_send_to, not the target"
    echo "Ending first line: Needed from you: tell $cepa_send_to to check its Orca inbox"
    exit 1
  fi
  echo "Orca nudge not needed: $cepa_send_target is a mailbox Orca delivers; sent as no-nudge"
  exit 0
fi
[ "$cepa_send_mode" = nudge ] || exit 0
if [ "$cepa_send_to" != "$cepa_send_target" ]; then
  if [[ $cepa_send_to == run:* ]]; then
    echo "Orca nudge not needed: Orca stored it in $cepa_send_to, a Run mailbox it prompts"
    exit 0
  fi
  echo "Orca nudge skipped: Orca stored it for $cepa_send_to, not the target"
  echo "Ending first line: Needed from you: tell $cepa_send_to to check its Orca inbox"
  exit 1
fi
cepa_send_nudge="$(dirname "$0")/orca-nudge.sh"
if [ ! -f "$cepa_send_nudge" ]; then
  echo "Orca nudge skipped: orca-nudge.sh not found beside orca-send.sh"
  echo "Ending first line: Needed from you: tell $(cepa_send_who "$cepa_send_target") to check its Orca inbox"
  exit 1
fi
rm -rf "$cepa_send_tmp"
trap - EXIT
# The nudge's lines are read back so its own `tell <handle>` line can name the
# session too: only that exact line changes, and only with a session name.
cepa_send_nout=$(bash "$cepa_send_nudge" "$cepa_send_cli" "$cepa_send_target")
cepa_send_nrc=$?
cepa_send_tell="Ending first line: Needed from you: tell $cepa_send_target to check its Orca inbox"
[ -z "$cepa_send_nout" ] || while IFS= read -r cepa_send_line; do
  [ "$cepa_send_line" != "$cepa_send_tell" ] \
    || cepa_send_line="Ending first line: Needed from you: tell $(cepa_send_who "$cepa_send_target") to check its Orca inbox"
  printf '%s\n' "$cepa_send_line"
done <<<"$cepa_send_nout"
# A nudge that printed nothing gave the session no line to end on: it may
# have died on a syntax error or `set -u` (PR #110 review). Not delivered.
if [ "$cepa_send_nrc" -le 3 ] && [ -z "$cepa_send_nout" ]; then
  echo "Orca nudge skipped: orca-nudge.sh exited $cepa_send_nrc and printed nothing"
  echo "Ending first line: Needed from you: tell $(cepa_send_who "$cepa_send_target") to check its Orca inbox"
  exit 1
fi
if [ "$cepa_send_nrc" -gt 3 ]; then
  echo "Orca nudge skipped: orca-nudge.sh would not start (exit $cepa_send_nrc)"
  echo "Ending first line: Needed from you: tell $(cepa_send_who "$cepa_send_target") to check its Orca inbox"
  exit 1
fi
exit "$cepa_send_nrc"
