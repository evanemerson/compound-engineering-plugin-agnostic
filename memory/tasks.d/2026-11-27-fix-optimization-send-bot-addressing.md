# Residuals — fix/optimization/send-bot-addressing (punch-list L97, L98, L103 C1–C2)

Worker: tab50@optimization (task_7bbef425c1d3). coord@main owns the punch list;
this shard holds what this branch did not close.

## Undone items (2026-11-27)

1. [P2] Not measured: the `orchestration send` reply's own
   `result.message.to_handle` for a `bot:<name>` target. No test send was made
   (it wakes the bot). orca-send.sh counts a bot send only when that field is
   an `orca_session_id:` that `bot chats --bot <name> --json` lists as an open
   chat of the bot; any other shape is `not proven stored` (exit 5, never
   lost). orca-lab's C1 re-measure (send to `bot:orca-lab-bot`) settles it.
   Inbox rows read 2026-11-27 (Orca 1.4.280) do carry that form.
2. [P3] Not measured: whether Orca wakes a chat that owns no Run when a reply
   is stored for its `orca_session_id:` address. The script prints `Orca
   nudge not needed` for it, as for any non-term_ mailbox. orca-lab's P2d
   measured the wake only for a chat WITH a Run.
3. [P3] A chat sender's alert and outbox files still record `sender=unknown`:
   orca-health.sh reads only `term_…|unknown` there. Recording
   `orca_session_id:<id>` needs both readers changed; part of L103 C4 (bot
   mode for health and the outbox).
4. [P3] Only `bot:<name>` is accepted, not Orca's `bot:<id>` form, and a
   paused bot named `<repo>-bot` still wins the `coord:` resolve (its mail
   waits in Orca). Neither was needed for C1–C2.
5. [P3] A reply to a reply whose question row is outside the 200-row inbox
   window stays `not proven stored` (stated in the script header, THE REPLY
   THREAD). A larger window, or an Orca read of one message by id, would
   close it; no such read exists on 1.4.280 (`orchestration --help`).
