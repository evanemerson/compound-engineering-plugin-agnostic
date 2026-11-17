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
# STATED LIMITS: the check never runs as root-proof for an unreadable file
# (chmod does not stop root), never imports without PyYAML (the YAML NOT
# CHECKED row), and never sets the repo name to farmtender (that needs a git
# common dir). Fleet repos are not read here: the corpus run is in the PR
# body, with its probe.
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

def run(files):
    with tempfile.TemporaryDirectory() as d:
        root = os.path.join(d, "demo")
        for path, body in files.items():
            if body is None:
                continue
            full = os.path.join(root, path)
            os.makedirs(os.path.dirname(full), exist_ok=True)
            with open(full, "w") as f:
                f.write(body)
        p = subprocess.run([sys.executable, SCRIPT, root], capture_output=True, text=True, timeout=60)
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
case("BASE skill examples report no MISS", p.returncode == 0 and not misskeys(rows) and rows,
     "rc=%d MISS=%s out=%r" % (p.returncode, sorted(misskeys(rows)), p.stdout[-600:]))
# The rows a gated verdict rests on. Every other row is pinned by a CASE that
# expects it to turn MISS, which also proves the row is printed at all.
for key, want in [("stop", "OK"), ("start:fresh", "OK"), ("start:worktree-init-stack", "OK")]:
    case("BASE row %s is %s" % (key, want), rows.get(key) == {want}, "row %s is %s" % (key, rows.get(key)))

WT = "  setup: env -u COMPOSE_PROJECT_NAME make worktree-init\n"
# (name, [(path, old, new)], exact MISS keys, {key: exact status set})
CASES = [
    ("yaml duplicate key voids the file", [("orca.yaml", None, YAML + "setupAgentStartupPolicy: wait-for-setup\n")],
     {"yaml-parse", "setup-closure"}, {}),
    ("yaml that does not parse", [("orca.yaml", "\n  archive:", "\n archive:")], {"yaml-parse", "setup-closure"}, {}),
    ("policy start-immediately", [("orca.yaml", "Policy: wait-for-setup", "Policy: start-immediately")], {"policy"}, {}),
    ("policy value Orca drops", [("orca.yaml", "Policy: wait-for-setup", "Policy: wait-for-setp")], {"policy"}, {}),
    ("no archive in a Docker repo", [("orca.yaml", "  archive: make worktree-clean\n", "")], {"archive"}, {}),
    ("no setup in a Docker repo", [("orca.yaml", WT, "")], {"setup", "setup-closure"}, {"policy": {"INFO"}}),
    (".worktreeinclude present", [(".worktreeinclude", None, ".env\n")], {"worktreeinclude"}, {}),
    ("shared node_modules", [("orca.yaml", None, YAML + "worktree:\n  sharedDirectories:\n    - node_modules\n")],
     {"shared-dirs"}, {}),
    ("shared cache is fine", [("orca.yaml", None, YAML + "worktree:\n  sharedDirectories:\n    - .ruff_cache\n")],
     set(), {"shared-dirs": {"OK"}}),
    ("unknown key is only INFO", [("orca.yaml", None, YAML + "issueComand: x\n")], set(), {"yaml-keys": {"INFO"}}),
    ("entry point named in CLAUDE.md", [("CLAUDE.md", None, "Make a lane with `make worktree branch=x`.\n")],
     {"entry"}, {}),
    ("entry point forbidden in CLAUDE.md", [("CLAUDE.md", None, "Never use `make worktree branch=x`.\n")],
     set(), {"entry": {"OK"}}),
    ("worktree help without orca-lane.sh", [("Makefile", "new lanes use cepa orca-lane.sh create", "make a lane")],
     {"entry"}, {}),
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
    ("stop only in a message", [("Makefile", "@trap '$(DEV_COMPOSE) stop' EXIT;", '@echo "then docker compose stop";')],
     {"stop"}, {}),
    ("ungated restart", [("Makefile", '@GATE="$$CEPA_ROOT/scripts/stack-gate.sh"; bash "$$GATE" "$$PROJECT" -- $(DEV_COMPOSE) restart web',
                          "$(DEV_COMPOSE) restart web")], {"start:restart"}, {}),
    ("refusal only in a message", [("Makefile", "@$(call lane_refuse,use make up BUILD=1)", '@echo "refused"')],
     {"start:fresh"}, {}),
    ("ungated make up", [("Makefile", "\nup: worktree-guard\n", "\nup-old: worktree-guard\n"),
                         ("Makefile", "prod-up:\n", "up:\n\t$(DEV_COMPOSE) up -d\n\nprod-up:\n")],
     {"make-up", "start:up"}, {"start:up-old": {"OK"}}),
    ("prod stack by file name", [("Makefile", "prod-up:\n", "boot:\n")], set(), {"start:boot": {"INFO"}}),
    ("setup runs a target with no rule", [("orca.yaml", "make worktree-init", "make worktree-init worktree-setup")],
     {"setup-closure"}, {"wt-name": {"OK"}}),
    ("prod target with no -f", [("Makefile", "PROD_COMPOSE = docker compose -f docker-compose.prod.yml", "PROD_COMPOSE = docker compose")],
     set(), {"start:prod-up": {"INFO"}}),
    ("setup through a script with a compose function",
     [("orca.yaml", WT, "  setup: bash scripts/lane.sh init\n"), ("scripts/lane.sh", None, SCRIPT_SH)],
     set(), {"wt-name": {"OK"}, "setup-gate": {"OK"}, "stop": {"OK"}}),
    ("script without stop",
     [("orca.yaml", WT, "  setup: bash scripts/lane.sh init\n"),
      ("scripts/lane.sh", None, SCRIPT_SH.replace("trap 'dc stop' EXIT\n", "# dc stop\n"))],
     {"stop"}, {}),
    ("non-Docker repo with archive", [("docker-compose.dev.yml", None, None), ("docker-compose.prod.yml", None, None)],
     {"archive"}, {"make-up": None, "wt-name": None, "start:up": None}),
    ("no orca.yaml", [("orca.yaml", None, None)], set(), {"orca-yaml": {"INFO"}, "kind": None}),
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
    case("CASE " + name, p.returncode == 0 and got == want and not bad,
         "rc=%d MISS %s, want %s; %s" % (p.returncode, sorted(got), sorted(want), "; ".join(bad)))

sys.exit(1 if misses else 0)
PY
