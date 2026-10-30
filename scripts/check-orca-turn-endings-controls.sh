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
    # Inside a fence: still once in the raw file, but not an instruction.
    # A fenced example that quotes the citation is not a second citation:
    # the check must stay green (an empty set means rc 0 and no MISS).
    ("cite-quoted-in-fence-sweep", "sweep.md", CITE, CITE + "\n\n```text\n" + CITE + "\n```", set()),
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
