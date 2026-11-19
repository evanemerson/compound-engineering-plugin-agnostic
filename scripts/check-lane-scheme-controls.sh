#!/usr/bin/env bash
# Controls for scripts/check-lane-scheme.sh. Each mutant is one substitution in
# a temp copy of plugins/cepa/scripts/lane_scheme.py. It must turn the check
# red with EXACTLY the MISS cases pinned for it in
# scripts/check-lane-scheme-controls.want, so each mutant shows which case
# catches it and that no other case does. A mutant that breaks BASE is pinned
# as ("contains", <its BASE rows>) instead. The unmutated copy must run with
# no MISS line, or every red below proves nothing. A mutant whose anchor is
# not found exactly once, or that is not valid Python, is a MISS, never a
# skip: a crash is not a kill. The last control asserts that every case is
# killed by an exact mutant (or is a pinned BASE row of a "contains" one).
#
# Usage: bash scripts/check-lane-scheme-controls.sh [--discover]
#   --discover prints each mutant's actual MISS set instead of judging it;
#   pin from it by reading, never by copying blind.
#
# STATED LIMITS: a mutant is one substitution; two compensating edits are not
# modeled. The controls prove each named case can fail, not that the case
# list is complete.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }
CEPA_DISCOVER="${1:-}" python3 - <<'PY'
import ast, concurrent.futures, os, re, subprocess, sys, tempfile

SCRIPT = "plugins/cepa/scripts/lane_scheme.py"
CHECK = "scripts/check-lane-scheme.sh"
DISCOVER = os.environ.get("CEPA_DISCOVER") == "--discover"
src = open(SCRIPT, encoding="utf-8").read()

B = "BASE row %s is %s"
# (name, old, new) — the expected set is pinned in WANT below, by name.
MUTANTS = [
    # YAML contract
    ("dup-key-ignored", "                if key in seen:", "                if False:"),
    ("yaml-value-error-escapes", "    except (yaml.YAMLError, ValueError, OverflowError, RecursionError) as e:",
     "    except yaml.YAMLError as e:"),
    ("not-a-mapping-accepted", '        return None, "the file is not a mapping"', "        return {}, None"),
    ("policy-any-value", 'r.add("OK" if pol == "wait-for-setup" else "MISS", "policy",',
     'r.add("OK" if pol in POLICY_VALUES or pol is None else "MISS", "policy",'),
    ("setup-optional-in-docker", 'r.add("OK" if setup_cmd else "MISS", "setup",', 'r.add("OK", "setup",'),
    ("setup-list-accepted", '        if setup is not None and not isinstance(setup, str):\n', "        if False:\n"),
    ("archive-optional-in-docker", 'r.add("OK" if str(archive or "").strip() else "MISS", "archive",', 'r.add("OK", "archive",'),
    ("archive-allowed-non-docker", 'r.add("MISS" if str(archive or "").strip() else "OK", "archive",', 'r.add("OK", "archive",'),
    ("shape-unchecked", '            if doc.get(key) is not None and not isinstance(doc.get(key), dict):', "            if False:"),
    ("worktreeinclude-exists-only", 'if os.path.lexists(os.path.join(root, ".worktreeinclude")):',
     'if os.path.exists(os.path.join(root, ".worktreeinclude")):'),
    ("node-modules-shareable", 'PER_BRANCH = re.compile(r"^(node_modules|', 'PER_BRANCH = re.compile(r"^('),
    ("env-shareable", r"|target|\.env(\..+)?)/?$", "|target)/?$"),
    ("shared-scalar-iterated", "        shared = shared if isinstance(shared, list) else [shared]\n",
     "        shared = list(shared)\n"),
    ("unknown-keys-silent", "        if extra:\n", "        if False:\n"),
    ('rows-not-one-line', '    return re.sub(r"[\\x00-\\x1f\\x7f]", "?", " ".join(str(x).split()))[:n]', '    return str(x)[:n]'),
    ("orca-yaml-exists-only", "    if not os.path.lexists(yml):", "    if not os.path.exists(yml):"),
    # Docker detection and the Makefile
    ("docker-by-root-only", "    docker = bool(composes) or mk_compose\n", "    docker = bool(composes)\n"),
    ("compose-yaml-ignored", r're.fullmatch(r"(docker-)?compose[\w.-]*\.ya?ml"', r're.fullmatch(r"docker-compose[\w.-]*\.ya?ml"'),
    ("makefile-last-wins", "            mk_path = n\n            break\n", "            mk_path = n\n"),
    ("continuation-not-flattened", '            flat = raw.replace("\\\\\\n", " ").strip()', "            flat = raw.strip()"),
    ("conditional-ends-recipe", "            if self.COND.match(flat):     # a conditional keeps the recipe context\n                continue\n", ""),
    ("second-rule-dropped", "                    if all(rec is not c for c in cur):\n                        cur.append(rec)",
     "                    if all(rec is not c for c in cur) and rec is fresh:\n                        cur.append(rec)"),
    # ENTRY
    ("entry-any-window", r'if not re.search(r"\b(not|never|forbidden|fallback)\b|orca-lane\.sh", win, re.I):', "if False:"),
    ("worktree-help-unchecked", '            and "orca-lane" not in mk.targets["worktree"]["help"]:', "            and False:"),
    ("unread-entry-ok", '    elif unread:\n        r.add("INFO", "entry",', '    elif False:\n        r.add("INFO", "entry",'),
    # TIMEOUT
    ("timeout-unseen", '            if re.search(r"(?:^|[\\s(])timeout\\s", seg) and "--foreground" not in seg \\\n',
     "            if False \\\n"),
    ("foreground-needs-k", '            if re.search(r"(?:^|[\\s(])timeout\\s", seg) and "--foreground" not in seg \\\n',
     '            if re.search(r"(?:^|[\\s(])timeout\\s", seg) and not ("--foreground" in seg and "-k" in seg) \\\n'),
    # the cepa.local.md opt-out (L90)
    ("optout-ignored", '    if lanes is not None and lanes.lower() == "none":', "    if False:"),
    ("optout-any-value", '    if lanes is not None and lanes.lower() == "none":', "    if lanes is not None:"),
    ("optout-any-section", '        if section == "Conventions" and value is None:', "        if value is None:"),
    ("optout-in-fence", "        if fence:\n            continue\n", ""),
    ("optout-marker-required", r'LANES_RE = re.compile(r"^\s*(?:[-*]\s+)?lanes', r'LANES_RE = re.compile(r"^\s*[-*]\s+lanes'),
    ("optout-backticks-kept", """.strip().strip("`\\"'")""", ".strip()"),
    ("optout-unread-silent", "    if lerr:\n", "    if False:\n"),
    ("skip-by-dir-name", "def check(root):\n    r = Report()\n",
     'def check(root):\n    r = Report()\n    if os.path.basename(root) == "farmtender":\n        return r\n'),
    ("timeout-T-alone", '                    and not (re.search(r"(?:^|\\s)-T(?:\\s|$)", seg) and "</dev/null" in seg.replace(" ", "")):',
     '                    and not (re.search(r"(?:^|\\s)-T(?:\\s|$)", seg)):'),
    ("timeout-devnull-alone", '                    and not (re.search(r"(?:^|\\s)-T(?:\\s|$)", seg) and "</dev/null" in seg.replace(" ", "")):',
     '                    and not ("</dev/null" in seg.replace(" ", "")):'),
    ("timeout-ok-unread", '    if doc is None:\n        r.add("INFO", "timeout",', '    if False:\n        r.add("INFO", "timeout",'),
    # TEXT: a word in a message or a comment is not code
    ('messages-count', '        line = MSG_RE.sub(r\'\\1\\2 ""\', line)\n', ''),
    ("trailing-comments-count", "        line = re.sub(r\"\"\"(^|\\s)#[^'\"]*$\"\"\", r\"\\1\", line)     # a trailing comment\n", ""),
    # SETUP CLOSURE
    ("wt-always", 'r.add("OK" if "-wt-" in closure else "MISS", "wt-name",', 'r.add("OK", "wt-name",'),
    ("setup-gate-always", 'r.add("OK" if GATE_RE.search(closure) else "MISS", "setup-gate",', 'r.add("OK", "setup-gate",'),
    ("stop-any-token", '        stops = any(compose_verb(toks)[0] == "stop"',
     '        stops = any("stop" in [x.strip("\\"\';") for x in toks]'),
    ("no-compose-aliases", "            names.add(m.group(1))", "            pass"),
    ("alias-arg-is-verb", '        if t.startswith("$"):            # `dc_project "$P" stop`: an argument, not the verb\n            k += 1\n            continue\n', ""),
    ("closure-no-make-calls", "            queue += mk.expand(\" \".join(mk.targets[t][\"prereqs\"])).split() + make_targets_in(rec)",
     "            queue += mk.expand(\" \".join(mk.targets[t][\"prereqs\"])).split()"),
    ("make-flag-value-split", '                depth += t.count("(") - t.count(")")', "                depth += 0"),
    ("make-j-value-target", '"-j", "-l", "-I",', '"-l", "-I",'),
    ("unresolved-target-silent", "                    unresolved.append(t)", "                    pass"),
    ('missing-script-silent', '        elif missing is not None and p not in missing \\\n', '        elif False \\\n'),
    ("empty-closure-ok", "    elif len(texts) <= 1:\n", "    elif False:\n"),
    # START targets
    ("make-up-always", "        ok = bool(GATE_RE.search(rec)) or bool(via)", "        ok = True"),
    ("make-up-no-via", "        ok = bool(GATE_RE.search(rec)) or bool(via)", "        ok = bool(GATE_RE.search(rec))"),
    ("no-up-ok", '        r.add("MISS", "make-up", "%s has no `up` target', '        r.add("OK", "make-up", "%s has no `up` target'),
    ("start-always-gated", "        elif GATE_RE.search(rec):\n", "        elif True:\n"),
    ("gate-case-sensitive", 'GATE_RE = re.compile(r"stack[-_]gate", re.I)', 'GATE_RE = re.compile(r"stack-gate")'),
    ('refusal-unseen', '        elif REFUSAL_RE.search(code_of(mk.recipe(t), printf=True)) or REFUSAL_RE.search(raw):\n', '        elif False:\n'),
    ("refusal-narrow", 'REFUSAL_RE = re.compile(r"refus|main[-_]only|require-main|is-main|not run in a lane", re.I)',
     'REFUSAL_RE = re.compile(r"refus|not run in a lane", re.I)'),
    ("gated-caller-unseen", "                gated_callers.setdefault(callee, t)", "                pass"),
    ("no-f-is-other", "                      and not (f and all(OTHER_STACK_FILE.search(x) for x in f))]",
     "                      and not all(OTHER_STACK_FILE.search(x) for x in f)]"),
    ("any-file-is-other", "                      and not (f and all(OTHER_STACK_FILE.search(x) for x in f))]",
     "                      and not (f and any(OTHER_STACK_FILE.search(x) for x in f))]"),
    ("prod-name-unseen", "        lane_sites = [(v, f) for v, f in sites if not OTHER_STACK_TARGET.search(t)\n",
     "        lane_sites = [(v, f) for v, f in sites if True\n"),
    ("prod-name-unanchored", r'OTHER_STACK_TARGET = re.compile(r"(^|[-_])(prod|proxy)([-_]|$)")', r'OTHER_STACK_TARGET = re.compile(r"(prod|proxy)")'),
    ("legacy-compose-unseen", r'COMPOSE_RE = r"(?:\bdocker[ -]compose\b)"', r'COMPOSE_RE = r"(?:\bdocker compose\b)"'),
    ("start-verb-dropped", 'START_VERBS = ("up", "start", "restart")', 'START_VERBS = ("up", "restart")'),
    ("profile-is-verb", '"--profile", ', ""),
    # adversarial-review fixes
    ("merge-key-is-a-key", '                if knode.tag == "tag:yaml.org,2002:merge":   # `<<: *anchor` is not a key\n                    continue\n', ""),
    ('echo-flags-unseen', '(echo|die|warn|fail|error|info|log)((?:\\s+-[A-Za-z]+|\\s+[0-9]?>&[0-9])*)', '(echo|die|warn|fail|error|info|log)()'),
    ("printf-refusal-counts", "        if printf:\n            line = PRINTF_RE.sub(", "        if False:\n            line = PRINTF_RE.sub("),
    ("file-substring-is-other", r'OTHER_STACK_FILE = re.compile(r"(^|[/._-])(prod|production|proxy|traefik)([/._-]|$)", re.I)',
     r'OTHER_STACK_FILE = re.compile(r"prod|proxy|traefik", re.I)'),
    ('caller-any-mention', '                if " -- " in seg and re.search(r"\\bGATE\\b|stack[-_]gate", seg, re.I):\n                    for callee in make_targets_in(seg.split(" -- ", 1)[1]):', '                if True:\n                    for callee in make_targets_in(seg):'),
    ("up-not-followed", '            if sub in mk.targets and sub != "up":    # `up: dev-up`: one level down', '            if False:'),
    ("fifo-read", '        if not os.path.isfile(path):         # a FIFO or a device never returns', '        if os.path.isdir(path):'),
    ("worktreeinclude-unchecked", 'if os.path.lexists(os.path.join(root, ".worktreeinclude")):', "if False:"),
    ("entry-never-forbidden", r'if not re.search(r"\b(not|never|forbidden|fallback)\b|orca-lane\.sh", win, re.I):',
     r'if not re.search(r"(?!)", win, re.I):'),
    ("no-orca-yaml-checked", "    if not os.path.lexists(yml):\n", "    if False:\n"),
    ("invalid-policy-unseen", "        if pol is not None and pol not in POLICY_VALUES:\n", "        if False:\n"),
    ("prod-file-unseen", r'OTHER_STACK_FILE = re.compile(r"(^|[/._-])(prod|production|proxy|traefik)([/._-]|$)", re.I)',
     r'OTHER_STACK_FILE = re.compile(r"(?!)")'),
    ("stop-always", '        stops = any(compose_verb(toks)[0] == "stop"', '        stops = True or any(compose_verb(toks)[0] == "stop"'),
    ("every-dir-per-branch", "for s in shared if not isinstance(s, str) or PER_BRANCH.match(s.strip())]", "for s in shared]"),
    ("timeout-no-exemption", '                    and not (re.search(r"(?:^|\\s)-T(?:\\s|$)", seg) and "</dev/null" in seg.replace(" ", "")):',
     "                    and True:"),
    ("invalid-policy-ok", '            r.add("MISS", "policy", "setupAgentStartupPolicy %s is not a value Orca accepts',
     '            r.add("OK", "policy", "setupAgentStartupPolicy %s is not a value Orca accepts'),
    ("unicode-digit-crash", "        if args is not None and inner.isascii() and inner.isdigit():", "        if args is not None and inner.isdigit():"),
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

# WANT pins each mutant's MISS set: a set is EXACT; ("contains", set) is for a
# mutant that breaks BASE, where every case fails and only the named ones are
# pinned. Only exact mutants count toward "every case has a killer": a
# mutant that breaks everything proves no single case can fail.
WANT = {}
exec(open(os.path.join(os.path.dirname(CHECK), "check-lane-scheme-controls.want")).read(), {"B": B}, WANT)
WANT = WANT["WANT"]

jobs = []
for name, old, new in MUTANTS:
    n = src.count(old)
    if n != 1:
        case("control %s" % name, False, "anchor found %d times" % n)
        continue
    text = src.replace(old, new)
    try:
        ast.parse(text)
    except SyntaxError as e:
        case("control %s" % name, False, "the mutant is not valid Python (%s): a crash is not a kill" % e)
        continue
    if not DISCOVER and name not in WANT:
        case("control %s" % name, False, "no WANT entry")
        continue
    jobs.append((name, text, WANT.get(name)))
for name in sorted(set(WANT) - {m[0] for m in MUTANTS}):
    case("control %s" % name, False, "WANT entry with no mutant")
with concurrent.futures.ThreadPoolExecutor(4) as ex:
    results = list(ex.map(lambda j: (j[0], j[2]) + run(j[1]), jobs))
seen = set()
for name, want, rc, out in results:
    got = misses(out)
    if DISCOVER:
        print("DISCOVER %r: %r," % (name, sorted(got)))
        continue
    if isinstance(want, tuple):
        seen |= want[1] & got      # the pinned rows are shown to fail under it
        case("control %s (contains)" % name, rc != 0 and want[1] <= got,
             "rc=%d got %s, want at least %s" % (rc, sorted(got), sorted(want[1])))
    else:
        seen |= got
        case("control %s" % name, rc != 0 and got == want,
             "rc=%d got %s want %s" % (rc, sorted(got), sorted(want)))

if not DISCOVER:
    rc, out = run(src)
    every = {re.sub(r"^ok ", "", l) for l in out.splitlines() if l.startswith("ok ")}
    every.discard("SKILL one yaml and one make example")
    unkilled = sorted(every - seen)
    case("control every case has an exact mutant that kills it", not unkilled, "unkilled: %s" % unkilled)
sys.exit(1 if fails else 0)
PY
