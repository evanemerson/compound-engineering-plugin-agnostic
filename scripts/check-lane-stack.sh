#!/usr/bin/env bash
# Check for the lane & stack scheme skill, plugins/cepa/skills/lane-stack/SKILL.md
# (punch-list L62). The skill is the document every repo's lane setup is
# checked against, so what it states as a contract must stay true to itself.
#
# Usage: bash scripts/check-lane-stack.sh [<skill file>]
#   Prints `ok <case>` or `MISS <case> — <why>` per case; exits 1 on any MISS.
#   The optional path lets the controls run it on a mutated copy.
#
# Legs:
#   YAML      the `orca.yaml` example block parses, uses only the top-level
#             keys Orca 1.4.245's parser reads (measured 2026-11-02 in
#             out/shared/orca-yaml.js), and has scripts.setup,
#             scripts.archive and `setupAgentStartupPolicy: wait-for-setup`
#             (the only two values that parser accepts are listed there).
#   GATE      inside the `## The stack gate` section, the gate is cited by
#             path, config path, call shape, output line and exit codes
#             (design "Builder-check answers" 6), the start command
#             is the start only, never a build (L68), and the build mode,
#             its skip and the `make up BUILD=1` rebuild are stated (L70).
#             Scoped to that section
#             so a sentence elsewhere cannot satisfy a needle.
#   MAKE      the `make up` example block is RUN in throwaway git repos with
#             a stub gate and a stub compose: the main checkout starts
#             directly; a lane builds first through the gate's build mode
#             (`--build <project> -- <compose>`, L68/L70), then starts only
#             through the gate, with `<project> -- <compose> up -d
#             --no-build`; `BUILD=1` passes `--rebuild` in a lane and
#             `--build` to compose in the main checkout; a failed build
#             starts nothing and never reaches the start gate; a gate refusal
#             (exit 3) fails make; and each default-deny refusal builds and
#             starts nothing: a lane with no gate, a lane whose project name
#             is unset or lacks `-wt-`, and a severed lane (its main repo
#             moved, so git cannot resolve it). A missing `git` or `make`,
#             or a failed fixture step, is a MISS that names it.
#   TEMPLATE  exactly one four-backtick `markdown` block (the coord@main first
#             prompt); line 1 is `You are <session name>.`; it carries the
#             `<lane names>` and `<lane count>` blanks, steps 1-5 in order
#             each with its anchor, and the `make up` worker-prompt step.
#   ENTRY     every mention of `make worktree branch=` sits beside a word
#             that forbids it (not, never, forbidden), so the skill never
#             presents it as an entry point.
#
# STATED LIMITS: the YAML leg checks the key set against a list copied from
# Orca's parser on one date; a later Orca can add keys, and this check will
# not see that. The MAKE leg runs the example as written with stubs; it does
# not prove any repo's real Makefile is gated (that is L67's /cepa:setup
# check). No leg checks the Setup section: its order (build, then the gate,
# then `.env` and migrations under it) and its two build preconditions are
# prose only. The TEMPLATE leg checks anchors, not the meaning of each step.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }
CEPA_LS_SKILL="$(realpath "${1:-plugins/cepa/skills/lane-stack/SKILL.md}")" python3 - <<'PY'
import os, re, shutil, subprocess, sys, tempfile

path = os.environ["CEPA_LS_SKILL"]
try:
    text = open(path, encoding="utf-8").read()
except OSError as e:
    print("MISS read skill — %s" % e)
    sys.exit(1)

misses = 0
def case(name, ok, why=""):
    global misses
    if ok:
        print("ok %s" % name)
    else:
        misses += 1
        print("MISS %s — %s" % (name, why))

def blocks(lang, fence="```"):
    pat = r"^%s%s\n(.*?)^%s$" % (re.escape(fence), re.escape(lang), re.escape(fence))
    return re.findall(pat, text, re.S | re.M)

# YAML
ORCA_KEYS = {"scripts", "setupAgentStartupPolicy", "issueCommand", "defaultTabs",
             "environmentRecipes", "worktree"}
ys = blocks("yaml")
doc = None
try:
    import yaml
except ImportError:
    yaml = None
    case("YAML PyYAML available", False, "python3 cannot import yaml — install PyYAML")
if len(ys) == 1 and yaml is not None:
    try:
        doc = yaml.safe_load(ys[0])
    except yaml.YAMLError:
        doc = None
case("YAML one orca.yaml block that parses", isinstance(doc, dict),
     "found %d yaml blocks, or the block does not parse to a mapping" % len(ys))
doc = doc if isinstance(doc, dict) else {}
extra = sorted(set(doc) - ORCA_KEYS)
case("YAML only keys Orca reads", not extra, "unknown top-level keys: %s" % extra)
sc = doc.get("scripts") if isinstance(doc.get("scripts"), dict) else {}
case("YAML scripts.setup present", bool(str(sc.get("setup") or "").strip()), "no scripts.setup")
case("YAML scripts.archive present", bool(str(sc.get("archive") or "").strip()), "no scripts.archive")
case("YAML policy wait-for-setup", doc.get("setupAgentStartupPolicy") == "wait-for-setup",
     "setupAgentStartupPolicy is %r" % doc.get("setupAgentStartupPolicy"))
case("YAML setup strips COMPOSE_PROJECT_NAME",
     str(sc.get("setup") or "").startswith("env -u COMPOSE_PROJECT_NAME "),
     "setup does not start with `env -u COMPOSE_PROJECT_NAME`")

# GATE
gm = re.search(r"^## The stack gate\n(.*?)(?=^## )", text, re.S | re.M)
gsec = gm.group(1) if gm else ""
case("GATE section present", bool(gsec), "no `## The stack gate` section")
for name, needle in [
    ("GATE script path", "`plugins/cepa/scripts/stack-gate.sh`"),
    ("GATE config path", "`~/.config/cepa/stack-gate.conf`"),
    ("GATE call shape", "`stack-gate.sh <compose project name> -- <start command…>`"),
    ("GATE refused line", "`STACK gate: refused — …`"),
    ("GATE exit 3 refused", "`3` refused (the start command did not run)"),
    ("GATE exit 2 usage", "`2` usage"),
    ("GATE runs start under lock", "runs the start command itself, under its lock"),
    ("GATE counts running only", "at least one running container (stopped\n  stacks do not count)"),
    ("GATE start is never a build", "**The start command is the start only, never a build:**"),
    ("GATE build mode call shape", "`stack-gate.sh --build <compose project name> -- <compose command…>`"),
    ("GATE build skipped when images exist", "it skips the build and\n  takes no lock"),
    ("GATE rebuild with BUILD=1", "**run `make up BUILD=1` after any\n  change to a Dockerfile"),
]:
    case(name, needle in gsec, "the stack gate section no longer says %r" % needle)

# MAKE
MAKE_CASES = ("MAKE main starts directly", "MAKE lane starts through gate",
              "MAKE lane builds before the gate", "MAKE lane build failure starts nothing",
              "MAKE lane gate refusal propagates", "MAKE lane without gate refuses",
              "MAKE lane unset project refuses", "MAKE lane non-wt project refuses",
              "MAKE severed lane refuses", "MAKE BUILD=1 rebuilds")
ms = blocks("make")
tools = [t for t in ("git", "make") if not shutil.which(t)]
if len(ms) != 1 or tools:
    for n in MAKE_CASES:
        case(n, False, "found %d make blocks (expected 1), missing tools %s" % (len(ms), tools))
else:
    with tempfile.TemporaryDirectory() as d:
        mk = os.path.join(d, "Makefile")
        # The compose stub prints `START <args>`; STUB_BUILD_FAIL fails a build.
        comp = os.path.join(d, "compose")
        with open(comp, "w") as f:
            f.write('#!/usr/bin/env bash\necho "START $*"\n'
                    'if [ -n "${STUB_BUILD_FAIL:-}" ] && [ "${1:-}" = build ]; then exit 1; fi\n')
        os.chmod(comp, 0o755)
        with open(mk, "w") as f:
            f.write("DEV_COMPOSE = %s\nworktree-guard:\n\t@true\n" % comp + ms[0])
        root = os.path.join(d, "root")
        os.makedirs(os.path.join(root, "scripts"))
        with open(os.path.join(root, "scripts", "resolve-plugin-root.sh"), "w") as f:
            f.write("#!/usr/bin/env bash\necho %s\n" % root)
        with open(os.path.join(root, "scripts", "stack-gate.sh"), "w") as f:
            f.write('#!/usr/bin/env bash\necho "GATE $*"\n'
                    'case "$1" in --build|--rebuild) shift 3; "$@" build; exit $?;; esac\n'
                    'if [ -n "${STUB_REFUSE:-}" ]; then echo "STACK gate: refused — stub"; exit 3; fi\n'
                    'shift 2\n"$@"\n')
        # A caller's GIT_DIR / GIT_WORK_TREE / GIT_INDEX_FILE (a hook) would
        # point the fixture at the real repo: drop every GIT_* variable.
        base = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
        base.update(GIT_AUTHOR_NAME="c", GIT_AUTHOR_EMAIL="c@c",
                    GIT_COMMITTER_NAME="c", GIT_COMMITTER_EMAIL="c@c",
                    GIT_CONFIG_NOSYSTEM="1", HOME=os.path.join(d, "nohome"))
        def run(args, cwd, env=None):
            return subprocess.run(args, cwd=cwd, env=env or base, capture_output=True, text=True)
        main, lane = os.path.join(d, "main"), os.path.join(d, "lane")
        sev_main, sev_lane = os.path.join(d, "smain"), os.path.join(d, "slane")
        setup_err = ""
        for m_dir, l_dir in ((main, lane), (sev_main, sev_lane)):
            os.makedirs(m_dir)
            for args, cwd in ((["git", "init", "-q"], m_dir),
                              (["git", "commit", "-q", "--allow-empty", "-m", "x"], m_dir),
                              (["git", "worktree", "add", "-q", l_dir], m_dir)):
                r = run(args, cwd)
                if r.returncode != 0 and not setup_err:
                    setup_err = "%s failed: %s" % (" ".join(args), r.stderr.strip())
        if not setup_err:
            os.rename(sev_main, sev_main + "-moved")   # severs the lane's .git link
        if setup_err:
            for n in MAKE_CASES:
                case(n, False, "fixture setup: " + setup_err)
        else:
            def make(cwd, **env):
                e = dict(base, CEPA_PLUGIN_ROOT="")
                e.pop("COMPOSE_PROJECT_NAME", None)
                e.update(env)
                return run(["make", "-s", "-f", mk, "up"], cwd, e)
            def show(r):
                return "rc=%d out=%r" % (r.returncode, r.stdout + r.stderr)
            proj = "x-wt-lane-1"
            up = "START up -d --no-build"
            gate_line = "GATE %s -- %s up -d --no-build" % (proj, comp)
            build_line = "GATE --build %s -- %s" % (proj, comp)
            def lines(r):
                return r.stdout.splitlines()
            def nothing(r):  # nothing built, nothing started, gate never called
                return not any(l.startswith(("START", "GATE")) for l in lines(r))
            r = make(main, CEPA_PLUGIN_ROOT=root)
            case("MAKE main starts directly",
                 r.returncode == 0 and r.stdout.strip() == "START up -d", show(r))
            r = make(lane, CEPA_PLUGIN_ROOT=root, COMPOSE_PROJECT_NAME=proj)
            ls = lines(r)
            case("MAKE lane starts through gate",
                 r.returncode == 0 and gate_line in ls and up in ls
                 and ls.index(up) == ls.index(gate_line) + 1, show(r))
            case("MAKE lane builds before the gate",
                 build_line in ls and "START build" in ls and gate_line in ls
                 and ls.index(build_line) + 1 == ls.index("START build") < ls.index(gate_line), show(r))
            r = make(lane, CEPA_PLUGIN_ROOT=root, COMPOSE_PROJECT_NAME=proj, STUB_BUILD_FAIL="1")
            case("MAKE lane build failure starts nothing",
                 r.returncode != 0 and "START build" in lines(r)
                 and not any(l.startswith(("START up", "GATE " + proj)) for l in lines(r))
                 and "STACK build: failed" in r.stdout, show(r))
            r = make(lane, CEPA_PLUGIN_ROOT=root, COMPOSE_PROJECT_NAME=proj, STUB_REFUSE="1")
            case("MAKE lane gate refusal propagates",
                 r.returncode != 0 and up not in lines(r) and "STACK gate: refused" in r.stdout, show(r))
            r = make(lane, COMPOSE_PROJECT_NAME=proj)
            case("MAKE lane without gate refuses",
                 r.returncode != 0 and nothing(r) and "STACK gate: not found" in r.stdout, show(r))
            r = make(lane, CEPA_PLUGIN_ROOT=root)
            case("MAKE lane unset project refuses",
                 r.returncode != 0 and nothing(r) and "has no -wt-" in r.stdout, show(r))
            r = make(lane, CEPA_PLUGIN_ROOT=root, COMPOSE_PROJECT_NAME="x")
            case("MAKE lane non-wt project refuses",
                 r.returncode != 0 and nothing(r) and "has no -wt-" in r.stdout, show(r))
            r = make(lane, CEPA_PLUGIN_ROOT=root, COMPOSE_PROJECT_NAME=proj, BUILD="1")
            rm = make(main, CEPA_PLUGIN_ROOT=root, BUILD="1")
            ls = lines(r)
            case("MAKE BUILD=1 rebuilds",
                 r.returncode == 0 and ("GATE --rebuild %s -- %s" % (proj, comp)) in ls
                 and build_line not in ls and gate_line in ls
                 and rm.returncode == 0 and rm.stdout.strip() == "START up -d --build",
                 show(r) + " main " + show(rm))
            r = make(sev_lane, CEPA_PLUGIN_ROOT=root, COMPOSE_PROJECT_NAME=proj)
            case("MAKE severed lane refuses",
                 r.returncode != 0 and nothing(r) and "checkout identity unknown" in r.stdout, show(r))

# TEMPLATE
ts = blocks("markdown", "````")
case("TEMPLATE one first-prompt block", len(ts) == 1, "found %d four-backtick markdown blocks" % len(ts))
t = ts[0] if ts else ""
case("TEMPLATE line 1 is the name blank", t.split("\n", 1)[0] == "You are <session name>.",
     "line 1 is %r" % t.split("\n", 1)[0])
for blank in ("<lane names>", "<lane count>"):
    case("TEMPLATE blank %s" % blank, blank in t, "missing %s" % blank)
ANCHORS = [(1, "re-bind block"), (2, "`orca.yaml`"), (3, "/cepa:review"),
           (4, "`orca-lane.sh create`"), (5, "`orca-lane.sh rm` first, then")]
pos, order_ok, why = -1, True, ""
for n, anchor in ANCHORS:
    m = re.search(r"^%d\. (.*?)(?=^\d\. |\Z)" % n, t, re.S | re.M)
    if not m or anchor not in m.group(1) or m.start() < pos:
        order_ok, why = False, "step %d missing, out of order, or without %r" % (n, anchor)
        break
    pos = m.start()
case("TEMPLATE steps 1-5 in order", order_ok, why)
case("TEMPLATE worker step make up", "start the stack with `make up` before exec targets" in t,
     "the template does not carry the worker-prompt `make up` step")

# ENTRY
bad = []
for m in re.finditer(r"make worktree branch=", text):
    win = text[max(0, m.start() - 120): m.end() + 120].replace("\n", " ")
    if not re.search(r"\b(not|never|forbidden)\b", win):
        bad.append(m.start())
case("ENTRY make worktree branch= only as forbidden", not bad,
     "mention at offset(s) %s with no forbidding word nearby" % bad)

sys.exit(1 if misses else 0)
PY
