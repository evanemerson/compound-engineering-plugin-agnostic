# Residuals — fix/matrix/orca-cli-path-stale-alerts (2026-11-05)

Worker tab3@matrix, punch-list L81 and L82. coord@main owns the punch list, so
these lines stay here until it reads them.

1. [L81 item 2, out of scope, not resolved] `coordinator_handle: null` on
   `orca serve`. Nothing was learned here: no serve host is at hand, and the
   code path was not read. orca-health.sh still treats a null holder as "not
   raised" (`isinstance(holder, str)`), and its `run-current` reader exits 1 on
   a non-string holder, which reads as `orca-unreadable:run-current`. So a
   coordinator on `orca serve` with no named Run would see that alert.
   Unverified: read from the script only, never run against a serve host.
2. [L81, unmeasured] The two Linux paths come from punch-list L81 and from Orca
   1.4.249's installed code (`resources/app.asar.unpacked/out/main/chunks/
   agent-session-operation-ledger-*.js`: `linux-orca-cli-shim`, `[cli, bin]`;
   app.asar's `PCt` launcher writer). No run on a Linux Orca host: the gate uses
   planted stubs of the same shape. The first real Linux session should run
   §12a and report `ORCA: present`.
3. [L81 limit] A command that declares `allowed-tools` grants the `orca-ide`
   forms only (§12a's stated limit), so on Linux such a command still reads
   absent. Not changed here.
4. [L81 item 3, confirmed by source only] Rule 3 now states the follow-up.
   Evidence: Orca 1.4.249 `orcad-migration-source-retention-*.js` (`Hft`:
   `getUnreadMessages("dispatch:<id>")`, a follow-up with body "You have new
   orchestration messages", and "its follow-up reported without reading the
   mail it was started for"), and `skills get orchestration --full` ("a
   finished or closed one gets it as a follow-up Task"). Not measured on a live
   worker: that needs a real dispatch to settle with mail waiting. The sender's
   source name `settled-worker-follow-through.ts` was not seen; the bundle is
   minified.
5. [L82 limit] Terminal output proves drawing, not progress: an agent hung
   inside a turn whose timer redraws reads as live until `long:` at 180
   minutes. Stated in the script's header. If that proves too weak, the second
   shape needs its own decision.
6. [L82, untested] The 10-second total git budget in orca-health.sh has no
   control: a test needs more than 10 real seconds per mutant. The 3-second
   wait and the stop after a timeout are controlled.
