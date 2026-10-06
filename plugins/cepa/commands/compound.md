---
description: Document a solved problem with 5 parallel sub-agents. Creates solution docs with bidirectional plan linking.
argument-hint: "[mode:headless]"
allowed-tools: Write, Edit, Bash(git log:*), Bash(git diff:*), Bash(git status:*), Bash(git symbolic-ref:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(git check-ignore:*), Bash(git rev-parse:*), Bash(git hash-object:*), Bash(gh repo view:*), Bash(bash:*), Bash(python3:*), Bash(grep:*)
---

# Compound Documentation

Document a solved problem so that future work benefits from this experience. Uses 5 parallel sub-agents to extract, classify, and write the solution document.

**Announce at start:** "I'm using the cepa:compound command to document this solution."

**Required sub-skill:** Use `cepa:compound-docs` skill for document format and categories.

**Worktree coordinator:** before the first step, apply this command's row
in `cepa:autonomy` §10f. It outranks every write step below.

## Modes

Parse a `mode:headless` token from anywhere in the arguments and strip it.

- **Interactive (default):** run as written below.
- **`mode:headless`** (for callers like `/cepa:lfg` and autonomous
  `/cepa:task`): never prompt. Write the solution doc, plan links, and
  CONCEPTS.md vocabulary updates (Step 4.5 — a silent side effect in every
  mode) exactly as below, but do NOT suggest or perform CLAUDE.md edits —
  return the saved doc path(s), the plan links created, the CONCEPTS.md
  outcome, the commit outcome (Step 4.7 — committed SHA, local-only list,
  or `failed — <reason>`), and the prevention recommendations as structured
  output for the caller's report. Sub-agents return text to this
  orchestrator; only the orchestrator writes files.

## Step 1: Gather Context

Before spawning agents, collect the raw materials:
1. Review the current conversation for the problem that was solved
2. Run `git log --oneline -20` to see recent commits related to this work
3. Run `git diff <trunk>...HEAD` to see the full set of changes — resolve
   `<trunk>` per `cepa:autonomy` §8. On a repo whose work lands on `dev`,
   `main...HEAD` diffs against a deploy branch and sweeps unrelated commits
   into the solution doc.
4. If a plan file path is known (from the conversation), note it for plan-solution linking

## Step 2: Spawn 5 Parallel Sub-Agents

Launch these 5 agents simultaneously using Task tool calls.

**Dispatch each with an explicit `model: sonnet` override** — generic
subagents doing extraction and search, which autonomy §9c places at the
routine tier. §9a is why the override lives here and not in frontmatter.

### Agent 1: Context Analyzer
**Prompt:** "Analyze the conversation context and git history. Extract: (1) What problem was being solved — symptoms, error messages, unexpected behavior. (2) What was tried that didn't work. (3) The timeline of investigation. Return a structured summary."

### Agent 2: Solution Extractor
**Prompt:** "From the conversation and git diff, extract: (1) The root cause of the problem. (2) The exact fix — specific files, lines, and code changes. (3) Why the fix works. (4) Any side effects or trade-offs of the fix. Return structured findings with code snippets."

### Agent 3: Related Docs Finder
**Prompt:** "Search `docs/solutions/` for existing solution documents that relate to this problem. Look for: (1) Similar symptoms. (2) Same files or modules affected. (3) Related patterns or anti-patterns. Return a list of related document paths with brief descriptions of how they relate."

### Agent 4: Prevention Strategist
**Prompt:** "Based on the root cause and fix, determine: (1) How could this have been prevented? (2) Should there be a linter rule, test, or CI check? (3) Should CLAUDE.md be updated with a new rule? (4) Are there other places in the codebase where the same pattern might cause issues? (5) Detection signals: 2-5 concrete, greppable code patterns a review agent should flag when it sees similar code in a future diff — name the exact construct and where it's dangerous, each with one clause on why it fails (per the `cepa:compound-docs` skill's `### The Detection Section` spec; signals for automated reviewers, distinct from the prevention rules for humans). Return concrete prevention recommendations and the Detection signals separately."

### Agent 5: Category Classifier
**Prompt:** "Based on the problem and solution, classify this into one of these categories: build-errors, database-issues, runtime-errors, performance-issues, security-issues, ui-bugs, integration-issues, logic-errors. Also suggest 3-5 tags for the document. Additionally, list candidate domain vocabulary terms this problem involved — entities, named processes, or status concepts whose meaning is project-specific and precise enough that a new engineer would need them defined (per the `cepa:compound-docs` skill's CONCEPTS.md qualifying bar; general programming vocabulary never qualifies). For each candidate: the term and a one-sentence definition drawn from how the code actually uses it. Return the category, tags, and candidate terms (or 'none qualify')."

## Step 3: Assemble Solution Document

After all agents return, combine their outputs into a single document following the `compound-docs` skill format:

```markdown
---
title: [descriptive title]
category: [from Agent 5]
date: YYYY-MM-DD
tags: [from Agent 5]
related: [from Agent 3 — list of related solution paths]
plan: [path to originating plan, if known]
---

# [Title]

## Problem
[From Agent 1 — what went wrong, symptoms, context]

## Investigation
[From Agent 1 — what was tried, timeline]

## Root Cause
[From Agent 2 — why it happened]

## Solution
[From Agent 2 — the fix, with code snippets]

## Prevention
[From Agent 4 — how to prevent recurrence]

## Detection
[From Agent 4 — concrete code patterns review agents should flag, per the
`cepa:compound-docs` Detection spec. Mandatory — a doc without Detection
signals only helps humans who happen to read it. If Agent 4 returned no
signals meeting the spec's bar, re-prompt Agent 4 once with the spec's
example; if still none, write the section with an explicit
`<!-- BACKFILL: no concrete signals extracted -->` marker and flag it in
the Step 5 report. Never invent vague bullets to satisfy the mandatory
rule.]

## Related
[From Agent 3 — links to related solutions]
```

## Step 4: Save and Link

1. Save to `docs/solutions/<category>/<descriptive-filename>.md`
2. Create the category directory if it doesn't exist
3. **Plan-Solution Linking** (if a plan file is identified):
   - Add `plan: docs/plans/YYYY-MM-DD-<name>.md` to the solution's frontmatter
   - Read the plan file and append a `## Solutions` section (or add to existing one):
     ```markdown
     ## Solutions
     - [Solution title](../solutions/<category>/<filename>.md) — YYYY-MM-DD
     ```

## Step 4.5: Vocabulary Capture (CONCEPTS.md)

Reconcile Agent 5's candidate terms against `CONCEPTS.md` at the project
root, following the `cepa:compound-docs` skill's vocabulary-map rules:

1. Drop candidates that fail the qualifying bar or violate the
   stands-on-its-own rules (implementation specifics, config values).
2. **If `CONCEPTS.md` exists:** add missing qualifying terms; refine an
   existing entry only when this solution surfaced new precision. Never
   duplicate a term already covered under another name — add an
   `*Avoid:*` alias instead.
3. **If `CONCEPTS.md` does not exist** and at least one term qualifies:
   create it with the skill's preamble, the qualifying term(s), and the
   core domain nouns of the solved problem's area that meet the bar —
   seeded from that area's declared model (schema, core types, primary
   models) only. Do not reach for repo-wide nouns this run never touched;
   hold borderline terms for a later run.
4. Apply edits silently in both modes — vocabulary capture is a side effect
   of documenting, not a decision the user makes per run. Skip entirely
   (and say so in the report) when no candidates qualify.
5. **Failure is never reported as emptiness.** If the CONCEPTS.md write
   fails, report the outcome as `failed — <reason>` and list the qualifying
   terms so a human can apply them manually — never stop, never prompt. If
   Agent 5's output contains no parseable candidate-terms block, report
   "vocabulary capture skipped — classifier returned no candidates block".
   Neither case may be reported as "no qualifying terms" — that phrase
   claims a scan happened and came up empty.

## Step 4.6: Brain Writeback (optional — participating repos only)

When `cepa.local.md` has an `## Integrations` `brain:` key, mirror this
solution into the cross-repo brain per the **`cepa:brain` skill** (the
canonical contract). No key → skip entirely; the doc on disk is unchanged
and authoritative either way.

1. **Decompose, never post the raw doc.** The Agent Memory API takes typed
   string arrays and rejects (422) content with ≥2 fenced code blocks or
   >15k chars. Map this solution's Root Cause / Solution / Prevention /
   Detection points into the `memory_payload` arrays below as short prose,
   **fenced code stripped**, each string well under 15k (aim < ~500 chars,
   ~3-8 total). Add the qualifying CONCEPTS terms to `lessons`. Name the
   technology inside each string so it stands alone when recalled from
   another repo.

   `memory_payload` is an **OBJECT keyed by memory type, whose values are
   arrays of PLAIN STRINGS** — `lessons`, `constraints`, `failures`
   (also `decisions`, `outputs`, `unresolved_questions`, `next_steps`). It
   is **NOT** a list of `{"type":…,"content":…}` objects; that shape is
   rejected. The API turns each string into one memory row.
2. **PHI scrub** — the gate is in the step-3 block below, and it is
   executable: it detects the forced-on condition, scrubs the payload FILE,
   and suppresses the writeback if the scrub cannot run. Do not re-implement
   it here or treat this step as a separate manual pass. When the scrub is
   forced and what it does and does not redact are the `cepa:brain` skill's
   `## Compliance` section — read it there. Two things worth knowing at this step:
   it redacts numeric patterns ONLY (no names, emails, phones, or
   written-month dates), so a completed scrub never means "this payload is
   safe"; and it runs over the whole file, so ordinary digits in engineering
   prose are redacted as collateral. Count redactions into `scrubbed:` —
   that count is self-reported, as `scrub` emits none.
3. **Write via the vendored client** (never inline the key on a command
   line). Build the payload file with the literal envelope below, then post
   it. **Every field shown is required and the API 400s without it** —
   `schema_version` must be that EXACT literal (it is not a version number
   to choose: `"1.0"`, `"1"`, `"v1"` all 400), and `workspace_id` comes from
   `BRAIN_WORKSPACE_ID`. A 400 here costs more than this call: under the
   mid-run degrade rule it disables the brain for the REST of the run.

   **Build the payload with the Write tool, then run a script — never a
   heredoc.** Two reasons, both of which have already bitten this file:

   - `memory_payload` strings and the doc title are solution-doc prose that
     routinely contains quotes, backslashes, and newlines. Splicing those
     into a heredoc produces invalid JSON that `_assert_envelope` (a
     grep-based presence check, not a JSON validator) passes straight
     through to a 400.
   - A heredoc inside an indented block is a silent killer: the terminator
     must sit at column 0, so a copy that keeps this page's list indentation
     swallows every following line as heredoc body and **exits 0 having done
     nothing**. `<<-` does not save you (it strips tabs, not spaces).

   So: emit the JSON with the **Write tool** (no shell quoting involved at
   all — you are writing a file, and `json`-shaped text is just text), then
   run the steps below. Compute the `idempotency_key` AFTER the payload
   exists — `idkey`'s third argument is the PAYLOAD FILE, so the key hashes
   the strings actually being written, not the source doc.

   **MINT THE PAYLOAD PATH FIRST — run this block BEFORE the Write tool, and
   do not choose the filename yourself.** `mktemp` is what makes the path
   unique per run; a name an agent picks from these instructions is the same
   name a concurrent run picks from the same instructions.

   ```bash
   set -euo pipefail
   # One unique payload path per run. Two concurrent /cepa:compound runs that
   # both chose a conventional name (`payload.json`, `/tmp/payload.json`)
   # collide on the payload AND on every path derived from it — .scrubbed,
   # .phiseal, .resp, .ids — and the gate then fails in BOTH directions
   # (measured, residual 2j):
   #   run A seals 1; run B overwrites the seal with 3; A verifies its own
   #   1-marker payload against 3 -> SUPPRESSED, and the suppression path
   #   rm -f's it. A correctly-scrubbed memory is destroyed and the run
   #   reports "re-Write reintroduced pre-scrub content" — which is false.
   #   Reverse the interleaving and B verifies against A's LOWER seal while
   #   holding raw PHI -> passes. Each suppression path also deletes the
   #   other run's payload mid-flight.
   # mktemp with a template, not a bare name, so the uniqueness is the
   # kernel's rather than the agent's.
   # RUN="<a short id unique to this run>" — substitute it ONCE here, then
   # paste the SAME literal into every later block. It is the run's only
   # cross-block identifier and it is a documented literal, exactly like $REPO
   # and $DOC. Any short unique string works (the branch name, an issue
   # number, a timestamp you read from `date` yourself).
   #
   # DO NOT reach for `$$` here. Each fenced block is a different shell, so
   # `$$` is a different PID in each one and a pointer named with it is
   # unfindable from the next block. Measured 2026-10-03 while writing this
   # block: three bash invocations gave 4064353 / 4064354 / 4064355. That is
   # residual 2g's class — instance 6, inside the fix for 2j — and it is why
   # the identifier is a literal you paste rather than anything the shell
   # derives.
   RUN="<short-run-id>"
   # Validate before composing any path from it. $RUN lands in a filename, so
   # an unsubstituted placeholder or a value carrying `/` or `..` would write
   # the pointer somewhere no later block looks — or outside $TMPDIR entirely.
   # This is autonomy §5's slug discipline applied at the one place this
   # command composes a path from a substituted value.
   case "$RUN" in ''|'<short-run-id>'|*[!A-Za-z0-9._-]*)
     echo "brain writeback ABORTED: substitute RUN with a short id ([A-Za-z0-9._-])." >&2
     exit 1 ;;
   esac
   # allowed-tools note: every verb below (`mktemp`, `printf`, `chmod`, `cat`,
   # `rm`) runs INSIDE this fenced block, so `Bash(bash:*)` is the grant that
   # covers them — the same way the pre-existing `cat`/`rm`/`echo`/`chmod`/`mv`
   # in the later blocks are covered. No per-verb grant is added, and none is
   # needed; recorded here because CLAUDE.md requires re-verifying
   # `allowed-tools` whenever a command body gains a verb, and "checked, the
   # existing grant covers it" is the answer rather than an omission.
   P="$(mktemp "${TMPDIR:-/tmp}/cepa-compound-payload-$RUN-XXXXXX.json")"
   chmod 600 "$P"                 # it will hold doc content; create it private
   # RECORD THE PATH where a LATER BLOCK can read it. The payload is written by
   # the Write tool (no shell at all) and posted from a different fenced block —
   # a different process — so `$P` does not survive to the writeback. Per
   # residual 2g, state crosses a block boundary through the FILESYSTEM or not
   # at all; five instances of that class have shipped on this exact surface
   # before this one.
   # The pointer's name is derivable from $RUN alone, so the next block can
   # FIND it without inheriting anything. That findability is exactly why it
   # cannot also be unique by construction the way `mktemp` is — so the
   # uniqueness has to be CHECKED rather than assumed.
   PTR="${TMPDIR:-/tmp}/cepa-compound-payload-$RUN.path"
   # REFUSE to clobber another run's pointer. $RUN is agent-chosen, and nothing
   # stops two concurrent runs picking the same short id — "A", a shared issue
   # number, the same date. Measured 2026-10-03: minting twice with RUN=A gave
   # two distinct mktemp payloads but ONE pointer, which the second mint
   # overwrote. Run 1's payload was orphaned and BOTH runs' later blocks then
   # read run 2's path — the payloads no longer collide, but the pointer does,
   # which moves residual 2j up one level instead of closing it.
   # Same shape as `scrub-seal`'s refusal to re-seal different content: an
   # existing pointer means another run owns this id, so stop and say so.
   #
   # `set -C` (noclobber) in a SUBSHELL, not `[ -e "$PTR" ]` then write. The
   # test-then-write form is a TOCTOU race: two runs starting together both see
   # no pointer, both write, and the loser is silently orphaned again — the
   # same defect in a smaller window. noclobber makes the create-or-refuse one
   # atomic operation in the kernel. Measured 2026-10-03: 20 concurrent
   # noclobber writers to one path, exactly 1 winner, 19 refused at rc=1.
   # The subshell scopes `-C` so the rest of this block keeps ordinary
   # redirection.
   if ! ( set -C; printf '%s\n' "$P" > "$PTR" ) 2>/dev/null; then
     echo "brain writeback ABORTED: pointer '$PTR' already exists — another" >&2
     echo "  /cepa:compound run is using RUN='$RUN'. Pick a different RUN id." >&2
     echo "  (If it is a leftover from a dead run, remove that file and retry.)" >&2
     rm -f "$P"                     # do not leave this run's payload orphaned
     exit 1
   fi
   chmod 600 "$PTR"
   printf 'payload path: %s\npointer: %s\n' "$P" "$PTR"
   ```

   **If that block exited non-zero, STOP.** Do not Write a payload, do not run
   the next block, and do not report a writeback. Every gate in this phase is
   enforced by a non-zero `exit` from a Bash call, and a non-zero block is a
   hard stop for the step — never a line of output to read past. (This is the
   general rule for every fenced block below too; residual 2l tracks stating it
   once in `cepa:autonomy`'s execution contract rather than per command file.)

   Now **Write the payload JSON to the path that block printed** — the
   `mktemp` path, not a name of your own. Then run the block below.

   ```bash
   set -euo pipefail
   REPO="<repo>"; DOC="<doc-path>"
   # The SAME literal you substituted above. This is the one value that has to
   # be identical across blocks; everything else is re-derived from it.
   RUN="<short-run-id>"
   # Re-read the payload path from the pointer rather than retyping it: a
   # retyped path is an agent-chosen path again, and a typo here operates on a
   # file that does not exist while every later step still reads rc=0 on its
   # own terms.
   case "$RUN" in ''|'<short-run-id>'|*[!A-Za-z0-9._-]*)
     echo "brain writeback ABORTED: substitute RUN with the same short id used" >&2
     echo "  in the path-minting block ([A-Za-z0-9._-])." >&2
     exit 1 ;;
   esac
   PTR="${TMPDIR:-/tmp}/cepa-compound-payload-$RUN.path"
   [ -s "$PTR" ] || { echo "brain writeback ABORTED: no payload pointer at $PTR — run the path-minting block first, with the same RUN id." >&2; exit 1; }
   P="$(cat "$PTR")"
   # CONTAIN the path the pointer names. Its contents are used as a file path,
   # and the pointer sits at a predictable name in a world-writable /tmp — so
   # whatever it holds must be proven to be THIS run's minted payload, not
   # merely readable. Without this, a pointer aimed at an unrelated file makes
   # the scrub rewrite that file in place and a later suppression `rm -f` it:
   # measured 2026-10-03, the seal reported success on a file outside the
   # minted prefix. Same discipline `brain-client.sh` already applies to
   # `.phiseal` ("the path is predictable"), applied to the pointer.
   case "$P" in
     "${TMPDIR:-/tmp}/cepa-compound-payload-$RUN-"*.json) : ;;
     *) echo "brain writeback ABORTED: pointer names '$P', which is not this" >&2
        echo "  run's minted payload (expected ${TMPDIR:-/tmp}/cepa-compound-payload-$RUN-*.json)." >&2
        echo "  Refusing to operate on it." >&2
        exit 1 ;;
   esac
   [ -f "$P" ] && [ ! -L "$P" ] || { echo "brain writeback ABORTED: payload '$P' is not a regular file." >&2; exit 1; }
   [ -s "$P" ] || { echo "brain writeback ABORTED: payload '$P' is missing or empty — the Write step did not land on the minted path." >&2; exit 1; }
   # BRAIN_WORKSPACE_ID comes from the gitignored repo-root .env.local. In a
   # linked git worktree that file does NOT exist — it lives only in the main
   # checkout — so resolve it via git-common-dir rather than assuming `./`.
   # BRAIN_ENV_FILE wins when set, matching brain-client.sh's _load_env
   # precedence; diverging here loads different credentials than the client
   # uses on the very same run.
   ENVF="${BRAIN_ENV_FILE:-}"
   if [ -z "$ENVF" ]; then
     ENVF=".env.local"
     [ -f "$ENVF" ] || ENVF="$(git rev-parse --path-format=absolute --git-common-dir)/../.env.local"
   fi
   set -a; . "$ENVF"; set +a
   # Resolve the plugin root — do NOT spell "${CLAUDE_PLUGIN_ROOT}/scripts/…"
   # here. That variable is NOT exported into the shell this block runs in, so
   # the expansion becomes "/scripts/brain-client.sh" and the call exits 127
   # with "No such file or directory". That signature reads as a MISSING
   # BINARY, and reporting it as one is how 42 review files in artist360 came
   # to carry a false "brain unreachable" claim while the service was live
   # (artist360: docs/solutions/integration-issues/
   #  false-unavailable-from-missing-cli-path-and-untracked-credential.md).
   # resolve-plugin-root.sh is self-locating, so the ONLY absolute path needed
   # is the resolver's own; find it the same way, then let it do the rest.
   for R in "${CEPA_PLUGIN_ROOT:-}/scripts/resolve-plugin-root.sh" \
            "${CLAUDE_PLUGIN_ROOT:-}/scripts/resolve-plugin-root.sh" \
            "$HOME"/.claude/plugins/marketplaces/*/plugins/cepa/scripts/resolve-plugin-root.sh \
            "${CEPA_DEV:+$(git rev-parse --show-toplevel 2>/dev/null)/plugins/cepa/scripts/resolve-plugin-root.sh}"; do
     [ -f "$R" ] && . "$R" && break     # sets $CEPA_ROOT
   done
   # Fail LOUDLY and STOP. An unresolved client must never be reported as a
   # brain outage, and must never fall through to "wrote 0 rows" at exit 0.
   [ -n "${CEPA_ROOT:-}" ] || {
     echo "brain writeback ABORTED: cannot resolve the cepa plugin root." >&2
     echo "  This is PATH RESOLUTION, not a service outage. Do not record the" >&2
     echo "  brain as unavailable. Set CEPA_PLUGIN_ROOT and re-run." >&2
     exit 1
   }
   CLIENT="$CEPA_ROOT/scripts/brain-client.sh"
   [ -x "$CLIENT" ] || { echo "brain writeback ABORTED: $CLIENT is not executable" >&2; exit 1; }
   chmod 600 "$P"                              # payload holds doc content

   # PHI SCRUB — executable, not a reminder. ASK THE CLIENT; do not re-derive
   # the condition here. `brain-client.sh scrub-required` is the single
   # executable home of the rule the cepa:brain skill's `## Compliance`
   # section defines — including the permissive matching and the
   # gitignored-in-a-worktree path resolution, both of which have their own
   # measured history. This command and compound-refresh.md each carried their
   # own copy of that logic and DIVERGED (residual 2h); the verb exists so
   # there is one answer, not two.
   #
   # THREE outcomes, and the third is the one that matters:
   #   0 = required   1 = not required   2 = CANNOT DECIDE -> refuse to send
   # Never collapse 2 into 1. An unresolvable cepa.local.md is exactly the
   # state that must not fall through to the unscrubbed path.
   FORCE_SCRUB=0
   set +e
   bash "$CLIENT" scrub-required >/dev/null 2>&1
   _sr_rc=$?
   set -e
   case "$_sr_rc" in
     0) FORCE_SCRUB=1 ;;
     1) FORCE_SCRUB=0 ;;
     *) echo "brain writeback ABORTED: scrub-required could not evaluate the" >&2
        echo "  forced-scrub condition (rc=$_sr_rc). Refusing to send." >&2
        rm -f "$P" "$PTR"                     # payload and its pointer
        exit 1 ;;
   esac
   if [ "$FORCE_SCRUB" = 1 ]; then
     # Scrub to a sidecar. Do NOT mv it over the original: a failed mv leaves
     # the pre-scrub payload in place — intact and non-empty, so
     # _assert_envelope passes it and unscrubbed content egresses with every
     # exit code reading 0 (measured 2026-09-26).
     bash "$CLIENT" scrub "$P" "$P.scrubbed" || {
       echo "brain writeback SUPPRESSED: PHI scrub failed; not sending" >&2
       echo "  unscrubbed. Record it in suppressed_writebacks:." >&2
       rm -f "$P" "$PTR"                       # unscrubbed bytes must not linger
       exit 1
     }
     chmod 600 "$P.scrubbed"
     # An EMPTY sidecar means the scrub produced nothing while still exiting
     # 0. Check BEFORE installing: `cat empty > "$P"` succeeds, so the || gate
     # cannot see it, and the payload is silently destroyed. _assert_envelope
     # would reject it one verb later as a confusing empty-envelope error,
     # after the sidecar is deleted and the evidence is gone.
     [ -s "$P.scrubbed" ] || {
       echo "brain writeback SUPPRESSED: the scrub produced an EMPTY payload." >&2
       echo "  The payload was removed; regenerate from $DOC to retry." >&2
       rm -f "$P" "$P.scrubbed" "$PTR"; exit 1
     }
     # Install with mv, and KEEP THE SAME PATH. Two reasons for each half:
     # mv is atomic within a directory, so it can never leave a truncated
     # payload the way a `cat >` redirect can; and the same path means the
     # writeback — which runs in a LATER fenced block, a different shell
     # where $P is unset — still finds the scrubbed bytes. It also leaves no
     # unscrubbed copy at rest on a HIPAA repo's disk.
     mv -f "$P.scrubbed" "$P" || {
       echo "brain writeback SUPPRESSED: could not install scrubbed payload." >&2
       echo "  The payload was removed; regenerate from $DOC to retry." >&2
       rm -f "$P" "$P.scrubbed" "$PTR"; exit 1
     }
     chmod 600 "$P"                            # mv carries the mode; be explicit
   fi

   git hash-object "$DOC"                      # blob SHA for the source_refs uri
   # idkey AFTER the scrub — it hashes $P's bytes, and the scrub changes them.
   # Keyed on pre-scrub bytes, the key would describe content never sent and
   # the dedup it exists for would break.
   bash "$CLIENT" idkey "$REPO" "$DOC" "$P"    # -> idempotency_key (hashes $P)

   # SEAL the redaction count before the agent's re-Write. This is the gate's
   # first half; `scrub-verify` in the step-4 block is the second. The next
   # thing that happens is an agent editing $P by hand while still holding the
   # PRE-scrub strings in context — the one step where the agent's own context
   # is the contamination source — and the writeback runs in a LATER fenced
   # block, a different shell where $P and any count variable are unset. So the
   # count goes to a FILE ($P.phiseal) and is re-read there. Do not "simplify"
   # this into a variable: that is residual 2g's class, which has shipped four
   # times on this exact surface.
   #
   # Seal UNCONDITIONALLY, not only under FORCE_SCRUB. On a no-scrub repo the
   # seal is 0 and verify trivially passes; gating the seal on FORCE_SCRUB
   # instead leaves NO seal on the scrubbed path if the flag is ever misread,
   # and a missing seal is what scrub-verify must treat as unevaluable.
   bash "$CLIENT" scrub-seal "$P" || {
     echo "brain writeback SUPPRESSED: cannot seal the redaction count, so" >&2
     echo "  re-Write contamination would be unverifiable. Record it in" >&2
     echo "  suppressed_writebacks:." >&2
     rm -f "$P" "$P.phiseal" "$PTR"; exit 1
   }
   ```

   Write the SHA into `source_refs[0].uri` as `<repo>:<doc-path>@<sha>` and
   the idkey into `idempotency_key`, then re-Write the payload file. Its shape:

   > **If the scrub ran, do NOT regenerate this file from the payload you
   > built earlier.** Those strings are the PRE-scrub ones and you still hold
   > them; re-emitting them silently undoes the redaction and posts the raw
   > content. **Read the file back from `$P` first** and edit only the two
   > fields — everything else must be the bytes the scrub produced.
   >
   > This is no longer on your honour: the block above sealed the redaction
   > count to `$P.phiseal`, and the step-4 block re-counts and **suppresses the
   > writeback if it fell**. Edit only the two fields and the gate passes. Do
   > not touch or delete `$P.phiseal` — a missing seal is unevaluable, which
   > suppresses the writeback just as a failed count does.

   ```json
   {"schema_version": "openbrain.agent_memory.writeback.v1",
    "workspace_id": "<from BRAIN_WORKSPACE_ID>",
    "project_id": "<repo>",
    "idempotency_key": "<from idkey>",
    "runtime": {"name": "cepa-compound"},
    "source_refs": [{"kind": "solution-doc", "uri": "<repo>:<doc-path>@<sha>",
                     "title": "<doc title>"}],
    "memory_payload": {"lessons": [], "constraints": [], "failures": []}}
   ```

   Each `source_refs` element **requires** `kind` (an element without it
   400s); `uri` packs repo+path+blob-SHA so provenance survives file moves.
   The `idempotency_key` is a CONTENT hash and is the BASE only — the API
   appends its own row index (`<base>:<n>`), so never add an index yourself.
   Unchanged docs dedup; edited docs get new rows.
4. **Post once, then promote every returned id — the rows are invisible
   until you do.** Writeback stamps each row `review_status: pending`, which
   recall DROPS, so an unpromoted write is indistinguishable from no write at
   all. Post the payload EXACTLY ONCE and keep that response; re-posting to
   re-read the ids spends a second call and discards the first response's ids.

   ```bash
   # THE RE-WRITE GATE, second half. $P was sealed before the agent edited it;
   # re-count now and refuse to send if the redactions fell. This must run
   # IMMEDIATELY BEFORE writeback and after every edit to $P — anything between
   # the check and the call is unchecked, which is the whole defect being
   # closed. $P and $CLIENT are re-resolved here because this is a DIFFERENT
   # SHELL from the block above: nothing crosses that boundary except the files
   # themselves (residual 2g).
   #
   # rc=1 means contamination (markers fell); rc=2 means the gate could not be
   # evaluated (seal missing, empty, or non-numeric). BOTH suppress. Do not
   # collapse 2 into "nothing to check" — an unevaluable gate that passes is
   # the unscrubbed-egress path this exists to close.
   # RE-RESOLVE, do not inherit. `$CEPA_ROOT` and `$CLIENT` were assigned in
   # the step-3 block and are UNSET here. Writing `CLIENT="$CEPA_ROOT/..."`
   # expands to "/scripts/brain-client.sh" and exits 127 — the signature that
   # reads as a missing binary and put a false "brain unreachable" claim into
   # 42 review files. Measured again 2026-10-02 while writing this block: under
   # `set -u` it dies "CEPA_ROOT: unbound variable"; without it, rc=127. This
   # block previously used a bare `$CLIENT` for exactly this reason-shaped
   # defect, so the resolver is repeated rather than assumed.
   # Same RUN literal as the earlier blocks, and the payload path is re-read
   # from the pointer — never retyped. Retyping it reintroduces the
   # agent-chosen path residual 2j is about, and a path that does not exist
   # makes `scrub-verify` report rc=2 "unevaluable" for a run whose payload was
   # in fact perfectly clean.
   RUN="<short-run-id>"
   # Validate HERE too, not only in the minting block. Each block composes
   # $PTR from $RUN independently, so a guard that lives in one block leaves
   # the other two deriving the same path unchecked — the asymmetry residual 2g
   # is about. Latent today (an invalid $RUN makes the pointer lookup miss and
   # abort), but any future change to how $PTR is built would turn that safe
   # abort into an unguarded path composition.
   case "$RUN" in ''|'<short-run-id>'|*[!A-Za-z0-9._-]*)
     echo "brain writeback ABORTED: substitute RUN with the same short id used" >&2
     echo "  in the path-minting block ([A-Za-z0-9._-])." >&2
     exit 1 ;;
   esac
   PTR="${TMPDIR:-/tmp}/cepa-compound-payload-$RUN.path"
   [ -s "$PTR" ] || { echo "brain writeback ABORTED: no payload pointer at $PTR (same RUN id as the earlier blocks?)." >&2; exit 1; }
   P="$(cat "$PTR")"
   # Contain it, exactly as the step-3 block does — see the rationale there.
   case "$P" in
     "${TMPDIR:-/tmp}/cepa-compound-payload-$RUN-"*.json) : ;;
     *) echo "brain writeback ABORTED: pointer names '$P', which is not this" >&2
        echo "  run's minted payload. Refusing to operate on it." >&2
        exit 1 ;;
   esac
   [ -f "$P" ] && [ ! -L "$P" ] || { echo "brain writeback ABORTED: payload '$P' is not a regular file." >&2; exit 1; }
   [ -s "$P" ] || { echo "brain writeback ABORTED: payload '$P' is missing or empty." >&2; exit 1; }
   # CLEAN UP ON EVERY EXIT, via a trap rather than per-branch `rm -f`. This
   # block has ten `exit 1` paths (resolver unresolved, gate suppressed,
   # writeback non-2xx, unparseable response, …) and before the trap only ONE
   # of them removed anything — measured 2026-10-03. Every other failure left
   # $P, holding scrubbed solution-doc content, plus the pointer, sitting in
   # /tmp at mode 600 after the run. A per-branch rm is a list that has to stay
   # complete as branches are added; a trap is the mechanism.
   # Set AFTER the containment checks above, so a refused pointer can never
   # make the trap delete a file this run does not own.
   trap 'rm -f "$P" "$P.phiseal" "$P.resp" "$P.ids" "$PTR"' EXIT
   for R in "${CEPA_PLUGIN_ROOT:-}/scripts/resolve-plugin-root.sh" \
            "${CLAUDE_PLUGIN_ROOT:-}/scripts/resolve-plugin-root.sh" \
            "$HOME"/.claude/plugins/marketplaces/*/plugins/cepa/scripts/resolve-plugin-root.sh \
            "${CEPA_DEV:+$(git rev-parse --show-toplevel 2>/dev/null)/plugins/cepa/scripts/resolve-plugin-root.sh}"; do
     [ -f "$R" ] && . "$R" && break     # sets $CEPA_ROOT
   done
   [ -n "${CEPA_ROOT:-}" ] || {
     echo "brain writeback ABORTED: cannot resolve the cepa plugin root." >&2
     echo "  This is PATH RESOLUTION, not a service outage. Do not record the" >&2
     echo "  brain as unavailable. The payload is left in place; set" >&2
     echo "  CEPA_PLUGIN_ROOT and re-run this block." >&2
     exit 1
   }
   CLIENT="$CEPA_ROOT/scripts/brain-client.sh"
   [ -x "$CLIENT" ] || { echo "brain writeback ABORTED: $CLIENT is not executable" >&2; exit 1; }
   bash "$CLIENT" scrub-verify "$P" || {
     echo "brain writeback SUPPRESSED: the re-Write reintroduced pre-scrub" >&2
     echo "  content, or redaction survival could not be evaluated. NOT" >&2
     echo "  sending. Record it in suppressed_writebacks: and regenerate the" >&2
     echo "  payload from the scrubbed file rather than from context." >&2
     rm -f "$P" "$P.phiseal" "$PTR"   # contaminated bytes must not linger
     exit 1
   }
   rm -f "$P.phiseal"                 # consumed; a stale seal must not outlive it

   # A non-2xx writes an ERROR BODY to $P.resp and exits nonzero. Without this
   # branch the next line's parse dies on a missing "memories" key, $P.ids
   # ends up empty, and the promote loop runs zero times and exits 0 — a
   # failed write that is bash-indistinguishable from "wrote 0 rows". THIS
   # branch is what makes the mid-run degrade rule fire at all.
   if ! bash "$CLIENT" writeback "$P" > "$P.resp"; then
     echo "brain writeback FAILED: $(cat "$P.resp")" >&2
     # degrade the provider for the rest of the run; do NOT parse. Rows the
     # API committed before a mid-loop 5xx are NOT recoverable — it discards
     # its created[] on error — so record the doc as needing a re-run (the
     # stable idkey makes that safe) rather than reporting a clean write.
     exit 1
   fi
   # jq is NOT available on every operator host — parse with python3.
   if ! python3 -c "import json,sys; print('\n'.join(m['memory_id'] for m in json.load(open(sys.argv[1]))['memories']))" "$P.resp" > "$P.ids"; then
     echo "brain writeback response UNPARSEABLE: $(cat "$P.resp")" >&2
     exit 1
   fi
   # `|| [ -n "$id" ]` is REQUIRED, not defensive style: a bare `while read`
   # discards a final line with no trailing newline, so the last row is
   # never promoted and stays invisible in `pending` forever — a silent,
   # partial success that looks exactly like a clean run. (Reproduced live
   # 2026-08-22: 2 rows written, 1 promoted, 1 stranded.)
   total=0; promoted=0
   while read -r id || [ -n "$id" ]; do
     [ -n "$id" ] || continue
     total=$((total+1))
     if bash "$CLIENT" review "$id" evidence_only >/dev/null; then
       promoted=$((promoted+1))
     else
       echo "STRANDED: memory_id=$id failed to promote" >&2
     fi
   done < "$P.ids"
   [ "$promoted" -eq "$total" ] \
     || echo "brain writeback: $((total-promoted)) of $total ids stranded in pending" >&2

   # No explicit cleanup here: the EXIT trap set at the top of this block
   # already removes $P, .phiseal, .resp, .ids and the pointer, and it fires on
   # the success path as well as on all ten failure paths. A second copy would
   # be a list to keep in sync with the trap for no benefit.
   ```

   The counters are the mechanism, not a reminder: report `written: $promoted`
   and count any shortfall under `suppressed_writebacks`. A 422/oversize
   string is a recorded skip, never silent.

   The full contract is in the `cepa:brain` skill; this is its writeback
   half made copyable. If the two ever disagree, the skill governs.
5. **Retire prior versions on edit → `mark_stale` (not supersede) — but only
   from ids you already hold.** `mark_stale` takes a `memory_id`, and
   **recall cannot give you one by source path**: per the `cepa:brain` skill's
   response-shape rule, `source_refs` is never projected into a recall
   response and `source.uri` is null on every hit, so there is nothing
   path-scoped to select on. Re-measured 2026-09-26 against the deployed
   service: 5 hits, `source_refs` absent on all, `source.uri` null on all,
   `scope.project_id` the only provenance returned.

   So:
   - **Ids in hand** (this run posted them, or they are recorded in the doc's
     own Run Metadata / residual shard): `PATCH review mark_stale` each one,
     THEN write the current strings (their new content hash makes them new
     rows).
   - **No ids** (the usual case for a doc edited by a later run): you CANNOT
     retire the pre-edit rows. Write the new strings anyway — recall serving
     both versions beats losing the current one — and record
     `mark_stale: skipped — no path-identifiable prior rows` in the `brain`
     Run Metadata block. Never report the write as clean: an unretired
     pre-edit row keeps being served, which is the staleness this step exists
     to prevent.

   **Do not invent a lookup to work around this.** A recall filtered on
   `scope.project_id` returns every memory this repo ever wrote, not this
   doc's — stale-marking those would retire unrelated rows. Until the API
   projects provenance or exposes a by-source query, partial retirement is
   the honest ceiling.

   (OB1's `supersede` action is a no-op without a related id — use `mark_stale`.)
6. Record the outcome in the `brain` Run Metadata block; for interactive
   runs with no findings file, append a one-line record to the run's
   residual shard (`cepa:autonomy` §5 sink 1)
   for any strip/suppression/scrub. A brain failure degrades (grep-only
   world continues) and loses nothing — the file is source-of-truth.

Compliance: writeback happens ONLY for a repo that declares the `brain:`
key (opt-in, fail-closed) — and for a `## Compliance` repo the PHI scrub is
mandatory (step 2). A repo without the `brain:` key is never written,
regardless of content.

## Step 4.7: Commit the Artifacts (headless mode)

In headless mode, the artifacts must not be left uncommitted — a caller
pipeline (`/cepa:lfg`) runs this command after its push, and an uncommitted
artifact gets autostashed by the next run's git audit, so the compounding
output would structurally never ship.

1. Identify what this command wrote: the solution doc, the plan file (if a
   `## Solutions` link was added), and CONCEPTS.md (if Step 4.5 touched it).
2. Drop anything gitignored (`git check-ignore <path>` — some repos ignore
   `docs/` entirely); those are reported as local-only, never force-added.
3. If anything tracked remains: stage ONLY those files, commit
   `docs(compound): <solution title>`, and push when the current branch has
   an upstream. A failed commit or push is reported as
   `commit: failed — <reason>` with the file list — never silently dropped.

Interactive mode skips this step — the user decides when to commit.

## Step 5: Report

Present to the user:
- Summary of what was documented
- File path where the solution was saved
- Any plan-solution links created
- CONCEPTS.md outcome: created (N entries), updated (terms added/refined), no qualifying terms, vocabulary capture skipped (no candidates block), or failed — reason + terms for manual apply
- Commit outcome (headless): committed SHA + files, local-only (gitignored) list, or failed — reason
- Prevention recommendations that might warrant CLAUDE.md updates
- Say: "Solution documented. Consider running `/claude-md-management:revise-claude-md` if prevention rules should be added to CLAUDE.md."
