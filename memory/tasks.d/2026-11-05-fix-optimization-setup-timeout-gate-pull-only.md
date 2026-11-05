# Residuals — fix/optimization/setup-timeout-gate-pull-only (punch-list L78, L75)

## Undone items (2026-11-05)

1. [P3] `cepa:autonomy` §12b rule 2 and the `create` success line in
   `plugins/cepa/scripts/orca-lane.sh` say "read the Setup tab" with no wait.
   Both should cite lane-stack's "Reading the `Setup` tab". Not edited here:
   tab3@matrix had those files open. Probe:
   `git grep -n -i 'setup. tab' -- plugins/cepa/skills/autonomy/SKILL.md plugins/cepa/scripts/orca-lane.sh`.
2. [P3] The global CLAUDE.md "New lane" text also says "read the lane's Setup
   tab". It is outside this repo: operator's file.
3. [P3] The Setup terminal's `title`, its end-of-setup signal (the shell
   prompt returning) and the 15-minute quiet bound are not measured: no real
   `create` ran. Record them the next time a lane is made, then tighten the
   lane-stack step. The 5-minute bound rests on one measurement (about 2
   minutes, porch).
4. [P3] #136 review finding 5: a failed read prints one message for every
   cause, and both stderr streams are dropped. This also moves
   `memory/tasks.d/2026-11-02-fix-roles-bounded-builds.md` item 3: the
   `config --images` probe it names is now
   `config --no-env-resolution --format json | python3`.
   `plugins/cepa/scripts/stack-gate.sh`.
5. [P3] Telling each repo's coord@main to check `worktree-init` for `timeout`
   is coord@main's job after the merge (L78 item 1).
6. [P3] #136 review finding 6: `--foreground` signals only the direct child,
   so a compose descendant could hold the read's pipe past 60 s. Not confirmed
   for `docker compose`. Measure it first. `stack-gate.sh`, `cepa_sg_images_exist`.
7. [P3] #136 review finding 9: "SETUP examples run no bare timeout" reads only
   yaml and make fences, and any `-T` plus `</dev/null` on a line passes.
   `scripts/check-lane-stack.sh`.
8. [P3] #136 review finding 10: no targeted mutant for `c["name"]` and
   `c["services"]`. The proposed `.get` mutants still build by another path, so
   they would stay green. `scripts/check-stack-gate-controls.sh`.
