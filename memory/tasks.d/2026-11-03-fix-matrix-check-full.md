# Residuals — fix/matrix/check-full (punch-list L73)

Closes item 1 of `memory/tasks.d/2026-11-02-fix-roles-orca-full-reads.md`
(#131 finding 4: `check` rows not measured; rules 5/8 and the nudge text
passed no `--full`). Measurement: `cepa:autonomy` §12b rule 8, the
**Every `check` passes `--full`** bullet.

## Undone items (2026-11-03)

1. [P3] The FULL leg of `scripts/check-orca-turn-endings.sh` cannot see a
   bare `` `check` `` span that lost `--full` (prose references use the same
   span). PEEK_HAS pins the two bare-`check --full` sentences rule 8 has
   today; a new one is pinned only if someone adds it there.
2. [P3] Rule 8's drain still runs `check --ack <deliveryId> --full` after a
   `check --full` that Orca 1.4.246 already marked acknowledged
   (`deliveryAcknowledged: true`; the `--ack` answer says it is not needed).
   Kept as a no-op for older Orca. Drop it once no 1.4.245 is in use.
3. [P3] The no-bound-Run paragraph of rule 8 rests on the L35 measurement
   on Orca 1.4.245. This run could not re-measure it on 1.4.246: the
   measuring session was bound to a Dispatch.
4. [P3] The operator's `~/.claude/CLAUDE.md` tells a session to run
   `orca-ide orchestration check --peek --format --json`. It needs `--full`
   too. That file is the operator's, outside this repo.
5. [P2] Rule 8's drain loses a batch whose output is lost on Orca 1.4.246:
   the drain marks the batch read itself. The stated limit now says so.
   Whether every session should process from its peek first (as a session
   with no bound Run does) is a rule change, left to the coordinator.
   #132 review, adversarial finding 1 (judgment).
6. [P3] Whether Orca 1.4.245 accepts `--full` on `check` was not measured
   (none at hand). Item 2 assumes 1.4.245 is still in use: measure it, or
   state one support floor. #132 review, adversarial finding 3.
7. [P3] The fixture's `check` verb is not exercised by any checker case
   (no script runs `check`). #132 review, test finding 4.
