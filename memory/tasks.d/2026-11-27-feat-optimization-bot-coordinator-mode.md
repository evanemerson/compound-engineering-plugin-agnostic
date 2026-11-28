# Residuals — feat/optimization/bot-coordinator-mode (punch-list L100, L102, L103 C4 + C6, tab49 residual 1)

Worker: tab54@optimization (task_3801551632a7). coord@main owns the punch list;
this shard holds what this branch did not close.

Closed here, for coord@main's fold: tab49's
`2026-11-27-rebind-null-holder.md` item 1 (orca-health.sh reads a null holder
as a known shape and raises `unbound` for it from a terminal), and tab50's
`2026-11-27-fix-optimization-send-bot-addressing.md` item 3 (a chat's alert
and outbox files now record `orca_session_id:<id>`, and both readers take it).

## Probe list for orca-lab (not measurable from a terminal worker)

Each is stated in the script header named beside it. Expected results are
what cepa 1.62.0 prints.

1. [P2] Health from a bot home. In `orca-lab-bot`'s chat (cwd
   `~/.orca/bots/orca-lab-bot`), run rule 8's health block with no Run line.
   Expected: `run-current` is read with no `orca-unreadable:run-current`; the
   bot's Run (`coordinator_handle: null`) is checked (`ORCA health: ok — Run
   <run> checked`, or its workers' alerts); only `orca-lab` alert files show
   (repo from the home name `orca-lab-bot`); no own-question-off note.
   — `plugins/cepa/scripts/orca-health.sh` (BOT MODE)
2. [P2] Outbox from a bot home: rule 8's drain block in the same chat.
   Expected: `ORCA outbox: none for coord:orca-lab` or the pending files;
   never `not inside a git checkout`. — `orca-outbox.sh` (BOT MODE)
3. [P2] Re-bind from a chat: rule 2's re-bind block with the bot's own Run
   as `run:`. Expected `ORCA rebind: ok — <run> is this chat's Run …`, exit
   0, and no `run-use` call. — `orca-rebind.sh` (THE CHAT)
4. [P2] Not measured: whether a restarted bot (a new Home chat) still gets
   its old Run from `run-current`. If not, the re-bind block asks, naming
   the old Run, and the bot creates a new one. Measure: note the Run id,
   start a new chat of the bot (`bot new-chat` or a restart), run
   `orchestration run-current --json --full` there. — `orca-rebind.sh`
   (THE CHAT)
5. [P2] Not measured: `run-use --id <run>` from a chat (does it bind, raise
   `consumer_generation`, set `coordinator_handle`?). cepa never calls it
   from a chat today; a measured result could let a bot re-take its own Run
   after a restart. Use a throwaway Run. — `orca-rebind.sh` (THE CHAT)
6. [P3] Not measured: which mailbox `orchestration inbox --limit 200 --json
   --full` lists from a chat (the whole store, as from a terminal, or only
   the chat's Run). The `question:` and `awaited:` alerts assume the whole
   store. — `orca-health.sh` (BOT MODE)
7. [P3] Not measured: whether `run-current` from a chat can report another
   chat's Run. Health and rebind trust it as the chat's own.
   — `orca-health.sh`, `orca-rebind.sh`

## Undone items (2026-11-27)

8. [P3] A repo-less outbox file (`repo=unknown`, a `coord:` send from a bot
   or chat with no checkout) still counts in every coordinator's
   `outbox:<repo>:<newest>` alert, acked per worktree. L100's rule (show to
   the session it names; one shared ack) covers alert files only. A bot's
   `coord:` send could record its repo from the bot home name, as health
   and the drain now read it. — `orca-send.sh` outbox write, `orca-health.sh`
   section 1b
9. [P3] A repo-less alert file that names a session no coordinator runs as
   waits one hour unseen before every coordinator sees it (stated in the
   health header). A liveness read of the named session would shorten it.
   — `orca-health.sh` (THE REPO-LESS FILE)
10. [P3] From a chat, a named Run with a null holder raises no `unbound`:
   Orca records no chat as a holder, so another chat's Run reads the same.
   — `orca-health.sh` (STATED LIMITS)
11. [P3] A stale worker's commit read (LIFE) needs `git worktree list` of the
   repo; a bot home has none, so a bot's stale alerts read `commit unread`.
   `git -C <lane>` from the worker's `terminal.worktreePath` would cover it.
   — `orca-health.sh` `worktree_refs()`
12. [P3] Bot mode trusts the bot home's name: a bot named `<repo>-bot` reads
   `<repo>`'s alerts and drains `coord:<repo>`. Every session runs as one
   user, so this is a claim, as a checkout's directory name is.
   — `orca-outbox.sh` (STATED LIMITS)

## Deferred from the PR #153 review (todos/review-2026-11-28-005445-feat-optimization-bot-coordinator-mode.md)

13. [P2] The L100 one-hour wait can hide a repo-less `send_failed` file that
   names a session which already ended from the coordinator that needs it.
   Options: wait only for `nudge_skipped`, or drop the wait and keep the
   shared ack. L100's design choice; coord@main decides. (finding 6)
   — `plugins/cepa/scripts/orca-health.sh` section 1
14. [P2] A chat's `ok` (rebind) and own-Run check (health) trust that a
   chat's run-current reports only its own Run; probe 7 measures it.
   (finding 7) — `plugins/cepa/scripts/orca-rebind.sh` THE CHAT
15. [P3] The rule 8 health and drain blocks have no placeholder line for a
   bot's `repo:`; it is given in rule 9's prose only. Adding one needs the
   BLOCK and HEALTHBLOCK legs changed with it. (finding 13)
   — `plugins/cepa/skills/autonomy/SKILL.md` rule 8
16. [P3] For coord@main's fold: L103 C4's text ("shows every repo's alerts")
   is orca-lab's M6 observation. This branch shows only the named repo's
   files, and alerts `orca-unreadable:repo` when it names none. orca-lab's
   C4 re-measure should expect that. (finding 14)
   — `memory/tasks.d/2026-10-02-punch-list.md` L103
17. [P3] A no-repo session skips unknown-shape outbox entries and prints a
   plain `ok` when no named-repo file exists, so a forgotten `repo:` stays
   invisible. (finding 15) — `plugins/cepa/scripts/orca-health.sh` section 1b
18. [P3] The bot-home rule depends on HOME and on the bot home not being
   inside a git checkout; say which repo was derived and how in the
   summary. (finding 16) — `plugins/cepa/scripts/orca-health.sh` BOT MODE
19. [P3] Case gaps: a chat's own repo-less failed send seen from a no-repo
   session; a stale worker's commit read from a bot home; a bot home
   through a symlink or a 101-character name; `term_x` beside a chat
   identity in health; a shared ack marker that cannot be written.
   (finding 18) — `scripts/check-orca-nudge.sh` HEALTH
