#!/usr/bin/env bash
# Controls for scripts/check-orca-turn-endings.sh. Each mutant is one
# substitution in a temp copy of the shipped skill file or of one command file.
# It must turn the check red with EXACTLY the MISS lines named beside it: a
# mutant that also trips another leg proves nothing about the leg meant to
# catch it, and an exact set shows each leg kills a mutant no other leg kills.
# A mutant with an empty set must stay green: it plants a form the check must
# not flag. One exception: rule-head-gone loses rule 7's whole text, so it asserts only
# that every MISS is a RULE line and one is the head count.
# The unmutated copies must run with no MISS line, or every red below proves
# nothing. A mutant whose anchor text is gone is a MISS, never a skip: the
# shipped text changed shape and these mutants need re-reading.
#
# Every leg has at least one mutant here. The check has no slow cases, so the
# whole set runs in a few seconds.
#
# STATED LIMITS: a mutant is one substitution; two compensating edits are not
# modeled. The controls prove each named case can fail, not that the case list
# is complete.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

python3 - <<'PY'
import os, shutil, subprocess, tempfile

HOME = "plugins/cepa/skills/autonomy/SKILL.md"
SITES = "plugins/cepa/commands"
CHECK = "scripts/check-orca-turn-endings.sh"
CITE = "**Under Orca**, end the run per `cepa:autonomy` §12b rule 7."
# (name, file, old, new, exact MISS set) — file is "skill" or a command file.
MUTANTS = [
    ("rule-head-gone", "skill", "7. **How a turn ends under Orca.**", "7. **How a turn ends.**",
     # Without its head, rule 7's text is not found, so every phrase misses too.
     None),
    ("rule-no-trigger", "skill", "When §12a printed `ORCA: present`, this\n   rule replaces",
     "When this\n   rule replaces",
     {"RULE: rule 7 holds When §12a printed `ORCA: present`, this rule replaces §6's `## Next steps` tail"}),
    ("rule-no-self-detect", "skill", "A command that\n   cites this rule runs §12a's block first",
     "A command that\n   cites this rule may run §12a's block first",
     {"RULE: rule 7 holds A command that cites this rule runs §12a's block first"}),
    ("rule-more-options", "skill", "one question, at most 3 options", "one question, at most 5 options",
     {"RULE: rule 7 holds call AskUserQuestion: one question, at most 3 options"}),
    ("rule-options-as-text", "skill", "Do not also write the options as\n       text.", "Also write the options as\n       text.",
     {"RULE: rule 7 holds Do not also write the options as text."}),
    ("rule-worker-may-ask", "skill", "Dispatch IDs) never calls AskUserQuestion.", "Dispatch IDs) may call AskUserQuestion.",
     {"RULE: rule 7 holds never calls AskUserQuestion"}),
    ("rule-transcript-delivers", "skill", "Writing a step in the\n     transcript is not delivery.",
     "Writing a step in the\n     transcript is delivery.",
     {"RULE: rule 7 holds Writing a step in the transcript is not delivery."}),
    ("rule-no-sent-line", "skill", "`Sent: <to> — <subject> (<message id>)`", "`Sent: <to>`",
     {"RULE: rule 7 holds `Sent: <to> — <subject> (<message id>)`"}),
    ("rule-first-line", "skill", "`Needed from you: nothing` or", "`Needed: nothing` or",
     {"RULE: rule 7 holds **First line, always:** `Needed from you: nothing`"}),
    ("rule-nobody-tail", "skill", "Others end with no tail: no numbered options, no `My read`, no\n       `Stop here`.",
     "Others end with a `## Next steps` tail.",
     {"RULE: rule 7 holds Others end with no tail: no numbered options, no `My read`, no `Stop here`."}),
    ("rule-no-precedence", "skill", " and any repo or global rule that\n   requires one.", ".",
     {"RULE: rule 7 holds and any repo or global rule that requires one. It does not change §10d, the Handoff block."}),
    ("rule-headless-tool-only", "skill", "In a headless run (the `mode:headless` token, or no\n       AskUserQuestion tool)",
     "With no AskUserQuestion tool (headless)",
     {"RULE: rule 7 holds In a headless run (the `mode:headless` token, or no AskUserQuestion tool), file the decision per §5"}),
    ("rule-handoff-sends-done", "skill", "(rule 3; `/cepa:handoff` never sends it)", "(rule 3)",
     {"RULE: rule 7 holds `/cepa:handoff` never sends it"}),
    ("rule-record-asks", "skill", "A `## Record` section may list", "A Record section may list",
     {"RULE: rule 7 holds A `## Record` section"}),
    ("rule-one-handoff-gone", "skill", "   - **One Handoff block per message** (rule 1).\n", "",
     {"RULE: rule 7 holds **One Handoff block per message** (rule 1)."}),
    # The phrase moves into a rule 8 after rule 7: rule 7's bound must stop at rule 8.
    ("rule-phrase-in-rule-8", "skill",
     "   - **One Handoff block per message** (rule 1).\n",
     "8. **Other.**\n   - **One Handoff block per message** (rule 1).\n",
     {"RULE: rule 7 holds **One Handoff block per message** (rule 1)."}),
    ("rule-operator-gone", "skill", '"You" is the operator, the human who reads this tab. ', "",
     {'RULE: rule 7 holds "You" is the operator, the human who reads this tab.'}),
    # Probe C of L26: a coordinator's decision written as the operator's.
    ("rule-coordinator-needs-you", "skill", "`Needed from you: nothing`: it travels",
     "`Needed from you: the coordinator's answer`: it travels",
     {"RULE: rule 7 holds A decision that belongs to a coordinator or to another session, once delivered, is `Needed from you: nothing`"}),
    # #100 review: an undelivered decision must not read as `nothing`.
    ("rule-undelivered-is-nothing", "skill", "One that could not be delivered is the operator's (Delivery, below).", "",
     {"RULE: rule 7 holds One that could not be delivered is the operator's (Delivery, below)."}),
    ("rule-coordinator-nothing-unconditional", "skill", "When the\n       send and its nudge both succeeded, its own first line", "Its own first line",
     {"RULE: rule 7 holds When the send and its nudge both succeeded, its own first line is `Needed from you: nothing`; otherwise rule 1 gives the line."}),
    # #100 finding 2: a send whose nudge did not go is not delivered.
    ("rule-coordinator-send-only", "skill", "send and its nudge both succeeded", "send succeeded",
     {"RULE: rule 7 holds When the send and its nudge both succeeded, its own first line is `Needed from you: nothing`; otherwise rule 1 gives the line."}),
    ("rule-skip-delivered", "skill", " A\n     send whose nudge did not go is not delivered (rule 1, \"Only a sent\n     nudge completes the delivery\").\n", "\n",
     {"RULE: rule 7 holds A send whose nudge did not go is not delivered (rule 1, \"Only a sent nudge completes the delivery\")."}),
    # Probe C of L26: the decision sent as a status, not a question.
    ("rule-status-type", "skill", "`orchestration send --type question`", "`orchestration send --type status`",
     {"RULE: rule 7 holds sends it with `orchestration send --type question` to that coordinator's handle, never `--type status`"}),
    ("rule-coordinator-no-nudge", "skill", ", then applies rule 1's nudge. When the", ". When the",
     {"RULE: rule 7 holds then applies rule 1's nudge."}),
    ("rule-delivery-no-nudge", "skill", "(rule 1's target rules, then its nudge)", "(rule 1's target rules)",
     {"RULE: rule 7 holds `orchestration send` (rule 1's target rules, then its nudge) to any other (rule 1's \"Only a sent nudge completes the delivery\" says when a send counts)."}),
    ("nudge-call-gone", "skill", 'orca-nudge.sh" "<cli>" "<target>"', 'orca-nudge.sh" "<target>"',
     {"NUDGE: rule 1 holds the nudge script call exactly once"}),
    # The fixed text must never carry message content.
    ("nudge-content-spliced", "skill", "`You have 1 orchestration message. Run",
     "`<subject>. You have 1 orchestration message. Run",
     {"NUDGE: rule 1 holds the fixed nudge text exactly once"}),
    # #100 finding 5: rule 1 cites the script, never the raw command.
    ("nudge-raw-command-back", "skill", "     - **Never type the line with",
     "     `<cli> terminal send --terminal <target> --enter`\n     - **Never type the line with",
     {"NUDGE: rule 1 holds no raw terminal send command"}),
    # #100 finding 3: only an idle target is nudged, matched by pane.
    ("nudge-any-state", "skill", "says `done`, matched", "says `idle`, matched",
     {"NUDGE: rule 1 holds agent row in `worktree ps --agent-wait` says `done`"}),
    ("nudge-by-title", "skill", "pane, never by its title.", "pane or by its title.",
     {"NUDGE: rule 1 holds matched by the target's pane, never by its title."}),
    ("nudge-skip-silent", "skill", "wait on those), it exits 1 and prints `Orca nudge skipped: <reason>`", "wait on those), it is nudged anyway",
     {"NUDGE: rule 1 holds Still `working` at the bound, or `waiting`, `blocked`, an unknown state or no row from the start (no wait on those), it exits 1 and prints `Orca nudge skipped: <reason>`"}),
    # #100 finding 2: the bounded wait, and a skip is not a delivery.
    ("nudge-wait-unbounded", "skill", "for up to 2 minutes, a bound fixed in the script", "until it is done",
     {"NUDGE: rule 1 holds When the row says `working`, the script re-reads it for up to 2 minutes, a bound fixed in the script."}),
    ("nudge-skip-is-delivery", "skill", "message stays unread and the delivery is not done.", "the delivery still stands.",
     {"NUDGE: rule 1 holds the message stays unread and the delivery is not done."}),
    # L28: the printed ending line, the send retry, the first-line order.
    ("nudge-ending-not-copied", "skill", "Copy the text after `Ending first line: `\n       verbatim", "Read the text after `Ending first line: `",
     {"NUDGE: rule 1 holds Copy the text after `Ending first line: ` verbatim as the ending's first line"}),
    ("send-no-vsock-retry", "skill", "retry that send once, with\n", "report it, with\n",
     {"NUDGE: rule 1 holds retry that send once, with the same command, before reporting `Orca send failed`"}),
    ("fallback-block-first", "skill", "block comes AFTER the ending's", "block comes BEFORE the ending's",
     {"NUDGE: rule 1 holds the printed block comes AFTER the ending's `Needed from you: …` first line"}),
    ("nudge-skip-no-operator-line", "skill", "`Needed from you: tell <session> to check its Orca inbox`, and its body\n       lists the message id.", "`Needed from you: nothing`.",
     {"NUDGE: rule 1 holds `Needed from you: tell <session> to check its Orca inbox`, and its body lists the message id."}),
    ("nudge-handoff-skips-nudge", "skill", "after the send,\n     its nudge (above) and the printed copy.", "after the send and\n     the printed copy.",
     {"NUDGE: rule 1 holds ends its run right after the send, its nudge (above) and the printed copy."}),
    ("nudge-run-coord-nudged", "skill", "A Run coordinator gets no nudge, so its send\n       alone completes the delivery.", "A Run coordinator is nudged too.",
     {"NUDGE: rule 1 holds A Run coordinator gets no nudge, so its send alone completes the delivery."}),
    # #100 finding 3: the half-typed draft is a stated, accepted limit.
    ("nudge-draft-limit-gone", "skill", "**Stated limit, accepted by the operator on 2026-10-30.** A nudge can\n     submit a half-typed draft in the target.", "**Stated limit.**",
     {"NUDGE: rule 1 holds **Stated limit, accepted by the operator on 2026-10-30.** A nudge can submit a half-typed draft in the target."}),
    ("nudge-waiting-unmeasured", "skill", "An open AskUserQuestion shows `waiting` (measured by coord@main\n       twice on 2026-10-30), so the guard skips it.", "The AskUserQuestion state is unmeasured.",
     {"NUDGE: rule 1 holds An open AskUserQuestion shows `waiting` (measured by coord@main twice on 2026-10-30), so the guard skips it."}),
    ("nudge-why-gone", "skill", "so the nudge's Enter would answer a\n       question meant for the operator", "so the nudge is noisy",
     {"NUDGE: rule 1 holds the nudge's Enter would answer a question meant for the operator"}),
    ("nudge-guard-head-gone", "skill", "**Only an idle target is nudged.** ", "",
     {"NUDGE: rule 1 holds **Only an idle target is nudged.**"}),
    ("nudge-no-refuse", "skill", "prints\n       `Orca nudge refused: <reason>` and sends nothing.", "is sent anyway.",
     {"NUDGE: rule 1 holds `Orca nudge refused: <reason>`"}),
    ("nudge-interrupt", "skill", "It never passes\n       `--interrupt`.", "It may pass `--interrupt`.",
     {"NUDGE: rule 1 holds It never passes `--interrupt`."}),
    ("nudge-raw-allowed", "skill", "**Never type the line with `terminal send` yourself.**", "**Or type it yourself.**",
     {"NUDGE: rule 1 holds **Never type the line with `terminal send` yourself.**"}),
    ("nudge-every-target", "skill", "So after a send succeeds to a\n     target that is not a Run coordinator, the sender",
     "So after a send succeeds, the sender",
     {"NUDGE: rule 1 holds after a send succeeds to a target that is not a Run coordinator"}),
    ("nudge-run-coord-undefined", "skill", "live Orca preamble, or a\n     `run:` or `dispatch:` address.",
     "live Orca preamble.",
     {"NUDGE: rule 1 holds A Run coordinator is a target taken from a live Orca preamble, or a `run:` or `dispatch:` address."}),
    ("nudge-doubled", "skill", "Orca already prompts it, so it gets no\n     nudge.", "It gets a nudge too.",
     {"NUDGE: rule 1 holds Orca already prompts it, so it gets no nudge."}),
    ("nudge-splice-allowed", "skill", "The text is fixed: never splice a subject, a body or any message\n     content into it.",
     "The text may carry the subject.",
     {"NUDGE: rule 1 holds The text is fixed: never splice a subject, a body or any message content into it."}),
    # A failed nudge must not undo or repeat a send that succeeded.
    ("nudge-failure-aborts", "skill", "`Orca nudge failed: <reason>`.\n       Skipped, refused or failed, the send still stands:",
     "the send is aborted.",
     {"NUDGE: rule 1 holds `Orca nudge failed: <reason>`",
      "NUDGE: rule 1 holds Skipped, refused or failed, the send still stands: the message stays in the target's inbox, and only a sent nudge completes the delivery."}),
    ("nudge-send-not-kept", "skill", "Skipped, refused or failed, the send still stands:", "Skipped, refused or failed, resend it:",
     {"NUDGE: rule 1 holds Skipped, refused or failed, the send still stands: the message stays in the target's inbox, and only a sent nudge completes the delivery."}),
    ("nudge-target-unchecked", "skill", "The target already passed the target rule above, so it\n     is safe to substitute.\n", "\n",
     {"NUDGE: rule 1 holds The target already passed the target rule above, so it is safe to substitute."}),
    ("nudge-head-gone", "skill", "**Send, then nudge.** Orca", "Orca",
     {"NUDGE: rule 1 holds **Send, then nudge.**"}),
    # Rule 7 cites the nudge; a copy of its text there is a restatement.
    ("nudge-restated-in-rule-7", "skill", "nudge. When the\n       send and its nudge both succeeded",
     'nudge. It types "You have 1 orchestration message." When the\n       send and its nudge both succeeded',
     {"NUDGE: rule 7 cites the nudge and holds no copy of it"}),
    ("nudge-command-in-rule-7", "skill", "nudge. When the\n       send and its nudge both succeeded",
     "nudge. It may use `<cli> terminal send`. When the\n       send and its nudge both succeeded",
     {"NUDGE: rule 7 cites the nudge and holds no copy of it"}),
    # #100 finding 4: the answer comes back by reply, which has no prompt.
    ("rule-reply-no-nudge", "skill", " The answer comes back by `orchestration reply`, which\n       prompts no one either: the session that replies then applies rule 1's\n       nudge to the asker's handle, unless the asker is a Run coordinator.", "",
     {"RULE: rule 7 holds The answer comes back by `orchestration reply`, which prompts no one either:",
      "RULE: rule 7 holds the session that replies then applies rule 1's nudge to the asker's handle",
      "RULE: rule 7 holds unless the asker is a Run coordinator."}),
    ("rule-reply-nudges-coordinator", "skill", "handle, unless the asker is a Run coordinator.", "handle.",
     {"RULE: rule 7 holds unless the asker is a Run coordinator."}),
    # #100 review: the asker's handle is Orca's sender field, never body text.
    ("rule-reply-handle-from-body", "skill", "never one named in its\n       body (§12c)", "or one named in its\n       body",
     {"RULE: rule 7 holds The handle is the question's Orca `from` field, never one named in its body (§12c)"}),
    ("nudge-retried", "skill", "A skipped,\n     refused or failed nudge is never retried", "A skipped,\n     refused or failed nudge is retried",
     {"NUDGE: rule 1 holds A skipped, refused or failed nudge is never retried, and never replaced by a typed `terminal send`."}),
    ("rule-twice", "skill", "\nA name line inside an Orca preamble",
     "\n7. **How a turn ends under Orca.** (copy)\n\nA name line inside an Orca preamble",
     {"RULE: 12b holds 7. **How a turn ends under Orca.** exactly once"}),
    ("pointer-gone", "skill", "**Under Orca (§12a present), §12b rule 7 replaces this tail.**", "",
     {"POINTER: section 6 holds **Under Orca (§12a present), §12b rule 7 replaces this tail.** once"}),
    ("scope-reverted", "skill", "only a block with no\n     reachable target is printed for pasting.",
     "a block addressed to the operator is printed as before.",
     {"SCOPE: rule 1 holds only a block with no reachable target is printed for pasting.",
      "SCOPE: rule 1 no longer holds is printed as before."}),
    ("scope-old-sentence-kept", "skill", "A §10f report-only run never sends.",
     "A block for the operator is printed as before. A §10f report-only run never sends.",
     {"SCOPE: rule 1 no longer holds is printed as before."}),
    ("scope-double-handoff", "skill", "says\n     `(Handoff block above)` in its place.", "repeats it.",
     {"SCOPE: rule 1 holds says `(Handoff block above)` in its place."}),
]
CITE_SITES = {"handoff.md": "## Step 7: Report and Emit the Prompt",
         "triage.md": "### Step 4a: Execute Decisions and Summarize",
         "plan-review.md": "## Step 6: Report", "compound.md": "## Step 5: Report",
         "compound-refresh.md": "## Phase 5: Report and Commit",
         "setup.md": "## Step 3: Report", "sweep.md": "## Step 6: Report",
         "review.md": "## Step 6: Report (interactive mode)",
         "resolve-pr.md": "## Step 9: Report"}
def cites(n):
    return {"CITES: %s carries the rule 7 citation once, in %s" % (n, CITE_SITES[n])}
for n in CITE_SITES:
    MUTANTS.append(("cite-gone-" + n[:-3], n, CITE, "", cites(n)))
MUTANTS += [
    ("cite-twice-triage", "triage.md", CITE, CITE + "\n\n" + CITE, cites("triage.md")),
    # Moved to the mid-run decision table: still once, wrong step.
    ("cite-moved-triage", "triage.md", "### Step 4a: Execute Decisions and Summarize\n",
     "### Step 4a: Execute Decisions and Summarize\n\n### Step 4a-split\n", cites("triage.md")),
    # A fenced example that quotes the citation is not a second citation:
    # the check must stay green (an empty set means rc 0 and no MISS).
    ("cite-quoted-in-fence-sweep", "sweep.md", CITE, CITE + "\n\n```text\n" + CITE + "\n```", set()),
    # Inside a fence: still once in the raw file, but not an instruction.
    ("cite-fenced-sweep", "sweep.md", CITE, "```text\n" + CITE + "\n```", cites("sweep.md")),
    ("scope-head-reverted", "skill", "block addressed to a session Orca can reach", "block addressed to a coordinator",
     {"SCOPE: rule 1 holds block addressed to a session Orca can reach"}),
    ("alltools-gone-compound", "compound.md", "\nallowed-tools:", "\nallowed_tools_removed:",
     {"GRANTS: compound.md declares no allowed-tools line"}),
    ("cite-wrong-rule-setup", "setup.md", CITE, CITE.replace("rule 7", "rule 6"),
     cites("setup.md")),
    ("grant-gone-compound", "compound.md", ", Bash(orca-ide orchestration send:*)", "",
     {"GRANTS: compound.md grants Bash(orca-ide orchestration send:*)"}),
    ("grant-gone-plan-review", "plan-review.md", ", Bash(orca-ide orchestration ask:*)", "",
     {"GRANTS: plan-review.md grants Bash(orca-ide orchestration ask:*)"}),
    ("grant-gone-setup", "setup.md", ", Bash(orca-ide status:*)", "",
     {"GRANTS: setup.md grants Bash(orca-ide status:*)"}),
    # Under a headless heading: still once, but a headless sub-step does not
    # end a turn (rule 7), so it is the wrong step.
    ("cite-moved-review", "review.md", "\n\n**Under Orca**, end the run per",
     "\n\n## Headless return\n\n**Under Orca**, end the run per", cites("review.md")),
    ("grant-gone-review", "review.md", ", Bash(orca-ide orchestration send:*)", "",
     {"GRANTS: review.md grants Bash(orca-ide orchestration send:*)"}),
    ("grant-gone-nudge-triage", "triage.md", ', Bash(bash "$CEPA_ROOT/scripts/orca-nudge.sh":*)', "",
     {'GRANTS: triage.md grants Bash(bash "$CEPA_ROOT/scripts/orca-nudge.sh":*)'}),
    # #100 finding 5: the raw grant admits any text, terminal and --interrupt.
    ("grant-raw-terminal-send-handoff", "handoff.md", "Bash(orca-ide terminal rename:*)",
     "Bash(orca-ide terminal rename:*), Bash(orca-ide terminal send:*)",
     {"GRANTS: handoff.md grants no raw terminal send"}),
    ("grant-raw-terminal-send-orca-dev-setup", "setup.md", "Bash(orca-ide status:*)",
     "Bash(orca-ide status:*), Bash(orca-dev terminal send:*)",
     {"GRANTS: setup.md grants no raw terminal send"}),
    # #99 review P3 1: a higher-level heading ends a deeper step. Step 4a is
    # `###`, so a `##` heading before the citation moves it out of the step,
    # though the next `###` heading is further down.
    ("cite-under-higher-heading-triage", "triage.md", CITE, "## Foo\n\n" + CITE, cites("triage.md")),
    ("grant-gone-handoff", "handoff.md", "Bash(orca-ide skills get:*), ", "",
     {"GRANTS: handoff.md grants Bash(orca-ide skills get:*)"}),
]
passed = failed = 0
TMP = tempfile.mkdtemp(prefix="cepa-turn-ctl-")

def ok(msg):
    global passed; passed += 1; print("PASS", msg)

def miss(msg):
    global failed; failed += 1; print("MISS", msg)

def run(skill, sites):
    r = subprocess.run(["bash", CHECK, skill], env=dict(os.environ, CEPA_TURN_SITES=sites),
                       capture_output=True, text=True, timeout=120)
    return r.returncode, {l[5:] for l in r.stdout.splitlines() if l.startswith("MISS ")}

def copy_tree(name):
    d = os.path.join(TMP, name)
    shutil.copytree(SITES, os.path.join(d, "commands"))
    shutil.copy(HOME, os.path.join(d, "SKILL.md"))
    return os.path.join(d, "SKILL.md"), os.path.join(d, "commands")

skill, sites = copy_tree("clean")
rc, misses = run(skill, sites)
if rc == 0 and not misses:
    ok("unmutated copies run with no MISS")
else:
    miss("unmutated copies: rc=%s, MISS %r" % (rc, sorted(misses)[:2]))

for name, f, old, new, want in MUTANTS:
    skill, sites = copy_tree(name)
    path = skill if f == "skill" else os.path.join(sites, f)
    s = open(path, encoding="utf-8").read()
    if s.count(old) != 1:
        miss("%s: anchor found %d times in %s, want 1" % (name, s.count(old), f)); continue
    open(path, "w", encoding="utf-8").write(s.replace(old, new))
    rc, got = run(skill, sites)
    if want is None:
        good = rc == 1 and any(m.startswith("RULE: 12b holds") for m in got) \
            and all(m.startswith("RULE:") for m in got)
    elif not want:
        good = rc == 0 and not got
    else:
        good = rc == 1 and got == want
    if good:
        ok("%s %s" % (name, "goes red on RULE only" if want is None else
                      "stays green" if not want else "goes red on " + sorted(want)[0]))
    else:
        miss("%s: rc=%s, MISS set %r" % (name, rc, sorted(got)))

shutil.rmtree(TMP, ignore_errors=True)
print("-- %d/%d controls passed --" % (passed, passed + failed))
raise SystemExit(1 if failed else 0)
PY
