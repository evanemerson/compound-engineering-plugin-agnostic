# `slug(x)` trailing-hyphen concern — NOT a defect, do not "fix" it

**Raised:** 2026-08-26, while dogfooding `/cepa:handoff` (PR #48).
**Status:** CLOSED — investigated, no change made, no change owed.

## The claim, and why it was wrong

A dogfood run appeared to produce `feat-handoff-command-` (trailing hyphen)
from branch `feat/handoff-command`, and it was reported as a possible
`cepa:autonomy` §5 `slug(x)` defect affecting every command that slugs a
branch name.

**The trailing hyphen came from the ad-hoc test command, not from `slug(x)`.**
The probe piped the branch name through `tr` in a way that included the
trailing newline, which `tr -c 'A-Za-z0-9_-'` then mapped to `-`. §5's
definition operates on the branch string, which has no newline.

Re-tested directly: `feat/handoff-command` → `feat-handoff-command`. Clean.

## What the re-test DID surface — both cosmetic, neither actionable

| input | slug | note |
|---|---|---|
| `feat/handoff-command` | `feat-handoff-command` | clean |
| `dependabot/npm_and_yarn/foo-1.2.3` | `dependabot-npm_and_yarn-foo-1-2-3` | fine |
| `feat/thing/` | `feat-thing-` | trailing `-`, but **git forbids a ref ending in `/`** — unreachable |
| `a—b` (em dash) | `a---b` | multi-byte collapses to a run; still valid and unique |

Every result is a valid, unique, filesystem-safe filename. §5's stated
purpose is a §7-grade charset guard, not aesthetics, and it achieves that.

## Empirical check — the case does not occur

Surveyed every local and remote branch across five repos (artist360, dpc-pro,
helm, contexthub, compound-engineering): **zero** branch names contain any
character outside `[A-Za-z0-9_/-]`. There is no branch in the portfolio that
would produce a trailing hyphen or a collapsed run.

## Why NOT to change it

- The defect does not occur on any real input.
- §5's `slug(x)` is a cited anchor; editing it obligates checking every citer
  (CLAUDE.md's cite-once rule), which is real cost for zero behavioural gain.
- Adding trailing-separator trimming would change filenames that existing
  shards already use, for cosmetics.

**If this resurfaces:** it was checked on 2026-08-26 and closed deliberately.
Re-open only with a real branch name that produces a genuinely broken path —
not an ugly one.
