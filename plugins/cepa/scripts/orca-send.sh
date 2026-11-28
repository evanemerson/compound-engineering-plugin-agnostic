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
#                           address; `bot:<name>`, an Orca bot on this
#                           computer (THE BOT ADDRESS, below); for a reply,
#                           the question's msg_ id; or
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
#     on: <server>          optional (punch-list L88): the paired Orca server
#                           (its id or name, Orca's `--on`) that issued a
#                           `term_` target, for a worker on an Orca host. Only
#                           with a `term_` target, never a reply. The value is
#                           [A-Za-z0-9 ._:%()@-], starting with a letter or
#                           digit, at most 100 characters. Such a target is
#                           never nudged from here: orca-nudge.sh reads this
#                           machine's `worktree ps`, which does not list a host
#                           terminal. Nor is it needed: the host Orca prompts
#                           its own worker (orca-lab's re-measure of cepa 1.60.0,
#                           msg_6a0b36ef91b6, sender report: the worker read
#                           the message and replied). So with `nudge`, a row
#                           stored for the target prints `Orca nudge not
#                           needed: … which prompts its own worker` and exits
#                           0, with no operator ask (L89 a). L89 a (orca-lab,
#                           Orca 1.4.262, live WSL host, 2026-11-17; sender
#                           report, not re-run here): the stored row is only
#                           in the HOST's inbox (`to_handle` the host term_,
#                           `from_handle` `<sender> on <machine>`), so the
#                           re-read and the read-back pass `--environment
#                           <server>` (its `--help`: "a saved paired Orca
#                           server (id or name)", the same as `--on`). The
#                           read-back takes that `from_handle` form only with
#                           `on:`. PR #142's run measured the read itself (Orca
#                           1.4.262, 2026-11-17, host live): `orchestration
#                           inbox --environment <sel> --limit 3 --json --full`
#                           answered `"ok": true` with the host's rows for
#                           both `wsl:ubuntu-24.04` and `Ubuntu-24.04 (WSL)`.
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
#   0  Orca send stored as a follow-up dispatch: dispatch:<new> of <target>
#      (punch-list L89 b) — a `dispatch:` send that Orca 1.4.262 carried as a
#      follow-up dispatch of a finished `--keep-open` worker (orca-lab's
#      measurement, sender report). Its reply has no `result.message`; it
#      counts only with exit 0, `"ok": true`, `state: "ready"`, `followUpOf`
#      equal to the target's dispatch id, a `dispatchId` (`ctx_` then
#      [A-Za-z0-9_-], at most 64) that is not the target's, no `message` at
#      all, and a type other than reply and worker_done. There is no msg_ id
#      to re-read, and no nudge. A plain `dispatch:` send that failed in any
#      other way and is not read back exits 5 as `not proven stored`, never
#      `no message stored`: it may have started a follow-up. `followUpOf`
#      is accepted as `ctx_…` or `dispatch:ctx_…`. Any other shape goes on to
#      THE READ-BACK as before.
#   0  Orca send stored as a follow-up dispatch: dispatch:<new> of <target>,
#      after <ctx> in its follow-up chain (punch-list L89 b) — the same
#      shape, but `followUpOf` names another dispatch. orca-lab's 1.60.0
#      re-measure (msg_6a0b36ef91b6, sender report): it is a bare `ctx_…`
#      naming the NEWEST dispatch of the chain, so every send after the
#      first carries one. THE FOLLOW-UP CHAIN proves it from Orca's own
#      records, re-measured by PR #143 (Orca 1.4.262, 2026-11-18, read only;
#      the chains found with `orchestration worker-list --environment
#      wsl:ubuntu-24.04 --limit 100 --json --full`, 15 dispatches): on
#      the WSL host, `worker-show --environment wsl:ubuntu-24.04 --dispatch
#      <id> --json --full` gives `result.dispatch.followUpOf` = the dispatch
#      it followed up (chains of 4, 3 and 3 dispatches, each sharing one
#      terminal, the oldest `null`); this machine's record of the same host
#      dispatch has `followUpOf: null` and `result.server.environmentId`,
#      and a local dispatch's record has no `server` key. So the walk reads
#      the target's record here, then each hop on the target's server, from
#      <ctx> back along `followUpOf`, and counts the send only when it
#      reaches the target within the hop cap (8, the `for hop` loop). A
#      stranger's dispatch cannot pass, by construction (not run against
#      Orca): its `followUpOf` links, written by Orca, end at its own first
#      dispatch (`null`) without passing the target. A sender keeps chains
#      short by sending the next message to the `dispatch:<new>` it was
#      given: that send is then the direct follow-up, with no walk. A read that fails, an
#      unknown shape, a loop, `null` before the target or more hops than the cap
#      exits 5 as `not proven stored` (it may have started a follow-up).
#   0  Orca send stored as a follow-up dispatch: dispatch:<new> of <target>,
#      found by a re-read, though <reason> (punch-list L93) — a plain
#      `dispatch:` send whose call failed (exit != 0: a timeout, or an exit
#      with no reply) and that THE READ-BACK did not find. orca-lab's report
#      (msg_9dce386e6069, Orca 1.4.262, cepa 1.60.0, a coord@main ON the WSL
#      host; sender report, not re-run here): two such sends exited 124 with
#      no output, and each had started a follow-up dispatch that the worker
#      answered. THE FOLLOW-UP RE-READ proves the new dispatch from Orca's
#      own records, every read on the target's server. Before such a send,
#      the script reads the owner of the target's terminal: the target's
#      record names its terminal (`result.dispatch.assigneeHandle`), and
#      `worker-list --limit 100 --json --full` has exactly one row whose
#      `resource.terminalHandle` is that terminal and whose
#      `resource.ownerDispatchId` is the row's own `dispatchId`. After a
#      failed call it reads that owner again, and counts the send only when
#      the owner changed, the new owner's `followUpOf` is the old owner, and
#      the old owner is the target or THE FOLLOW-UP CHAIN leads from it to the
#      target. No clock is used. PR #144 review: a window on `createdAt`
#      would take a follow-up an EARLIER send started as this one, and report
#      a lost message as stored. Measured for L93, read only (Orca 1.4.262,
#      2026-11-18, `worker-list --environment wsl:ubuntu-24.04 --limit 100
#      --json --full`: 18 rows, newest first; and `worker-show` of each
#      dispatch of one 3-dispatch chain): only the chain's newest dispatch
#      carries the terminal resource, its `ownerDispatchId` is itself and
#      `originDispatchId` is the chain's first; the older ones have
#      `resource: null`. Not measured: the moment a follow-up takes the
#      resource over while the send is still running (a late take-over
#      exits 5). A follow-up another sender starts on the same worker between
#      the two reads would pass as this one; one coordinator owns a worker
#      (§10), so that is accepted. Anything else, or an owner read that
#      failed before the send, exits 5 as `not proven stored`, with `a
#      re-read proved no follow-up (<why>), but one may exist, so do not
#      resend` after the reason.
#   0  Orca send stored: <msg id> for <recipient>, then either orca-nudge.sh's
#      `Orca nudge sent to <handle>`, this script's `Orca nudge not needed:
#      <reason>` (stored in a Run mailbox, `nudge` given for a `run:` or
#      `dispatch:` target and sent as `no-nudge`, or a host `term_` target
#      given `on:` and stored for it, L89 a), or nothing more (`no-nudge`).
#   1, 2, 3  stored, then the nudge skipped, refused or failed: orca-nudge.sh's
#      own lines, its `Ending first line:` included, or this script's own
#      skip (stored for another handle; orca-nudge.sh missing or would not
#      start). The message stands. Every nudge skip or failure but a skip on
#      the target's own row (busy, asking, no row, two rows) also writes a
#      `nudge_skipped` alert file for orca-health.sh (L65): a failed or
#      timed-out Orca call, Orca output it could not read, a missing tool, or
#      an orca-nudge.sh that is missing, will not start or printed nothing.
#      Its `Orca alert recorded:` line comes just before the ending line.
#      A reply also exits 1, with
#      `Orca reply misaddressed: …` in place of `Orca send stored` and no
#      nudge, when it came back to this session (its own address, THE CHAT
#      SENDER AND RECIPIENT): Orca
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
# THE READ-BACK (punch-list L84). "Read Orca's state before reporting a
# failure" (L79, #134 learning 3). A send whose call failed in a way that
# leaves the result unknown may still have stored: a timeout (Orca keeps
# working after its CLI gives up, as `worktree create` did in L79), an exit
# with no output or no JSON, an exit != 0 beside an ok reply, or `"ok": true`
# with no `result.message.id` (L88 item 2: a `dispatch:` send that Orca
# delivered as a follow-up dispatch exited 5 this way, and wrote an alert;
# sender report, cause not found). Before any of those is reported, the
# script reads `inbox --limit 200 --json --full` once for a row that is this
# message: made no earlier than 120 s before the send began (Orca's clock is
# Windows', this one WSL's; with no clock there is no read-back), from
# this session's own address (ORCA_TERMINAL_HANDLE when that is a term_
# handle, else a chat's `orca_session_id:`), the same body (trailing
# space aside), and the same type and subject (a reply: the same thread_id
# as the target, never its root, THE REPLY THREAD, instead), stored for the target itself (a
# `dispatch:` target: for any dispatch, as L88 item 2's rewrite was; a
# `bot:` target: for an `orca_session_id:` or a `run:`, then proven by THE BOT ADDRESS). A worker_done also needs the payload's
# dispatch, task and outcome, and then `worker-show` must report the dispatch
# `completed` or `failed` as the outcome asks, else it is `not proven stored`.
# Found, it prints `Orca send read back: <id> is in the inbox from this send,
# though <reason> (punch-list L84)` and goes on as a stored send (the re-read
# below, the nudge). Not found, or the inbox unreadable, the first reason
# stands. A reply whose `ok` is not true (Orca's `"ok": false` included) is
# Orca's answer, so it is never read back. The
# other Orca writes cepa makes, and why each needs no read-back here or has
# one: §12b rule 2 (worker-start, run-create) and the PR body of L84.
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
# A follow-up chain (L89 b) is the send plus at most 9 reads and no nudge:
# at most 340 s. A plain send to a `dispatch:` target is bounded at 60 s
# instead (L93 1: on a WSL host coordinator, orca-lab measured two such sends
# exit 124 at 15 s, both delivered; 60 is a margin chosen here, not a
# measured start time), so at most 124 s with its retry, after the 3 reads
# of the terminal's owner (THE FOLLOW-UP RE-READ). When it fails and takes
# the re-read, add the inbox read-back, 4 reads and the chain walk's 9: at
# most about 700 s in all (3 + 1 + 4 + 9 reads of 34 s and 124 s), no nudge.
# A `coord:` send adds one `bot list` read before the Run list (THE BOT
# FIRST), and a `bot:` send one `bot chats` read after the re-read (and one
# `run-show` before it when Orca stored it for a Run, L104), each at most
# 34 s; a bot is never nudged, so a bot send takes at most about 175 s (bot
# list, send, re-read, run-show, chats), and a failed bot list then adds the
# terminal resolver's reads.
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
#   - THE BOT FIRST (punch-list L103 C2). Before the Run list, the resolver
#     reads `bot list --json` (Orca 1.4.280, read only, 2026-11-27: `ok`,
#     then `result.bots`, a list of rows with a `name`). Exactly one row named
#     `<repo>-bot` that is not `paused: true` sends to `bot:<repo>-bot`
#     (THE BOT ADDRESS), as `no-nudge`. Two or more such rows are pending with an `outbox_ambiguous` alert.
#     No such row goes on to the terminal resolver above, as before. The
#     bot wins over a live terminal coord@main of the same repo: that is the
#     operator's design for a bot coordinator (L103 C2); the transition (C6)
#     keeps a terminal coord@main only where no `<repo>-bot` exists. So does
#     a list that could not be read (an Orca with no `bot` command): it
#     prints `Orca send resolved: no bot list (<why>); trying the terminal
#     coord@main` first. A delivered bot message moves to
#     <repo>/delivered/<stem>.drained.md: Orca wakes the bot itself, so no
#     drain owes it (orca-outbox.sh shows only `.to-term_` files).
#
# THE BOT ADDRESS (punch-list L103 C1). `bot:<name>` (`<name>` is
# [A-Za-z0-9_] then [A-Za-z0-9._-], at most 105 characters) mails the Home
# Chat of that bot on this computer. Measured by orca-lab (Orca 1.4.272,
# 2026-11-27, docs/research/2026-11-23-bot-coordinator-pilot.md M2; sender
# report): a raw `send --to bot:orca-lab-bot` stores and wakes the bot with a
# new turn. Read here (Orca 1.4.280, 2026-11-27, read only): such rows have
# `to_handle` `orca_session_id:<uuid>`, and `bot chats --bot orca-lab-bot
# --json` lists that uuid as the bot's Home chat id. So a bot send counts
# only with the usual proof (ok, a msg_ id, the re-read row) for an
# `orca_session_id:` recipient, AND `bot chats --bot <name> --json` lists
# that uuid as a chat of the bot that is not `closed`. A row for any other
# address, or a chat list that cannot be read, is `not proven stored`. Orca
# wakes the bot, so a bot is never nudged: `nudge` is sent as `no-nudge`,
# as for a `run:` target.
#   A BOT'S RUN (punch-list L104). A bot whose Home chat is bound to a Run gets
#   its mail in that Run. Measured by coord@main (Orca 1.4.280, 2026-11-28):
#   a send to `coord:orca-lab` resolved to `bot:orca-lab-bot` and was stored
#   as msg_ede2e13a5255 for `run:run_cf8f7c0d2b33`, and the bot's Home chat
#   showed it as its last question. 1.61.0 read that row as `not proven
#   stored`, kept a pending outbox copy and wrote an alert. Re-read here (the
#   same Orca and date, read only): `inbox --limit 2000 --json --full` (429
#   rows) has 12 rows for that Run. 11 are bot sends, and each has a `payload`
#   whose JSON holds a `botRequest` object. The 12th is a worker_done from the
#   bot's own worker, with no botRequest. Over the whole inbox, 18 rows hold
#   one: 11 for that Run and 7 for `orca_session_id:` chats that `bot chats`
#   lists for orca-lab-bot or fleet, so every one is mail to a bot. The probe:
#   `python3 -c 'import json,sys,collections; r=json.load(sys.stdin)
#   ["result"]["messages"]; b=[x for x in r if isinstance(json.loads(
#   x.get("payload") or "null"),dict) and isinstance(json.loads(x["payload"])
#   .get("botRequest"),dict)]; print(len(r), len(b), collections.Counter(
#   x["to_handle"] for x in b))'`. This script never passes `--payload`.
#   No Orca read names a bot's Run: `bot list` rows hold id, name, agent,
#   paused, linked, specialty, chats; `bot chats --json` rows hold id, title,
#   lastActivityAt, lastAsked, lastSaid, home, self, closed (lastAsked is the
#   message TEXT, cut at 200 characters, with no message id);
#   `run-show`/`run-list` give that Run's objective and `coordinator_handle`
#   null, with no bot field; `run-current --from orca_session_id:<chat>`
#   refuses (`session_caller_chat_not_declarable`); the bot's `bot.json`
#   holds id, name, agent, avatar, members. So a bot send stored for
#   `run:<id>` counts only when the usual proof holds AND (1) the re-read row
#   with THIS msg id for that `run:` has a `payload` that parses to an object
#   with a `botRequest` object, (2) `run-show --id <id>` is ok, names that
#   id, and has `coordinator_handle` null (no terminal coordinator), and (3)
#   `bot chats --bot <name> --json` lists a chat with `home: true` and
#   `closed: false`. STATED GAP: the tie of that Run to THIS bot is Orca's own
#   routing of `bot:<name>`, not proven by a second record. It is the same
#   trust the script gives Orca when it moves a `term_` send to a `run:`
#   mailbox (THE RE-READ). Text matching on lastAsked was weighed and not
#   taken (coord@main, 2026-11-28): it would match the subject, and the bot's
#   wake can change it before the read.
#   Not measured: the `send` reply's own `to_handle` for a bot (no test send
#   was made here: a bot is made only when its owner accepts a card). One with
#   no `to_handle` is read back (THE READ-BACK takes an `orca_session_id:` or
#   a `run:` row, then the proof above), and one with any other address is
#   `not proven stored`.
#   A REPLY TO A BOT is refused by Orca (coord@main, Orca 1.4.280,
#   2026-11-28: a terminal's reply to msg_ceda090dbc42, which a bot sent,
#   answered `bot_reply_not_yours`). The refusal exits 5 as before, and its
#   reason adds that a bot is answered with a send to `bot:<name>`.
#
# THE CHAT SENDER AND RECIPIENT (punch-list L98, L103 C1). A Chat or bot
# session has no ORCA_TERMINAL_HANDLE. Its identity is ORCA_AGENT_SESSION_ID
# with ORCA_STRUCTURED_SESSION=1, and its mail goes out from
# `orca_session_id:<id>` (orca-lab, Orca 1.4.272, 2026-11-27,
# docs/research/2026-11-27-chat-coordinator-probes.md P1; sender report). So
# when ORCA_TERMINAL_HANDLE is empty, that address is this session's own:
# the read-back and the misaddressed-reply check use it as they use a
# `term_` handle. A reply to such a sender is stored for `run:<the chat's
# Run>`, or for `orca_session_id:<id>` itself (read here: msg_cbe3e101fcd4,
# 2026-11-23), and both count as a recipient. Up to 1.60.x the second was
# refused as "the reply names no valid recipient" though it stored (L98).
# Orca wakes a chat for mail to its Run (P2d), so a reply stored for a Run
# is never nudged. Not measured: whether Orca wakes a chat that has no Run,
# so a reply stored for `orca_session_id:` itself is not claimed delivered:
# it prints `Orca nudge skipped: … whether Orca wakes it is not measured`,
# asks the operator to tell that chat, and exits 1 (PR #149 review).
#
# THE REPLY THREAD (punch-list L97). A reply's row carries `thread_id` = the
# thread's ROOT, not the message it answers. Read here (Orca 1.4.280,
# 2026-11-27, `orchestration inbox --limit 2000 --json --full`, read only:
# 400 rows; the field scan was `python3 -c 'import json,sys,collections;
# r=json.load(sys.stdin)["result"]["messages"]; print(len(r),
# collections.Counter(k for x in r for k in x))'` and a count of
# `thread_id` null / equal to `id`): no row has a parent or reply-to field; a root row has
# `thread_id` null (348 rows) or its own id (14); a reply carries the root's
# id. orca-lab's alert 1795389024-4JM95YWl was a reply to a reply that
# stored with the root's id and exited 5. So a reply counts as threaded when
# its `thread_id` is the target, OR the target's own row is in the same
# inbox read and its `thread_id` is a msg_ id equal to the reply's. A target
# row outside the 200-row window leaves a reply to a reply `not proven
# stored`, as before. THE READ-BACK still matches a reply on the target's
# own id only, never on the root: a root match would take this session's
# earlier reply to ANOTHER message of the thread, with the same body, as
# this one (PR #149 review). So a reply to a reply whose call failed is not
# read back, as before this change.
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
# unreadable (`outbox_unreadable`, or an
# unconfirmed send). `terminal`, `worktree` and `repo` reads have no `--full` flag
# on 1.4.246 and still print the full record. Whether an older Orca (1.4.245
# or before) accepts `--full` was not measured: none was at hand to run.
# No script here reads `check`. Its short form, message rows included, is
# measured in `cepa:autonomy` §12b rule 8 (punch-list L73).
# The WRITES print a concise view too. `send` without `--full` printed
# `{"messageId": "msg_…", "warnings": ["<text>"]}` (no `message` object, so
# every send read "no result.message.id" and exit 5 though Orca stored it);
# with `--full` it prints `{message: {id, to_handle, …}, warnings, mutation:
# {requestId, replayed}}` (measured 2026-11-02 by one send to this worker's
# own terminal, replayed with `--full` under the same `--retry-request`: one
# message stored). `reply` documents the same `--full` in its `--help`; its
# output was not measured (no question to answer), so it passes `--full` on
# that evidence alone.
#
# STATED LIMITS:
#   - The outbox is on this machine, and every session runs as one user, so
#     a file's sender is a claim, never proven (review residual risk).
#   - A tab that closes in the seconds after a stored send leaves a
#     `delivered` file no coordinator read (Builder-check 4); a new
#     coord@main's drain shows such files for 7 days (#10).
#   - The misaddressed-reply check needs this session's own address
#     (ORCA_TERMINAL_HANDLE, or a chat's `orca_session_id:`, above). With
#     neither, a reply Orca stored in this session's own `dispatch:` mailbox
#     reads as stored unless the message it names is in the 200-row window.
#   - A row in the inbox is "stored", not "read". Reading is the nudge's job,
#     and rule 8's peek is the backstop.
#   - The size cap is 28,000 bytes of subject plus body, below the measured
#     limit. The Windows limit counts UTF-16 units of the whole command line,
#     so bytes over-count non-ASCII text: a cap in bytes is the safe side.
#   - If the inbox cannot be read or parsed, or a send that timed out has not
#     reached the inbox by THE READ-BACK's one read, the send is reported
#     failed even when it may have stored (the reason then says "unconfirmed"
#     or names the exit): a pasted copy then duplicates it. A duplicate is the
#     accepted cost; a lost message is not.
#   - THE READ-BACK cannot tell this send from an identical one (same type,
#     subject, body and recipient) made in the same two minutes, by this
#     session, or by any session when this session has no address of its
#     own: such a row reads as stored. The message did reach that recipient.
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
  [[ $cepa_send_target =~ ^(term_[0-9a-f-]{36}|run:[A-Za-z0-9_-]{1,64}|dispatch:[A-Za-z0-9_-]{1,64}|coord:[A-Za-z0-9_-]{1,100}|bot:[A-Za-z0-9_][A-Za-z0-9._-]{0,104})$ ]]
}
# This session's own address (THE CHAT SENDER AND RECIPIENT): its term_
# handle, else a chat's `orca_session_id:<id>` when ORCA_TERMINAL_HANDLE is
# empty and ORCA_STRUCTURED_SESSION=1, else nothing. A handle that is set but
# not a term_ handle stays nothing, as before.
cepa_send_me=${ORCA_TERMINAL_HANDLE:-}
if [ -z "$cepa_send_me" ]; then
  [ "${ORCA_STRUCTURED_SESSION:-}" = 1 ] && [[ ${ORCA_AGENT_SESSION_ID:-} =~ ^[0-9a-f-]{36}$ ]] \
    && cepa_send_me=orca_session_id:$ORCA_AGENT_SESSION_ID
elif ! [[ $cepa_send_me =~ ^term_[0-9a-f-]{36}$ ]]; then
  cepa_send_me=
fi
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
  [[ $tgt =~ ^(msg_[0-9a-f]{6,32}|term_[0-9a-f-]{36}|run:[A-Za-z0-9_-]{1,64}|dispatch:[A-Za-z0-9_-]{1,64}|coord:[A-Za-z0-9_-]{1,100}|bot:[A-Za-z0-9_][A-Za-z0-9._-]{0,104})$ ]] || tgt=invalid
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
# sees it, not the one that happened to prune (review). A file whose count
# alert is already acked goes with no alert (L87). Names that are not the
# writer's shape are left for orca-health.sh to report.
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
      # L87: a file whose count alert the operator already acked goes with no
      # second alert. orca-health.sh keys that alert `outbox:<sub>:<name>` and
      # writes its ack under acked/<worktree>/ of the checkout that saw it:
      # the file's own sender lane (worktree=), or its repo's main checkout
      # (repo=). Only a plain name is joined into the path.
      if cepa_send_obox_acked "$sub" "${f##*/}" "$r" "$w"; then
        rm -f -- "$f" 2>/dev/null || echo "Orca outbox: could not prune $st/${f##*/}"
        continue
      fi
      cepa_send_alert_for outbox_pruned "coord:$sub" "an outbox file was pruned unread after 7 days: $sub/$n" "$r" "$w" \
        || { echo "Orca outbox: kept $sub/$n past 7 days: its prune alert could not be recorded"; continue; }
    fi
    rm -f -- "$f" 2>/dev/null || echo "Orca outbox: could not prune $st/${f##*/}"
  done
}
# True when the count alert that covered outbox:<$1>:<$2> is acked under
# acked/<$3> or acked/<$4> of the alert directory (L87). That alert is keyed
# by its NEWEST file, and its ack holds every file up to that one, so a
# marker outbox:<$1>:<m> with m sorting at or after $2 counts (names start
# with their UTC stamp). $3 and $4 come from the file's header, so each must
# be a plain name before it is joined into a path. A main checkout's ack
# also covers a lane's file: that coordinator saw the same message.
cepa_send_obox_acked() {
  local dir w m
  dir=${CEPA_ORCA_ALERT_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/cepa/orca-alerts}
  [[ $dir == /* ]] || return 1
  for w in "$3" "$4"; do
    [[ $w =~ ^[A-Za-z0-9._@-]{1,100}$ && $w != . && $w != .. ]] || continue
    for m in "$dir/acked/$w/outbox:$1:"*.md; do
      [ -f "$m" ] || continue
      m=${m##*/outbox:"$1":}
      [[ $m =~ ^[0-9]{8}T[0-9]{6}Z-[A-Za-z0-9]{8}\.md$ ]] || continue
      [[ $m < $2 ]] || return 0
    done
  done
  return 1
}
# An alert about another coord: target than this send's (a pruned file).
# $4 and $5 are that file's own repo= and worktree= (checked again in the
# writer). Returns non-zero when the alert was not recorded.
cepa_send_alert_for() {
  local keep=$cepa_send_target out
  cepa_send_target=$2 cepa_send_arepo=${4-} cepa_send_awt=${5-}
  out=$(cepa_send_alert "$1" "$3")
  cepa_send_target=$keep cepa_send_arepo= cepa_send_awt=
  [[ $out == "Orca alert recorded: "* ]] || { printf '%s\n' "$out"; return 1; }
}

[ $# -eq 0 ] || refuse "orca-send.sh takes no arguments; its fields go on stdin"
# THE FIELDS: `<name>: <value>` lines up to an empty line or the end of
# stdin. Each value is read by `read -r` from the heredoc, so bash never
# parses it as code. No field comes from the environment: only a line on
# stdin sets one.
unset cepa_send_f_cli cepa_send_f_target cepa_send_f_type cepa_send_f_nudge cepa_send_f_outcome \
  cepa_send_f_task cepa_send_f_session cepa_send_f_on cepa_send_f_file
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
    cli|target|type|nudge|outcome|task|session|on|file) ;;
    *) refuse "a field name is not cli, target, type, nudge, outcome, task, session, on or file" ;;
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
  orca) [ "$(uname -s 2>/dev/null || echo Linux)" != Linux ] || case "$cepa_send_cli" in
    /*/linux-orca-cli-shim/orca|/*/cli/bin/orca)
      cepa_send_l=; [ ! -f "$cepa_send_cli" ] || { IFS= read -r cepa_send_l <"$cepa_send_cli"; } 2>/dev/null || :
      case "$cepa_send_l" in
        '#!/usr/bin/env bash'|'#!/usr/bin/env sh') ;;
        *) refuse "an orca path on Linux is not an Orca launcher" ;;
      esac ;;
    /*) refuse "an orca path on Linux is not an Orca launcher" ;;
    *) refuse "bare orca on Linux is the screen reader" ;;
  esac ;;
  *) refuse "the cli does not name an Orca CLI" ;;
esac
case "$cepa_send_type" in
  escalation)
    [[ $cepa_send_target != coord:* ]] || refuse "an escalation cannot go to a coord: address; it keeps its Run path"
    cepa_send_valid_target || refuse "the target is not a term_ handle, run:, dispatch: or bot: address" ;;
  status|question|handoff|merge_ready)
    cepa_send_valid_target || refuse "the target is not a term_ handle, run:, dispatch: or bot: address" ;;
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
# THE HOST TARGET (punch-list L88): `on:` names the paired Orca server that
# issued a term_ handle, and the send carries it as `--on <server>`.
cepa_send_on=
if [[ $cepa_send_seen == *" on "* ]]; then
  cepa_send_on=${cepa_send_f_on-}
  [[ $cepa_send_target =~ ^term_[0-9a-f-]{36}$ && $cepa_send_type != reply ]] \
    || refuse "an on: server goes only with a term_ target"
  cepa_send_onre='^[A-Za-z0-9][A-Za-z0-9 ._:%()@-]{0,99}$'
  [[ $cepa_send_on =~ $cepa_send_onre ]] || refuse "the on: server is not an Orca server id or name"
fi
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

# One Orca call, bounded at cepa_send_bound seconds (15, or 60 for a plain
# send to a `dispatch:` target: TIME BUDGET) plus a 2-second kill, its stdout
# to $1. Sets cepa_send_rc. Retried once, only on the WSL interop error.
cepa_send_bound=15
cepa_send_orca() {
  local out=$1 try
  shift
  for try in 1 2; do
    timeout -k 2 "$cepa_send_bound" "$cepa_send_cli" "$@" </dev/null >"$out" 2>"$cepa_send_tmp/err" && { cepa_send_rc=0; return 0; }
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
cepa_send_bot=
if [ -n "$cepa_send_coord" ]; then
  # THE BOT FIRST (L103 C2): a bot named <repo>-bot is the coordinator.
  if cepa_send_orca "$cepa_send_tmp/bots.json" bot list --json; then
    cepa_send_bot=$(python3 -I - "$cepa_send_tmp/bots.json" "$cepa_send_coord-bot" <<'PY' 2>/dev/null
import json, sys
d = json.load(open(sys.argv[1]))
r = d["result"] if d.get("ok") is True else sys.exit(1)
if not isinstance(r, dict) or not isinstance(r.get("bots"), list):
    sys.exit(1)
# A paused bot is no live coordinator (PR #149 review): it does not count.
n = sum(1 for b in r["bots"] if isinstance(b, dict) and b.get("name") == sys.argv[2] and b.get("paused") is not True)
print("BOT" if n == 1 else "AMBIG" if n > 1 else "NONE")
PY
) || cepa_send_bot="the bot list has a shape this reader does not know"
  else
    cepa_send_bot="the bot list could not be read"
  fi
  case "$cepa_send_bot" in
    BOT) cepa_send_bot=bot:$cepa_send_coord-bot ;;
    NONE) cepa_send_bot= ;;
    AMBIG) pending outbox_ambiguous "more than one bot is named $cepa_send_coord-bot" ;;
    *) echo "Orca send resolved: no bot list ($cepa_send_bot); trying the terminal coord@main"
       cepa_send_bot= ;;
  esac
fi
if [ -n "$cepa_send_bot" ]; then
  cepa_send_target=$cepa_send_bot
  cepa_send_valid_target || pending outbox_unreadable "the Orca output has a shape this reader does not know"
  # Orca wakes a bot: it is never nudged (THE BOT ADDRESS).
  [ "$cepa_send_mode" != nudge ] || cepa_send_mode=no-nudge cepa_send_downgraded=1
  echo "Orca send resolved: coord:$cepa_send_coord is $cepa_send_target"
elif [ -n "$cepa_send_coord" ]; then
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
# Where the target's chain lives: reads the target's home record into $1 and
# sets cepa_send_where_env to `--environment <id>` for a host dispatch, whose
# home record names its server (`result.server.environmentId`), or to nothing
# for a local one, which has no `server` key. Returns 1 on a failed read or
# an unknown shape.
cepa_send_where() {
  local td=${cepa_send_target#dispatch:} nx
  cepa_send_where_env=()
  cepa_send_orca "$1" orchestration worker-show --dispatch "$td" --json --full || return 1
  nx=$(python3 -I - "$1" "$td" <<'PY' 2>/dev/null
import json, re, sys
d = json.load(open(sys.argv[1]))
r = d["result"] if d.get("ok") is True else sys.exit(1)
if not isinstance(r, dict) or not isinstance(r.get("dispatch"), dict) or r["dispatch"].get("id") != sys.argv[2]:
    sys.exit(1)
if "server" not in r:
    print("local")
    sys.exit(0)
e = r["server"].get("environmentId") if isinstance(r["server"], dict) else None
if not (isinstance(e, str) and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9 ._:%()@-]{0,99}", e)):
    sys.exit(1)
print("env " + e)
PY
) || return 1
  case "$nx" in
    local) ;;
    'env '*) cepa_send_where_env=(--environment "${nx#env }") ;;
    *) return 1 ;;
  esac
}
# The owner of the target's terminal (L93 1; header, THE FOLLOW-UP RE-READ).
# Reads the target's home record, its record on its own server for a host
# dispatch, and that server's worker list into files tagged $1. Prints
# `OK <dispatch id>\t<environment id or ->`: the one row whose
# `resource.terminalHandle` is the target's `assigneeHandle` and whose
# `resource.ownerDispatchId` is its own `dispatchId`. Else `FAIL <reason>`.
cepa_send_owner() {
  local td=${cepa_send_target#dispatch:} e=- o
  local -a env=()
  cepa_send_where "$cepa_send_tmp/$1-0.json" || { echo "FAIL the target's record could not be read"; return 1; }
  env=(${cepa_send_where_env[@]+"${cepa_send_where_env[@]}"})
  if [ ${#env[@]} -gt 0 ]; then
    e=${env[1]}
    cepa_send_orca "$cepa_send_tmp/$1-1.json" orchestration worker-show --dispatch "$td" "${env[@]}" \
      --json --full || { echo "FAIL the target's record on $e could not be read"; return 1; }
  else
    cp "$cepa_send_tmp/$1-0.json" "$cepa_send_tmp/$1-1.json" 2>/dev/null || { echo "FAIL the target's record could not be kept"; return 1; }
  fi
  cepa_send_orca "$cepa_send_tmp/$1-2.json" orchestration worker-list ${env[@]+"${env[@]}"} \
    --limit 100 --json --full || { echo "FAIL the worker list could not be read"; return 1; }
  o=$(python3 -I - "$cepa_send_tmp/$1-1.json" "$cepa_send_tmp/$1-2.json" "$td" <<'PY' 2>/dev/null
import json, re, sys
a, b, td = json.load(open(sys.argv[1])), json.load(open(sys.argv[2])), sys.argv[3]
x = a["result"]["dispatch"] if a.get("ok") is True else sys.exit(1)
h = x.get("assigneeHandle") if isinstance(x, dict) and x.get("id") == td else None
if not isinstance(h, str):
    sys.exit(1)
rows = b["result"]["workers"] if b.get("ok") is True else sys.exit(1)
if not isinstance(rows, list):
    sys.exit(1)
hit = []
for w in rows:
    r = w.get("resource") if isinstance(w, dict) else None
    i = w.get("dispatchId") if isinstance(w, dict) else None
    if isinstance(r, dict) and r.get("terminalHandle") == h and isinstance(i, str) \
            and r.get("ownerDispatchId") == i and re.fullmatch(r"ctx_[A-Za-z0-9_-]{1,64}", i):
        hit.append(i)
if len(hit) != 1:
    sys.exit(2)
print(hit[0])
PY
)
  case $? in
    0) printf 'OK %s\t%s\n' "$o" "$e" ;;
    2) echo "FAIL no single dispatch owns the target's terminal"; return 1 ;;
    *) echo "FAIL the target's record or the worker list has a shape this reader does not know"; return 1 ;;
  esac
}
# A plain send to a dispatch reads that owner first, so a failed call can be
# re-read against it. A failed read only leaves the re-read unable to prove.
cepa_send_owner0=
if [[ $cepa_send_target == dispatch:* && $cepa_send_type != worker_done && $cepa_send_type != reply ]]; then
  cepa_send_owner0=$(cepa_send_owner pre) || :
fi
# THE READ-BACK's window starts here (punch-list L84).
cepa_send_t0=$(date +%s 2>/dev/null) || cepa_send_t0=
[[ $cepa_send_t0 =~ ^[0-9]{1,12}$ ]] || cepa_send_t0=0
case "$cepa_send_type" in
  reply)
    cepa_send_orca "$cepa_send_tmp/send.json" orchestration reply --id "$cepa_send_target" \
      --body "$cepa_send_body" --retry-request "$cepa_send_req" --json --full ;;
  worker_done)
    cepa_send_orca "$cepa_send_tmp/send.json" orchestration send --type worker_done \
      --subject "$cepa_send_subject" --body "$cepa_send_body" --task-id "$cepa_send_task" \
      --dispatch-id "${cepa_send_target#dispatch:}" --outcome "$cepa_send_outcome_arg" \
      --retry-request "$cepa_send_req" --json --full ;;
  *)
cepa_send_on_args=()
[ -z "$cepa_send_on" ] || cepa_send_on_args=(--on "$cepa_send_on")
# L93 1: a host Orca took longer than 15 s to start a follow-up dispatch.
[[ $cepa_send_target != dispatch:* ]] || cepa_send_bound=60
cepa_send_orca "$cepa_send_tmp/send.json" orchestration send --to "$cepa_send_target" \
  ${cepa_send_on_args[@]+"${cepa_send_on_args[@]}"} \
  --type "$cepa_send_type" --subject "$cepa_send_subject" --body "$cepa_send_body" \
  --retry-request "$cepa_send_req" --json --full ;;
esac
cepa_send_bound=15

# Prints `<msg id> <recipient>`, or `FAIL <reason>`. The reason holds no Orca
# text except an error code that is a plain word.
cepa_send_got=$(python3 -I - "$cepa_send_tmp/send.json" "$cepa_send_rc" "$cepa_send_target" \
  "$cepa_send_type" "$cepa_send_task" "$cepa_send_outcome" <<'PY' 2>/dev/null
import json, re, sys
path, rc, target = sys.argv[1], int(sys.argv[2]), sys.argv[3]
typ, task, action = sys.argv[4], sys.argv[5], sys.argv[6]
# A recipient. `orca_session_id:` is a Chat or bot session (L98, L103 C1).
ADDR = r"(term_[0-9a-f-]{36}|run:[A-Za-z0-9_-]{1,64}|dispatch:[A-Za-z0-9_-]{1,64}|orca_session_id:[0-9a-f-]{36})"
MIDRE = r"msg_[0-9a-f]{6,32}"

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
        # L89 b (orca-lab, Orca 1.4.262, sender report): a `dispatch:` send to
        # a finished `--keep-open` worker starts a follow-up dispatch. The
        # reply then has no `message`, but `dispatchId` (the new dispatch),
        # `followUpOf` and `state: "ready"`. Only that whole shape counts.
        # L89 b (orca-lab's re-measure of cepa 1.60.0): `followUpOf` is a bare ctx_
        # naming the NEWEST dispatch of the target's follow-up chain, so from
        # the second send on it is not the target: CHAIN, which the caller
        # proves from Orca's own records (THE FOLLOW-UP CHAIN, below).
        if m is None and typ not in ("reply", "worker_done") and target.startswith("dispatch:") \
                and isinstance(r, dict) and r.get("state") == "ready":
            fu, td = r.get("followUpOf"), target[len("dispatch:"):]
            fu = fu[len("dispatch:"):] if isinstance(fu, str) and fu.startswith("dispatch:") else fu
            nd = r.get("dispatchId")
            if isinstance(fu, str) and re.fullmatch(r"ctx_[A-Za-z0-9_-]{1,64}", fu) \
                    and isinstance(nd, str) and re.fullmatch(r"ctx_[A-Za-z0-9_-]{1,64}", nd) \
                    and nd not in (td, fu):
                return ("FOLLOWUP dispatch:" + nd) if fu == td else ("CHAIN dispatch:%s %s" % (nd, fu))
        return "FAIL the reply has no result.message.id"
    to = m.get("to_handle")
    root = ""
    if typ == "reply":
        # A reply has no target handle to fall back on, and must answer the
        # question it names. Orca threads on the ROOT (L97): a thread_id that
        # is another msg_ id is passed on, and the re-read proves it is the
        # target's own thread.
        th = m.get("thread_id")
        if th != target:
            if not (isinstance(th, str) and re.fullmatch(MIDRE, th)):
                return "UNPROVEN the reply is not threaded on %s" % target
            root = " " + th
    elif target.startswith("bot:"):
        # A bot's mail is stored for its chat, or for the Run its Home chat
        # is bound to (THE BOT ADDRESS, L104): only an orca_session_id: or a
        # run: recipient, which the re-read and the bot leg then pin to the
        # bot. No recipient at all (not measured, header) is read back.
        if to is None:
            return "FAIL the reply names no recipient for %s" % target
        if not (isinstance(to, str) and to.startswith(("orca_session_id:", "run:"))):
            return "UNPROVEN the reply names no valid recipient"
    elif to is None:
        to = target
    if typ == "worker_done":
        lc = r.get("lifecycle")
        if not isinstance(lc, dict) or lc.get("action") != action \
                or lc.get("dispatchId") != target[len("dispatch:"):] or lc.get("taskId") != task:
            return "UNPROVEN Orca did not record the dispatch as %s" % action
    if not isinstance(to, str) or not re.fullmatch(ADDR, to):
        return "UNPROVEN the reply names no valid recipient"
    # A chat recipient answers a reply (L98) or a bot (C1) only; a term_,
    # run: or dispatch: send stored for a chat is not that target's.
    if to.startswith("orca_session_id:") and typ != "reply" and not target.startswith("bot:"):
        return "UNPROVEN the reply names no valid recipient"
    return mid + " " + to + root

try:
    print(verdict())
except Exception:
    print("FAIL the send output could not be read")
PY
) || cepa_send_got=
# L89 a (orca-lab, Orca 1.4.262, sender report): a send with `on:` is stored
# in the HOST's inbox, not this machine's, so both inbox reads below go to
# that server (`--environment` takes the same id or name as `--on`).
cepa_send_env_args=()
[ -z "$cepa_send_on" ] || cepa_send_env_args=(--environment "$cepa_send_on")
# THE READ-BACK (punch-list L84; header). A send whose CLI call failed after
# the request left may still have stored, so before such a failure is
# reported the inbox is read for this very message. Only Orca's own
# `"ok": false` is a result that needs no read.
cepa_send_readback() {
  cepa_send_orca "$cepa_send_tmp/back.json" orchestration inbox \
    ${cepa_send_env_args[@]+"${cepa_send_env_args[@]}"} --limit 200 --json --full || return 1
  { printf '%s' "$cepa_send_subject" >"$cepa_send_tmp/subject" && printf '%s' "$cepa_send_body" >"$cepa_send_tmp/body"; } \
    2>/dev/null || return 1
  python3 -I - "$cepa_send_tmp/back.json" "$cepa_send_type" "$cepa_send_target" "$cepa_send_task" \
    "${cepa_send_outcome_arg-}" "$cepa_send_t0" "$cepa_send_me" "$cepa_send_tmp/subject" \
    "$cepa_send_tmp/body" "$cepa_send_on" <<'PY' 2>/dev/null
import calendar, json, re, sys, time
f, typ, target, task, outcome, t0, me, sf, bf, on = sys.argv[1:11]
ADDR = r"(term_[0-9a-f-]{36}|run:[A-Za-z0-9_-]{1,64}|dispatch:[A-Za-z0-9_-]{1,64}|orca_session_id:[0-9a-f-]{36})"
MIDRE = r"msg_[0-9a-f]{6,32}"
d = json.load(open(f))
rows = d["result"]["messages"] if d.get("ok") is True else sys.exit(1)
if not isinstance(rows, list):
    sys.exit(1)
subj = open(sf, encoding="utf-8", errors="replace").read()
body = open(bf, encoding="utf-8", errors="replace").read().rstrip()
me = me if re.fullmatch(r"term_[0-9a-f-]{36}|orca_session_id:[0-9a-f-]{36}", me) else ""

def when(s):
    for fmt in ("%Y-%m-%dT%H:%M:%SZ", "%Y-%m-%dT%H:%M:%S.%fZ", "%Y-%m-%d %H:%M:%S"):
        try:
            return calendar.timegm(time.strptime(s, fmt))
        except (TypeError, ValueError):
            pass
    return None

hits = []
for x in rows:
    if not isinstance(x, dict):
        continue
    t = when(x.get("created_at"))
    # 120 s of slack: Orca's clock is Windows', this script's is WSL's.
    if t is None or t < int(t0) - 120:
        continue
    # L89 a: a host's inbox names this sender `<handle> on <machine>`.
    fh = x.get("from_handle")
    if me and fh != me and not (on and isinstance(fh, str) and fh.startswith(me + " on ")):
        continue
    if not isinstance(x.get("body"), str) or x["body"].rstrip() != body:
        continue
    # A reply is read back only on the target's own thread id, never on its
    # root (PR #149 review): an earlier reply of this session to another
    # message of the same thread would match, and read as this one.
    if typ == "reply":
        if x.get("thread_id") != target:
            continue
    elif x.get("type") != typ or x.get("subject") != subj:
        continue
    if typ == "worker_done":
        try:
            p = json.loads(x.get("payload") or "")
        except (TypeError, ValueError):
            continue
        if not isinstance(p, dict) or p.get("dispatchId") != target[len("dispatch:"):] \
                or p.get("taskId") != task or p.get("outcome") != outcome:
            continue
    mid, to = x.get("id"), x.get("to_handle")
    # The recipient (PR #138 review): a term_ or run: target only as itself;
    # a dispatch: target also as another dispatch (L88 item 2: Orca rewrote it
    # to the follow-up dispatch). A reply and a worker_done are bound by
    # thread and payload above.
    if typ not in ("reply", "worker_done"):
        if target.startswith("dispatch:"):
            if not (isinstance(to, str) and to.startswith("dispatch:")):
                continue
        elif target.startswith("bot:"):
            # THE BOT ADDRESS: a chat or a Run (L104), which the caller pins
            # to the bot.
            if not (isinstance(to, str) and to.startswith(("orca_session_id:", "run:"))):
                continue
        elif to != target:
            continue
    if isinstance(mid, str) and re.fullmatch(MIDRE, mid) \
            and isinstance(to, str) and re.fullmatch(ADDR, to):
        seq = x.get("sequence")
        hits.append((seq if isinstance(seq, int) else 0, t, mid, to))
if not hits:
    sys.exit(1)
hits.sort()
print(hits[-1][2], hits[-1][3])
PY
}
# THE FOLLOW-UP CHAIN (punch-list L89 b; header). Proves that dispatch $1
# (the reply's `followUpOf`) is in the target's follow-up chain: each hop is
# `worker-show --dispatch <id>`, whose `result.dispatch.followUpOf` names the
# dispatch it followed up, until the walk reaches the target. On failure it
# sets cepa_send_chain_why and returns 1.
cepa_send_chain() {
  local x=$1 td=${cepa_send_target#dispatch:} hop seen=' ' nx
  local -a env=()
  cepa_send_chain_why="the follow-up names $1, and the follow-up chain of $cepa_send_target could not be read"
  cepa_send_where "$cepa_send_tmp/chain0.json" || return 1
  env=(${cepa_send_where_env[@]+"${cepa_send_where_env[@]}"})
  for hop in 1 2 3 4 5 6 7 8; do
    [ "$x" != "$td" ] || return 0
    case "$seen" in *" $x "*) cepa_send_chain_why="the follow-up chain of $cepa_send_target loops at $x"; return 1 ;; esac
    seen+="$x "
    cepa_send_orca "$cepa_send_tmp/chain.json" orchestration worker-show --dispatch "$x" \
      ${env[@]+"${env[@]}"} --json --full || return 1
    nx=$(python3 -I - "$cepa_send_tmp/chain.json" "$x" <<'PY' 2>/dev/null
import json, re, sys
d = json.load(open(sys.argv[1]))
r = d["result"] if d.get("ok") is True else sys.exit(1)
x = r.get("dispatch") if isinstance(r, dict) else None
if not isinstance(x, dict) or x.get("id") != sys.argv[2] or "followUpOf" not in x:
    sys.exit(1)
f = x["followUpOf"]
if f is None:
    print("END")
elif isinstance(f, str) and re.fullmatch(r"ctx_[A-Za-z0-9_-]{1,64}", f):
    print(f)
else:
    sys.exit(1)
PY
) || return 1
    if [ "$nx" = END ]; then
      cepa_send_chain_why="the follow-up names $1, which is not in the follow-up chain of $cepa_send_target"
      return 1
    fi
    x=$nx
  done
  [ "$x" != "$td" ] || return 0
  cepa_send_chain_why="the follow-up names $1, and the follow-up chain of $cepa_send_target is longer than 8 hops"
  return 1
}
# THE FOLLOW-UP RE-READ (punch-list L93 1; header). A plain send to a
# `dispatch:` target whose call failed (a timeout, or an exit with no reply)
# may have started a follow-up dispatch, which leaves no inbox row. This
# proves it from the owner of the target's terminal, read before the send
# (cepa_send_owner0) and again now: the owner changed, the new owner follows
# up the old one, and the old one is the target or in its follow-up chain.
# Prints `OK <new dispatch id>`, or `FAIL <reason>` and returns 1.
cepa_send_fresh() {
  local td=${cepa_send_target#dispatch:} o0 got nd e fu
  local -a env=()
  case "$cepa_send_owner0" in
    'OK '*) o0=${cepa_send_owner0#OK } o0=${o0%%$'\t'*} ;;
    *) echo "FAIL the terminal's owner before the send was not read"; return 1 ;;
  esac
  got=$(cepa_send_owner post)
  case "$got" in
    'OK '*) nd=${got#OK } e=${nd#*$'\t'} nd=${nd%%$'\t'*} ;;
    *) [ -n "$got" ] || got="FAIL the owner of the terminal could not be read"; echo "$got"; return 1 ;;
  esac
  [ "$e" = - ] || env=(--environment "$e")
  if [ "$nd" = "$o0" ]; then
    echo "FAIL the target's terminal is still owned by $o0, so no follow-up was seen"
    return 1
  fi
  cepa_send_orca "$cepa_send_tmp/fresh3.json" orchestration worker-show --dispatch "$nd" \
    ${env[@]+"${env[@]}"} --json --full || { echo "FAIL $nd could not be read"; return 1; }
  fu=$(python3 -I - "$cepa_send_tmp/fresh3.json" "$nd" <<'PY' 2>/dev/null
import json, re, sys
d = json.load(open(sys.argv[1]))
x = d["result"]["dispatch"] if d.get("ok") is True else sys.exit(1)
if not isinstance(x, dict) or x.get("id") != sys.argv[2]:
    sys.exit(1)
f = x.get("followUpOf")
# Compared with the old owner (a checked ctx_ id), never passed on.
print(f if isinstance(f, str) and "\n" not in f else "-")
PY
) || { echo "FAIL $nd could not be read"; return 1; }
  if [ "$fu" != "$o0" ]; then
    echo "FAIL the terminal's owner $nd does not follow up $o0, its owner before the send"
    return 1
  fi
  if [ "$o0" != "$td" ] && ! cepa_send_chain "$o0"; then
    echo "FAIL $cepa_send_chain_why"
    return 1
  fi
  echo "OK $nd"
}
case "$cepa_send_got" in
  'CHAIN '*)
    cepa_send_got=${cepa_send_got#CHAIN }
    # A failed walk may follow a follow-up Orca did start: a resend would
    # start another one (PR #143 review), so the reason says so.
    cepa_send_chain "${cepa_send_got#* }" \
      || unproven "$cepa_send_chain_why; a follow-up dispatch may already exist, so do not resend"
    echo "Orca send stored as a follow-up dispatch: ${cepa_send_got%% *} of $cepa_send_target, after ${cepa_send_got#* } in its follow-up chain (punch-list L89 b)"
    [ -z "$cepa_send_downgraded" ] \
      || echo "Orca nudge not needed: $cepa_send_target is a mailbox Orca delivers; sent as no-nudge"
    exit 0 ;;
esac
case "$cepa_send_got" in
  ''|'FAIL '*)
    cepa_send_why=${cepa_send_got#FAIL }
    [ -n "$cepa_send_why" ] || cepa_send_why="the send output could not be read"
    # Orca 1.4.280 refuses a terminal's reply to a message a bot sent
    # (`bot_reply_not_yours`, coord@main 2026-11-28, msg_ceda090dbc42): the
    # reason says how a bot is answered (punch-list L104).
    case "$cepa_send_why" in *'(bot_reply_not_yours)')
      fail "$cepa_send_why; a bot is answered with a send to bot:<name>, not a reply" ;; esac
    case "$cepa_send_why" in 'Orca did not return "ok": true'*) fail "$cepa_send_why" ;; esac
    # With no clock there is no window, so any older row would match.
    [ "$cepa_send_t0" != 0 ] || fail "$cepa_send_why"
    cepa_send_back=$(cepa_send_readback) || cepa_send_back=
    if ! [[ $cepa_send_back =~ ^msg_[0-9a-f]{6,32}\ (term_[0-9a-f-]{36}|run:[A-Za-z0-9_-]{1,64}|dispatch:[A-Za-z0-9_-]{1,64}|orca_session_id:[0-9a-f-]{36})$ ]]; then
      # L89 b (PR #142 review): a plain send to a dispatch may have started a
      # follow-up dispatch, which leaves no inbox row to read back, so it is
      # not proven either way; a rerun would start a second one. When the
      # call itself failed (L93 1: a host send exited 124, and was delivered),
      # THE FOLLOW-UP RE-READ looks for that dispatch first.
      if [[ $cepa_send_target == dispatch:* && $cepa_send_type != worker_done ]]; then
        if [ "$cepa_send_rc" != 0 ]; then
          cepa_send_new=$(cepa_send_fresh) || :
          if [[ $cepa_send_new == 'OK '* ]]; then
            echo "Orca send stored as a follow-up dispatch: dispatch:${cepa_send_new#OK } of $cepa_send_target, found by a re-read, though $cepa_send_why (punch-list L93)"
            [ -z "$cepa_send_downgraded" ] \
              || echo "Orca nudge not needed: $cepa_send_target is a mailbox Orca delivers; sent as no-nudge"
            exit 0
          fi
          cepa_send_new=${cepa_send_new#FAIL }
          unproven "$cepa_send_why; a re-read proved no follow-up ($cepa_send_new), but one may exist, so do not resend"
        fi
        unproven "$cepa_send_why"
      fi
      fail "$cepa_send_why"
    fi
    echo "Orca send read back: ${cepa_send_back%% *} is in the inbox from this send, though $cepa_send_why (punch-list L84)"
    cepa_send_got=$cepa_send_back
    # A worker_done also needs its lifecycle: the dispatch must have settled
    # the way the outcome asks.
    if [ "$cepa_send_type" = worker_done ]; then
      cepa_send_orca "$cepa_send_tmp/wshow.json" orchestration worker-show \
        --dispatch "${cepa_send_target#dispatch:}" --json --full \
        || unproven "Orca did not record the dispatch as $cepa_send_outcome"
      python3 -I -c '
import json, sys
d = json.load(open(sys.argv[1]))
st = d["result"]["dispatch"]["status"] if d.get("ok") is True else None
sys.exit(0 if st == sys.argv[2] else 1)
' "$cepa_send_tmp/wshow.json" "$cepa_send_outcome" 2>/dev/null \
        || unproven "Orca did not record the dispatch as $cepa_send_outcome"
    fi ;;
  'UNPROVEN '*) unproven "${cepa_send_got#UNPROVEN }" ;;
  'FOLLOWUP '*)
    # L89 b: Orca carried the message as a follow-up dispatch, so there is no
    # msg_ id to re-read. A dispatch mailbox is never nudged.
    echo "Orca send stored as a follow-up dispatch: ${cepa_send_got#FOLLOWUP } of $cepa_send_target (punch-list L89)"
    [ -z "$cepa_send_downgraded" ] \
      || echo "Orca nudge not needed: $cepa_send_target is a mailbox Orca delivers; sent as no-nudge"
    exit 0 ;;
esac
cepa_send_id=${cepa_send_got%% *}
cepa_send_to=${cepa_send_got#* }
[ -n "$cepa_send_to" ] && [ "$cepa_send_to" != "$cepa_send_got" ] || fail "the send output could not be read"
# THE REPLY THREAD (L97): a reply threaded on another message names that
# root third; the re-read proves it is the target's own thread.
cepa_send_root=
if [[ $cepa_send_to == *" "* ]]; then
  cepa_send_root=${cepa_send_to#* } cepa_send_to=${cepa_send_to%% *}
  [ "$cepa_send_type" = reply ] && [[ $cepa_send_root =~ ^msg_[0-9a-f]{6,32}$ ]] \
    || fail "the send output could not be read"
fi

# THE RE-READ.
cepa_send_orca "$cepa_send_tmp/inbox.json" orchestration inbox \
  ${cepa_send_env_args[@]+"${cepa_send_env_args[@]}"} --limit 200 --json --full \
  || fail "the inbox could not be re-read, so $cepa_send_id is unconfirmed"
cepa_send_q=
[ "$cepa_send_type" = reply ] && cepa_send_q=$cepa_send_target
python3 -I - "$cepa_send_tmp/inbox.json" "$cepa_send_id" "$cepa_send_to" "$cepa_send_q" \
  "$cepa_send_me" "$cepa_send_root" "$cepa_send_target" <<'PY' >/dev/null 2>&1
import json, re, sys
try:
    d = json.load(open(sys.argv[1]))
    rows = d["result"]["messages"] if d.get("ok") is True else []
    # Orca 1.4.246's concise inbox (no --full) names `to`, not `to_handle`
    # (L72): a row without `to_handle` is a shape this reader does not know,
    # never "not stored".
    if not isinstance(rows, list) or not all(isinstance(x, dict) and "to_handle" in x for x in rows):
        sys.exit(2)
    mine_rows = [x for x in rows if x.get("id") == sys.argv[2] and x.get("to_handle") == sys.argv[3]]
    found = bool(mine_rows)
    # THE BOT ADDRESS (L104): a bot: send stored for a run: counts only when
    # THIS row's payload carries Orca's own `botRequest` object. The payload
    # is parsed: the word in its text, the body or another row is not it.
    def botreq(x):
        try:
            p = json.loads(x.get("payload") or "")
        except (TypeError, ValueError):
            return False
        return isinstance(p, dict) and isinstance(p.get("botRequest"), dict)
    if found and sys.argv[7].startswith("bot:") and sys.argv[3].startswith("run:") \
            and not any(botreq(x) for x in mine_rows):
        sys.exit(5)
    # A reply answers the sender of the message it names. It came back here
    # when Orca addressed it to this session's handle, or when that message's
    # row is in the window and this session sent it.
    # me is cepa_send_me, already checked (a term_ handle, a chat's
    # orca_session_id:, or empty).
    q, me, root = sys.argv[4], sys.argv[5], sys.argv[6]
    mine = bool(q and me) and (sys.argv[3] == me or any(
        isinstance(x, dict) and x.get("id") == q and x.get("from_handle") == me for x in rows))
    # THE REPLY THREAD (L97): the question's own row names that root.
    threaded = not root or any(isinstance(x, dict) and x.get("id") == q and x.get("thread_id") == root
                               for x in rows)
except Exception:
    sys.exit(2)
sys.exit(1 if not found else 3 if mine else 4 if not threaded else 0)
PY
case $? in
  0) ;;
  3) echo "Orca reply misaddressed: $cepa_send_id stored for $cepa_send_to, but $cepa_send_target was sent by this session, so the reply came back to it"
     echo "Ending first line: Needed from you: check which session asked $cepa_send_target"
     exit 1 ;;
  1) fail "$cepa_send_id is not in the inbox for $cepa_send_to" ;;
  4) unproven "the reply is threaded on $cepa_send_root, and the re-read does not show $cepa_send_target in that thread" ;;
  5) unproven "$cepa_send_id is stored for $cepa_send_to without Orca's bot request, so it is not proven a send to $cepa_send_target" ;;
  *) fail "the inbox could not be parsed, so $cepa_send_id is unconfirmed" ;;
esac
# THE BOT ADDRESS (L104): a send stored for a Run counts only when that Run
# has no terminal coordinator and the bot has an open Home chat. The Run's
# tie to the bot is Orca's own routing (header): no Orca read names it.
if [[ $cepa_send_target == bot:* && $cepa_send_to == run:* ]]; then
  cepa_send_orca "$cepa_send_tmp/botrun.json" orchestration run-show --id "${cepa_send_to#run:}" --json --full \
    || unproven "the Run ${cepa_send_to#run:} could not be read, so $cepa_send_id is not proven a send to $cepa_send_target"
  python3 -I - "$cepa_send_tmp/botrun.json" "${cepa_send_to#run:}" <<'PY' >/dev/null 2>&1
import json, sys
# Exit 1: the Run was read whole and has a coordinator, or another id. Any
# other answer is unreadable (2).
try:
    d = json.load(open(sys.argv[1]))
    r = d["result"]["run"] if isinstance(d, dict) and d.get("ok") is True else None
    if not isinstance(r, dict) or "coordinator_handle" not in r:
        sys.exit(2)
    ok = r.get("id") == sys.argv[2] and r["coordinator_handle"] is None
except Exception:
    sys.exit(2)
sys.exit(0 if ok else 1)
PY
  case $? in
    0) ;;
    1) unproven "$cepa_send_id is stored for $cepa_send_to, a Run with a terminal coordinator, so it is not proven a send to $cepa_send_target" ;;
    *) unproven "the Run ${cepa_send_to#run:} could not be read, so $cepa_send_id is not proven a send to $cepa_send_target" ;;
  esac
  cepa_send_orca "$cepa_send_tmp/chats.json" bot chats --bot "${cepa_send_target#bot:}" --json \
    || unproven "the chats of $cepa_send_target could not be read, so $cepa_send_id is unconfirmed"
  python3 -I - "$cepa_send_tmp/chats.json" "${cepa_send_target#bot:}" <<'PY' >/dev/null 2>&1
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    r = d["result"] if isinstance(d, dict) and d.get("ok") is True else None
    if not isinstance(r, dict) or r.get("bot") != sys.argv[2] or not isinstance(r.get("chats"), list):
        sys.exit(2)
    hit = any(isinstance(c, dict) and c.get("home") is True and c.get("closed") is False for c in r["chats"])
except Exception:
    sys.exit(2)
sys.exit(0 if hit else 1)
PY
  case $? in
    0) ;;
    1) unproven "$cepa_send_id is stored for $cepa_send_to, but $cepa_send_target has no open Home chat" ;;
    *) unproven "the chats of $cepa_send_target could not be read, so $cepa_send_id is unconfirmed" ;;
  esac
# THE BOT ADDRESS: the chat Orca stored it for must be one of the bot's.
elif [[ $cepa_send_target == bot:* ]]; then
  cepa_send_orca "$cepa_send_tmp/chats.json" bot chats --bot "${cepa_send_target#bot:}" --json \
    || unproven "the chats of $cepa_send_target could not be read, so $cepa_send_id is unconfirmed"
  python3 -I - "$cepa_send_tmp/chats.json" "${cepa_send_target#bot:}" "${cepa_send_to#orca_session_id:}" <<'PY' >/dev/null 2>&1
import json, sys
# Exit 1 only for a list read whole that holds no such open chat; any
# other answer is unreadable (2), never "not the bot's".
try:
    d = json.load(open(sys.argv[1]))
    r = d["result"] if isinstance(d, dict) and d.get("ok") is True else None
    if not isinstance(r, dict) or r.get("bot") != sys.argv[2] or not isinstance(r.get("chats"), list):
        sys.exit(2)
    hit = any(isinstance(c, dict) and c.get("id") == sys.argv[3] and c.get("closed") is False for c in r["chats"])
except Exception:
    sys.exit(2)
sys.exit(0 if hit else 1)
PY
  case $? in
    0) ;;
    1) unproven "$cepa_send_id is stored for $cepa_send_to, which is not an open chat of $cepa_send_target" ;;
    *) unproven "the chats of $cepa_send_target could not be read, so $cepa_send_id is unconfirmed" ;;
  esac
fi

echo "Orca send stored: $cepa_send_id for $cepa_send_to"
# Delivered (Builder-check 4): the outbox file moves to delivered/, named
# with the handle it went to, so a new coord@main's drain can show it when
# that handle is gone (#10).
if [ -n "$cepa_send_obox" ]; then
  cepa_send_n=${cepa_send_obox##*/}
  # A bot (THE BOT FIRST) is woken by Orca, so no drain owes it: `.drained`.
  cepa_send_dn=${cepa_send_n%.md}.to-$cepa_send_target.md
  [[ $cepa_send_target != bot:* ]] || cepa_send_dn=${cepa_send_n%.md}.drained.md
  if ( umask 077 && mkdir -p "${cepa_send_obox%/*}/delivered" ) 2>/dev/null \
      && mv -f "$cepa_send_obox" "${cepa_send_obox%/*}/delivered/$cepa_send_dn" 2>/dev/null; then
    echo "Orca outbox: delivered: $cepa_send_coord/delivered/$cepa_send_dn"
  else
    echo "Orca outbox: could not mark delivered; still pending: $cepa_send_coord/$cepa_send_n (a drain may show it again)"
  fi
fi
if [ "$cepa_send_type" = reply ]; then
  [ "$cepa_send_mode" = nudge ] || exit 0
  # A chat's own address (L98): no script can nudge a chat, and whether
  # Orca wakes a chat that has no Run is not measured (header), so the
  # delivery is not claimed.
  if [[ $cepa_send_to == orca_session_id:* ]]; then
    echo "Orca nudge skipped: Orca stored it for $cepa_send_to, a chat; whether Orca wakes it is not measured"
    echo "Ending first line: Needed from you: tell $cepa_send_to to check its Orca inbox"
    exit 1
  fi
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
# A host worker's terminal (L88) is not in this machine's worktree ps, where
# orca-nudge.sh finds the row it guards on, so it is never nudged from here.
# Nor does it need it (L89 a, orca-lab's re-measure of cepa 1.60.0, sender report):
# the host Orca prompted its worker itself, which read the message and
# replied. A row stored for another handle still takes the skip below.
if [ -n "$cepa_send_on" ] && [ "$cepa_send_mode" = nudge ] && [ "$cepa_send_to" = "$cepa_send_target" ]; then
  echo "Orca nudge not needed: $cepa_send_target is on Orca server $cepa_send_on, which prompts its own worker (punch-list L89 a)"
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
  cepa_send_alert nudge_skipped "orca-nudge.sh not found beside orca-send.sh"
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
  # L65: a nudge that did not run to a decision leaves an alert, so
  # orca-health.sh shows the unread message even when the session drops its
  # ending line. Only a skip on the target's own row (busy, asking, gone, or
  # two rows) is a normal skip and writes none; every other skip or failure
  # (a failed or timed-out Orca call, output it could not read, a missing
  # tool) writes one. orca-health.sh shows only reasons in its REASONS list.
  case "$cepa_send_line" in
    "Orca nudge skipped: the target is "* | "Orca nudge skipped: the target has no agent row" \
    | "Orca nudge skipped: the target matches "* | "Orca nudge skipped: the target state is unknown") ;;
    "Orca nudge skipped: "* | "Orca nudge failed: "*)
      cepa_send_alert nudge_skipped "${cepa_send_line#Orca nudge *: }" ;;
  esac
done <<<"$cepa_send_nout"
# A nudge that printed nothing gave the session no line to end on: it may
# have died on a syntax error or `set -u` (PR #110 review). Not delivered.
if [ "$cepa_send_nrc" -le 3 ] && [ -z "$cepa_send_nout" ]; then
  echo "Orca nudge skipped: orca-nudge.sh exited $cepa_send_nrc and printed nothing"
  cepa_send_alert nudge_skipped "orca-nudge.sh exited $cepa_send_nrc and printed nothing"
  echo "Ending first line: Needed from you: tell $(cepa_send_who "$cepa_send_target") to check its Orca inbox"
  exit 1
fi
if [ "$cepa_send_nrc" -gt 3 ]; then
  echo "Orca nudge skipped: orca-nudge.sh would not start (exit $cepa_send_nrc)"
  cepa_send_alert nudge_skipped "orca-nudge.sh would not start (exit $cepa_send_nrc)"
  echo "Ending first line: Needed from you: tell $(cepa_send_who "$cepa_send_target") to check its Orca inbox"
  exit 1
fi
exit "$cepa_send_nrc"
