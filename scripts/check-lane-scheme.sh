#!/usr/bin/env bash
# Check for plugins/cepa/scripts/lane_scheme.py, /cepa:setup's lane & stack
# scheme check (punch-list L67; scope: design "Plan-review decisions" #20).
#
# Usage: bash scripts/check-lane-scheme.sh [<lane_scheme.py>]
#   Prints `ok <case>` or `MISS <case> — <why>` per case; exits 1 on any MISS.
#   The optional path lets the controls run it on a mutated copy.
#
# How: it builds a throwaway Docker repo from the lane-stack skill's OWN
# examples (its `orca.yaml` block and its `make up` block, read from
# SKILL.md at run time), plus a worktree-init that builds and starts through
# the gate and stops its stack. That BASE must report no MISS: the skill's
# examples pass the repo check. Each case then makes one edit to a copy of
# BASE (a gap, or a near miss that must stay clean) and asserts the EXACT set
# of MISS keys, plus named rows where the verdict is the point. A case that
# only checked "some MISS" would pass a check that flags everything.
#
# A case that hangs fails by name after 30 s; it never stops the run.
#
# STATED LIMITS: no case covers a file unreadable by permissions (chmod does
# not stop root, and CI may run as root); a dangling symlink and a FIFO stand
# in for it. No case runs without PyYAML (the YAML NOT CHECKED row). The
# farmtender case names the temp root only: no case builds a git common dir.
# Fleet repos
# are not read here, so the corpus result is not reproducible from this repo.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }
CEPA_LS_SCRIPT="$(realpath "${1:-plugins/cepa/scripts/lane_scheme.py}")" python3 - <<'PY'
import os, re, subprocess, sys, tempfile

SCRIPT = os.environ["CEPA_LS_SCRIPT"]
skill = open("plugins/cepa/skills/lane-stack/SKILL.md", encoding="utf-8").read()
misses = 0
def case(name, ok, why=""):
    global misses
    print(("ok %s" % name) if ok else ("MISS %s — %s" % (name, why)))
    misses += 0 if ok else 1

def block(lang):
    b = re.findall(r"^```%s\n(.*?)^```$" % lang, skill, re.S | re.M)
    return b[0] if len(b) == 1 else None

YAML, MAKE_UP = block("yaml"), block("make")
case("SKILL one yaml and one make example", YAML is not None and MAKE_UP is not None,
     "the skill no longer has exactly one ```yaml and one ```make block")
if YAML is None or MAKE_UP is None:
    sys.exit(1)

MAKEFILE = r'''DEV_COMPOSE = docker compose -f docker-compose.dev.yml
PROD_COMPOSE = docker compose -f docker-compose.prod.yml

define lane_refuse
echo "this target does not run in a lane: $(1)"; exit 1
endef

worktree-guard:
	@true

worktree: ## Fallback only when Orca is absent; new lanes use cepa orca-lane.sh create
	@true

worktree-init:
	@PROJECT=demo-wt-lane-abc123; \
	GATE="$$CEPA_ROOT/scripts/stack-gate.sh"; \
	bash "$$GATE" --build "$$PROJECT" -- $(DEV_COMPOSE); \
	bash "$$GATE" "$$PROJECT" -- make --no-print-directory -f "$(lastword $(MAKEFILE_LIST))" worktree-init-stack

worktree-init-stack:
	@trap '$(DEV_COMPOSE) stop' EXIT; \
	$(DEV_COMPOSE) up -d --no-build db; \
	timeout --foreground -k 10 300 $(DEV_COMPOSE) exec -T web migrate </dev/null

worktree-clean:
	@true

fresh: worktree-guard
	@$(call lane_refuse,use make up BUILD=1)
	$(DEV_COMPOSE) up -d --force-recreate

restart: worktree-guard
	@GATE="$$CEPA_ROOT/scripts/stack-gate.sh"; bash "$$GATE" "$$PROJECT" -- $(DEV_COMPOSE) restart web

prod-up:
	$(PROD_COMPOSE) up -d

''' + MAKE_UP

SCRIPT_SH = '''#!/usr/bin/env bash
dc() { docker compose -f docker-compose.dev.yml "$@"; }
name() { printf 'demo-wt-%s\\n' "$1"; }
GATE="$root/scripts/stack-gate.sh"
trap 'dc stop' EXIT
'''

BASE = {"orca.yaml": YAML, "Makefile": MAKEFILE, "docker-compose.dev.yml": "services: {}\n",
        "docker-compose.prod.yml": "services: {}\n", "CLAUDE.md": "# demo\n"}

def run(files, name="demo"):
    with tempfile.TemporaryDirectory() as d:
        root = os.path.join(d, name)
        os.makedirs(root)
        for path, body in files.items():
            if body is None:
                continue
            full = os.path.join(root, path)
            os.makedirs(os.path.dirname(full), exist_ok=True)
            if isinstance(body, tuple) and body[0] == "symlink":
                os.symlink(body[1], full)
                continue
            if isinstance(body, tuple) and body[0] == "fifo":
                os.mkfifo(full)
                continue
            with open(full, "w", encoding="utf-8") as f:
                f.write(body)
        try:
            p = subprocess.run([sys.executable, SCRIPT, root], capture_output=True, text=True, timeout=30)
        except subprocess.TimeoutExpired:   # a hang is this case's failure, never the whole run's
            p = subprocess.CompletedProcess([], -1, "", "probe timed out after 30 s")
    rows = {}
    for line in p.stdout.splitlines():
        m = re.match(r"^(OK|MISS|INFO)\s+lane:(\S+) — ", line)
        if m:
            rows.setdefault(m.group(2), set()).add(m.group(1))
    return p, rows

def misskeys(rows):
    return {k for k, v in rows.items() if "MISS" in v}

def edit(files, path, old, new):
    """One edit. old=None adds or replaces the whole file; new=None deletes it."""
    f = dict(files)
    if old is None:
        f[path] = new
        return f, ""
    n = (f.get(path) or "").count(old)
    if n != 1:
        return f, "anchor %r found %d times in %s" % (old, n, path)
    f[path] = f[path].replace(old, new)
    return f, ""

p, rows = run(BASE)
case("BASE skill examples report no MISS", p.returncode == 0 and not p.stderr and not misskeys(rows) and rows,
     "rc=%d MISS=%s out=%r stderr=%r" % (p.returncode, sorted(misskeys(rows)), p.stdout[-600:], p.stderr[-400:]))
# The rows a gated verdict rests on. Every other row is pinned by a CASE that
# expects it to turn MISS, which also proves the row is printed at all.
for key, want in [("stop", "OK"), ("start:fresh", "OK"), ("start:worktree-init-stack", "OK")]:
    case("BASE row %s is %s" % (key, want), rows.get(key) == {want}, "row %s is %s" % (key, rows.get(key)))

WT = "  setup: env -u COMPOSE_PROJECT_NAME make worktree-init\n"
# (name, [(path, old, new)], exact MISS keys, {key: exact status set})
CASES = [
    ("yaml duplicate key voids the file", [("orca.yaml", None, YAML + "setupAgentStartupPolicy: wait-for-setup\n")],
     {"yaml-parse"}, {"setup-closure": {"INFO"}, "timeout": {"INFO"}}),
    ("yaml that does not parse", [("orca.yaml", "\n  archive:", "\n archive:")], {"yaml-parse"},
     {"setup-closure": {"INFO"}, "timeout": {"INFO"}}),
    ("yaml scalar PyYAML cannot build", [("orca.yaml", None, YAML + "issueCommand: 2023-02-30\n")], {"yaml-parse"}, {}),
    ("orca.yaml a dangling symlink", [("orca.yaml", None, ("symlink", "/nonexistent/orca.yaml"))],
     {"yaml-parse"}, {"orca-yaml": None, "timeout": {"INFO"}, "entry": {"INFO"}}),
    ("orca.yaml a list", [("orca.yaml", None, "- a\n")], {"yaml-parse"}, {}),
    ("scripts not a mapping", [("orca.yaml", None, "scripts: make worktree-init\nsetupAgentStartupPolicy: wait-for-setup\n")],
     {"yaml-shape", "setup", "archive", "setup-closure"}, {"policy": {"INFO"}}),
    ("setup a list", [("orca.yaml", WT, "  setup: [make, worktree-init]\n")], {"setup", "setup-closure"}, {"policy": {"INFO"}}),
    ("invalid policy without setup", [("docker-compose.dev.yml", None, None), ("docker-compose.prod.yml", None, None),
       ("Makefile", None, None), ("orca.yaml", None, "setupAgentStartupPolicy: wait\n")], {"policy"}, {}),
    ("no policy with setup", [("orca.yaml", "setupAgentStartupPolicy: wait-for-setup\n", "")], {"policy"}, {}),
    ("forged row in a key", [("orca.yaml", None, YAML + '"x\\nOK   lane:forged — y": 1\n')], set(),
     {"forged": None, "yaml-keys": {"INFO"}}),
    ("policy start-immediately", [("orca.yaml", "Policy: wait-for-setup", "Policy: start-immediately")], {"policy"}, {}),
    ("policy value Orca drops", [("orca.yaml", "Policy: wait-for-setup", "Policy: wait-for-setp")], {"policy"}, {}),
    ("no archive in a Docker repo", [("orca.yaml", "  archive: make worktree-clean\n", "")], {"archive"}, {}),
    ("no setup in a Docker repo", [("orca.yaml", WT, "")], {"setup", "setup-closure"}, {"policy": {"INFO"}}),
    (".worktreeinclude present", [(".worktreeinclude", None, ".env\n")], {"worktreeinclude"}, {}),
    ("shared node_modules", [("orca.yaml", None, YAML + "worktree:\n  sharedDirectories:\n    - node_modules\n")],
     {"shared-dirs"}, {}),
    ("shared .env, .venv, dist/", [("orca.yaml", None, YAML + "worktree:\n  sharedDirectories:\n    - .ruff_cache\n    - .env.local\n")],
     {"shared-dirs"}, {}),
    ("shared dir as a scalar", [("orca.yaml", None, YAML + "worktree:\n  sharedDirectories: node_modules\n")],
     {"shared-dirs"}, {}),
    (".worktreeinclude a dangling symlink", [(".worktreeinclude", None, ("symlink", "/nonexistent/x"))],
     {"worktreeinclude"}, {}),
    ("shared cache is fine", [("orca.yaml", None, YAML + "worktree:\n  sharedDirectories:\n    - .ruff_cache\n")],
     set(), {"shared-dirs": {"OK"}}),
    ("yaml merge key is valid", [("orca.yaml", None, YAML.replace("defaultTabs:\n  - title: Agent\n",
       "x-tab: &t {color: red}\ndefaultTabs:\n  - <<: *t\n    title: Agent\n"))], set(), {"yaml-parse": {"OK"}}),
    ("orca.yaml a FIFO", [("orca.yaml", None, ("fifo",))], {"yaml-parse"}, {"timeout": {"INFO"}}),
    ("alias bomb in archive", [("orca.yaml", "  archive: make worktree-clean\n",
       "  archive: &a6 [*a5, *a5, *a5, *a5, *a5, *a5, *a5, *a5, *a5]\n"),
      ("orca.yaml", "scripts:\n", "x0: &a0 [lol, lol, lol, lol, lol, lol, lol, lol, lol]\n" + "".join(
       "x%d: &a%d [%s]\n" % (i, i, ", ".join(["*a%d" % (i - 1)] * 9)) for i in range(1, 6)) + "scripts:\n")],
     {"archive"}, {"yaml-keys": {"INFO"}}),
    ("unknown key is only INFO", [("orca.yaml", None, YAML + "issueComand: x\n")], set(), {"yaml-keys": {"INFO"}}),
    ("entry point named in CLAUDE.md", [("CLAUDE.md", None, "Make a lane with `make worktree branch=x`.\n")],
     {"entry"}, {}),
    ("entry point forbidden in CLAUDE.md", [("CLAUDE.md", None, "Never use `make worktree branch=x`.\n")],
     set(), {"entry": {"OK"}}),
    ("worktree help without orca-lane.sh", [("Makefile", "new lanes use cepa orca-lane.sh create", "make a lane")],
     {"entry"}, {}),
    ("timeout with -T but no </dev/null", [("Makefile", "timeout --foreground -k 10 300 $(DEV_COMPOSE) exec -T web migrate </dev/null",
                                                 "timeout -k 10 300 $(DEV_COMPOSE) exec -T web migrate")], {"timeout"}, {}),
    ("timeout with </dev/null but no -T", [("Makefile", "timeout --foreground -k 10 300 $(DEV_COMPOSE) exec -T web migrate </dev/null",
                                                 "timeout 300 $(DEV_COMPOSE) exec web migrate </dev/null")], {"timeout"}, {}),
    ("bare timeout in setup", [("Makefile", "timeout --foreground -k 10 300 $(DEV_COMPOSE) exec -T web migrate </dev/null",
                                       "timeout 300 $(DEV_COMPOSE) exec web migrate")], {"timeout"}, {}),
    ("timeout with -T and </dev/null is fine",
     [("Makefile", "timeout --foreground -k 10 300 $(DEV_COMPOSE) exec -T web migrate </dev/null",
       "timeout -k 10 300 \\\n\t$(DEV_COMPOSE) exec -T web migrate </dev/null")], set(), {"timeout": {"OK"}}),
    ("no -wt- in the project name", [("Makefile", "PROJECT=demo-wt-lane", "PROJECT=demo-lane")], {"wt-name"}, {}),
    ("gate named only in a message",
     [("Makefile", 'GATE="$$CEPA_ROOT/scripts/stack-gate.sh"; \\\n\tbash "$$GATE" --build',
       'GATE=/bin/true; echo "uses stack-gate.sh"; \\\n\tbash "$$GATE" --build')],
     {"setup-gate", "start:worktree-init-stack"}, {}),
    ("stop only as an exec argument", [("Makefile", "@trap '$(DEV_COMPOSE) stop' EXIT;", "@$(DEV_COMPOSE) exec -T web stop;")],
     {"stop"}, {}),
    ("stop only in a trailing comment", [("Makefile", "@trap '$(DEV_COMPOSE) stop' EXIT;", "@true; # docker compose stop\n\t@true;")],
     {"stop"}, {}),
    ("stop only in a message", [("Makefile", "@trap '$(DEV_COMPOSE) stop' EXIT;", '@echo "then docker compose stop";')],
     {"stop"}, {}),
    ("ungated restart", [("Makefile", '@GATE="$$CEPA_ROOT/scripts/stack-gate.sh"; bash "$$GATE" "$$PROJECT" -- $(DEV_COMPOSE) restart web',
                          "$(DEV_COMPOSE) restart web")], {"start:restart"}, {}),
    ("refusal only in echo -e and printf", [("Makefile", "@$(call lane_refuse,use make up BUILD=1)",
       '@echo -e "Refusing here"; printf \'refused\\n\'; echo >&2 "refuse"')], {"start:fresh"}, {}),
    ("refusal only in a trailing comment", [("Makefile", "@$(call lane_refuse,use make up BUILD=1)", "@true # refuse in a lane")],
     {"start:fresh"}, {}),
    ("project name looks prod", [("Makefile", "prod-up:\n", "repro:\n\tdocker compose -p reproducer-dev up -d\n\nprod-up:\n")],
     {"start:repro"}, {}),
    ("gate mention outside the gate's command",
     [("Makefile", "prod-up:\n", "doctor:\n\tbash scripts/stack-gate.sh --status || true; $(MAKE) serve\n"
                                   "serve:\n\t$(DEV_COMPOSE) up -d web\n\nprod-up:\n")], {"start:serve"}, {}),
    ("make up delegates to a gated target", [("Makefile", "\nup: worktree-guard\n", "\nup: dev-up\n\ndev-up: worktree-guard\n")],
     set(), {"make-up": {"OK"}}),
    ("call with a non-ASCII digit", [("Makefile", "prod-up:\n", "define odd_body\n$(²)\nendef\nodd:\n\t@$(call odd_body,x)\n\nprod-up:\n")], set(), {}),
    ("compose file name only looks prod", [("Makefile", "prod-up:\n", "repro2:\n\tdocker compose -f docker-compose.reproduce.yml up -d\n\nprod-up:\n")],
     {"start:repro2"}, {}),
    ("refusal only in a message", [("Makefile", "@$(call lane_refuse,use make up BUILD=1)", '@echo "refused"')],
     {"start:fresh"}, {}),
    ("ungated make up", [("Makefile", "\nup: worktree-guard\n", "\nup-old: worktree-guard\n"),
                         ("Makefile", "prod-up:\n", "up:\n\t$(DEV_COMPOSE) up -d\n\nprod-up:\n")],
     {"make-up", "start:up"}, {"start:up-old": {"OK"}}),
    ("ungated start with no -f", [("Makefile", "prod-up:\n", "boot:\n\tdocker compose up -d\n\nprod-up:\n")],
     {"start:boot"}, {}),
    ("ungated dev+prod files", [("Makefile", "prod-up:\n", "both:\n\tdocker compose -f docker-compose.dev.yml -f docker-compose.prod.yml up -d\n\nprod-up:\n")],
     {"start:both"}, {}),
    ("prod and ungated dev site", [("Makefile", "prod-up:\n", "mixed:\n\t$(PROD_COMPOSE) up -d; $(DEV_COMPOSE) up -d\n\nprod-up:\n")],
     {"start:mixed"}, {}),
    ("target name only looks prod", [("Makefile", "prod-up:\n", "produce-up:\n\t$(DEV_COMPOSE) up -d\n\nprod-up:\n")],
     {"start:produce-up"}, {}),
    ("proxy target with no -f", [("Makefile", "prod-up:\n", "proxy-up:\n\tdocker compose up -d\n\nprod-up:\n")],
     set(), {"start:proxy-up": {"INFO"}}),
    ("legacy docker-compose spelling", [("Makefile", "prod-up:\n", "legacy:\n\tdocker-compose up -d\n\nprod-up:\n")],
     {"start:legacy"}, {}),
    ("ungated compose start verb", [("Makefile", "prod-up:\n", "wake:\n\t$(DEV_COMPOSE) start web\n\nprod-up:\n")],
     {"start:wake"}, {}),
    ("ungated start behind --profile", [("Makefile", "prod-up:\n", "full:\n\tdocker compose --profile full up -d\n\nprod-up:\n")],
     {"start:full"}, {}),
    ("start inside a conditional", [("Makefile", "prod-up:\n", "cond:\nifeq ($(X),1)\n\t$(DEV_COMPOSE) up -d\nendif\n\nprod-up:\n")],
     {"start:cond"}, {}),
    ("start in a second rule for one target", [("Makefile", "prod-up:\n", "twice: worktree-guard\ntwice:\n\t$(DEV_COMPOSE) up -d\n\nprod-up:\n")],
     {"start:twice"}, {}),
    ("compose split over continuation lines", [("Makefile", "PROD_COMPOSE = docker compose -f docker-compose.prod.yml",
       "PROD_COMPOSE = docker compose -f docker-compose.prod.yml\nLONG = docker compose \\\n  -f docker-compose.dev.yml"),
      ("Makefile", "prod-up:\n", "long:\n\t$(LONG) up -d\n\nprod-up:\n")], {"start:long"}, {}),
    ("gate as STACK_GATE variable", [("Makefile", '@GATE="$$CEPA_ROOT/scripts/stack-gate.sh"; bash "$$GATE" "$$PROJECT" -- $(DEV_COMPOSE) restart web',
                                       'bash "$$STACK_GATE" "$$PROJECT" -- $(DEV_COMPOSE) restart web')], set(), {"start:restart": {"OK"}}),
    ("refusal markers main-only, require-main, is-main",
     [("Makefile", "prod-up:\n", "m1:\n\t@$(call main_only,x)\n\t$(DEV_COMPOSE) up -d\n"
                                   "m2:\n\t@bash x require-main m2\n\t$(DEV_COMPOSE) up -d\n"
                                   "m3:\n\t@if is-main; then $(DEV_COMPOSE) up -d; fi\n\nprod-up:\n")],
     set(), {"start:m1": {"OK"}, "start:m2": {"OK"}, "start:m3": {"OK"}}),
    ("make -j 4 is not a target", [("Makefile", "make --no-print-directory -f", "make -j 4 --no-print-directory -f")],
     set(), {"setup-closure": {"INFO"}}),
    ("prod stack by file name", [("Makefile", "prod-up:\n", "boot:\n")], set(), {"start:boot": {"INFO"}}),
    ("setup runs a target with no rule", [("orca.yaml", "make worktree-init", "make worktree-init worktree-setup")],
     {"setup-closure"}, {"wt-name": {"OK"}}),
    ("prod target with no -f", [("Makefile", "PROD_COMPOSE = docker compose -f docker-compose.prod.yml", "PROD_COMPOSE = docker compose")],
     set(), {"start:prod-up": {"INFO"}}),
    ("no up target", [("Makefile", "\nup: worktree-guard\n", "\nup-old: worktree-guard\n")], {"make-up"}, {}),
    ("make up gated through a script", [("Makefile", "\nup: worktree-guard\n", "\nup-old: worktree-guard\n"),
                                        ("Makefile", "prod-up:\n", "up:\n\t@bash scripts/up.sh\n\nprod-up:\n"),
                                        ("scripts/up.sh", None, 'G="$root/scripts/stack-gate.sh"\n')], set(), {"make-up": {"OK"}}),
    ("make up script names the gate only in a message", [("Makefile", "\nup: worktree-guard\n", "\nup-old: worktree-guard\n"),
                                        ("Makefile", "prod-up:\n", "up:\n\t@bash scripts/up.sh\n\nprod-up:\n"),
                                        ("scripts/up.sh", None, 'echo "use stack-gate.sh"\n# stack-gate\n')], {"make-up"}, {}),
    ("Docker repo whose setup reaches nothing", [("orca.yaml", WT, "  setup: npm install\n")], {"setup-closure"}, {}),
    ("Docker repo by a Makefile alone", [("docker-compose.dev.yml", None, None), ("docker-compose.prod.yml", None, None)],
     set(), {"kind": {"INFO"}, "make-up": {"OK"}, "wt-name": {"OK"}}),
    ("compose.yaml names a Docker repo", [("docker-compose.dev.yml", None, None), ("docker-compose.prod.yml", None, None),
                                          ("Makefile", None, "x:\n\t@true\n"), ("compose.yaml", None, "services: {}\n")],
     {"setup-closure", "make-up"}, {}),
    ("GNUmakefile wins over Makefile", [("GNUmakefile", None, "x:\n\t@true\n")], {"setup-closure", "make-up"}, {}),
    ("setup names a script that is missing", [("orca.yaml", WT, "  setup: make worktree-init && bash scripts/gone.sh\n")],
     set(), {"setup-missing": {"INFO"}}),
    ("stop through an alias with a project argument",
     [("orca.yaml", WT, "  setup: bash scripts/lane.sh init\n"),
      ("scripts/lane.sh", None, SCRIPT_SH.replace("trap 'dc stop' EXIT\n",
        'dcp() { docker compose -p "$1" "${@:2}"; }\ntrap \'dcp "$P" stop\' EXIT\n'))],
     set(), {"stop": {"OK"}}),
    ("non-Docker bare timeout", [("docker-compose.dev.yml", None, None), ("docker-compose.prod.yml", None, None),
                                 ("Makefile", None, None), ("orca.yaml", None, "scripts:\n  setup: timeout 300 npm ci\nsetupAgentStartupPolicy: wait-for-setup\n")],
     {"timeout"}, {"wt-name": None}),
    ("setup through a script with a compose function",
     [("orca.yaml", WT, "  setup: bash scripts/lane.sh init\n"), ("scripts/lane.sh", None, SCRIPT_SH)],
     set(), {"wt-name": {"OK"}, "setup-gate": {"OK"}, "stop": {"OK"}}),
    ("script without stop",
     [("orca.yaml", WT, "  setup: bash scripts/lane.sh init\n"),
      ("scripts/lane.sh", None, SCRIPT_SH.replace("trap 'dc stop' EXIT\n", "# dc stop\n"))],
     {"stop"}, {}),
    ("non-Docker repo with archive", [("docker-compose.dev.yml", None, None), ("docker-compose.prod.yml", None, None),
                                      ("Makefile", None, None)],
     {"archive", "setup-closure"}, {"make-up": None, "wt-name": None, "start:up": None}),
    ("no orca.yaml", [("orca.yaml", None, None)], set(), {"orca-yaml": {"INFO"}, "kind": None}),
    # L91: contract item 7's rule is `--foreground`; -k and </dev/null are its "Why"
    ("timeout --foreground without -k or </dev/null is fine",
     [("Makefile", "timeout --foreground -k 10 300 $(DEV_COMPOSE) exec -T web migrate </dev/null",
       "timeout --foreground 300 $(DEV_COMPOSE) exec web migrate")], set(), {"timeout": {"OK"}}),
    # L90: the repo opt-out. Each case also voids orca.yaml, so a skip shows as
    # no yaml-parse row and a checked repo as a yaml-parse MISS.
    ("lanes: none opts out", [("orca.yaml", None, "- a\n"), ("cepa.local.md", None, "# x\n\n## Conventions\n- lanes: none\n")],
     set(), {"yaml-parse": None, "kind": {"INFO"}, "opt-out": None}),
    ("lanes: none with no list marker, in backticks", [("orca.yaml", None, "- a\n"),
     ("cepa.local.md", None, "## Conventions\n  lanes: `none`   # no Orca lanes\n")],
     set(), {"yaml-parse": None, "kind": {"INFO"}}),
    ("lanes: none outside Conventions is checked", [("orca.yaml", None, "- a\n"),
     ("cepa.local.md", None, "## Stack\n- lanes: none\n\n## Conventions\n- trunk: dev\n")],
     {"yaml-parse"}, {"opt-out": {"INFO"}}),
    ("lanes: none in a fenced block is checked", [("orca.yaml", None, "- a\n"),
     ("cepa.local.md", None, "## Conventions\n```markdown\n- lanes: none\n```\n- trunk: dev\n")],
     {"yaml-parse"}, {"opt-out": None}),
    ("lanes: another value is checked", [("orca.yaml", None, "- a\n"), ("cepa.local.md", None, "## Conventions\n- lanes: orca\n")],
     {"yaml-parse"}, {"opt-out": {"INFO"}}),
    ("cepa.local.md a FIFO is checked", [("cepa.local.md", None, ("fifo",))], set(), {"opt-out": {"INFO"}, "yaml-parse": {"OK"}}),
]
for name, ops, want, rowwant in CASES:
    files, err = dict(BASE), ""
    for path, old, new in ops:
        files, e = edit(files, path, old, new)
        err = err or e
    if err:
        case("CASE " + name, False, err)
        continue
    p, rows = run(files)
    got = misskeys(rows)
    bad = ["%s is %s" % (k, rows.get(k)) for k, v in rowwant.items() if rows.get(k) != v]
    case("CASE " + name, p.returncode == 0 and not p.stderr and got == want and not bad,
         "rc=%d MISS %s, want %s; %s; stderr %r" % (p.returncode, sorted(got), sorted(want), "; ".join(bad), p.stderr[-400:]))

# L90: no repo is skipped by its name. BASE in a root named farmtender is checked.
p, rows = run(BASE, "farmtender")
case("CASE a repo named farmtender is checked", p.returncode == 0 and not p.stderr and not misskeys(rows)
     and rows.get("yaml-parse") == {"OK"}, "rc=%d rows %s stderr %r" % (p.returncode, rows, p.stderr[-400:]))

sys.exit(1 if misses else 0)
PY
