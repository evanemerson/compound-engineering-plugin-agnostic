#!/usr/bin/env bash
# Controls for scripts/check-lane-stack.sh. Each mutant is one substitution in
# a temp copy of plugins/cepa/skills/lane-stack/SKILL.md. It must turn the
# check red with EXACTLY the MISS cases named beside it, so each mutant shows
# which case catches it and that no other case does. The unmutated copy must
# run with no MISS line, or every red below proves nothing. A mutant whose
# anchor text is not found exactly once is a MISS, never a skip: the skill
# changed shape and the mutant needs re-reading.
#
# Every case the unmutated check prints is in at least one mutant's exact
# set, and every leg (YAML, GATE, MAKE, TEMPLATE, ENTRY) has a mutant that
# only its own cases kill; the last controls assert both. The one case no
# mutant of the skill can reach, `YAML PyYAML available`, is about the
# runner, not the skill: it prints only when the import fails.
#
# STATED LIMITS: a mutant is one substitution; two compensating edits are not
# modeled. The controls prove each named case can fail, not that the case
# list is complete.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

python3 - <<'PY'
import os, re, subprocess, sys, tempfile

SKILL = "plugins/cepa/skills/lane-stack/SKILL.md"
CHECK = "scripts/check-lane-stack.sh"

# (name, old, new, exact MISS case set)
MUTANTS = [
    # YAML
    ("policy-immediate", "setupAgentStartupPolicy: wait-for-setup\ndefaultTabs:",
     "setupAgentStartupPolicy: start-immediately\ndefaultTabs:", {"YAML policy wait-for-setup"}),
    ("policy-typo-key", "setupAgentStartupPolicy: wait-for-setup\ndefaultTabs:",
     "setupAgentStartupPolicies: wait-for-setup\ndefaultTabs:",
     {"YAML only keys Orca reads", "YAML policy wait-for-setup"}),
    ("no-archive", "  archive: make worktree-clean\n", "",
     {"YAML scripts.archive present"}),
    ("setup-no-env-u", "  setup: env -u COMPOSE_PROJECT_NAME make worktree-init\n",
     "  setup: make worktree-init\n", {"YAML setup strips COMPOSE_PROJECT_NAME"}),
    ("yaml-broken", "  - title: Git status\n    color: \"#16a34a\"\n    command:",
     "  - title: Git status\n   color: \"#16a34a\"\n    command:",
     {"YAML one orca.yaml block that parses", "YAML scripts.setup present",
      "YAML scripts.archive present", "YAML policy wait-for-setup",
      "YAML setup strips COMPOSE_PROJECT_NAME"}),
    # GATE
    ("exit-code-swap", "- **Exit:** `3` refused", "- **Exit:** `1` refused", {"GATE exit 3 refused"}),
    ("gate-counts-stopped", "at least one running container (stopped\n  stacks do not count)",
     "at least one container (stopped\n  stacks count too)", {"GATE counts running only"}),
    ("config-moved", "Its config is `~/.config/cepa/stack-gate.conf`", "Its config is `~/.stack-gate.conf`",
     {"GATE config path"}),
    # MAKE
    ("make-ungated", '\t  bash "$$CEPA_ROOT/scripts/stack-gate.sh" "$$COMPOSE_PROJECT_NAME" -- $(DEV_COMPOSE) up -d --no-build; \\\n',
     '\t  $(DEV_COMPOSE) up -d --no-build; \\\n',
     {"MAKE lane starts through gate", "MAKE lane builds before the gate", "MAKE lane gate refusal propagates",
      "MAKE BUILD=1 rebuilds"}),
    # L68: the build stays outside the gate, and the gated start never builds.
    ("make-build-under-gate",
     '\t  bash "$$CEPA_ROOT/scripts/stack-gate.sh" $(if $(filter 1,$(BUILD)),--rebuild,--build) "$$COMPOSE_PROJECT_NAME" -- $(DEV_COMPOSE) || { \\\n\t    echo "STACK build: failed — this lane\'s stack was not started"; exit 1; }; \\\n'
     '\t  bash "$$CEPA_ROOT/scripts/stack-gate.sh" "$$COMPOSE_PROJECT_NAME" -- $(DEV_COMPOSE) up -d --no-build; \\\n',
     '\t  bash "$$CEPA_ROOT/scripts/stack-gate.sh" "$$COMPOSE_PROJECT_NAME" -- $(DEV_COMPOSE) up -d --build; \\\n',
     {"MAKE lane starts through gate", "MAKE lane builds before the gate", "MAKE lane build failure starts nothing",
      "MAKE BUILD=1 rebuilds", "MAKE BUILD=0 does not rebuild"}),
    ("make-start-may-build", '-- $(DEV_COMPOSE) up -d --no-build; \\\n', '-- $(DEV_COMPOSE) up -d; \\\n',
     {"MAKE lane starts through gate", "MAKE lane builds before the gate", "MAKE BUILD=1 rebuilds"}),
    ("make-build-failure-ignored", '\t  bash "$$CEPA_ROOT/scripts/stack-gate.sh" $(if $(filter 1,$(BUILD)),--rebuild,--build) "$$COMPOSE_PROJECT_NAME" -- $(DEV_COMPOSE) || { \\\n\t    echo "STACK build: failed — this lane\'s stack was not started"; exit 1; }; \\\n',
     '\t  bash "$$CEPA_ROOT/scripts/stack-gate.sh" $(if $(filter 1,$(BUILD)),--rebuild,--build) "$$COMPOSE_PROJECT_NAME" -- $(DEV_COMPOSE); \\\n',
     {"MAKE lane build failure starts nothing"}),
    # L70: the lane build goes through the gate's build mode, and BUILD=1 rebuilds.
    ("make-build-bypasses-lock", '$(if $(filter 1,$(BUILD)),--rebuild,--build) "$$COMPOSE_PROJECT_NAME" -- $(DEV_COMPOSE) || {',
     '"$$COMPOSE_PROJECT_NAME" -- true; $(DEV_COMPOSE) build || {',
     {"MAKE lane builds before the gate", "MAKE BUILD=1 rebuilds", "MAKE lane build failure starts nothing",
      "MAKE BUILD=0 does not rebuild"}),
    ("make-build-any-value", '$(if $(filter 1,$(BUILD)),--rebuild,--build) "$$COMPOSE_PROJECT_NAME"',
     '$(if $(BUILD),--rebuild,--build) "$$COMPOSE_PROJECT_NAME"', {"MAKE BUILD=0 does not rebuild"}),
    ("make-build1-ignored", '$(if $(filter 1,$(BUILD)),--rebuild,--build) "$$COMPOSE_PROJECT_NAME"', '--build "$$COMPOSE_PROJECT_NAME"',
     {"MAKE BUILD=1 rebuilds"}),
    ("gate-build-mode-gone", "- **Builds:** `stack-gate.sh --build <compose project name> -- <compose command…>`,",
     "- **Builds:** `stack-gate.sh <compose project name> -- <compose command…> build`,",
     {"GATE build mode call shape"}),
    ("gate-skip-unstated", "it skips the build and\n  takes no lock", "it still builds", {"GATE build skipped when images exist"}),
    ("gate-rebuild-unstated", "**run `make up BUILD=1` after any\n  change to a Dockerfile", "**rebuild after any\n  change to a Dockerfile",
     {"GATE rebuild with BUILD=1"}),
    ("make-build-before-guards", '\tif [ "$$GD" = "$$CD" ]; then \\\n', '\t$(DEV_COMPOSE) build; if [ "$$GD" = "$$CD" ]; then \\\n',
     {"MAKE main starts directly", "MAKE lane without gate refuses", "MAKE lane unset project refuses",
      "MAKE lane non-wt project refuses", "MAKE lane builds before the gate", "MAKE BUILD=1 rebuilds"}),
    ("make-fail-open", 'echo "STACK gate: not found — this lane\'s stack was not started (set CEPA_PLUGIN_ROOT)"; exit 1; }; \\',
     'echo "STACK gate: not found — this lane\'s stack was not started (set CEPA_PLUGIN_ROOT)"; $(DEV_COMPOSE) up -d; exit 0; }; \\',
     {"MAKE lane without gate refuses"}),
    ("make-main-gated", '\t  $(DEV_COMPOSE) up -d $(if $(filter 1,$(BUILD)),--build); \\\n\telse \\',
     '\t  exit 1; \\\n\telse \\', {"MAKE main starts directly", "MAKE BUILD=1 rebuilds"}),
    # TEMPLATE
    ("template-no-name", "````markdown\nYou are <session name>.", "````markdown\nYou are coord@main.",
     {"TEMPLATE line 1 is the name blank"}),
    ("template-no-count", "Lanes to have: <lane count> — <lane names>.", "Lanes to have: <lane names>.",
     {"TEMPLATE blank <lane count>"}),
    ("template-create-before-rm", "rebuild it under the SAME name: `orca-lane.sh rm` first, then\n   `create`",
     "rebuild it under the SAME name: `create`, then\n   `orca-lane.sh rm`", {"TEMPLATE steps 1-5 in order"}),
    ("template-no-make-up", "start the stack with `make up` before exec targets.\n````",
     "start the stack before exec targets.\n````", {"TEMPLATE worker step make up"}),
    ("no-setup", "  setup: env -u COMPOSE_PROJECT_NAME make worktree-init\n", "",
     {"YAML scripts.setup present", "YAML setup strips COMPOSE_PROJECT_NAME"}),
    ("gate-section-renamed", "## The stack gate\n", "## The gate\n",
     {"GATE section present", "GATE script path", "GATE config path", "GATE call shape",
      "GATE refused line", "GATE exit 3 refused", "GATE exit 2 usage",
      "GATE runs start under lock", "GATE counts running only", "GATE start is never a build",
      "GATE build mode call shape", "GATE build skipped when images exist", "GATE rebuild with BUILD=1"}),
    ("gate-path-gone", "The gate is `plugins/cepa/scripts/stack-gate.sh`, built", "The gate is built",
     {"GATE script path"}),
    ("call-no-dashdash", "- **Call:** `stack-gate.sh <compose project name> -- <start command…>`.",
     "- **Call:** `stack-gate.sh <compose project name> <start command…>`.", {"GATE call shape"}),
    ("refused-line-renamed", "`STACK gate: refused — …`", "`STACK gate: no — …`", {"GATE refused line"}),
    ("usage-code", "`2` usage", "`4` usage", {"GATE exit 2 usage"}),
    ("lock-dropped", "runs the start command itself, under its lock", "checks, then returns",
     {"GATE runs start under lock"}),
    ("gate-build-allowed", "**The start command is the start only, never a build:**",
     "**The start command may build:**", {"GATE start is never a build"}),
    ("refusal-swallowed", '-- $(DEV_COMPOSE) up -d --no-build; \\\n\tfi', '-- $(DEV_COMPOSE) up -d --no-build || true; \\\n\tfi',
     {"MAKE lane gate refusal propagates"}),
    ("unset-project-ok", '*-wt-*) ;; *) \\', '*-wt-*|"") ;; *) \\', {"MAKE lane unset project refuses"}),
    ("any-project-ok", '*-wt-*) ;; *) \\', '*-wt-*|?*) ;; *) \\', {"MAKE lane non-wt project refuses"}),
    ("identity-fail-open",
     '\t@GD=$$(git rev-parse --absolute-git-dir) && \\\n\t  CD=$$(git rev-parse --path-format=absolute --git-common-dir) && \\\n\t  [ -n "$$GD" ] && [ -n "$$CD" ] || { \\\n',
     '\t@GD=$$(git rev-parse --absolute-git-dir 2>/dev/null); CD=$$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); false && { \\\n',
     {"MAKE severed lane refuses"}),
    ("template-wrong-fence", "````markdown\nYou are <session name>.", "````text\nYou are <session name>.",
     {"TEMPLATE one first-prompt block", "TEMPLATE line 1 is the name blank", "TEMPLATE blank <lane names>",
      "TEMPLATE blank <lane count>", "TEMPLATE steps 1-5 in order", "TEMPLATE worker step make up",
      "TEMPLATE step 1 names the Run", "TEMPLATE step 2 build contract", "TEMPLATE step 5 every pre-fix lane"}),
    # L71: each fixed step keeps its contract.
    ("template-run-not-named", "   (`run-create`), or `coord:<repo>` cannot reach this session.",
     "   (it may keep the old Run).", {"TEMPLATE step 1 names the Run"}),
    ("template-no-outbox-drain", "rule 8's inbox peek and its outbox drain,", "rule 8's inbox peek,",
     {"TEMPLATE step 1 names the Run"}),
    ("template-build-1-54", "setup builds with `stack-gate.sh --build` (one\n   build at a time, skipped when the images exist), outside the gate,",
     "setup builds with `compose build`, outside the gate,", {"TEMPLATE step 2 build contract"}),
    ("template-start-may-build", "starts through the gate with `up -d --no-build`;", "starts through the gate with `up -d`;",
     {"TEMPLATE step 2 build contract"}),
    ("template-unusable-only", "List every lane whose setup ran before the\n   repo met the scheme",
     "List the lanes Orca cannot use, not those whose setup ran before the\n   repo met the scheme", {"TEMPLATE step 5 every pre-fix lane"}),
    ("template-no-orca-lanes", "AND Orca-made lanes (under `~/orca/workspaces/<repo>/`) whose\n   setup ran then",
     "but not Orca-made lanes", {"TEMPLATE step 5 every pre-fix lane"}),
    ("template-no-names", "Lanes to have: <lane count> — <lane names>.", "Lanes to have: <lane count>.",
     {"TEMPLATE blank <lane names>"}),
    # ENTRY
    ("entry-promoted", "1. **One entry point: `orca-lane.sh create`.**",
     "1. **One entry point: `orca-lane.sh create`, or `make worktree branch=<b>` by hand.**",
     {"ENTRY make worktree branch= only as forbidden"}),
]

def run(path):
    r = subprocess.run(["bash", CHECK, path], capture_output=True, text=True)
    miss = {re.sub(r" — .*", "", l[5:]) for l in r.stdout.splitlines() if l.startswith("MISS ")}
    return r.returncode, miss, r.stdout + r.stderr

src = open(SKILL, encoding="utf-8").read()
fails = 0
def control(name, ok, why=""):
    global fails
    if ok:
        print("ok %s" % name)
    else:
        fails += 1
        print("MISS %s — %s" % (name, why))

with tempfile.TemporaryDirectory() as d:
    clean = os.path.join(d, "clean.md")
    open(clean, "w", encoding="utf-8").write(src)
    rc, miss, out = run(clean)
    control("clean copy passes", rc == 0 and not miss, "rc=%d miss=%s" % (rc, sorted(miss)))

    killers = {}
    for name, old, new, want in MUTANTS:
        n = src.count(old)
        if n != 1:
            control("mutant %s" % name, False, "anchor found %d times, expected 1" % n)
            continue
        p = os.path.join(d, name + ".md")
        open(p, "w", encoding="utf-8").write(src.replace(old, new))
        rc, miss, out = run(p)
        control("mutant %s" % name, rc != 0 and miss == want,
                "rc=%d want=%s got=%s" % (rc, sorted(want), sorted(miss)))
        legs = {m.split(" ", 1)[0] for m in miss}
        if len(legs) == 1:
            killers.setdefault(legs.pop(), []).append(name)

    # Every case the clean run prints must be in some mutant's exact set, so
    # no case can be broken or deleted while the suite stays green.
    r0 = subprocess.run(["bash", CHECK, clean], capture_output=True, text=True)
    clean_cases = {l[3:] for l in r0.stdout.splitlines() if l.startswith("ok ")}
    covered = set().union(*(m[3] for m in MUTANTS))
    control("every case has a killing mutant", clean_cases <= covered,
            "no mutant kills: %s" % sorted(clean_cases - covered))

    for leg in ("YAML", "GATE", "MAKE", "TEMPLATE", "ENTRY"):
        control("leg %s has a mutant only it kills" % leg, bool(killers.get(leg)),
                "no mutant is killed by %s alone" % leg)

print("%d failed" % fails)
sys.exit(1 if fails else 0)
PY
