#!/usr/bin/env bash
# Check for how a turn ends under Orca: rule 7 of section 12b in
# plugins/cepa/skills/autonomy/SKILL.md, and every place that cites it.
# Rule 7 is cited once and restated nowhere, so the failure this guards is a
# citation that drifts away: a command that loses its line ends with a
# `## Next steps` tail under Orca, and the operator's decision lands in DONE.
#
# Usage: check-orca-turn-endings.sh [SKILL.md]
#   The optional path replaces the shipped skill file, and CEPA_TURN_SITES
#   replaces the commands directory. Only check-orca-turn-endings-controls.sh
#   sets either, to run this check against a mutant.
#
# Every MISS line starts with its leg name, so the controls can assert the
# exact finding set of each mutant. Legs, in order:
#   RULE     — 12b holds rule 7, `7. **How a turn ends under Orca.**`, exactly
#              once, and its text (whitespace folded) holds each phrase in
#              RULE_PHRASES: the trigger, the first line, the three kinds, the
#              AskUserQuestion bounds, the worker's ban, the delivery line,
#              the Record section and the one-Handoff-block pointer.
#   POINTER  — section 6 holds POINTER exactly once.
#   SCOPE    — 12b rule 1 holds the send-scope sentence and the
#              `(Handoff block above)` sentence, and no longer holds the
#              old "is printed as before" sentence.
#   CITES    — each command in SITES carries CITE exactly once.
#   GRANTS   — each command in SITES that declares allowed-tools grants each
#              `orca-ide` verb in GRANTS, because the cited rule makes the
#              command run 12a's probe and send by Orca. sweep.md declares no
#              allowed-tools (the pipeline-command exception) and is skipped.
#
# STATED LIMITS — a green run does not mean:
#   - an agent follows rule 7. This tests the text and its citations, not the
#     model that reads them. The live probe (three throwaway sessions under
#     Orca) is the operator's coordinator's to run after merge.
#   - the rule is correct. A phrase in RULE_PHRASES pins wording that was
#     approved; it cannot tell whether that wording still matches Orca.
#   - the commands not in SITES end correctly. They cite section 6, whose
#     POINTER carries rule 7 to them.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

CEPA_TURN_SKILL="${1:-plugins/cepa/skills/autonomy/SKILL.md}" python3 - <<'PY'
import os, re, sys

HOME = os.environ["CEPA_TURN_SKILL"]
SITES_DIR = os.environ.get("CEPA_TURN_SITES", "plugins/cepa/commands")
SITES = ["handoff.md", "triage.md", "plan-review.md", "compound.md",
         "compound-refresh.md", "setup.md", "sweep.md"]
CITE = "**Under Orca**, end the run per `cepa:autonomy` §12b rule 7."
POINTER = "**Under Orca (§12a present), §12b rule 7 replaces this tail.**"
RULE_HEAD = "7. **How a turn ends under Orca.**"
RULE_PHRASES = [
    "When §12a printed `ORCA: present`, this rule replaces §6's `## Next steps` tail",
    "A command that cites this rule runs §12a's block first",
    "**First line, always:** `Needed from you: nothing`",
    "**Nobody.**", "**The operator.**", "**A coordinator.**",
    "call AskUserQuestion: one question, at most 3 options",
    "Do not also write the options as text.",
    "never calls AskUserQuestion",
    "`Sent: <to> — <subject> (<message id>)`",
    "Writing a step in the transcript is not delivery.",
    "A `## Record` section",
    "**One Handoff block per message** (rule 1).",
]
SCOPE_HAS = ["only a block with no reachable target is printed for pasting.",
             "says `(Handoff block above)` in its place."]
SCOPE_LACKS = "is printed as before."
GRANTS = ["orca-ide status", "orca-ide skills get",
          "orca-ide orchestration send", "orca-ide orchestration ask"]
passed = failed = 0

def ok(msg):
    global passed; passed += 1; print("PASS", msg)

def miss(msg):
    global failed; failed += 1; print("MISS", msg)

def check(cond, msg):
    (ok if cond else miss)(msg)

def fold(s):
    return re.sub(r"\s+", " ", s)

def between(s, start, end):
    i = s.find(start)
    if i < 0:
        return None
    j = s.find(end, i + len(start))
    return s[i:] if j < 0 else s[i:j]

try:
    skill = open(HOME, encoding="utf-8").read()
except OSError as e:
    miss("RULE: cannot read %s: %s" % (HOME, e)); skill = ""

# --- RULE ---
b12 = between(skill, "\n### 12b.", "\n### 12c.")
check(b12 is not None, "RULE: section 12b found")
b12 = b12 or ""
check(b12.count("\n" + RULE_HEAD) == 1, "RULE: 12b holds %s exactly once" % RULE_HEAD)
r7 = fold(between(b12, "\n" + RULE_HEAD, "\nA name line inside") or "")
for p in RULE_PHRASES:
    check(fold(p) in r7, "RULE: rule 7 holds %s" % p)

# --- POINTER ---
s6 = between(skill, "\n## 6.", "\n## 7.") or ""
check(fold(s6).count(POINTER) == 1, "POINTER: section 6 holds %s once" % POINTER)

# --- SCOPE ---
r1 = fold(between(b12, "\n1. **Hand-offs", "\n2. **") or "")
for p in SCOPE_HAS:
    check(p in r1, "SCOPE: rule 1 holds %s" % p)
check(r1 != "" and SCOPE_LACKS not in r1, "SCOPE: rule 1 no longer holds %s" % SCOPE_LACKS)

# --- CITES and GRANTS ---
for n in SITES:
    p = os.path.join(SITES_DIR, n)
    try:
        s = open(p, encoding="utf-8").read()
    except OSError as e:
        miss("CITES: cannot read %s: %s" % (p, e)); continue
    check(s.count(CITE) == 1, "CITES: %s carries the rule 7 citation once" % n)
    fm = s.split("\n---", 1)[0] if s.startswith("---") else ""
    tl = re.search(r"^allowed-tools:(.*)$", fm, re.M)
    if not tl:
        continue
    for g in GRANTS:
        check("Bash(%s:*)" % g in tl.group(1), "GRANTS: %s grants Bash(%s:*)" % (n, g))

print("-- %d/%d checks passed --" % (passed, passed + failed))
sys.exit(1 if failed else 0)
PY
