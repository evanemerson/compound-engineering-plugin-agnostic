# Residuals — fix/formulation/gate-release-early (punch-list L70 items 2-4)

Closes items 2, 3 and 4 of
`memory/tasks.d/2026-11-02-fix-roles-gate-build-outside-lock.md` (operator
decision dated 2026-11-28 in the punch list, recorded in the punch list's L70). The gate header
(`plugins/cepa/scripts/stack-gate.sh`) owns the contract; this shard owns
only what is left.

## Undone Items from fix/formulation/gate-release-early (2026-11-27)
1. [P3] The build lock has no holder file. A `STACK build: refused — lock
   busy` still names no holder, and a build waits far longer (3600 s) than a
   start. The start lock's holder functions could take a lock path. Not in
   the operator's item 4, which names the gate lock.
2. [P3] The `depends_on` health wait still runs under the start lock. It
   cannot be split from `up -d` (the measurement and the missing flag are
   in the gate header, L70 item 2). A repo whose health check has a long interval times
   retries can still push a late lane toward `lock_wait_seconds`. Choices if
   it bites: a shorter health check in the repo, or `up -d --no-build` on the
   leaf services only, then the dependents after the gate (changes what
   "the start" means).
3. [P3] A refused setup now leaves the lane's `.env` (Setup step 3 writes
   it before the gate, because the gate covers only the start). The refused
   path re-creates the lane, so nothing reads it. Stated in the skill, not
   handled.
4. [P3] Existing lanes' repo `worktree-init` targets still run migrations
   under the gate until each repo adopts the new Setup block. No repo is
   changed here (cross-repo rule): each repo's coord@main brings its
   `worktree-init` onto the block, checked by first-prompt step 2.
5. [process] /cepa:plan-review was not run: the operator fixed the design
   (all three choices) before dispatch, so the plan held no open judgment.
   The plan stays local (`docs/` is gitignored).

## Deferred review findings (PR #151, `todos/review-2026-11-27-220313-fix-formulation-gate-release-early.md`)
6. [P3] `--pull` has no time limit: a stalled registry blocks `make up` and an unattended setup with no alert (no lock is held, so other lanes are unaffected). Choice: a `pull_wait_seconds` key and `timeout` around the pull. `plugins/cepa/scripts/stack-gate.sh` cepa_sg_pull_mode. Finding #18.
7. [P3] `--pull` pulls every service, while a repo's setup may start only a subset: an image the start never needs, but cannot pull, now fails setup. Choice: pass services through, or state that `--pull` is all-services. Same function. Finding #19.
8. [P3] A failed `lane_env` or `lane_isolation` makes the Setup trap print "stop $PROJECT by hand" for a stack that never started (compose cannot load the project). The exit code stays right. Choice: run the stop only once the gate was called. `plugins/cepa/skills/lane-stack/SKILL.md` Setup block. Finding #20.
9. [P3] A skipped `--pull` (failed `pull --help`) drops the reason (a bad `-f`, a dead daemon, a timeout all print one line). Choice: keep the first stderr line in the skip message. `stack-gate.sh` cepa_sg_pull_mode. Finding #21.
10. [P3] The skill and the `make up` text do not say that a skipped pull means the start pulls under the lock again; only the gate header does. Finding #22.
11. [P3] Test gaps: the stale-holder case reads stdout only (the waiting line is stderr); no case holds the build lock against `--pull`; no help text with the flags only as substrings; no `pull --help` hang case; no check that the holder file is gone after a failing command. `scripts/check-stack-gate.sh` PULL and HOLDER legs. Finding #23.

