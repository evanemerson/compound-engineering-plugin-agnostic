# Residuals — fix/plugin-root-unset-in-dispatched-shell

## 2026-09-25

1. **`cepa:brain` SKILL.md should own "a resolution failure is not an outage"**
   — P3, judgment, from PR #69's architecture review.
   `plugins/cepa/skills/brain/SKILL.md:55-75` (the "Availability + degrade"
   section) is the contract owner for the `fresh | degraded | unavailable`
   status vocabulary, but says nothing about a plugin-root resolution failure
   being a distinct case that must NOT produce `degraded` or `unavailable`.
   PR #69 stated that rule at four sites instead
   (`commands/compound.md`, `commands/compound-refresh.md`,
   `commands/setup.md`, and `scripts/resolve-plugin-root.sh`'s stderr).

   Deferred from #69 deliberately, not forgotten. Two of those four copies are
   *instantiations* — executable guards sitting next to the call they protect —
   which `docs/solutions/logic-errors/cross-cutting-policy-must-be-cited-once-not-restated-at-every-site.md`
   explicitly carves out from the consolidate rule ("a guard replaced by a
   pointer to a guard stops guarding"). So the residual is NOT "delete the
   duplication"; it is specifically: extend the skill's `status:` vocabulary to
   name resolution failure as its own condition, then reduce the two PROSE
   copies (compound-refresh.md, setup.md) to citations while leaving the two
   executable guards in place.

   Scoped out of #69 because it changes the brain contract every consumer
   reads, which a path-resolution bugfix should not do silently.

   Filed by: `/cepa:review` on PR #69 (see
   `todos/review-2026-09-25-193000.md`, finding 7).
