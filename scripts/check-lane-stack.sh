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
#   GATE      the gate is cited by path, config path, call shape, output
#             line and exit codes (design "Builder-check answers" 6).
#   MAKE      the `make up` example block is RUN in throwaway git repos with
#             a stub gate: the main checkout starts directly; a lane starts
#             only through the gate, with `<project> -- <start>`; a lane with
#             no gate exits non-zero and does not run the start command.
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
# check). The TEMPLATE leg checks anchors, not the meaning of each step.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }
CEPA_LS_SKILL="$(realpath "${1:-plugins/cepa/skills/lane-stack/SKILL.md}")" python3 - <<'PY'
import os, re, subprocess, sys, tempfile

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
if len(ys) == 1:
    try:
        import yaml
        doc = yaml.safe_load(ys[0])
    except Exception as e:  # noqa: BLE001 - any parse failure is the finding
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
for name, needle in [
    ("GATE script path", "`plugins/cepa/scripts/stack-gate.sh`"),
    ("GATE config path", "`~/.config/cepa/stack-gate.conf`"),
    ("GATE call shape", "`stack-gate.sh <compose project name> -- <start command…>`"),
    ("GATE refused line", "`STACK gate: refused — …`"),
    ("GATE exit 3 refused", "`3` refused (the start command did not run)"),
    ("GATE exit 2 usage", "`2` usage"),
    ("GATE runs start under lock", "runs the start command itself, under its lock"),
    ("GATE counts running only", "at least one running container (stopped\n  stacks do not count)"),
]:
    case(name, needle in text, "the skill no longer says %r" % needle)

# MAKE
ms = blocks("make")
if len(ms) != 1:
    for n in ("MAKE main starts directly", "MAKE lane starts through gate",
              "MAKE lane without gate refuses"):
        case(n, False, "found %d make blocks, expected 1" % len(ms))
else:
    with tempfile.TemporaryDirectory() as d:
        mk = os.path.join(d, "Makefile")
        with open(mk, "w") as f:
            f.write("DEV_COMPOSE = echo START\nworktree-guard:\n\t@true\n" + ms[0])
        root = os.path.join(d, "root")
        os.makedirs(os.path.join(root, "scripts"))
        with open(os.path.join(root, "scripts", "resolve-plugin-root.sh"), "w") as f:
            f.write("#!/usr/bin/env bash\necho %s\n" % root)
        with open(os.path.join(root, "scripts", "stack-gate.sh"), "w") as f:
            f.write('#!/usr/bin/env bash\necho "GATE $*"\nshift 2\n"$@"\n')
        main = os.path.join(d, "main")
        lane = os.path.join(d, "lane")
        genv = dict(os.environ, GIT_AUTHOR_NAME="c", GIT_AUTHOR_EMAIL="c@c",
                    GIT_COMMITTER_NAME="c", GIT_COMMITTER_EMAIL="c@c")
        def run(args, cwd, env=None):
            return subprocess.run(args, cwd=cwd, env=env or genv, capture_output=True, text=True)
        os.makedirs(main)
        run(["git", "init", "-q"], main)
        run(["git", "commit", "-q", "--allow-empty", "-m", "x"], main)
        run(["git", "worktree", "add", "-q", lane], main)
        def make(cwd, **env):
            e = dict(genv, HOME=os.path.join(d, "nohome"), CEPA_PLUGIN_ROOT="")
            e.pop("COMPOSE_PROJECT_NAME", None)
            e.update(env)
            return run(["make", "-s", "-f", mk, "up"], cwd, e)
        r = make(main, CEPA_PLUGIN_ROOT=root)
        case("MAKE main starts directly",
             r.returncode == 0 and r.stdout.strip() == "START up -d",
             "rc=%d out=%r" % (r.returncode, r.stdout + r.stderr))
        r = make(lane, CEPA_PLUGIN_ROOT=root, COMPOSE_PROJECT_NAME="x-wt-lane-1")
        case("MAKE lane starts through gate",
             r.returncode == 0 and r.stdout.splitlines() == ["GATE x-wt-lane-1 -- echo START up -d", "START up -d"],
             "rc=%d out=%r" % (r.returncode, r.stdout + r.stderr))
        r = make(lane, COMPOSE_PROJECT_NAME="x-wt-lane-1")
        case("MAKE lane without gate refuses",
             r.returncode != 0 and "START" not in r.stdout and "STACK gate: not found" in r.stdout,
             "rc=%d out=%r" % (r.returncode, r.stdout + r.stderr))

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
