# Residuals — chore/forced-phi-scrub-verification

## 2026-09-26

0. **Verification result: the FORCED PHI-scrub path is sound in the transport
   and in `/cepa:compound`, and MISSING in `/cepa:compound-refresh`.** This
   shard records the one real defect found plus the measurements behind it, so
   a later session does not have to re-derive them.

   Measured against the installed copy
   (`~/.claude/plugins/marketplaces/cepa/plugins/cepa`, v1.26.5 @ `a815590`)
   on 2026-09-26. No command was ever run with another repo as the working
   directory; both `cepa.local.md` files were read through `gh api`.

   **Which repos force the scrub — BOTH, and for two independent reasons.**

   | repo | `## Compliance` | `brain:` | `brain_phi_scrub:` | scrub forced |
   |---|---|---|---|---|
   | `dpc-pro` | yes (line 13, `hipaa: true`) | `enabled` (line 62) | `true` (line 63) | yes — both triggers |
   | `helm` | yes (line 66, PCI/GDPR/PII) | `enabled` (line 103) | `true` (line 104) | yes — both triggers |

   Both are participants AND compliance repos, and both *also* set the
   explicit flag — so the forced-on rule is currently belt-and-braces rather
   than load-bearing. That is worth knowing: the `## Compliance` auto-on
   branch has no repo in the portfolio where it is the *only* thing forcing
   the scrub, so it has never been exercised in isolation by a real run.

   Note for future greps: both files write the key as a markdown list item
   (`- brain: enabled`), not bare `brain:`. A line-anchored `^brain:` grep
   reports "no brain key" on both — it is wrong. Match `^[[:space:]]*-?[[:space:]]*brain:`.

1. **`/cepa:compound-refresh` writes to the brain with NO PHI scrub step.**
   P1. This is the defect this verification found. **FIXED in v1.26.6
   (`1dbd1bc`, this branch)** — citation form, per the recommendation below.
   Retained here as the record of what was wrong and why it survived.

   `compound-refresh.md` is one of exactly two command files that call
   `brain-client.sh writeback` (the other is `compound.md`). `compound.md`
   carries the forced-scrub instruction at lines 170–174, including the
   fail-closed clause. `compound-refresh.md` contains **no mention of `phi`
   or `Compliance` anywhere in the file**, and no scrub step in its writeback
   phase.

   Its three occurrences of the word "scrub" (lines 333, 334, 357) are a
   DIFFERENT SENSE of the word — CONCEPTS.md vocabulary pruning ("scrubbed V"
   entries). A `grep -c scrub` returns 3 and looks reassuring. That false
   signal is why this survived: the file appears to discuss scrubbing.

   **Consequence.** Run `/cepa:compound-refresh` in `dpc-pro` or `helm` — both
   HIPAA/PII repos, both brain participants — and successor strings go to the
   cloud unscrubbed. Refresh rewrites drifted solution docs, so its payloads
   are *exactly* the ones carrying freshly-quoted code and log lines, which is
   where numeric PHI actually lives. This is the higher-risk of the two
   writeback paths, not the lower.

   **Fix.** Port `compound.md`'s lines 170–174 into `compound-refresh.md`'s
   writeback phase — the forced-on condition (`brain_phi_scrub: true` OR a
   `## Compliance` section), the count-redactions step, and the fail-closed
   suppression. Prefer a citation to `cepa:brain`'s Compliance section over a
   verbatim second copy: CLAUDE.md § "Every dispatch declares its model"
   records what duplicated prose does to this repo (seven longhand copies,
   two divergent rationales). The scrub rule is now on the same trajectory —
   this would be copy number two.

   Consider also whether `_assert_envelope` should hard-refuse an unscrubbed
   payload for a compliance repo, so the guarantee does not rest on every
   command file remembering. That is a larger change and a judgment call, not
   a drive-by.

2. **Measurements that do NOT need re-deriving.** All run against the
   installed client.

   - **The scrub redacts every documented pattern.** SSN in all three
     separators (`123-45-6789`, `987 65 4321`, `555.44.3333`), MRN/account
     digit runs (7 and 12 digits), DOB in US month-first (`03/14/1982`,
     `12-25-1999`) and ISO-8601 (`1982-03-14`). A 6-digit id and a 13-digit
     run correctly survive — the rule is a 7–12 digit bound, as documented.
     Names are not caught, which is the stated and accepted scope.

   - **Scrub failure is fail-closed at the transport, on every path tested.**
     Missing infile → rc=2. Missing outfile arg → rc=2. Unwritable outfile
     dir → rc=1. **`sed` absent from `PATH` (the contract's literal "scrub
     tool is unavailable" case) → rc=127 and the outfile is truncated to 0
     bytes.** It never emits unscrubbed content.

   - **Defense in depth holds even if a caller ignores the exit code.**
     `writeback` on the 0-byte file a failed scrub leaves behind → rc=2 from
     `_assert_envelope`'s `[ -s "$f" ]` check, before any network call. So
     the 127-then-blindly-writeback sequence still cannot leak.

   - **One sharp edge worth knowing.** An argument-validation failure (rc=2)
     returns *before* the redirect, so a pre-existing outfile is left
     UNTOUCHED — verified: a file holding `123-45-6789` still held it after a
     failed scrub. Only the sed-stage failure truncates. A caller that
     reuses an outfile path across atoms and ignores rc=2 would therefore
     writeback the PREVIOUS atom's scrubbed content, not unscrubbed content —
     wrong data, not a PHI leak. Low severity, but it is the reason the
     "empty file" backstop alone is not a complete argument.

2a. **`scrub f f` destroys the payload and exits 0.** Measured while testing
   the v1.26.6 gate. The shell truncates the redirect target before `sed`
   reads it, so passing one path as both arguments empties the file — and
   the exit status is 0, because the redirect itself succeeded. A `||` gate
   cannot catch it; only `_assert_envelope`'s empty-file check stops the run,
   one verb later and with the payload already gone.

   Documented at the call site in `compound-refresh.md`, which now scrubs to
   a sidecar and `mv`s it over. **`compound.md` does not carry that warning**
   and says only "run `brain-client.sh scrub` over every string" — worth a
   look when someone next touches its writeback phase. Hardening the client
   to refuse `infile == outfile` outright would close it for every caller at
   once; that is the better fix if item 4 below is taken up.

3. **`brain-backfill.sh` names the scrub only in a comment.** P3, informational.
   Line 6 documents the procedure as `decompose → PHI-scrub → writeback →
   PATCH evidence_only`, but the script is a work queue and does not itself
   scrub — the agent driving it is expected to. That matches the skill's
   "agent-driven" framing, so it is not a defect, but it is a second place
   where the guarantee depends on an agent following prose. Worth folding
   into whatever fix item 1 gets.
