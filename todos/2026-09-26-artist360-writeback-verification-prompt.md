# Hand-off: verify brain writeback from artist360

**Why this is a hand-off and not a completed task.** Running `/cepa:compound`
in artist360 means executing commands with that repo as the working directory,
which the global CLAUDE.md prohibits — the rule draws its line at the
*directory*, not the verb, and the stated cost is a blocked human for days. So
this session verified the full writeback cycle from `compound-engineering`
instead (which is also a brain participant, so it exercises the identical code
path) and left the artist360 run to a session invoked there.

## What is already proven (2026-09-26, from compound-engineering)

Using the **installed** plugin at `~/.claude/plugins/marketplaces/cepa`
(v1.26.4), with `CLAUDE_PLUGIN_ROOT`, `CEPA_PLUGIN_ROOT`, and `CEPA_DEV` all
unset — i.e. exactly the conditions that produced rc=127 before the fix:

| Step | Result |
|---|---|
| Resolver | `CEPA_ROOT=~/.claude/plugins/marketplaces/cepa/plugins/cepa` |
| `health` | rc=0, `{"ok":true,"service":"agent-memory-api","version":"0.1.0"}` |
| `participants` | rc=0, 5 active repos |
| `idkey` | `compound-engineering:…cross-cutting-policy…md:61ae55852bda` |
| `writeback` | rc=0, **9 rows** (2 lessons + 3 constraints + 4 failures) |
| `review … evidence_only` | **9 of 9 promoted** |
| `recall` | 10 items, **including 2 rows written minutes earlier** |
| Re-post identical payload | same 9 ids, **0 new rows** — idempotent |

The recall also returned `c641883e`, artist360's own 2026-08-09 memory stating
this same root cause, via `scope.project_only: false`. Cross-repo recall works.

So: transport, credentials, envelope, promote, recall visibility, and
idempotency are all verified. What is NOT verified is `/cepa:compound`'s own
orchestration in artist360 — its doc selection, payload assembly, and PHI
posture on a repo with a `## Compliance` section.

## The one thing to watch for in artist360

**artist360 may be a `## Compliance` repo.** Per the `cepa:brain` skill the PHI
scrub is FORCED when `cepa.local.md` has a `## Compliance` section, regardless
of `brain_phi_scrub`. If the scrub cannot run, the writeback must be
SUPPRESSED — never sent unscrubbed. Check that first:

```bash
grep -n '## Compliance' cepa.local.md
```

compound-engineering has no such section, so this session's run did not
exercise the forced-scrub path at all.

## Prompt to run in an artist360 session

> Verify cepa brain writeback end-to-end now that the
> `${CLAUDE_PLUGIN_ROOT}` fix has shipped (cepa v1.26.4, merged as `3a38697`
> in compound-engineering, PR #69).
>
> Context: `${CLAUDE_PLUGIN_ROOT}` is NOT exported into the Bash tool's shell,
> so `"${CLAUDE_PLUGIN_ROOT}/scripts/brain-client.sh"` used to expand to
> `/scripts/brain-client.sh` and exit 127 — which was being misread as "the
> brain is unreachable". The fix adds `scripts/resolve-plugin-root.sh`. Do NOT
> spell `${CLAUDE_PLUGIN_ROOT}` anywhere; resolve the root with the loop the
> command files now use.
>
> Transport is already proven from compound-engineering (writeback 9 rows,
> 9/9 promoted, recall returned them, re-post idempotent). What is unproven
> here is `/cepa:compound`'s own orchestration in this repo.
>
> 1. Check whether `cepa.local.md` has a `## Compliance` section. If it does,
>    the PHI scrub is FORCED — confirm `brain-client.sh scrub` runs and that a
>    scrub failure SUPPRESSES the writeback rather than sending unscrubbed.
> 2. Confirm the resolver works here with both env vars unset:
>    `health` should be rc=0 and `participants` should list artist360 active.
> 3. Run `/cepa:compound` on a genuinely solved recent problem in this repo.
> 4. Verify the rows are actually visible: every returned `memory_id` must be
>    promoted (`review <id> evidence_only|confirm`), then a `recall` must
>    return them. Unpromoted rows are `review_status: pending`, which recall
>    DROPS — an unpromoted write is indistinguishable from no write at all.
> 5. Report: rows written, rows promoted, rows recalled, and the scrub
>    redaction count if the scrub ran.
>
> If anything fails, distinguish a PATH-RESOLUTION failure from a real service
> outage and never report the latter for a 127. Verify with `health` against a
> real URL before claiming an outage.

## Pointers

- Fix: `plugins/cepa/scripts/resolve-plugin-root.sh` (compound-engineering,
  `3a38697`)
- Findings from the fix's own review: `todos/review-2026-09-25-193000.md`
- Deferred residual:
  `memory/tasks.d/2026-09-25-fix-plugin-root-unset-in-dispatched-shell.md`
- Original diagnosis: artist360
  `docs/handoff/2026-09-25-cepa-plugin-root-unset-in-subagent-shell.md`
