# Residuals — chore/forced-phi-scrub-verification

## 2026-09-26

0. **Verification result: the FORCED PHI-scrub path is sound in the transport
   and in `/cepa:compound`, and MISSING in `/cepa:compound-refresh`.** This
   shard records the one real defect found plus the measurements behind it, so
   a later session does not have to re-derive them.

   Measured against the installed copy at v1.26.5 @ `a815590` on 2026-09-26.

   **Path label corrected 2026-09-28 (v1.26.11).** This line originally named
   `~/.claude/plugins/marketplaces/cepa/plugins/cepa` — the marketplace clone,
   which is NOT the copy Claude Code loads (see
   `scripts/check-plugin-freshness.sh`, and item 1 of
   `memory/tasks.d/2026-09-27-main.md`). The **measurements stand**: the loaded
   cache was independently confirmed to be v1.26.5 @ `a815590`, `lastUpdated`
   2026-09-26, so this shard did read the live artifact. Only the path was
   mislabelled — and that conflation is precisely what the freshness check now
   exists to prevent, so it is corrected rather than left to mislead. No command was ever run with another repo as the working
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

2a. **`scrub f f` destroys the payload and exits 0.** **FIXED in v1.26.7
   (`1d56e83`)** — `brain-client.sh scrub` now refuses `infile == outfile`,
   comparing resolved paths so `f` and `./f` are caught too. That closes the
   class for every caller at once, which is why the per-call-site warning was
   not the right fix. Retained below as the record of the behavior.

   Measured while testing the v1.26.6 gate. The shell truncates the redirect target before `sed`
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

2b. **`compound.md`'s PHI scrub is PROSE ONLY — there is no executable scrub
   call anywhere in it.** P1. **FIXED in v1.26.9 (`b51ab8e`).**

   **Correction — v1.26.8 (`86db93c`) did NOT close this, and this shard
   briefly claimed it did.** That commit made the gate executable but set
   `P="$P.scrubbed"` in one fenced block while `writeback "$P"` runs in a
   LATER block — a different shell, where `$P` is unset. The post therefore
   fell back to the unscrubbed original: the same leak, one block later.
   Three review agents found it independently. The claim was wrong for one
   commit; it is recorded here because a future session reading a bare
   "FIXED" would not have re-checked.

   v1.26.9 installs the scrubbed bytes at the SAME path, so nothing has to
   survive a shell boundary, and the unscrubbed copy is removed rather than
   left at rest. Also fixed there: the re-Write step could re-emit pre-scrub
   strings from the agent's context; `cepa.local.md` was read relative to
   cwd (false on any subdirectory, silently disabling the scrub); and the
   heading regex missed `## Compliance: HIPAA`, `##Compliance`, lowercase,
   and indented forms.

   One thing that did NOT carry over from the sibling fix: `idkey` hashes the
   payload file, so the scrub must run BEFORE it or the key describes content
   never sent. `compound-refresh.md` has no idkey step, so this was new work,
   not a port. Retained below as the record of what was wrong. Found by the PR #71 review and
   verified directly: `grep` for `brain-client.sh` in `compound.md` returns
   exactly ONE hit, line 170, inside a narrative instruction. Its executable
   writeback block (lines ~227-245) resolves `$CEPA_ROOT`, sets
   `CLIENT=`, `chmod 600`s the payload, and calls `idkey` — but never `scrub`.

   This is the same defect class PR #71 just fixed in the sibling, still live
   in the file that was used as the reference implementation. The
   plugin-root residual's ruling applies verbatim: "a guard expressed as
   prose in a command contract is not enforcement." `compound.md` is the
   PRIMARY writeback path — it runs on every `/cepa:compound` — so the forced
   scrub is currently code-enforced only in refresh.

   Fix: add the same gated block (scrub → gated `mv` → writeback) to
   `compound.md`'s writeback block, next to the `idkey` call that already
   operates on `$P`. Its block already sets `set -euo pipefail`, so only the
   explicit gates are needed. Not done here to keep the PHI-leak fix
   reviewable; this is the immediate next PR.

2i. **The re-Write step's protection is prose, not enforcement.** P1.
   **FIXED in v1.28.0** — `brain-client.sh scrub-seal` / `scrub-verify`, wired
   into `compound.md` either side of the agent's re-Write.

   **LIVE as of 2026-10-03.** Merged as `afe7ce1` (PR #80), both install hops
   refreshed, `check-plugin-freshness.sh` rc=0, and the gate re-verified
   against the LOADED copy at
   `~/.claude/plugins/cache/cepa/cepa/1.28.0/scripts/brain-client.sh` — not
   against this checkout. Four behaviors confirmed there: PHI added with the
   marker count intact → rc=1; honest two-field re-Write with reindented JSON
   → rc=0; re-seal after contamination → rc=2 refused; a 2^63 seal → rc=2, no
   fall-through. Stated this way because CLAUDE.md's rule is that a merged fix
   is not a live fix, and this surface is the one that wrote that rule.

   The count crosses the fenced-block boundary in a FILE (`<payload>.phiseal`),
   per 2g. It had to: measured under the real block split, `$CEPA_ROOT` is
   unbound in the step-4 shell, and the naive `CLIENT="$CEPA_ROOT/scripts/…"`
   expands to `/scripts/brain-client.sh` and exits **127** — the signature that
   reads as a missing binary and put a false "brain unreachable" claim into 42
   artist360 review files. The first cut of this fix shipped that line. It was
   caught by running the extracted block, not by reading it, which is the
   fifth instance of 2g's class on this surface and the reason 2g is now
   enforced at the top of the step-4 block rather than assumed.

   Exit semantics mirror `scrub-required`: 0 intact / 1 FELL / 2 unevaluable.
   A missing, empty, or non-numeric seal is 2 and suppresses — an unevaluable
   gate must never read as a pass, or the check silently stops existing while
   every call site still looks gated.

   **Three defects in the fix itself, all found by running it:**

   - **`grep -c` counts LINES, not occurrences.** `compound.md` emits
     single-line JSON, so every marker shares one line and the count can only
     be 0 or 1 — dropping one of two markers left it unchanged and the gate
     passed. Measured: a two-marker line gives `grep -c` 1 and
     `grep -o | grep -c ''` 2. Both verbs now count through one shared
     `_phi_count`, so they cannot drift apart and make the comparison
     meaningless.
   - **`[ $? -gt 1 ]` in an `elif` reads a status the `if` test already
     clobbered.** Measured: `$?` is 0 inside the elif regardless of grep's
     real status. An unreadable payload could therefore seal as "0
     redactions" — a count that can never fall, i.e. a gate that always
     passes. The status is now captured immediately.
   - **A failed seal left the PREVIOUS atom's seal in place** on a reused
     payload path (2a's shape), so `scrub-verify` would compare against a
     count describing different content. The stale seal is now removed before
     anything that can fail.

   **And one defect in the CONTROL for the first of those** — worth more than
   the fix. `sv_oneline` originally hardcoded its seal as `2`. Under a
   line-counting mutant, verify reads 1, `1 -lt 2` still fails, and the case
   passed **for the wrong reason**: it never exercised the counting at all.
   The seal is now written by `scrub-seal` itself, so both sides use the
   counter under test; the mutant then seals 1, reads 1, reports "intact", and
   the case fails as it should. **A fixture that hardcodes the expected side of
   a comparison cannot test the thing computing it** — the sibling of this
   file's own rule that a fixture score is necessary but never sufficient.

   **FOUR MORE P1s, found by the PR #80 review running the code — and the
   first cut of this fix was green on all 30 controls while every one of them
   was live.** That is this file's own "a fixture score is necessary, never
   sufficient" rule landing on the fix written to honor it.

   - **A marker count detects DELETION only.** The actual threat is an agent
     re-emitting pre-scrub strings it still holds, which it can do by
     ADDING them while every sealed marker stays put. Measured: seal 2,
     append `SSN 987-65-4321`, count still 2, verdict `verified: intact`,
     raw PHI sent. Found independently by two review agents. Fixed with
     `_phi_fingerprint` — a canonical-JSON SHA-256 over the payload minus the
     two authorized fields (`idempotency_key`, `source_refs`), so any byte
     changed outside them moves the hash. Canonical, not raw bytes: an agent
     rewrites the whole file, so key order and whitespace legitimately change
     and a byte hash would suppress every honest run.
   - **Re-running the setup block LAUNDERED contamination.** `scrub-seal`
     re-derived the seal from whatever the payload then held, so seal 2 →
     contaminate → re-seal 0 → `0 >= 0` → pass. Re-running a setup block is
     an ordinary recovery move. Fixed: `scrub-seal` refuses when a seal
     already describes different content; an identical-bytes re-seal is still
     a permitted no-op.
   - **A seal of 2^63 fell THROUGH to success.** All digits passes the
     non-numeric check, but bash `test` cannot parse ≥ 2^63, and the failing
     `[` was an `if` CONDITION — so `set -e` does not fire and execution
     reached the success `printf`. Measured: exit 0 on a fully contaminated
     payload; 2^63−1 compares correctly, so the boundary is exact. Fixed with
     a magnitude guard AND by inverting both comparisons so the pass is
     explicit (`[ ok ] || _die`), never "no failure branch fired".
   - **`$P` is agent-chosen, so concurrent runs can collide** on both the
     payload and the seal — failing in both directions (a clean memory
     suppressed and deleted; or PHI passing against a sibling's lower seal).
     NOT fixed here: it is a `compound.md` contract change (derive `$P` from
     `mktemp` and carry the path through the filesystem, per 2g). Filed as
     **2j** below.

   Controls: 36/36 (was 21/21). Fifteen new cases. Each of the four
   P1-guarding cases was mutation-tested: removing the fingerprint comparison
   reddens only `sv_added`, the re-seal guard only `ss_reseal`, the magnitude
   guard only `sv_hugeseal`, the legacy-seal refusal only `sv_legacyseal`.

   Behavior end-to-end was measured by extracting both fenced blocks with
   `scripts/extract-fenced-blocks.py` and running them under `bash -e` in
   separate processes with a stubbed curl: honest re-Write (reordered keys,
   reindented) → `verified: 3 intact` then the expected network degrade; PHI
   added with the count intact → suppressed, payload removed; markers removed
   → suppressed; re-seal after contamination → block 3 refuses, block 4
   suppresses; deleted seal → unevaluable, suppressed.

2g. **A fenced-block instruction file must never carry state across a block
   boundary in a shell variable.** P2. **CLOSED 2026-10-03** —
   `scripts/check-fenced-block-state.sh` + its controls, CI-gated in
   `.github/workflows/residual-integrity.yml`. The gate, not the rule, was the
   deliverable; see "What the gate is" at the end of this item.

   This is the most generalizable finding of the whole investigation. It was
   the SIXTH instance on the brain-writeback surface alone — and instances 5
   and 6 were each written BY the session enforcing the rule, in the block it
   was adding, with 2g's text on screen:

   1. `${CLAUDE_PLUGIN_ROOT}` is not exported into the Bash tool's shell
      (PR #69).
   2. `$CEPA_ROOT` must be re-resolved in every block that uses it
      (documented in `compound-refresh.md`).
   3. `P="$P.scrubbed"` did not reach the writeback block (v1.26.8, fixed
      v1.26.9).
   4. `compound.md`'s step-4 block used a bare `$CLIENT` assigned in step 3 —
      latent, since nothing in that block ran before the writeback.
   5. The first cut of 2i's own fix wrote `CLIENT="$CEPA_ROOT/scripts/…"` in
      the step-4 block. Measured 2026-10-02: `set -u` → "CEPA_ROOT: unbound
      variable"; without it → `/scripts/brain-client.sh`, rc=127.
   6. The first cut of **2j's** fix named the cross-block pointer file with
      `$$`, for per-run uniqueness. Each block is a different shell, so `$$` is
      a different PID in each: measured 2026-10-03, three bash invocations gave
      4064353 / 4064354 / 4064355, and the pointer would have been unfindable
      from the next block. A fix for a path-collision bug, broken by the
      state-crossing bug, in the same diff.

   The rule: state crosses blocks only through the FILESYSTEM — the same
   path, or an explicit re-read — never through a variable. The reviewable
   form: every variable used in block N was either assigned in block N or is
   a documented literal.

   **v1.28.0 is 2g's first enforcement**, and the lesson is that the rule does
   not survive being known. Instance 5 was written BY the session implementing
   2i, in the block it was adding, with 2g's text in front of it — and it
   reproduced the exact 127 signature the rule exists to prevent. Reading the
   diff did not catch it; running the extracted block did, in one command.
   **So the checker is the deliverable, not the rule.**

   **`scripts/extract-fenced-blocks.py` (v1.28.0) is the extraction half**, and
   it is committed rather than described — the PR #80 review caught this entry
   claiming "see the PR" for a script that existed only in scrollback, which is
   this shard's third false-durable-claim after 2b's and 2i's. `--emit` writes
   each block to a file to be run under `bash -e` in separate processes;
   `--report` lists, per block, names used but assigned in an EARLIER block.
   Verified against the reconstructed instance-5 shape: the defect reports
   `>> 2g DEFECT CANDIDATES: CEPA_ROOT` and the fix reports clean.

   Two things it deliberately does NOT do, so the next session does not
   over-trust it. It emits **candidates, not verdicts** — it cannot know which
   names the harness exports (`CLAUDE_PLUGIN_ROOT` is NOT exported into the Bash
   tool's shell; that is instance 1) nor which are literals the prose tells the
   agent to substitute (`$P`). That judgment is the small allowlist this item
   describes, and it is still owed. And it cannot see names set by a sourced
   script, so it reports sourcing separately instead of claiming the name is
   assigned — `resolve-plugin-root.sh` sets `$CEPA_ROOT` that way.

   Its own first cut was wrong in the same shape as everything else here: the
   assignment regex lacked `re.M`, so `^` anchored to the start of the whole
   block and every assignment except a column-0 one on line 1 was invisible.
   The deliberately-broken and the fixed shapes of `compound.md` produced
   IDENTICAL reports. **A checker for 2g that cannot see a re-assignment
   reports the fix and the defect the same way** — worse than no checker.
   Caught by running it on both shapes, not by reading the regex.

   **What the gate is (2026-10-03).** `scripts/check-fenced-block-state.sh`
   runs the extractor's `--report` across every command file, applies a
   per-name allowlist, and FAILS on what is left. Legs 0, 1, 2, 2b, 2s, 2f, 3
   and 4; the ones that matter most were each found by MUTATION-TESTING THE
   CONTROLS or by ADVERSARIAL ATTACK, never by reading code:

   - **Leg 2s is the load-bearing one, and its absence was a silent pass.**
     Leg 1 rests on the extractor's cross-block signal, which only fires when
     a name was *assigned* in an earlier block. `$CEPA_ROOT` is set by a
     **sourced** script, so it is never recorded as assigned and leg 1
     structurally CANNOT fire for it — the name behind instances 2, 4 and 5.
     With only legs 1–3, the reconstructed instance-5 shape reported **0
     MISS**: the gate green-lighting the exact defect it was built for. Leg 2s
     requires a `sourced` name's own block to source something.
   - **The fragment marker needed a one-per-file cap.** `compound-refresh.md`'s
     writeback block is a genuine fragment ("PASTE THIS AFTER … in ONE block"),
     so an exemption path was unavoidable — and an exemption with no cap is an
     off switch. Capped at one; over the cap NO block is exempt, so a
     capped-out file sees every finding its markers were hiding.

   **The allowlist is 5 entries, and three names were REJECTED from it** —
   that triage is the substance, exactly as this item predicted. `$RUN`,
   `$REPO` and `$DOC` all read as archetypal documented literals, and leg 3
   rejected all three as stale: each is re-assigned in every block that uses
   it (which is 2j's fix working), so none ever reaches the candidate list. The
   test is not "is it obviously a literal" but "does any block use it
   unassigned". Entries carry a mandatory reason and an unused entry is a MISS.

   **Four defects in the probe, all found by running it, none by reading it** —
   this item's own lesson, applied to its own fix:

   - `SOURCE_RE` was line-anchored (`^[ \t]*\.`), but this repo's resolve
     idiom is `[ -f "$R" ] && . "$R" && break`. It reported "sources nothing"
     for every one of those blocks: **6 of the first 7 findings were false
     positives.** An absence claim is a fact about the probe.
   - The uses scan counted names inside full-line comments, so `setup.md`
     block 1 was flagged over a comment reading "do NOT resolve it through
     `$CEPA_ROOT`" — a finding whose own evidence says the opposite.
   - `while read -r id` was invisible, surfacing `id` as a candidate. Fixed in
     the extractor (`READ_RE`) rather than allowlisted: papering a parser gap
     into a suppression makes the next loop variable an unexamined pass.
   - `READ_RE`'s first cut used a bare `\bread\b`, which matched the PROSE
     "Re-read the payload path from the pointer rather than retyping it" and
     harvested `from`, `it`, `rather`, `than`, `the`, `there`, `retyping`,
     `path`, `payload`, `pointer` as *assigned*. That direction is worse than
     a false positive: a phantom assignment SUPPRESSES every real candidate of
     that name. Same shape as the `re.M` defect this item already records.

   **THREE defects in the CONTROLS, every one of which made a case pass for
   the wrong reason** — the `sv_oneline` failure from 2i, reproduced three
   times in the suite written to honour it. This is the single most
   generalizable thing the PR produced:

   - `mut_instance5` had an empty allowlist, so it produced TWO MISSes (leg 2
     *and* leg 1). Disabling leg 1 left rc=1 and the case still passed:
     **removing 2g's own detection killed ZERO of 13 cases.**
   - **The fix for that was ALSO wrong, and the shard asserted it for one
     revision.** Allowlisting the name and declaring "leg 1 is the ONLY leg
     that can redden this case" was true when written and false when it
     shipped: leg 2s was added later, block 1 sourced nothing, and leg 2s
     became a second trigger. PR #82's adversarial review measured it —
     removing leg 1 killed only `mut_instance3`, and `mut_instance5` was a
     duplicate of `mut_sourced_gap`. **A later leg silently took over an
     earlier leg's only headline control.** Leg 1 now has `mut_leg1_literal`,
     a `literal`-class fixture leg 2s structurally cannot touch. Note what
     does NOT work: making block 1 source an unrelated script. Leg 1 cannot
     fire for a `sourced` name at all (never recorded as `assigned` — the
     reason leg 2s exists), so that variant reports 0 MISS.
   - `mut_frag_abuse`'s block 0 did not source, so it carried its own leg-2s
     finding and stayed red with the cap removed. Fixing it exposed a real bug:
     `frag_blk` was a scalar holding only the LAST marked block, so the
     exemption followed block ORDER rather than the marker — a real violation
     passing while a documented fragment was flagged. Now a set, with
     `mut_frag_order` pinning it.

   **THE RULE THIS YIELDS, and it outlives this gate:** after adding any leg,
   re-run the per-leg mutation sweep and confirm every leg still kills at least
   one case **that no other leg also kills**. A green suite is not evidence
   that each leg is covered, and rc alone cannot pin a leg's *scope* — the
   leg-2b whole-file mutant stayed red by over-reporting (2 MISSes instead of
   1), so `mut_env_scope_exact` asserts the exact finding set rather than rc.

   **Five more defects found by RUNNING the gate against hostile input** (PR
   #82's review), each a way to commit 2g and pass:

   - **A `` ```sh ``, unlabeled, or `` ```Bash `` fence was invisible.** The
     extractor matches `` ```bash `` exactly, so instance 5 placed in any of
     them gave rc=0 — `` ```sh `` with a label-only WARN, the other two in
     total silence. Leg 0 now detects by CONTENT. The live corpus has 62
     unlabeled fences and `handoff.md` block 9 holds six shell-looking lines,
     so this was a real blind spot. WARN not MISS: that block is a paste
     template with no second block to inherit from, so failing on it would
     make the fix "mangle a correct document".
   - **A heredoc body line shaped like an assignment phantom-assigned.** A
     block writing an operator runbook that documents `P=/tmp/payload.json`
     reported `assigned: P`, which SUPPRESSED the real candidate — the
     wrong-all-clear direction, and on `compound.md`'s writeback path it is the
     v1.26.8 shape: writeback falls back to the unscrubbed original, a PHI
     leak. `task.md` block 9 already contains a heredoc. Fixed by masking
     heredoc bodies before the assignment scan only; the uses scan must NOT be
     masked, because the shell really does expand `$NAME` there.
   - **One guarded mention laundered every unguarded use.** Leg 2b grepped the
     whole `.md` file, so unguarded `$X` in block 0 plus `${X:-}` in block 1
     passed — and the laundering mention did not have to be code: a comment, or
     markdown prose outside any fence, satisfied a claim about shell state.
     Now scoped per block, over the emitted body, comments stripped.
   - **The fragment marker could be granted by accident.** Two unanchored
     greps meant the strings matched inside a heredoc writing an unrelated
     note, or split across two `echo` arguments — each silently consuming the
     file's one fragment slot and disabling leg 2s on a block with a real
     violation. Reachable here specifically: command files routinely emit PR
     bodies and handoff prompts containing paste instructions. Now one
     full-line comment carrying both strings, which is what the prose always
     described.
   - **A drifted output label made the gate green while parsing NOTHING.**
     Renaming `block N:` in the extractor gave `scope: 0 block(s)`, 0 MISS,
     rc=0 — the `scope:` line printing the evidence of its own failure while
     nothing acted on it. Leg 4 now cross-checks the parsed count against two
     independent probes (a direct grep of the reports, and a fence count that
     does not involve the extractor). All three must agree.
   - **And leg 4 itself then shipped the same defect, one layer down.** Its
     extractor-independent probe summed via `paste -sd+ | bc`, and `bc` is a
     dependency this repo explicitly must not assume — CLAUDE.md records the
     identical gap for `jq`. Measured with a PATH identical except for `bc`:
     `bc: command not found`, then `[: : integer expression expected`, then
     **`0 MISS`, rc=0** with the `cross-check:` line printing a blank where its
     count belongs. The failed substitution leaves the value EMPTY rather than
     unset, so `set -u` cannot see it, and the `[` error is swallowed because
     it is an `if` CONDITION — residual 2i's 2^63 blind spot exactly. Now pure
     bash arithmetic that skips non-numeric input, so a grep failure degrades
     to 0 and the comparison REPORTS it instead of crashing on it. Pinned by
     `mut_no_bc`, which builds a PATH missing only `bc` and treats its own
     inability to do so as a failure rather than a pass. This is the
     `a-detector-is-not-exempt-from-the-class-it-detects` doc landing on the
     leg added to prevent that class.

   **Mutation-swept: 21 mutants, 18 killed outright; the 3 survivors are
   deliberate redundancy, verified individually** — leg 4's two cross-checks
   each catch the drift alone (removing BOTH kills `mut_parse_drift`), and the
   leg-2b scope mutant is killed by `mut_env_scope_exact` rather than by rc.
   Controls 31/31.

   Verification commands, per this repo's state-the-probe rule:

   ```
   bash scripts/check-fenced-block-state.sh           # 0 MISS, 1 WARN
   bash scripts/check-fenced-block-state-controls.sh  # 0 failed
   ```

   The 1 WARN is `handoff.md`'s unlabeled paste-template block, described
   above — expected, not a deferred failure. Measured over 28 ```bash blocks
   in 11 command files, of which 6 carry candidates. The extractor changes
   were corpus-diffed against `HEAD`: output IDENTICAL on all 11 files, so no
   row was lost to heredoc masking (the repo's "a fixture score is necessary,
   never sufficient" rule).

   Stated limits, so none reads as a pass: shell in a non-`bash` fence is
   WARNed, not inspected; it proves a `sourced` name's block sources
   SOMETHING, not that the sourced file sets that name; the fragment marker is
   still an unverifiable promise, merely a narrower one; and it proves a name
   is re-resolved, NOT that the re-resolution is correct — instance 5 was a
   re-assignment in the right block expanding to the wrong path. **Running the
   block remains the only thing that catches that**, which is what `--emit`
   is for.

   **The `docs/solutions/` entry is DONE, as an extension rather than a new
   doc.** `an-assertion-must-name-the-edit-that-reddens-it.md` already owned
   "a control detaches from the construct it names" with four mechanisms, each
   detaching **when the control is written**. What PR #82 found is a fifth that
   none of them cover — **succession**: the control was measured correct, and a
   later leg took its kill away. A new doc would have been the restatement this
   repo has paid for three times, so the doc now reads "five ways", with the
   mechanism, three reasons a reviewer cannot catch it (the control is not
   wrong; the invalidating edit is in another file's diff; adding coverage
   REMOVED coverage), the repair that works, and the repair that does not.
   Three Detection signals added — S0 (an unqualified "ONLY leg N" claim in a
   checker that has since gained a leg), S0b (a per-leg sweep with no
   uniqueness assertion), S0c (a control that can decline and still pass).

   **S0 immediately found two live instances in this PR's own controls** —
   `mut_instance5` and `mut_instance3` both still claimed "ONLY leg 1". One was
   false (fixed), one was true but unverified (re-measured, and the sentence
   now says how to re-verify rather than asserting it). A signal that catches
   something in the diff that created it is the right shape.

   Note `docs/` is gitignored here, so that write-up is local. The durable
   tracked record is CLAUDE.md's rule plus this item.

2j. **`$P` is agent-chosen, so two concurrent `/cepa:compound` runs can
   collide on the payload AND the seal.** P2. **FIXED in v1.28.1** — a
   path-minting block now runs BEFORE the Write tool: `mktemp` creates the
   payload path, and a pointer file named from a substituted `$RUN` literal
   carries that path to the later blocks.

   Three things had to be true at once, which is why this was its own diff.
   The payload is written by the **Write tool** (no shell), so `mktemp` cannot
   live in the block that uses it; the path must therefore cross a block
   boundary, so per 2g it goes through the filesystem; and the pointer itself
   must be findable without inheriting anything, so its NAME is derived from a
   literal rather than from shell state.

   **2g bit this fix too — instance 6, inside 2j's own fix.** The first cut
   named the pointer with `$$` for per-run uniqueness. Each fenced block is a
   different shell, so `$$` is a different PID in each: measured 2026-10-03,
   three bash invocations gave 4064353 / 4064354 / 4064355, and the pointer
   would have been unfindable from the next block. `$RUN` is a documented
   literal the agent substitutes once — the same shape `$REPO` and `$DOC`
   already use — and it is validated against `[A-Za-z0-9._-]` before any path
   is composed from it, since it lands in a filename. Measured: the
   placeholder, empty, `../../etc/evil`, `a/b` and `x;rm -rf /` all abort at
   rc=1 writing nothing; only a valid id creates files.

   Every suppression path now removes the pointer alongside the payload, and
   the successful path removes `$P`, `.phiseal`, `.resp`, `.ids` and the
   pointer after the promote loop has read `.ids`. A pointer outliving its
   payload resolves to a path that no longer exists, which the next block
   would report as "the Write step did not land" for a run that completed.

   **PR #81's review found three more defects in this fix, two of them P1 —
   again by running it.** The pattern now has a name on this surface: the first
   cut of every fix here has been green on its own tests while live.

   - **A reused `$RUN` sent the WRONG DOCUMENT at rc=0.** `mktemp` made the
     payloads distinct, so the collision moved to the single shared pointer:
     run B's later block read run A's path, sealed and verified A's payload,
     and posted A's document under B's idempotency_key while B's contaminated
     payload stayed at rest in /tmp. Measured: 12 concurrent runs on one
     `$RUN` gave 12 payloads, 1 pointer, 11 orphans. The old bug collided on
     payload AND seal, so a mismatch was loud; this was a green, consistently
     wrong gate — a false negative replacing a false positive. Fixed with an
     ATOMIC create: `( set -C; printf ... > "$PTR" )` in a subshell. A
     `[ -e "$PTR" ]` test-then-write is itself a TOCTOU race; measured, 20
     concurrent noclobber writers to one path give exactly 1 winner and 19
     refusals.
   - **The pointer's contents were used as a path with no containment.** A
     pointer aimed outside the minted prefix made the scrub rewrite an
     unrelated file in place, which a later suppression then `rm -f`'d:
     measured, `sealed: 1 redaction markers ... in <outside-TMPDIR>/precious.json`
     at rc=0. Both later blocks now require `$P` to match
     `$TMPDIR/cepa-compound-payload-$RUN-*.json` and to be a non-symlink
     regular file. The symlink half of this (a pre-squatted pointer path whose
     write followed the link and destroyed the target) was closed incidentally
     by the same `set -C`, since noclobber refuses to follow an existing
     symlink — verified.
   - **`$RUN` was validated in the minting block only.** The two later blocks
     composed `$PTR` from an unvalidated literal. Latent rather than active (a
     bad `$RUN` made the lookup miss and abort) but it is 2g's asymmetry
     exactly: the guard in one block, the same path re-derived without it in
     two others. Copied into all three.

   Also fixed while here, found by the same review's leftover-file note and
   then measured directly: **`_curl`'s trap was `RETURN` only**, which never
   fires when `set -e` kills the shell on a nonzero curl — so every network
   failure left the curl config, holding `x-brain-key: $MCP_ACCESS_KEY` in
   PLAINTEXT, in `/tmp` forever, one file per failure. Measured with a stub
   exiting 7: rc=7 and `grep` found the key in the leftover. Now
   `RETURN EXIT`; re-measured at 0 files after 1 and after 3 failed calls.
   Separately, block 2 had ten `exit 1` paths of which exactly ONE cleaned up,
   so an EXIT trap replaced the per-branch list — a list has to stay complete
   as branches are added; a trap is the mechanism.

   Verified by extracting all three blocks and running two interleaved runs:
   A seals 1 and B seals 3 against distinct `mktemp` paths, neither seal moves
   when the other runs, and a contaminated run suppresses while its concurrent
   honest sibling still passes. The `allowed-tools` re-check CLAUDE.md requires
   was done: `mktemp`/`printf` run inside the fenced block, so `Bash(bash:*)`
   covers them exactly as it already covers the pre-existing
   `cat`/`rm`/`echo`/`chmod`/`mv` — recorded at the call site rather than left
   as an apparent omission.

   Retained below as the record of what was wrong — found by PR #80's
   adversarial review, which measured both directions.

   `compound.md` says `P="<payload-file you just wrote>"` and, in the later
   block, `P="<the same payload file>"`. No `mktemp`, no run id. Two agents
   reading the same instructions plausibly choose the same conventional name.

   - **False positive, with data loss.** Run A seals 1; run B overwrites the
     seal with 3; A verifies its own 1-marker payload against 3 → suppressed,
     and the suppression path `rm -f`s the payload. A correctly-scrubbed
     memory is discarded and the run reports "re-Write reintroduced pre-scrub
     content", which is false.
   - **False negative.** Reverse interleaving: B verifies against A's lower
     seal while holding raw PHI → passes.

   The `rm -f` in each suppression path also deletes the other run's payload
   mid-flight.

   Fix: have the setup block derive the path (`P="$(mktemp -t
   cepa-brain-payload.XXXXXX)"`) and have the later block re-read it from one
   recorded location rather than from the agent's memory of it. Note the path
   itself then has to cross the block boundary — so it goes through the
   filesystem, per 2g. Not done in #80: it is a contract change to
   `compound.md`'s payload convention, affecting every step that names `$P`,
   and worth its own reviewable diff.

2h. **The two sibling commands now scrub under different conditions.** P2.
   **RESOLVED in v1.27.0** — operator decision taken 2026-09-28: unify on
   **forced-only**, and move detection into `brain-client.sh scrub-required`
   so the RULE has one executable home instead of being re-derived by each
   caller's own regexes.

   What shipped: the new verb (exit `0` required / `1` not required / `2`
   cannot decide → refuse to send), both call sites converted to ask it, the
   inline regex pair deleted from both command files, and the policy written
   into `cepa:brain`'s `## Compliance` section — which previously specified
   only the forced case and was the reason the two commands could each guess
   differently. `compound-refresh.md` changed behavior: it no longer scrubs
   unconditionally, because the scrub is numeric-only and content-blind
   (residual 2e) and would permanently degrade non-PHI memories while
   reporting protection that was never owed.

   Exit 2 is the load-bearing part. An unresolvable `cepa.local.md` must never
   collapse into "not required" — that is the unscrubbed-egress path — so it
   has its own case in `scripts/check-brain-client-args.sh` (`sr_undecidable`)
   rather than resting on the arity check. Both emitted blocks were extracted
   and run under `bash -e` across all three statuses; the required path posts
   the `.scrubbed` sidecar, the not-required path posts the original, and the
   undecidable path suppresses and removes the payload.

   **Reviewed (`todos/review-2026-09-29-101500.md`) — and item 3's warning held
   again, for a fourth round.** The consolidation itself shipped a defect of
   the class it was closing: `_cl="$(git rev-parse ... )/.."` let the
   assignment inherit git's **exit 128** outside a work tree, so under
   `set -e` the verb died at rc=128 with **completely empty output** — both
   `_die` messages unreachable. Not a leak (callers fail closed on 128,
   verified across rc 0/1/2/3/126/127/128/130) but the exact
   "a tool error is not a finding" misdiagnosis shape. Fixed in this PR by
   capturing the status, plus a new `sr_nongit` control that was
   mutation-tested: restoring the old line reddens only that case (20/21), and
   21/21 on restore.

   Also corrected there: the comment claimed resolution "exactly as"
   `.env.local` when it used a bare `/..` instead of `_load_env`'s
   `${common%/.git}`. **Known gap now recorded rather than papered over:**
   under `git init --separate-git-dir` auto-resolution lands on the gitdir and
   returns exit 2 — fails CLOSED, shared with `_load_env`, and such a repo
   passes the path explicitly.

   **The PHI-egress delta is empty for the real portfolio.** `dpc-pro` and
   `helm` each declare `## Compliance` AND the flag, so both still scrub; this
   repo declares neither, so it is the only participant whose refresh behavior
   changes, and its payloads are cepa's own solution docs. The
   `## Compliance`-only branch is still unexercised in isolation by a real run
   — only by fixture.

   Retained below as the record of the ambiguity and why it existed.
   `compound-refresh.md` scrubs unconditionally on every writeback;
   `compound.md` scrubs only when `FORCE_SCRUB=1`. So a participating repo
   that is neither flagged nor `## Compliance` gets scrubbed by refresh and
   not by compound. `cepa:brain`'s Compliance section only specifies the
   forced case and is silent on the non-forced participant, so it is genuinely
   ambiguous which behavior is correct.

   Resolve it in SKILL.md first, then make both commands match — ideally by
   moving detection into `brain-client.sh` (e.g. a `scrub-required` verb) so
   the RULE lives in one executable place instead of being re-derived by each
   caller's own regexes. That also answers the reviewer's objection that
   detecting the condition in a command body re-implements the rule rather
   than instantiating it.

2c. **The `cepa:brain` Compliance citation has no resolves-check.** P2.
   **CLOSED by PR #83** — leg 5 of `scripts/check-model-pins.sh`. Build
   record at the end of this item.
   `check-model-pins.sh` Leg 4 resolves anchors only for the `§9<letter>`
   autonomy family; nothing resolves a `cepa:brain` section-name citation
   against `SKILL.md`'s actual heading. Rename or reorder that heading and
   every pointer rots silently — no CI failure, nothing visible in a diff.

   This is the known cost of citation-over-restatement, recorded in
   `docs/solutions/logic-errors/cross-cutting-policy-must-be-cited-once-not-restated-at-every-site.md`.
   It is not an argument for restating. Fix: a second anchor-resolution leg
   covering skill-section citations.

   **Measured 2026-10-04 on `main` @ `d926225`, before any work started.** The
   numbers below are each the output of ONE command; re-run them rather than
   reasoning from them.

   A naive probe for a `cepa:brain` + Compliance-section citation finds **one**
   line (`compound-refresh.md:265`). That is the wrong shape — this item's own
   history records #74 adding a FOURTH citer. Widening to plain `Compliance`
   across `plugins/cepa` finds ~20 lines.

   **The difficulty is that `## Compliance` serves two unrelated roles, and only
   one of them can rot:**

   - **A — a citation of the cepa:brain SKILL's heading.** `compound.md:175`
     and `compound-refresh.md:265` are this shape. These are what a
     resolves-check must cover.
   - **B — a reference to a participant REPO's own `## Compliance` declaration
     in `cepa.local.md`.** `setup.md:171/189/241`, `review.md:435/528`,
     `compound.md:681-682`, `grounding/SKILL.md:215/219` are this shape. There
     is no heading to resolve; B is a condition about a repo.

   A checker that cannot separate A from B flags B everywhere and gets turned
   off. Separating them is the real design call — and if the answer is that
   A-shape citers must adopt a distinguishable syntax, that is a contract change
   touching every A site and belongs in the plan, not in the implementation.

   **A probe warning, paid for during this measurement:** `grep` is ugrep in an
   interactive shell and GNU grep 3.11 in scripts. A `[^.]{0,40}` pattern
   exceeded ugrep's complexity limit and errored rather than returning a wrong
   count — a visible failure that time. Run every probe from a script file.

   **Re-measured 2026-10-04 on `main` @ `5da0d52` (branch
   `fix/section-name-citations`).** Probes are Python script files, multi-line
   aware, over leg 4's own root set (`plugins CLAUDE.md README.md .github
   scripts`, extensions `md markdown sh yml yaml`):

   - Python `re.finditer` over each whole file (so a match may cross a line
     break), pattern
     ``r'`?cepa:(SKILLS)`?(?:[^.\n§]|\n){0,80}?(section|`#{2,4} [^`]+`)'``
     with SKILLS the alternation of `ls plugins/cepa/skills`: **11** hits.
   - Same harness, ``r"skill's\s+(?:#\s+)?[\"`]?[A-Z][^.\n]{0,50}?[\"`]?\s+(?:#\s+)?section"``:
     **6** hits, all shape A. ``r"\(see [A-Z][A-Za-z +-]{2,40}\)"``: 2
     in-skill self-references (and one unrelated `(see README …)`).

   **The brain Compliance heading has FIVE citers, not four:**
   `compound-refresh.md:265`, `compound.md:174-175`, `compound.md:388`,
   `brain-client.sh:25-26`, `brain-client.sh:333-334` — plus the in-skill
   `(see Compliance)` at `brain/SKILL.md:35`. Two of the five wrap across a
   line break, and both of those wrap inside a shell comment, so a
   line-based probe finds neither.

   **The same rot exists outside cepa:brain, and one instance is LIVE.**
   `review.md:423/452` cite "the `file-todos` skill's Run Metadata section"
   (the heading is `## Run Metadata (optional frontmatter fields)`).
   `compound.md:59` cites compound-docs' "Detection section" (the heading is
   `### The Detection Section (mandatory)`). And
   `scripts/check-residual-integrity.sh:198-199` cites the `cepa:file-todos`
   skill's `"Verify against the body" section` — **no such heading exists.**
   It is a bold paragraph lead at `file-todos/SKILL.md:224`, under
   `## Frontmatter Summary`. That citer is already rotted.

   **A second trap the probes found:** `compound-docs/SKILL.md` carries
   `## Detection` at lines 67 and 84, both INSIDE a fenced example. A heading
   index that does not skip code fences would let a citation resolve against
   example text.

   **PLAN (this entry is the plan; no separate plan file).**

   *Design call 3 — the syntax. A required form, because no heuristic can
   separate A from B.* A section-name citation is a skill's qualified name,
   optionally followed by the word `skill's`, then the heading's own `#`
   level and title in backticks — e.g. `` `cepa:brain` skill's `## Compliance` ``.
   B never carries a qualifier next to the heading literal, so B stays
   unflagged by construction rather than by a list of exceptions. The form is
   specified ONCE, in the leg-5 header of `scripts/check-model-pins.sh`
   (the checker's header already owns its legs, as
   `check-plugin-freshness.sh`'s header owns its rule). `cepa:autonomy` §9f
   gets one pointer row, nothing more.

   Resolution rule: only a qualifier whose plugin is a directory under
   `plugins/` is matched at all (an external `superpowers:` qualifier is
   never a citation); within a local plugin, the qualifier must name a skill
   discovered under `plugins/<plugin>/skills/<skill>/SKILL.md` (else MISS). The title must
   match a heading **of the same level**, outside code fences, whose text
   equals it, or starts with it followed by ` — ` or ` (` — so a heading can
   carry a subtitle that citations do not repeat. A bare prefix
   (`## Comp`) does not resolve.

   *Design call 2 — scope: the whole skill family, discovered.* Every skill
   under `plugins/*/skills/`, keyed `<plugin>:<skill>`, from the same
   `SKILL.md` list leg 4 indexes. Hardcoding `cepa:brain` would make the leg a
   property of one path, the defect leg 4's header already records. External
   skills (`superpowers:` and other plugins outside this repo) are out of
   scope — no SKILL.md to resolve against.

   *Design call 1 — a new leg in `check-model-pins.sh`, not a new script.*
   Leg 5 consumes leg 4's per-root file lists directly, so the two legs scan
   one root set **by construction**. Legs 2-3 versus leg 4 is the recorded
   divergence (a `.markdown` file read by one and invisible to the other);
   a separate script would be a second copy of `CITE_ROOTS`, `traverse`, and
   the per-root accounting. The symlink/`-R` hazard is inherited as solved:
   leg 5 never walks a tree itself. A root that leg 4 refused is already a
   MISS; leg 5 skips it rather than reporting it twice.

   *The near-miss half.* The required form only helps if the old prose form
   cannot quietly come back. Leg 5 also MISSes the prose shape
   `<skill> skill's <words> section` (qualifier adjacent, no heading
   literal). Measured: 6 hits on today's tree, all shape A, zero B.

   **U1. Convert every A site to the required form.** Qualifiers are always
   `<plugin>:<skill>`: the bare `file-todos` citers in `review.md:423/452`
   become `cepa:file-todos`. Sites: `compound-refresh.md:265`,
   `compound.md:174-175` (prose form), `compound.md:59` (cite
   `### The Detection Section`), `review.md:423/452` (cite `## Run Metadata`),
   `check-residual-integrity.sh:198-199` (comment only — re-point it at
   `## Frontmatter Summary` and name the paragraph in words). The two in-skill
   self-references (`brain/SKILL.md:35`, `file-todos/SKILL.md:94`) adopt the
   qualified form as well, so a rename inside a skill is caught like any other.
   `brain-client.sh:25-26/333-334` and `compound.md:388` are already in the
   form. Verification: leg 5's near-miss arm, which is the committed probe,
   reports 0 MISS on the converted tree.

   **U2. Leg 5 in `scripts/check-model-pins.sh`.** Leg 4's root loop appends
   every root it accepts to a new `CITE_FILES` array; leg 5 reads only that
   array and never calls `traverse`. The leg-5 header owns the form, the
   scope and the stated limits — a deliberate departure from leg 4, whose
   limits live in §9f, recorded in the header — and the top-of-file
   "All four legs" sentence is updated. Specified behavior:

   - *Adjacency.* Qualifier, then optionally `skill's`, then the backticked
     heading literal, separated only by whitespace. Any other token between
     them is not a citation.
   - *Joining.* A line break inside a paragraph counts as whitespace. A blank
     line (in `.sh`/`.yml`/`.yaml`, also a marker-only `#` line) ends the
     paragraph, so nothing joins across it. Leading indentation is stripped,
     and in those three extensions only, the continuation line's `#` comment
     marker too. BOM and CR are normalized as leg 4 does.
   - *Index.* Headings of level 2-4 outside code fences. A fence opens on
     three or more backticks or tildes and closes only on a run of the same
     character at least as long. An unterminated fence at end of file is a
     MISS. A citation matching more than one heading in its skill is a MISS
     (ambiguous target). A title containing a backtick cannot be cited — a
     stated limit.
   - *Self-trigger.* `scripts/` is a scanned root. The header's only literal
     example is a citation that resolves on the real tree; every broken or
     prose-form string in the controls and the mutant registry is assembled
     at runtime from fragments, the way `SS` is.
   - `checked == 0` is a MISS. Verification: `0 MISS, 0 WARN` on the
     converted tree.

   **U3. Controls in `scripts/check-model-pins-controls.sh`.** One case per
   construct, each naming its mutant: the brain `## Compliance` rename (the
   real-tree proof); an unresolved title; a correct citation; subtitle
   truncation on ` — ` and on ` (`; a bare title prefix; a level mismatch; a
   heading inside a backtick fence, a tilde fence, and a four-backtick fence
   wrapping a three-backtick one; an unterminated fence; an ambiguous title;
   a citation wrapped in markdown; one wrapped in a shell comment; no join
   across a blank line; an unknown qualifier under a local plugin; the
   `skill's` variant; the near-miss prose shape; repo-sense prose directly
   after a qualifier on the previous line staying clean; zero citations.
   Exact counts on README plants; `+` only where the count is how many
   citers the repo has. Every leg-5 case asserts the leg-5 message text, so
   no leg-4 finding can satisfy it. After U3, the clean tree stays at 0 MISS.

   **U4. Mutants in `scripts/mutants/registry.sh`**, silent on the clean
   tree, one per leg-5 construct, each killed by a case whose expected
   message is leg 5's own. Then the full sweep, and a per-leg check that
   every leg still owns a killing case no other leg's mutant also reaches.

   **U5. Pointer row in `cepa:autonomy` §9f; manifests 1.28.2 → 1.28.3**,
   same commit (plugin content changes in U1 and U5).

   Verification contract — each run from the repo root:
   `bash scripts/check-model-pins.sh` (0 MISS, 0 WARN);
   `bash scripts/check-model-pins-controls.sh` (all pass);
   `bash scripts/check-fenced-block-state.sh` (0 MISS, the one known WARN);
   `bash scripts/check-fenced-block-state-controls.sh` (0 failed);
   `bash scripts/check-residual-integrity.sh` (0 MISS, the two known WARNs);
   `bash scripts/run-mutation-sweep.sh` (exit 0). Plus the real-tree proof:
   rename `## Compliance` in `brain/SKILL.md` → red; restore → green. Plan
   written as `U<N>` bold labels inside this item
   rather than `### U<N>.` headings: a heading inside a numbered residual
   breaks the item the integrity checker reads.

   **Deferred / Open Questions — from the 2026-10-04 plan review**
   (`todos/review-2026-10-04-*.md`). Judgment findings; each records the
   decision taken at build so it can be reversed by a person:

   - Near-miss arm sees only the `skill's … section` spelling (adversarial,
     P2). Decision: record it as a stated limit; do not widen now — a wider
     trigger reaches prose that names no section.
   - Near-miss arm is a heuristic beside a design that rejects heuristics
     (scope-guardian, P3). Decision: keep it. It is not an A/B separator; it
     keys on `skill's`, which the repo sense never uses (6 of 6 hits are A).
   - Should the form also live in a skill doc that command authors read
     (feasibility)? Decision: no for now — the MISS message names the form,
     and a second home is the restatement this item exists to avoid.

   **Build record (2026-10-04, PR #83).** What shipped differs from U3/U4 in
   two deliberate ways. The subtitle-truncation cases and a plain
   "correct citation" case were dropped: the live tree cites through both
   ` — ` and ` (` subtitles, so breaking either reddens the clean baseline —
   no silent mutant of them exists, and a control would kill nothing. And the
   PR review added constructs U3 never listed, each with a control and a
   mutant (the list lives in the controls file, not here).

   - **Real-tree proof:** renaming `## Compliance` in `brain/SKILL.md` gives
     `5 MISS`, rc=1 — one per citing file; restoring gives `0 MISS`, rc=0.
   - **Old prose form:** restoring the six pre-conversion lines for one run
     gives 5 distinct near-miss MISSes (two identical `review.md` lines
     count once).
   - **Adjacency is load-bearing, measured:** loosening it to "any text
     between" gave 13 innocent MISSes on today's tree.
   - **PR review** (`todos/review-2026-10-04-*.md`, the second file of that
     date): two P2s were real silent passes and are fixed. A failing scan
     pipeline dropped a file's citations with no MISS (reproduced with a
     PATH stub). A citation wrapped in a blockquote or in a fenced shell
     comment inside markdown was invisible; `compound.md:388` sat one
     reflow from that shape. The near-miss arm also matched across a
     paragraph break.

   **Mutation sweep (2026-10-04, `f3edeb4`):** rc=1 — 96/98 accounted for,
   two ANCHOR-MISSING. Leg 5 duplicated two registry anchors: leg 1's
   `if [ ! -r "$f" ]` guard (leg 5 has it at four spaces) and leg 4's BOM
   `sed` over `"$sk"` (leg 5's index runs the same one). Both re-anchored,
   not deleted; `--mutants l1-unreadable,l4-index-bom` then gave CAUGHT by
   L1g and 41, their named killers. Combined: 98/98 — 88 CAUGHT plus these
   2, 8 SURVIVED-DECLARED. Per-leg uniqueness, with `v-exit` excluded (it
   reddens 81 controls, so it shadows every leg): t, dd, ext, rank and l3
   own no killer that no other mutant reaches. That predates this PR — every
   sharer except `l5-skills-form` is an l1-l4 mutant, and l3-grep-rc's
   controls are shared with l2 and l4 mutants too. Runtime: 2c-r7.

   **Solution doc:** `docs/solutions/logic-errors/a-heading-name-with-two-senses-needs-a-required-citation-form.md`
   (local only — `docs/` is gitignored), written by `/cepa:compound` on
   2026-10-04. Its Prevention pass filed 2c-r5 and 2c-r6 below. Brain:
   8 rows written, 8 promoted. The first attempt was SUPPRESSED by
   `scrub-verify` (the 2i gate, working as built): the agent filled
   `workspace_id` after the seal, outside the two authorized fields. Nothing
   was sent; the retry filled it before the seal.

   **Follow-ups, filed here, not built:**

   - [ ] 2c-r1. Headings inside an HTML comment are still indexed, so a
     commented-out section keeps its citations green. P3. Stated limit in
     leg 5's header.
   - [ ] 2c-r2. Leg 5 does not see a bold qualifier, an upper-case
     qualifier, plugin or skill name, or "the X skill's section on Y". P3.
     Stated limit in leg 5's header. Leg 4 folds case; whether leg 5 should
     is a judgment about false-positive cost.
   - [ ] 2c-r3. Leg 4's anchor index is not fence-aware; leg 5's is. P3.
     Stated limit in leg 5's header. Unify only if a numbered heading ever
     appears inside a skill's fence.
   - [ ] 2c-r4. The scan- and index-failure arms are declared survivors
     because the control harness cannot set PATH per case. P3. A per-case
     environment hook would let a PATH-stub control pin both.
   - [ ] 2c-r5. Leg 4's anchor index discards pipeline status. P3.
     `scripts/check-model-pins.sh:585` reads
     `sed … 2>/dev/null | grep … 2>/dev/null | sed | tr` through
     `done < <(…)` with no `PIPESTATUS`, so a failed stage drops anchors with
     no MISS — the silent pass f3edeb4 closed in leg 5. Legs 2-3 read
     `scan_body` / `scan_conditional` through process substitutions too; not
     yet verified whether those functions discard status. Found by the
     2026-10-04 `/cepa:compound` prevention pass.
   - [ ] 2c-r6. `scripts/check-residual-integrity.sh:336` toggles fences on
     any line whose first non-blank text is three backticks, ignoring fence
     character and length. P3. A four-backtick fence wrapping a three-backtick one, or a
     `~~~` fence, flips the wrong text. Leg 5's `L5_INDEX_AWK` is the model.
   - [ ] 2c-r7. **The full mutation sweep no longer fits its CI bound.** P2.
     Measured 2026-10-04 at `f3edeb4`, local, 98 mutants × 109 controls:
     224 min (19:09:57 → 22:54:12 CDT; a second, dying sweep shared the
     machine for ~1.5 h of it). `mutation-sweep.yml` bounds the step at
     150 min and the job at 180, and its own header measures hosted at 1.5×
     local — so the weekly run is expected to be CANCELLED, which opens the
     failure issue. Leg 5 added 27 mutants and ~20 controls; per-mutant cost
     is ~2.3 min. Needs a design call (shard the registry across jobs, or
     raise the bounds toward GitHub's 6 h job ceiling), not a number bump.
   - [ ] 2c-r8. Five model-pin legs own no unique killer. P3. In the
     2026-10-04 sweep (`v-exit` excluded), every control killed by a t-,
     dd-, ext-, rank- or l3- mutant is also killed by another leg's mutant —
     mostly `l2-suppress-marker`, `l1-dir-symlink`, `l4-root-scripts`. Not
     caused by leg 5 (see the sweep paragraph above). Either give each leg a
     control only it reaches, or record why a shared kill suffices for it.

2e. **The scrub is content-blind and mangles innocent digits.** P2, filed.
   Because it runs over the whole payload file, ordinary engineering prose is
   collateral: `Celery task 4567890 ... PR #1234567` becomes two
   `[REDACTED-PHI-ID]`s, and that memory is permanently degraded in the brain
   with `scrubbed: N` reporting it as protection. A numeric
   `BRAIN_WORKSPACE_ID` is redacted too, which 400s the call and then disables
   the brain for the rest of the run — the current value survives only
   because it contains letters. Both measured 2026-09-26.

   v1.26.7 documents the tradeoff at the call site. The real fix is a
   structure-aware scrub that walks `memory_payload`'s string arrays and
   leaves envelope keys alone — a `brain-client.sh` change needing a JSON
   parser, and this repo cannot assume `jq`.

2f. **The scrub does not cover what `helm` actually declares.** P2, filed.
   It redacts numeric patterns only. `helm`'s 11 `pii_fields` are emails and
   phone numbers; `dpc-pro` also carries names. Neither is matched. So for a
   PII repo the forced scrub is close to a no-op while Run Metadata reports
   it ran. v1.26.7 states this at the call site; whether the scrub should
   grow email/phone patterns is an operator judgment, not a drive-by.

2d. **`scrubbed:` and `suppressed_writebacks:` are unverifiable.** P3.
   `brain-client.sh scrub` emits no redaction count, so both Run Metadata
   fields are whatever the agent writes. v1.26.6 now labels them
   self-reported at the call site; making them real means teaching `scrub`
   to print a count (e.g. compare match counts before substitution) and
   summing it mechanically.

3. **`brain-backfill.sh` names the scrub only in a comment.** P3, informational.
   Line 6 documents the procedure as `decompose → PHI-scrub → writeback →
   PATCH evidence_only`, but the script is a work queue and does not itself
   scrub — the agent driving it is expected to. That matches the skill's
   "agent-driven" framing, so it is not a defect, but it is a second place
   where the guarantee depends on an agent following prose. Worth folding
   into whatever fix item 1 gets.

2k. **The `cepa:brain` skill's `## Compliance` section does not document the
   seal/verify contract.** P2, filed — from PR #80's review
   (`todos/review-2026-10-02-143000.md`, finding 7).

   That skill is the documented home of PHI-scrub policy ("One executable
   home: `brain-client.sh scrub-required`"). v1.28.0 adds a SECOND executable
   gate whose contract lives only in `brain-client.sh`'s header and
   `compound.md`'s prose — which makes `compound.md` a second normative home
   for a policy the skill owns. This is 2h's shape one level up: only one
   caller exists today, so nothing has diverged yet, but the skill is where a
   second author looks, and `compound-refresh.md` growing a hand-edit step is
   a plausible refactor.

   Fix: a `## Re-Write gate` subsection stating that a command which asks the
   agent to hand-edit a scrubbed payload MUST seal before the edit and verify
   after, exit codes 0/1/2 mirroring `scrub-required`. Then `compound.md`'s
   comments cite it instead of re-deriving the rationale. Also worth one
   sentence in `compound-refresh.md` saying why it is exempt (its envelope is
   posted in the same block it is built in, so there is no window) — otherwise
   the next author has no signpost.

2l. **Nothing binds an agent to STOP when a fenced block exits nonzero.** P2,
   filed — from PR #80's review (finding 8).

   Every gate in `compound.md` is enforced by `exit 1`/`exit 2` from a Bash
   tool call. That is correct inside a block, but the file is prose consumed by
   an agent: nothing in it, in `cepa:autonomy`, or in `cepa:brain` says "a
   fenced block that exits nonzero is a hard stop for this step — do not
   proceed to the next block, do not retry silently, do not report success."
   The whole gate rests on the agent voluntarily halting on a nonzero tool
   result.

   Pre-existing — the `scrub` step already depended on it before v1.28.0 — but
   that release doubles the number of gates resting on it, which is why it is
   filed now rather than left implicit.

   Fix: one explicit sentence, in **`cepa:autonomy`'s execution contract**, not
   in `compound.md`. It governs every gate in every command file, and this
   repo has already paid three times for restating a cross-cutting rule at
   each site (see CLAUDE.md § "Every dispatch declares its model").
