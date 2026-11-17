#!/usr/bin/env bash
# Controls for scripts/check-lane-scheme.sh. Each mutant is one substitution in
# a temp copy of plugins/cepa/scripts/lane_scheme.py. It must turn the check
# red with EXACTLY the MISS cases named beside it, so each mutant shows which
# case catches it and that no other case does. The unmutated copy must run
# with no MISS line, or every red below proves nothing. A mutant whose anchor
# is not found exactly once is a MISS, never a skip: the script changed shape
# and the mutant needs re-reading.
#
# Usage: bash scripts/check-lane-scheme-controls.sh [--discover]
#   --discover prints each mutant's actual MISS set instead of judging it.
#
# STATED LIMITS: a mutant is one substitution; two compensating edits are not
# modeled. The controls prove each named case can fail, not that the case
# list is complete.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }
CEPA_DISCOVER="${1:-}" python3 - <<'PY'
import concurrent.futures, os, re, subprocess, sys, tempfile

SCRIPT = "plugins/cepa/scripts/lane_scheme.py"
CHECK = "scripts/check-lane-scheme.sh"
DISCOVER = os.environ.get("CEPA_DISCOVER") == "--discover"
src = open(SCRIPT, encoding="utf-8").read()

B = "BASE row %s is %s"
# (name, old, new, exact MISS case set, or ("contains", set) for a mutant
# that breaks BASE: every case then fails, so only the named ones are pinned)
MUTANTS = [
    # YAML contract
    ("dup-key-ignored", "                if key in seen:", "                if False:",
     {"CASE yaml duplicate key voids the file"}),
    ("policy-any-value", '''r.add("OK" if pol == "wait-for-setup" else "MISS", "policy",''',
     '''r.add("OK" if pol in POLICY_VALUES else "MISS", "policy",''', {"CASE policy start-immediately"}),
    ("setup-optional-in-docker", '''r.add("OK" if setup_cmd else "MISS", "setup",''', '''r.add("OK", "setup",''',
     {"CASE no setup in a Docker repo"}),
    ("archive-optional-in-docker", '''r.add("OK" if str(archive or "").strip() else "MISS", "archive",''',
     '''r.add("OK", "archive",''', {"CASE no archive in a Docker repo"}),
    ("archive-allowed-non-docker", '''r.add("MISS" if str(archive or "").strip() else "OK", "archive",''',
     '''r.add("OK", "archive",''', {"CASE non-Docker repo with archive"}),
    ("worktreeinclude-ignored", 'if os.path.lexists(os.path.join(root, ".worktreeinclude")):', "if False:",
     {"CASE .worktreeinclude present"}),
    ("node-modules-shareable", 'PER_BRANCH = re.compile(r"^(node_modules|', 'PER_BRANCH = re.compile(r"^(',
     {"CASE shared node_modules"}),
    ("unknown-keys-silent", "        if extra:\n", "        if False:\n",
     {"CASE unknown key is only INFO"}),
    ("no-orca-yaml-checked", "    if not os.path.exists(yml):\n", "    if False:\n", {"CASE no orca.yaml"}),
    ("all-docker", "    docker = bool(composes)\n", "    docker = True\n", {"CASE non-Docker repo with archive"}),
    # ENTRY
    ("entry-any-window", r'''if not re.search(r"\b(not|never|forbidden|fallback)\b|orca-lane\.sh", win, re.I):''',
     "if False:", {"CASE entry point named in CLAUDE.md"}),
    ("worktree-help-unchecked", '''            and "orca-lane" not in mk.targets["worktree"]["help"]:''',
     "            and False:", {"CASE worktree help without orca-lane.sh"}),
    # TIMEOUT
    ("timeout-unseen", r'''            if re.search(r"(?:^|[\s(])timeout\s", seg) and "--foreground" not in seg \
''', "            if False \\\n", {"CASE bare timeout in setup"}),
    ("timeout-T-ignored", '''                    and not (re.search(r"(?:^|\\s)-T(?:\\s|$)", seg) and "</dev/null" in seg.replace(" ", "")):''',
     "                    and True:", {"CASE timeout with -T and </dev/null is fine"}),
    # TEXT: a word in a message is not code
    ("messages-count", '''        line = MSG_RE.sub(r'\\1 ""', line)\n''', "",
     {"CASE gate named only in a message", "CASE stop only in a message", "CASE refusal only in a message"}),
    # SETUP CLOSURE
    ("wt-always", '''r.add("OK" if "-wt-" in closure else "MISS", "wt-name",''', '''r.add("OK", "wt-name",''',
     {"CASE no -wt- in the project name"}),
    ("setup-gate-always", '''r.add("OK" if GATE_RE.search(closure) else "MISS", "setup-gate",''', '''r.add("OK", "setup-gate",''',
     {"CASE gate named only in a message"}),
    ("stop-always", "        stops = any(", "        stops = True or any(",
     {"CASE stop only in a message", "CASE script without stop"}),
    ("no-compose-aliases", "            names.add(m.group(1))", "            pass",
     {"CASE setup through a script with a compose function"}),
    ("closure-no-make-calls", '''            queue += mk.targets[t]["prereqs"] + make_targets_in(rec)''',
     '''            queue += mk.targets[t]["prereqs"]''', ("contains", {B % ("stop", "OK"), "BASE skill examples report no MISS"})),
    ("make-flag-value-split", '''                depth += t.count("(") - t.count(")")''', "                depth += 0",
     ("contains", {B % ("start:worktree-init-stack", "OK"), B % ("stop", "OK"), "BASE skill examples report no MISS"})),
    ("unresolved-target-silent", "                    unresolved.append(t)", "                    pass",
     {"CASE setup runs a target with no rule"}),
    # START targets
    ("make-up-always", "        ok = bool(GATE_RE.search(rec)) or bool(via)", "        ok = True",
     {"CASE ungated make up"}),
    ("start-always-gated", "        elif GATE_RE.search(rec):\n", "        elif True:\n",
     {"CASE gate named only in a message", "CASE refusal only in a message", "CASE ungated make up",
      "CASE ungated restart"}),
    ("refusal-unseen", "        elif REFUSAL_RE.search(rec) or REFUSAL_RE.search(raw):\n", "        elif False:\n",
     ("contains", {B % ("start:fresh", "OK"), "BASE skill examples report no MISS"})),
    ("gated-caller-unseen", "                gated_callers.setdefault(callee, t)", "                pass",
     ("contains", {B % ("start:worktree-init-stack", "OK"), "BASE skill examples report no MISS"})),
    ("prod-file-unseen", "all(OTHER_STACK_FILE.search(x) for x in f)", "False",
     {"CASE prod stack by file name"}),
    ("prod-name-unseen", "if OTHER_STACK_TARGET.search(t) or ", "if ",
     {"CASE prod target with no -f"}),
]

def misses(out):
    return {re.sub(r" — .*", "", l[5:]) for l in out.splitlines() if l.startswith("MISS ")}

def run(text):
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "lane_scheme.py")
        open(p, "w").write(text)
        r = subprocess.run(["bash", CHECK, p], capture_output=True, text=True, timeout=600)
        return r.returncode, r.stdout + r.stderr

fails = 0
def case(name, ok, why=""):
    global fails
    print(("ok %s" % name) if ok else ("MISS %s — %s" % (name, why)))
    fails += 0 if ok else 1

rc, out = run(src)
case("control baseline: unmutated check is clean", rc == 0 and not misses(out), out[-800:])

jobs = []
for name, old, new, want in MUTANTS:
    n = src.count(old)
    if n != 1:
        case("control %s" % name, False, "anchor found %d times" % n)
        continue
    jobs.append((name, src.replace(old, new), want))
with concurrent.futures.ThreadPoolExecutor(4) as ex:
    results = list(ex.map(lambda j: (j[0], j[2]) + run(j[1]), jobs))
seen = set()
for name, want, rc, out in results:
    got = misses(out)
    seen |= got
    if DISCOVER:
        print("DISCOVER %s rc=%d %s" % (name, rc, sorted(got)))
        continue
    if isinstance(want, tuple):
        case("control %s (contains)" % name, rc != 0 and want[1] <= got,
             "rc=%d got %s, want at least %s" % (rc, sorted(got), sorted(want[1])))
    else:
        case("control %s" % name, rc != 0 and got == want,
             "rc=%d got %s want %s" % (rc, sorted(got), sorted(want)))

if not DISCOVER:
    rc, out = run(src)
    every = {re.sub(r"^ok ", "", l) for l in out.splitlines() if l.startswith("ok ")}
    every.discard("SKILL one yaml and one make example")
    unkilled = sorted(every - seen)
    case("control every case has a mutant that kills it", not unkilled, "unkilled: %s" % unkilled)
sys.exit(1 if fails else 0)
PY
