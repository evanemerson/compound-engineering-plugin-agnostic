# Residuals — fix/formulation/gate-release-early (punch-list L70 items 2-4)

Closes items 2, 3 and 4 of
`memory/tasks.d/2026-11-02-fix-roles-gate-build-outside-lock.md` (operator
decision 2026-11-28, recorded in the punch list's L70). The gate header
(`plugins/cepa/scripts/stack-gate.sh`) owns the contract; this shard owns
only what is left.

## Undone Items from fix/formulation/gate-release-early (2026-11-27)
1. [P3] The build lock has no holder file. A `STACK build: refused — lock
   busy` still names no holder, and a build waits far longer (3600 s) than a
   start. The start lock's holder functions could take a lock path. Not in
   the operator's item 4, which names the gate lock.
2. [P3] The `depends_on` health wait still runs under the start lock. It
   cannot be split from `up -d` (measured in the gate header: 14.9 s with a
   `service_healthy` dependency, 2.4 s with `service_started`; no `up` flag
   skips a condition). A repo whose health check has a long interval times
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
