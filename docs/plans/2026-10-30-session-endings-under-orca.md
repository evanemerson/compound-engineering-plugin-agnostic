# Session endings under Orca — research and one recommended rule

Date: 2026-10-30 · Author: coord@main (compound-engineering) · Status: proposal, no rule changed

## 1. The problem, restated

Almost every turn ends with `## Next steps` and `My read: N`. In Orca's Agent
Dashboard every turn end lands in DONE, so a real decision written as text sits
among finished work. NEEDS YOU stays empty. Two L61 examples (artist360, PR
#826, tab1@merch-builder-v2) show both halves: decisions that sat in DONE, and
coordinator steps that were listed but never sent.

## 2. Orca findings

Orca 1.4.244 on WSL (`orca-ide`). "Verified" means measured on this machine or
read in Orca's installed code; the source is named.

| # | Finding | Status | Source |
|---|---|---|---|
| O1 | A card's bucket comes from the agent's state: `blocked` or `waiting` → **needs-you**; `working` → **working**; `done` → **done**, or **rest** when the turn's outcome is `cancellation`/`superseded`. A terminal with no agent status reads **rest**. | verified (code) | `orcad-server.js`, functions `Nq`, `fhs`, `o4t` |
| O2 | The popout groups cards as **Needs You** (attention), **Working**, **Idle**. A NEEDS YOU card is one of three kinds: `permission` ("Needs approval"), `question` ("Needs an answer"), `auth` ("Sign-in required"). | verified (code) | renderer `App-*.js`, `Rge`, `dashboardPopout.bucket.*` |
| O3 | Claude reports state through hooks. `~/.claude/settings.json` sends every event (incl. `PermissionRequest`, `Elicitation`, `Stop`, `StopFailure`) to `~/.orca/agent-hooks/claude-hook.sh`. For Claude, `Stop`/`StopFailure` ends the turn → `done`. A pending tool prompt is registered with kind `question` for `AskUserQuestion` and `approval` for any other tool. | verified (code + settings.json) | `F1s`, prompt registry `e5e.register`; settings.json:45-234 |
| O4 | **AskUserQuestion in a terminal session shows as NEEDS YOU.** Throwaway probe (Haiku, `--surface terminal`, `.claude/worktrees/integrity`): state `waiting`, `toolName: AskUserQuestion` while the question was open; `working` after the answer; `done` after its one-line text reply. | verified (measured 15:13–15:14 CDT) | `orca-ide worktree ps --agent-wait --json` |
| O5 | A turn that ends with options written as text lands in **done**, not needs-you (same probe, its final text turn). | verified (measured) | same |
| O6 | AskUserQuestion in **Chat UI**: not testable here. `agent launch --surface chat` refused: "Claude can't open as a chat here because this workspace runs under WSL." The prompt registry is not surface-specific, so it probably behaves the same. | **not verified** | launch error `agent_launch_surface_unavailable` |
| O7 | Orca's **dispatched-worker preamble forbids AskUserQuestion**: "Use this instead of AskUserQuestion: that opens a local prompt the coordinator cannot see or answer… Send every question through `ask`." | verified (code) | worker preamble template in `orcad-server.js` |
| O8 | `ask` goes to the worker's **coordinator**, which answers with `reply`; a timeout leaves one durable pending question. Gates are only for a coordinator's Task-DAG decisions ("Do not create a gate merely to answer a worker's `ask`"). Neither reaches the operator by itself. `worker_done` settles a Dispatch; it is not a question. | verified (guide) | `skills get orchestration`, `references/messaging-and-gates.md` |
| O9 | A worker blocked in `ask` is running a Bash command, so its own card reads **working**, not needs-you. The question is visible only in the coordinator's inbox. | inferred from O1/O3; not measured | — |
| O10 | No supported way for a finished session to leave DONE. **rest** happens only for a cancelled/superseded turn. `worktree set --read/--workspace-status` changes the workspace, not the agent card. | verified for `rest` (code); `--read` effect **not verified** | `o4t`; `worktree set --help` |
| O11 | `send` proves enqueue only. A send to a terminal handle (not `run:`/`dispatch:`) is a **terminal-only mailbox**, lost if the terminal closes. Wake/nudge is best-effort. | verified (send receipt `legacy_terminal_recipient`; guide) | L15 send, 2026-10-30 |

### What this means for the model

- Only a pending tool prompt puts a card in NEEDS YOU. Writing options as text never does (O3, O5).
- DONE cannot be emptied. Every finished turn lands there (O1, O10). The fix is to move real questions OUT of DONE, not to make DONE quiet.
- Under a dispatched worker, AskUserQuestion is the wrong tool (O7). The worker's question goes to its coordinator, and the coordinator is the one that asks the operator.

## 3. The L61 trace — did the coordinator steps arrive?

Measured through Orca's read-only views (`worktree ps`, `terminal list`, `search`). Nothing ran in artist360.

1. tab1@merch-builder-v2 (pane `772077ee`) ended `done`. Its listed steps for coord@merch-builder-v2 and coord@main were **not sent** at that point.
2. It sent to artist360's coord@main (`term_e83d28c6`) only after the operator typed **"send this to coord@main"**. Its reply says `accepted: true`, queued only.
3. artist360's coord@main relayed the R16/R5 decisions to the operator at 19:36 UTC **as text** ("Worker recommends the notice. 2. R5 — …"), so they landed in DONE again.
4. coord@merch-builder-v2 (pane `2077a934`) started on #826 after a typed prompt: **"Check your Orca inbox: coord@main sent '#826 L61 ready to merge'…"**. Whether the operator or coord@main typed it (`terminal send`) is **not verified**.

**Why the steps did not arrive by themselves:**

- **No rule covered them.** cepa §12b rule 1 sends only "a block addressed to a coordinator" or a `/cepa:handoff` prompt. A `## Next steps` item is neither. The global "Deliver prompts and handoffs through Orca" rule (CLAUDE.md:194-224) was written the same day and covers "prompts", not list items. And the tab1 session was likely started before it.
- **A sent message does not start the recipient's turn.** It sits in the recipient's mailbox until that session checks. With an idle session, someone has to prompt it (O11).
- **The double Handoff block** comes from three rules that each print one: global CLAUDE.md:81 ("End EVERY reply with the Handoff block"), §12b rule 1's printed copy, and `/cepa:handoff`'s prompt block (handoff.md:772-801). Nothing says "once per reply".

## 4. Rule inventory

Abbreviations: G = `~/.claude/CLAUDE.md`, A = cepa `skills/autonomy/SKILL.md` (1.36.0), H/T/L/R/Tr = cepa `commands/handoff|task|lfg|review|triage.md`. No output style exists (`~/.claude/output-styles/` is absent; no `outputStyle` key). No registered hook injects text (all hooks are telemetry).

| File:line | Rule (short quote) | Ending it forces |
|---|---|---|
| G:41, 81-90 | worker "End EVERY reply with the Handoff block. It replaces `## Next steps`" | worker: Handoff every reply |
| G:93-99 | "`Decisions` is optional… Never merge, deploy, another PR" | Handoff field rules |
| G:100 | "When your task is done, stop." | worker stops |
| G:170-192 | Next-steps item that starts work: session, prompt in a ```markdown block, starting state | coordinator Next steps shape |
| G:194-224 | "When Orca is available, the session delivers the prompt itself… Keep the record… 'Sent via Orca — do not paste'" | send + print |
| G:203-208 | worker launch via `orca-ide agent launch` | launch verb (differs from A:1615) |
| G:258-259 | review residuals: "list as numbered next steps" (worker: `Decisions`) | Next steps / Decisions |
| G:293-299 | "Run [`/cepa:handoff`] whenever a session is ending for context reasons… do not reason… skip it" | /cepa:handoff at end |
| G:561-564 | "Present options as a numbered list… User responds with just the number" | numbered choices |
| G:596-606 | ASD-STE100: "Tell me: 1. What you did. 2. If it worked. 3. What I do now." + recommend an option | report shape |
| G:610-646 | "End every substantive response with a `## Next steps`… only place a decision may live… Stop here… `My read: N`"; skip only for a factual answer or "stop" | coord/solo: always Next steps |
| A:405-463 | §6: one final report, `## Next steps` tail required, Stop here, `My read`; does NOT govern gated mid-run gates | Next steps |
| A:415-418, 1068-1089 | worker: Handoff block "in place of" Next steps; completion token follows it | worker Handoff |
| A:330-331 | residuals "the agent never stops to ask" | no ask (residuals) |
| A:1588-1614 | §12b rule 1: send to the coordinator, then print the block, first line `Sent to coord@main via Orca — do not paste.`; operator-addressed blocks are printed only | send + print |
| A:1645-1662 | §12b rule 3: `worker_done` body = summary + Handoff; rule 4: gated worker decisions via Orca `ask`, full → `Decisions` | worker_done / ask |
| H:4, 25-30 | `disable-model-invocation: true`; "does not self-invoke" | model cannot run it (conflicts G:293) |
| H:754-808 | report + tail, THEN the handoff prompt block; under Orca sent and printed | prompt after tail |
| T:28-29, 553-579 | gated gates use AskUserQuestion; final tail with Stop here + My read | Next steps |
| L:397-408 | §6 tail, then `<promise>DONE</promise>` | Next steps + token |
| R:699-745 | interactive Step 6 tail; collapse to one "Stop here" item when clean | Next steps |
| Tr:64-79, 141-146 | batch table "Reply with: 'fix 3, 7'…"; interactive AskUserQuestion | reply prompt / ask |
| sweep:459-470; plan-review:169-176; compound:713-722; compound-refresh:472-485; setup:200-214 | each ends its own way (no §6 tail, or no My read) | mixed |
| farmtender-laravel/CLAUDE.md:61-104 | always Next steps, "3 items minimum, 5 maximum", Stop here, My read; no worker carve-out | Next steps, all roles |
| contexthub/CLAUDE.md:947 | "list other items as numbered next steps" (no worker carve-out) | Next steps |
| ci-ops-self-hosted/CLAUDE.md:242-243 | inherits the global numbered options | — |
| helm/CLAUDE.md:59 | "plan then STOP for approval" | stop and ask |
| dpc-pro-marketing/CLAUDE.md:50-56 | "ASK the user whether to apply…" (repo is `autonomy: full`) | mid-task ask |
| dpc-pro/CLAUDE.md:681 | "Ask first — it is a production write." | ask |
| cepa.local.md `autonomy:` | `full`: artist360, artist360-www, contexthub, dpc-insider-www, dpc-pro, dpc-pro-docs, dpc-pro-marketing, kcprimetime, youtube. `gated`: helm, hillberry-app, leftl.ink. Default gated elsewhere. | gated vs full |

Repos with no CLAUDE.md and no cepa.local.md (22) inherit only the global file.

## 5. Conflicts and which side wins

| # | Conflict | Winner under Orca | Why |
|---|---|---|---|
| C1 | G:613 "always Next steps, the only place a decision may live" vs O3/O5 (text options never reach NEEDS YOU) | the new rule (§6 below) | the dashboard is the operator's triage surface; a text question is invisible there |
| C2 | G:81 "End EVERY reply with the Handoff block" vs A:1593 printed copy and H:772 prompt block → duplicate blocks | one Handoff block per reply | duplicates are noise and invite pasting twice |
| C3 | G:293 "run `/cepa:handoff`" vs H:4 `disable-model-invocation` | H:4 (operator triggers it) | the model cannot run it; G should say "ask the operator to run it" |
| C4 | A:1611 "operator-addressed blocks printed only" vs G:196-198 "deliver every prompt by Orca" | G's intent, narrowed: send whatever has a session to receive it | a step for another session that is only printed is lost (L61) |
| C5 | O7 (worker: never AskUserQuestion) vs Evan's model B for every session | O7 for dispatched workers; B for all others | a dispatched worker's local prompt blocks a session the coordinator cannot see |
| C6 | A:330 "never stops to ask" (full) vs model B | B at the **final** turn only | asking at the end stalls nothing; mid-run asking under `full` stays forbidden |
| C7 | farmtender "3–5 items, always" and contexthub:947 vs the worker Handoff rule and vs B | the new rule | fixed counts force padding; no worker carve-out |
| C8 | G:203-208 `agent launch` vs A:1615 `worker-start` | both, by purpose | `worker-start` for a supervised Dispatch (coordinator waits); `agent launch` for an unsupervised hand-off |
| C9 | G:217 "Sent via Orca — do not paste" header vs A:1597 `Sent to coord@main via Orca — do not paste.` | A's wording, one header | two spellings of one marker |

## 6. Testing the model (A–E)

The operator's model is mostly right. Four corrections:

1. **A and D are the same bucket.** Both land in DONE (O1). D is not a separate ending. It is an optional record section that may appear in any ending, as long as it asks nothing.
2. **E is not an alternative. It is a duty.** Work for another session must be delivered whatever the ending is. A session can need nothing from the operator (A) and still owe two sends (E). So the ending has two parts: **who must act now** (nobody / the operator / a coordinator) and **what was delivered**.
3. **B is wrong for a dispatched worker** (O7). Its decisions go to its coordinator (C), and the coordinator does B.
4. **B under `full` autonomy**: allowed at the final turn only (C6). Mid-run asks stay forbidden.

Also: B blocks the session until the operator answers. That is the point (the card stays in NEEDS YOU), but it means a B ending must put everything else (record, sends, Handoff) BEFORE the question, because the question is the last action.

## 7. Recommended rule — cepa `autonomy` §12b rule 7 (exact wording)

> **7. How a turn ends under Orca.** When §12a printed `ORCA: present`, this
> rule replaces §6's `## Next steps` tail and any repo or global rule that
> requires one. It does not change §10d, the Handoff block.
>
> **First line, always:** `Needed from you: nothing` or
> `Needed from you: <one line>`.
>
> **Then pick exactly one kind, by who must act now:**
>
> - **Nobody.** Write the body. A worker ends with its Handoff block. Others end
>   with no tail: no numbered options, no `My read`, no `Stop here`.
> - **The operator.** Use this only for a decision that the operator alone can
>   make, that no rule or residual can settle, and that is not about another
>   session's PR. Write the body. Then, as the turn's LAST action, call
>   AskUserQuestion: one question, at most 3 options, your pick first with
>   "(Recommended)" in its label. Do not also write the options as text. Under
>   `full` autonomy, ask only at the end of a finished run, never mid-run.
>   With no AskUserQuestion tool (headless), file the decision per §5 and end
>   as **Nobody**, naming the residual.
> - **A coordinator.** A dispatched worker (a live preamble with Task and
>   Dispatch IDs) never calls AskUserQuestion. It sends the decision with the
>   preamble's `ask`, or puts it in `Decisions` under `full`. Any other session
>   whose decision belongs to a coordinator (§10) sends it with `orchestration
>   send --type question` to that coordinator's handle. The coordinator then
>   ends as **The operator** if the decision is the operator's.
>
> **Delivery, in every kind.** Each step that another session must do is
> delivered to that session BEFORE the ending: `worker_done` to your own
> coordinator, `orchestration send` (rule 1's target rules) to any other. List
> each delivery in the body as `Sent: <to> — <subject> (<message id>)`. Writing
> a step in the transcript is not delivery. A step with no reachable target
> becomes an **operator** decision ("deliver this to <session>"), with the
> paste-ready block.
>
> **Record (optional, any kind).** A `## Record` section may list what
> happened or what comes later. It holds no question, no numbers to pick, no
> `My read`.
>
> **One Handoff block per message.** Rule 1's printed copy of a sent block
> omits a Handoff block that is already in the body, and says
> `(Handoff block above)`.

How a session knows it is under Orca: §12a's `ORCA: present` line (already
built and tested in 1.35.0/1.36.0). How it knows it is a dispatched worker: a
live Orca preamble with Task and Dispatch IDs in its prompt (O7). No new probe.

### Precedence — testing the operator's view

The operator's view: the global rule stays for interactive chats; the adapter
overrides it for automated sessions under Orca. **Partly sound.** A session
cannot tell "interactive chat I read" from "automated" (this coord@main
session is both: it runs under Orca, and the operator reads it live). The
reliable signal is **Orca present or not**:

- **Orca present:** rule 7 governs every session, interactive or not. This
  costs nothing for an interactive chat: AskUserQuestion shows the same
  numbered choice, with one click, and it puts the card in NEEDS YOU.
- **Orca absent** (VS Code, a plain terminal, `claude -p`): the global
  `## Next steps` rule stays as written.

## 8. Exact edits needed so no rule fights rule 7

All proposed. None is made by this PR.

**cepa (this repo, one worker PR, plugin 1.37.0):**

- `autonomy` §6, after A:418, add: "Under Orca (§12a present), §12b rule 7 replaces this tail."
- `autonomy` §12b: add rule 7 (wording above). In rule 1, replace "A block addressed to the operator, or to a fresh session of the same role, is printed as before" with "A block for a session that Orca can reach is sent; only a block with no reachable target is printed for pasting." Add rule 1's "omit a Handoff block already in the body" sentence.
- `commands/handoff.md:754-808`: under Orca, follow rule 7 for the report; the prompt block is sent (rule 1) and its printed copy carries no second Handoff block.
- `commands/triage.md`, `plan-review.md`, `compound.md`, `compound-refresh.md`, `setup.md`, `sweep.md`: one line each: "Under Orca, end per §12b rule 7."
- Tests: extend `scripts/check-orca-detection*.sh` or add a sibling checker that greps the six commands and §6 for the rule-7 citation (citation drift is the repo's known failure mode).

**Global `~/.claude/CLAUDE.md` (the operator's file; edit after approval):**

- G:610 heading, add the scope: "**Outside Orca.** Under Orca (`ORCA_CLI_COMMAND` set), cepa `autonomy` §12b rule 7 governs how a turn ends; this section does not apply."
- G:81: "End EVERY reply with the Handoff block" → "End EVERY reply with ONE Handoff block (never repeated in the same reply). Under Orca, cepa §12b rule 7 also applies: first line `Needed from you: …`, and decisions go to your coordinator by Orca `ask`, never AskUserQuestion."
- G:217-219: replace the header text with cepa's: "first line `Sent to <session> via Orca — do not paste.`"
- G:203-208: add "For a supervised worker (you will wait for its `worker_done`), use cepa §12b rule 2 (`worker-start`) instead."
- G:293-299: "Run it" → "Ask the operator to run `/cepa:handoff` (the model cannot invoke it)".
- G:596-603 ASD-STE100: add "Under Orca, the first line is `Needed from you: …`; item 3 'What I do now' is that line."

**Repo files (one Orca hand-off to each repo's coord@main):**

- `farmtender-laravel/CLAUDE.md:73-88`: prefix "Outside Orca, and for coordinators and solo sessions only:"; drop "3 items minimum" (keep "as many as the situation has", per G:618).
- `contexthub/CLAUDE.md:947`: "list other items as numbered next steps (workers: Handoff `Decisions`; under Orca: cepa §12b rule 7)".
- `dpc-pro-marketing/CLAUDE.md:50-56`, `helm/CLAUDE.md:59`, `dpc-pro/CLAUDE.md:681`: no edit. They ask a real operator question, which rule 7 routes to AskUserQuestion. Compatible.

## 9. Risks

| Risk | Mitigation |
|---|---|
| AskUserQuestion blocks a session until the operator answers; many open questions pile up in NEEDS YOU | That is the intended signal. Cap: one question per turn, at most 3 options. |
| Over-asking: a session asks about something a rule or residual settles | Rule text: "only… that no rule or residual can settle"; reviewer checks in the test run. |
| A send to a terminal-only mailbox is lost if that terminal closes (O11) | Prefer `run:`/`dispatch:` targets; keep the printed record; the `Sent:` line names the message id. |
| A sent message does not start the recipient's turn (L61 step 4) | Out of scope for endings; record it. A coordinator checks its inbox at each turn start (G:213-216 already says so). |
| Chat UI behaviour unverified (O6) | The rule names AskUserQuestion, not a surface. Re-test when a non-WSL workspace exists. |
| Orca's state mapping changes in a later version | Rule 7 depends only on "a pending tool prompt = needs-you", which is Orca's documented NEEDS YOU kind (O2). Re-run the probe after each Orca update. |
| `full`-autonomy runs that used to end silently now ask at the end | That is the requested behaviour: a decision that existed was hidden before. |

## 10. Test on one repo first

compound-engineering (this repo), because it owns the rule and has two parked lanes.

1. Build rule 7 in a worker PR (`feat/roles/orca-turn-endings`), plugin 1.37.0, merge, run both plugin hops.
2. In `.claude/worktrees/integrity`, start three throwaway Haiku sessions with `orca-ide agent launch --surface terminal`, each with a scripted prompt that forces one kind: **Nobody**, **The operator**, and **Delivery** to a stub coordinator terminal.
3. Pass criteria, read from `orca-ide worktree ps --agent-wait --json` and each session's last message:
   - Nobody → `done`; first line `Needed from you: nothing`; no numbered options; one Handoff block at most.
   - The operator → `waiting` with `toolName: AskUserQuestion`; ≤ 3 options, first marked Recommended.
   - Delivery → the stub's inbox holds the message (`orchestration check --peek`); the ending lists `Sent: … (<id>)`.
4. Then one real dispatched worker under the coordinator, to check that its question reaches the coordinator by `ask` and not by AskUserQuestion.
5. Roll out to artist360 (most active, `full`) only after 1–4 pass. Then send the repo edits in §8.
