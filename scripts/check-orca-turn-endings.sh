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
#              once, and its text (whitespace folded, up to the next numbered
#              rule or the line after the list) holds each phrase in
#              RULE_PHRASES. The phrases pin clauses, not the whole rule.
#   POINTER  — section 6 holds POINTER exactly once.
#   SCOPE    — 12b rule 1 holds each phrase in SCOPE_HAS (its head and its
#              send-scope bullets), and no longer holds SCOPE_LACKS.
#   CITES    — each command in SITES carries CITE exactly once outside fenced
#              blocks, and that once is inside the heading SITES names: the
#              step where its run ends.
#   GRANTS   — each command in SITES declares allowed-tools, unless it is in
#              NO_ALLOWED_TOOLS (the pipeline-command exception), and grants
#              each `orca-ide` verb in GRANTS: the set handoff.md grants for
#              12a and 12b. 12a's allowed-tools stated limit holds for all of
#              them.
#
# STATED LIMITS — a green run does not mean:
#   - an agent follows rule 7. This tests the text and its citations, not the
#     model that reads them. The live probe (three throwaway sessions under
#     Orca) is the operator's coordinator's to run after merge.
#   - the rule is correct. A phrase in RULE_PHRASES pins wording that was
#     approved; it cannot tell whether that wording still matches Orca.
#   - the commands not in SITES end correctly. task and lfg run 12a (they
#     cite section 12), so section 6's POINTER reaches them. A command that
#     cites neither section 12 nor rule 7 never runs 12a, and rule 7 does not
#     reach it.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

CEPA_TURN_SKILL="${1:-plugins/cepa/skills/autonomy/SKILL.md}" python3 - <<'PY'
import os, re, sys

HOME = os.environ["CEPA_TURN_SKILL"]
SITES_DIR = os.environ.get("CEPA_TURN_SITES", "plugins/cepa/commands")
# command file -> the heading of the step where its run ends.
SITES = {"handoff.md": "## Step 7: Report and Emit the Prompt",
         "triage.md": "### Step 4a: Execute Decisions and Summarize",
         "plan-review.md": "## Step 6: Report",
         "compound.md": "## Step 5: Report",
         "compound-refresh.md": "## Phase 5: Report and Commit",
         "setup.md": "## Step 3: Report",
         "sweep.md": "## Step 6: Report",
         "review.md": "## Step 6: Report (interactive mode)",
         "resolve-pr.md": "## Step 9: Report"}
NO_ALLOWED_TOOLS = {"sweep.md", "resolve-pr.md"}
CITE = "**Under Orca**, end the run per `cepa:autonomy` §12b rule 7."
POINTER = "**Under Orca (§12a present), §12b rule 7 replaces this tail.**"
RULE_HEAD = "7. **How a turn ends under Orca.**"
RULE_PHRASES = [
    "When §12a printed `ORCA: present`, this rule replaces §6's `## Next steps` tail",
    "A command that cites this rule runs §12a's block first",
    "**First line, always:** `Needed from you: nothing`",
    "and any repo or global rule that requires one. It does not change §10d, the Handoff block.",
    "It is the first line of the final reply, not of a printed block (rule 1)",
    "**Nobody.**", "Others end with no tail: no numbered options, no `My read`, no `Stop here`.",
    "**The operator.**", "**A coordinator.**",
    'your pick first with "(Recommended)" in its label',
    "Under `full` autonomy, ask only at the end of a finished run, never mid-run.",
    "In a headless run (the `mode:headless` token, or no AskUserQuestion tool), file the decision per §5",
    "call AskUserQuestion: one question, at most 3 options",
    "Do not also write the options as text.",
    "never calls AskUserQuestion",
    "`Sent: <to> — <subject> (<message id>)`",
    "Writing a step in the transcript is not delivery.",
    "`/cepa:handoff` never sends it",
    "A step with no reachable target becomes an **operator** decision",
    "A `## Record` section",
    "**One Handoff block per message** (rule 1).",
]
SCOPE_HAS = ["block addressed to a session Orca can reach",
             "only a block with no reachable target is printed for pasting.",
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
i7 = b12.find("\n" + RULE_HEAD)
r7 = ""
if i7 >= 0:
    m = re.compile(r"\n(?:[0-9]+\. \*\*|\S)").search(b12, i7 + len(RULE_HEAD) + 1)
    r7 = fold(b12[i7:m.start()] if m else b12[i7:])
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
def unfenced(s):
    # Drop fenced blocks, matching the closing fence's character and length.
    out, fence = [], None
    for line in s.split("\n"):
        m = re.match(r"\s*(`{3,}|~{3,})", line)
        if fence is None and m:
            fence = m.group(1)
        elif fence is not None and m and m.group(1)[0] == fence[0] and len(m.group(1)) >= len(fence) \
                and line.strip() == m.group(1):
            fence = None
        elif fence is None:
            out.append(line)
    return "\n".join(out)

for n, head in SITES.items():
    p = os.path.join(SITES_DIR, n)
    try:
        s = open(p, encoding="utf-8").read()
    except OSError as e:
        miss("CITES: cannot read %s: %s" % (p, e)); continue
    u = unfenced(s)
    level = head.split(" ", 1)[0]
    sec = between(u, "\n" + head + "\n", "\n" + level + " ")
    if sec is not None:
        # A heading of the same or a higher level ends the step.
        m = re.compile(r"\n#{1,%d} " % len(level)).search(sec, 1)
        sec = sec[:m.start()] if m else sec
    check(u.count(CITE) == 1 and sec is not None and CITE in sec,
          "CITES: %s carries the rule 7 citation once, in %s" % (n, head))
    fm = s.split("\n---", 1)[0] if s.startswith("---") else ""
    tl = re.search(r"^allowed-tools:(.*)$", fm, re.M)
    if n in NO_ALLOWED_TOOLS:
        continue
    if not tl:
        miss("GRANTS: %s declares no allowed-tools line" % n); continue
    for g in GRANTS:
        check("Bash(%s:*)" % g in tl.group(1), "GRANTS: %s grants Bash(%s:*)" % (n, g))

print("-- %d/%d checks passed --" % (passed, passed + failed))
sys.exit(1 if failed else 0)
PY
