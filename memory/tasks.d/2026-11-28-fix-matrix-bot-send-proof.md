# Residuals — fix/matrix/bot-send-proof (punch-list L104)

Worker: tab55@matrix (task_7ce1d9e8b21d). coord@main owns the punch list;
this shard holds what this branch did not close.

## Undone items (2026-11-28)

1. [P2] STATED GAP: no Orca 1.4.280 read ties a `run:<id>` to a bot. A
   bot send stored for a Run counts on Orca's own routing (the row's
   `botRequest` payload), plus that Run having no terminal coordinator and
   the bot having an open Home chat (coord@main chose this, option A,
   msg_0ae56781f0c4). Fields read and found lacking: `bot list`, `bot chats
   --json`, `run-show`, `run-list`, `run-current --from orca_session_id:`
   (refused: `session_caller_chat_not_declarable`), `~/.orca/bots/<name>/bot.json`.
   An Orca field that names a bot's Run (or a chat's bound Run) would close
   it: ask upstream, or re-check on each Orca upgrade.
2. [P3] Still not measured: the `orchestration send` reply's own
   `result.message.to_handle` for a `bot:` target (#149's item 1). No test
   send was made: `bot create` makes a bot only when its owner accepts a
   card, so there was no bot of this worker's own to send to. Both stored
   forms are now accepted; orca-lab's re-measure settles which the reply
   carries.
3. [P3] Measured 2026-11-28: a bot's Home chat bound to a Run gets mail in
   `run:<id>` (orca-lab-bot), and one with no Run in `orca_session_id:<chat>`
   (fleet). When Orca binds or unbinds that Run is not measured; the script
   takes either form.
