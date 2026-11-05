# Residuals — fix/optimization/setup-timeout-gate-pull-only (punch-list L78, L75)

## Undone items (2026-11-05)

1. [P3] `cepa:autonomy` §12b rule 2 and the `create` success line in
   `plugins/cepa/scripts/orca-lane.sh` say "read the Setup tab" with no wait.
   Both should cite lane-stack's "Reading the `Setup` tab". Not edited here:
   tab3@matrix had those files open. Probe:
   `git grep -n -i 'setup. tab' -- plugins/cepa/skills/autonomy/SKILL.md plugins/cepa/scripts/orca-lane.sh`.
2. [P3] The global CLAUDE.md "New lane" text also says "read the lane's Setup
   tab". It is outside this repo: operator's file.
3. [P3] The Setup terminal's `title` in `orca-ide terminal list` is not
   measured: no real `create` ran. Record it the next time a lane is made,
   then tighten the lane-stack step. The 5-minute bound rests on one
   measurement (about 2 minutes, porch).
4. [P3] A project with no `build:` section at all still runs a no-op
   `compose build` under the build lock. Kept on purpose: an empty list stays
   a build (safe failure). `plugins/cepa/scripts/stack-gate.sh`.
5. [P3] Telling each repo's coord@main to check `worktree-init` for `timeout`
   is coord@main's job after the merge (L78 item 1).
