#!/usr/bin/env bash
# Control for the worktree-coordinator write guard: section 10f of
# plugins/cepa/skills/autonomy/SKILL.md. A worktree coordinator shares its
# checkout with its worker, so it may write only when the worktree is parked;
# 10f holds the rule, the probe that measures "parked", and the per-command
# table. This script READS all three from there. It never carries its own copy
# of the probe, or an edit to the shipped block would leave it green while it
# tested something nobody runs.
#
# Legs, in order:
#   PROBE    — 10f holds exactly one bash block. It runs, under `bash -e` in a
#              separate process, in each fixture repo below, and its first
#              line must equal the fixture's expected verdict, reason
#              included: a NOT-PARKED for the wrong reason is a MISS.
#   COVERAGE — every command file under plugins/cepa/commands/ cites 10f, and
#              10f's table names every command exactly once and nothing else.
#              Zero command files is a MISS, never an empty pass.
#   TOOLS    — every command that declares `allowed-tools` grants each
#              `git <verb>` the probe block runs. The verbs are read from the
#              block, so a new probe verb needs no edit here.
#   MUTANTS  — each is built from the shipped text by one substitution and must
#              turn its leg red. PROBE mutants edit the block; COVERAGE and
#              TOOLS mutants edit an in-memory copy of a command file or the
#              table. A mutant whose anchor text is gone is a MISS, never a
#              skip: the shipped text changed shape and this script needs
#              re-reading.
#
# Why each PROBE mutant matters (the fixture that kills it):
#   branch-ok        — a branch reads as parked: a fresh worker branch cut at
#                      origin/<trunk> passes every other test (fresh-branch).
#   head-any-failure — symbolic-ref exit 128 reads as detached: the guard
#                      fails open on an unreadable HEAD (stub-sym-128).
#   no-ancestor      — a detached commit of the coordinator's own reads as
#                      parked (detached-own-commit, no-origin-ref).
#   no-dirty         — a tracked edit reads as parked (tracked-edit, staged).
#   status-fail-open — a failed `git status` reads as clean (stub-status-128).
#   untracked-counts — an editor's scratch file blocks a real park
#                      (untracked-only).
#   no-marker        — a bisect or rebase in progress reads as parked
#                      (bisect-marker).
#   relative-git-dir — drops --path-format=absolute (parked).
#   common-dir       — reads the shared git-dir, so a linked worktree's own
#                      bisect marker is invisible (worktree-bisect).
#   no-shape         — old git echoes an unknown flag as an output line, exit
#                      0; without the one-line-starting-with-/ test that echo
#                      reads as a git-dir (stub-old-git).
#
# Fixture repos use a local ref as origin/<trunk>; no network, no remote. Git
# config is isolated from the operator's (GIT_CONFIG_GLOBAL=/dev/null), and
# GIT_CEILING_DIRECTORIES stops the not-a-repo fixture from finding a parent.
#
# STATED LIMITS — a green run does not mean:
#   - a citation sits at the right step. COVERAGE proves each command cites
#     10f somewhere; placement holds by review.
#   - the report-only prose is followed. That is model behavior; this script
#     tests the measurement, not the agent that reads it.
#   - the probe is race-free. It runs once at the start of a run; a worker
#     started afterwards is not seen. 10f states this.
#   - TOOLS covers 10f's prose. Only the block's verbs are derived; the
#     `git check-ignore` that report-only names is granted by hand, and only
#     the commands that save a document need it.
# Not registered in the mutation sweep, matching check-batch-sibling-match.sh:
# the mutants above are this script's own per-leg proof.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

python3 - <<'PY'
import glob, os, re, shutil, subprocess, sys, tempfile

HOME = "plugins/cepa/skills/autonomy/SKILL.md"
CMD_GLOB = "plugins/cepa/commands/*.md"
CITE = "§10f"
passed = failed = 0

def ok(msg):
    global passed; passed += 1; print("PASS", msg)

def miss(msg):
    global failed; failed += 1; print("MISS", msg)

def finish():
    print("-- %d/%d checks passed --" % (passed, passed + failed))
    sys.exit(1 if failed else 0)

def read(path):
    try:
        return open(path, encoding="utf-8", errors="replace").read()
    except OSError as e:
        miss("cannot read %s (%s) — an unread file is not a pass" % (path, e))
        finish()

# --- 10f: section, block, table ---------------------------------------------
skill = read(HOME).splitlines()
start = next((i for i, l in enumerate(skill) if l.startswith("### 10f.")), None)
if start is None:
    miss("%s has no '### 10f.' heading" % HOME)
    finish()
section, fence = [], False
for l in skill[start + 1:]:
    if l.lstrip().startswith("```"):
        fence = not fence
    if not fence and re.match(r"#{1,3} ", l):
        break
    section.append(l)
text = "\n".join(section)
blocks = re.findall(r"^```bash\n(.*?)^```$", text, re.M | re.S)
if len(blocks) != 1:
    miss("10f must hold exactly one bash block; found %d" % len(blocks))
    finish()
BLOCK = blocks[0]
ok("10f holds one probe block")

def table_names(section_text):
    names = []
    for l in section_text.splitlines():
        if l.startswith("|") and not re.match(r"\|\s*-", l):
            names += re.findall(r"`/cepa:([a-z0-9-]+)`", l)
    return names

# --- PROBE --------------------------------------------------------------------
REAL_GIT = shutil.which("git")
ENV = dict(os.environ, GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1",
           GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t", GIT_COMMITTER_NAME="t",
           GIT_COMMITTER_EMAIL="t@t", LC_ALL="C")
TMP = tempfile.mkdtemp(prefix="coord-guard-")
ENV["GIT_CEILING_DIRECTORIES"] = TMP
STUB_DIR = os.path.join(TMP, "stub")
os.makedirs(STUB_DIR)
with open(os.path.join(STUB_DIR, "git"), "w") as f:
    f.write("""#!/bin/bash
case "$STUB" in
  sym128) [ "$1" = symbolic-ref ] && exit 128 ;;
  status128) [ "$1" = status ] && exit 128 ;;
  oldgit) if [ "$1" = rev-parse ] && [ "$2" = --path-format=absolute ]; then
            echo "$2"; exec "$REAL_GIT" rev-parse --path-format=absolute "${@:3}"; fi ;;
esac
exec "$REAL_GIT" "$@"
""")
os.chmod(os.path.join(STUB_DIR, "git"), 0o755)

def g(cwd, *args):
    subprocess.run([REAL_GIT, *args], cwd=cwd, env=ENV, check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def out(cwd, *args):
    return subprocess.run([REAL_GIT, *args], cwd=cwd, env=ENV, check=True,
                          capture_output=True, text=True).stdout.strip()

def base(name, trunk="main"):
    d = os.path.join(TMP, name)
    os.makedirs(os.path.join(d, "sub"))
    g(d, "init", "-q", "-b", "work")
    open(os.path.join(d, "f.txt"), "w").write("a\n")
    open(os.path.join(d, "sub", "g.txt"), "w").write("b\n")
    g(d, "add", "-A"); g(d, "commit", "-q", "-m", "c1")
    g(d, "update-ref", "refs/remotes/origin/" + trunk, "HEAD")
    g(d, "checkout", "-q", "--detach", "origin/" + trunk)
    return d

def f_parked(d): pass
def f_ahead(d):
    c2 = out(d, "commit-tree", "HEAD^{tree}", "-p", "HEAD", "-m", "c2")
    g(d, "update-ref", "refs/remotes/origin/main", c2)
def f_branch(d): g(d, "checkout", "-q", "-b", "feat/wt/x", "origin/main")
def f_own(d): g(d, "commit", "-q", "--allow-empty", "-m", "own")
def f_edit(d): open(os.path.join(d, "f.txt"), "a").write("x\n")
def f_staged(d): f_edit(d); g(d, "add", "f.txt")
def f_untracked(d): open(os.path.join(d, "scratch.tmp"), "w").write("x\n")
def f_bisect(d): open(os.path.join(d, ".git", "BISECT_LOG"), "w").close()
def f_noorigin(d): g(d, "update-ref", "-d", "refs/remotes/origin/main")

def worktree(d, marker):
    w = os.path.join(TMP, os.path.basename(d) + "-wt")
    g(d, "worktree", "add", "-q", "--detach", w, "origin/main")
    if marker:
        open(os.path.join(out(w, "rev-parse", "--path-format=absolute", "--git-dir"),
                          "BISECT_LOG"), "w").close()
    return w

# (name, setup, trunk, run-in, stub, expected verdict)
FIXTURES = [
    ("parked", f_parked, "main", "", "", "PARKED"),
    ("parked-origin-ahead", f_ahead, "main", "", "", "PARKED"),
    ("fresh-branch", f_branch, "main", "", "", "NOT-PARKED: on a branch"),
    ("detached-own-commit", f_own, "main", "", "", "NOT-PARKED: HEAD not contained in origin/main (rc=1)"),
    ("tracked-edit", f_edit, "main", "", "", "NOT-PARKED: tracked tree not clean"),
    ("staged-edit", f_staged, "main", "", "", "NOT-PARKED: tracked tree not clean"),
    ("untracked-only", f_untracked, "main", "", "", "PARKED"),
    ("bisect-marker", f_bisect, "main", "", "", "NOT-PARKED: operation in progress (BISECT_LOG)"),
    ("no-origin-ref", f_noorigin, "main", "", "", "NOT-PARKED: HEAD not contained in origin/main (rc=128)"),
    ("trunk-dev", f_parked, "dev", "", "", "PARKED"),
    ("trunk-dev-probed-as-main", f_parked, "dev->main", "", "", "NOT-PARKED: HEAD not contained in origin/main (rc=128)"),
    ("subdir-parked", f_parked, "main", "sub", "", "PARKED"),
    ("worktree-parked", None, "main", "wt", "", "PARKED"),
    ("worktree-bisect", None, "main", "wt+bisect", "", "NOT-PARKED: operation in progress (BISECT_LOG)"),
    ("stub-sym-128", f_parked, "main", "", "sym128", "NOT-PARKED: HEAD unreadable (rc=128)"),
    ("stub-status-128", f_parked, "main", "", "status128", "NOT-PARKED: tracked tree not clean"),
    ("stub-old-git", f_parked, "main", "", "oldgit", "NOT-PARKED: git-dir unreadable"),
    ("not-a-repo", None, "main", "norepo", "", "NOT-PARKED: HEAD unreadable (rc=128)"),
]

def prepare():
    dirs = {}
    for name, setup, trunk, where, stub, _ in FIXTURES:
        repo_trunk, probe_trunk = (trunk.split("->") + [trunk])[:2] if "->" in trunk else (trunk, trunk)
        if where == "norepo":
            d = os.path.join(TMP, name); os.makedirs(d)
        else:
            d = base(name, repo_trunk)
            if setup: setup(d)
            if where.startswith("wt"):
                d = worktree(d, where == "wt+bisect")
            elif where:
                d = os.path.join(d, where)
        dirs[name] = (d, probe_trunk, stub)
    return dirs

def verdict(block, d, trunk, stub):
    script = os.path.join(TMP, "probe.sh")
    open(script, "w").write(block.replace("<trunk>", trunk))
    env = dict(ENV, REAL_GIT=REAL_GIT, STUB=stub)
    if stub:
        env["PATH"] = STUB_DIR + os.pathsep + env["PATH"]
    r = subprocess.run(["bash", "-e", script], cwd=d, env=env,
                       capture_output=True, text=True)
    if r.returncode != 0:
        return "EXIT %d" % r.returncode
    return (r.stdout.splitlines() or [""])[0]

def probe_failures(block, dirs):
    got = {n: verdict(block, *dirs[n]) for n, *_ in FIXTURES}
    return [(n, want, got[n]) for n, *_, want in FIXTURES if got[n] != want]

try:
    dirs = prepare()
except subprocess.CalledProcessError as e:
    miss("fixture setup failed: %s" % e)
    shutil.rmtree(TMP, ignore_errors=True)
    finish()

bad = probe_failures(BLOCK, dirs)
if bad:
    miss("the shipped probe misclassifies: %s"
         % ", ".join("%s (want %s, got %s)" % b for b in bad))
else:
    ok("the shipped probe classifies all %d fixtures" % len(FIXTURES))

PROBE_MUTANTS = [
    ("branch-ok", '0) reason="${reason:-on a branch}" ;;', "0) ;;"),
    ("head-any-failure", '*) reason="${reason:-HEAD unreadable', '*) : "${reason:-HEAD unreadable'),
    ("no-ancestor", '[ "$anc_rc" -eq 0 ] ||', "true ||"),
    ("no-dirty", '[ -z "$dirty" ] ||', "true ||"),
    ("status-fail-open", "|| dirty='status failed'", "|| dirty="),
    ("untracked-counts", " --untracked-files=no", ""),
    ("no-marker", '[ ! -e "$gd/$m" ] ||', "true ||"),
    ("relative-git-dir", "rev-parse --path-format=absolute --git-dir", "rev-parse --git-dir"),
    ("common-dir", "--path-format=absolute --git-dir", "--path-format=absolute --git-common-dir"),
    ("no-shape", '/*) [ "$gd" = "${gd%%$\'\\n\'*}" ] || gd= ;; *) gd= ;;', "*) ;;"),
]
for name, old, new in PROBE_MUTANTS:
    if BLOCK.count(old) != 1:
        miss("PROBE mutant %s: anchor %r occurs %d times — re-read this script"
             % (name, old, BLOCK.count(old)))
        continue
    killers = probe_failures(BLOCK.replace(old, new), dirs)
    if killers:
        ok("PROBE mutant %s is killed by %s" % (name, ", ".join(k[0] for k in killers)))
    else:
        miss("PROBE mutant %s survives every fixture" % name)
shutil.rmtree(TMP, ignore_errors=True)

# --- COVERAGE -----------------------------------------------------------------
def coverage(files, section_text):
    """files: {name: text}. Returns the list of problems."""
    probs = []
    if not files:
        return ["no command files matched %s" % CMD_GLOB]
    for n, t in sorted(files.items()):
        if CITE not in t:
            probs.append("%s.md never cites %s" % (n, CITE))
    rows = table_names(section_text)
    for n in sorted(files):
        if rows.count(n) != 1:
            probs.append("/cepa:%s appears %d times in 10f's table" % (n, rows.count(n)))
    for n in sorted(set(rows) - set(files)):
        probs.append("10f's table names /cepa:%s, which has no command file" % n)
    return probs

FILES = {os.path.basename(p)[:-3]: read(p) for p in sorted(glob.glob(CMD_GLOB))}
probs = coverage(FILES, text)
if probs:
    for p in probs: miss("COVERAGE: " + p)
else:
    ok("COVERAGE: %d command files each cite %s and have one table row" % (len(FILES), CITE))

for n in sorted(FILES):
    # Built at runtime: scripts/ is a root check-model-pins.sh scans, so a
    # literal broken citation here would be a real finding there.
    mutated = dict(FILES, **{n: FILES[n].replace(CITE, CITE[:-1] + "x")})
    if coverage(mutated, text):
        ok("COVERAGE mutant drop-citation:%s is killed" % n)
    else:
        miss("COVERAGE mutant drop-citation:%s survives" % n)
rows = [l for l in text.splitlines() if l.startswith("|") and "`/cepa:" in l]
if rows:
    if coverage(FILES, text.replace(rows[-1], "")):
        ok("COVERAGE mutant drop-row is killed")
    else:
        miss("COVERAGE mutant drop-row survives")
    if coverage(FILES, text + "\n| `/cepa:no-such-command` | x |"):
        ok("COVERAGE mutant phantom-row is killed")
    else:
        miss("COVERAGE mutant phantom-row survives")
else:
    miss("COVERAGE: 10f's table has no /cepa: rows to mutate")
if coverage({}, text):
    ok("COVERAGE mutant empty-glob is killed")
else:
    miss("COVERAGE mutant empty-glob survives")

# --- TOOLS --------------------------------------------------------------------
VERBS = sorted(set(re.findall(r"\bgit ([a-z][a-z-]*)", BLOCK)))

def tools(files):
    probs, declaring = [], 0
    for n, t in sorted(files.items()):
        m = re.search(r"^allowed-tools:(.*)$", t, re.M)
        if not m:
            continue
        declaring += 1
        for v in VERBS:
            if "Bash(git %s:*)" % v not in m.group(1):
                probs.append("%s.md declares allowed-tools without Bash(git %s:*)" % (n, v))
    if not VERBS:
        probs.append("no git verb found in the probe block")
    if not declaring:
        probs.append("no command declares allowed-tools — nothing was checked")
    return probs

probs = tools(FILES)
if probs:
    for p in probs: miss("TOOLS: " + p)
else:
    ok("TOOLS: every declaring command grants %s" % ", ".join(VERBS))
for n in sorted(FILES):
    t = FILES[n]
    m = re.search(r"^allowed-tools:.*$", t, re.M)
    if not m:
        continue
    for v in VERBS:
        grant = ", Bash(git %s:*)" % v
        line = m.group(0)
        stripped = line.replace(grant, "") if grant in line else line.replace("Bash(git %s:*), " % v, "")
        if stripped == line:
            miss("TOOLS mutant drop:%s:%s — grant not found to remove" % (n, v))
            continue
        if tools(dict(FILES, **{n: t.replace(line, stripped)})):
            ok("TOOLS mutant drop:%s:%s is killed" % (n, v))
        else:
            miss("TOOLS mutant drop:%s:%s survives" % (n, v))

finish()
PY
