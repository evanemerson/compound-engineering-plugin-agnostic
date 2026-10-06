#!/usr/bin/env bash
# Control for the worktree-coordinator write guard: section 10f of
# plugins/cepa/skills/autonomy/SKILL.md. A worktree coordinator shares its
# checkout with its worker, so it writes tracked state only through a task or
# lfg run that starts in a parked worktree; 10f holds the rule, the probe that
# measures "parked", and the per-command table. This script READS all three
# from there. It never carries its own copy of the probe, or an edit to the
# shipped block would leave it green while it tested something nobody runs.
#
# Legs, in order:
#   PROBE    — 10f holds exactly one bash block. It runs, under `bash -e` in a
#              separate process, in each fixture repo below, and its first
#              line must equal the fixture's expected verdict, reason
#              included: a NOT-PARKED for the wrong reason is a MISS.
#   COVERAGE — every command file under plugins/cepa/commands/ cites 10f, and
#              10f's table names every command exactly once and nothing else.
#              Zero command files is a MISS, never an empty pass.
#   TOOLS    — every command whose 10f row runs the probe either declares no
#              `allowed-tools` in its frontmatter (the pipeline-command
#              exception in CLAUDE.md) or grants each `git <verb>` the block
#              runs. The verbs are read from the block. Zero probe-running
#              rows, or zero verbs, is a MISS.
#   MUTANTS  — each is built from the shipped text by one substitution and must
#              turn its leg red. A mutant whose anchor text is gone is a MISS,
#              never a skip: the shipped text changed shape and this script
#              needs re-reading.
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
#   no-marker        — every in-progress operation reads as parked.
#   drop:<marker>    — one per marker in the block's list: that operation
#                      alone reads as parked (marker-<marker>).
#   relative-git-dir — drops --path-format=absolute (parked).
#   common-dir       — reads the shared git-dir, so a linked worktree's own
#                      bisect marker is invisible (worktree-bisect).
#   no-shape         — old git echoes an unknown flag as an output line, exit
#                      0; without the shape test that echo reads as a git-dir
#                      (stub-old-git).
#   no-one-line      — keeps the leading-/ test, drops the one-line test
#                      (stub-two-line).
#
# Fixture repos use a local ref as origin/<trunk>; no network, no remote. Git
# config is isolated from the operator's (GIT_CONFIG_GLOBAL=/dev/null), and
# GIT_CEILING_DIRECTORIES stops the not-a-repo fixture from finding a parent.
# Each probe run has a 60-second timeout, and the temp tree is removed on every
# exit path.
#
# STATED LIMITS — a green run does not mean:
#   - a pointer sits at the right step. COVERAGE proves each command cites 10f
#     somewhere; placement holds by review.
#   - the table is followed. Stop, report-only and "a step of a PARKED run
#     takes its verdict" are model behavior; this script tests the
#     measurement, not the agent that reads it.
#   - the probe is race-free. It runs once per top-level run; 10f says so.
#   - TOOLS covers shell builtins (echo, case, [) or the report-only prose's
#     `git check-ignore`. Only the block's git verbs are derived.
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
TMP = None

def ok(msg):
    global passed; passed += 1; print("PASS", msg)

def miss(msg):
    global failed; failed += 1; print("MISS", msg)

def finish():
    if TMP:
        shutil.rmtree(TMP, ignore_errors=True)
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

def table_rows(section_text):
    """[(names, row text)] for each table row naming a /cepa: command."""
    rows = []
    for l in section_text.splitlines():
        if l.startswith("|") and not re.match(r"\|\s*-", l):
            names = re.findall(r"`/cepa:([a-z0-9-]+)`", l)
            if names:
                rows.append((names, l))
    return rows

ml = re.search(r"for m in ([^;]+); do", BLOCK)
MARKERS = ml.group(1).split() if ml else []
if not MARKERS:
    miss("the probe block has no `for m in ...; do` marker list")
    finish()

# --- PROBE --------------------------------------------------------------------
def probe_leg():
    global TMP
    REAL_GIT = shutil.which("git")
    ENV = dict(os.environ, GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1",
               GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t", GIT_COMMITTER_NAME="t",
               GIT_COMMITTER_EMAIL="t@t", LC_ALL="C")
    TMP = tempfile.mkdtemp(prefix="coord-guard-")
    ENV["GIT_CEILING_DIRECTORIES"] = TMP
    stub_dir = os.path.join(TMP, "stub")
    os.makedirs(stub_dir)
    with open(os.path.join(stub_dir, "git"), "w") as f:
        f.write("""#!/bin/bash
case "$STUB" in
  sym128) [ "$1" = symbolic-ref ] && exit 128 ;;
  status128) [ "$1" = status ] && exit 128 ;;
  oldgit) if [ "$1" = rev-parse ] && [ "$2" = --path-format=absolute ]; then
            echo "$2"; exec "$REAL_GIT" rev-parse --path-format=absolute "${@:3}"; fi ;;
  twoline) if [ "$1" = rev-parse ] && [ "$2" = --path-format=absolute ]; then
             "$REAL_GIT" "$@"; echo extra; exit 0; fi ;;
esac
exec "$REAL_GIT" "$@"
""")
    os.chmod(os.path.join(stub_dir, "git"), 0o755)

    def g(cwd, *args):
        subprocess.run([REAL_GIT, *args], cwd=cwd, env=ENV, check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def out(cwd, *args):
        return subprocess.run([REAL_GIT, *args], cwd=cwd, env=ENV, check=True,
                              capture_output=True, text=True).stdout.strip()

    def gitdir(d):
        return out(d, "rev-parse", "--path-format=absolute", "--git-dir")

    def base(name, trunk):
        d = os.path.join(TMP, name)
        os.makedirs(os.path.join(d, "sub"))
        g(d, "init", "-q", "-b", "work")
        open(os.path.join(d, "f.txt"), "w").write("a\n")
        open(os.path.join(d, "sub", "g.txt"), "w").write("b\n")
        g(d, "add", "-A"); g(d, "commit", "-q", "-m", "c1")
        g(d, "update-ref", "refs/remotes/origin/" + trunk, "HEAD")
        g(d, "checkout", "-q", "--detach", "origin/" + trunk)
        return d

    def marker(name):
        def setup(d):
            p = os.path.join(gitdir(d), name)
            if name in ("rebase-merge", "rebase-apply", "sequencer"):
                os.makedirs(p)
            else:
                open(p, "w").close()
        return setup

    def f_ahead(d):
        c2 = out(d, "commit-tree", "HEAD^{tree}", "-p", "HEAD", "-m", "c2")
        g(d, "update-ref", "refs/remotes/origin/main", c2)
    def f_branch(d): g(d, "checkout", "-q", "-b", "feat/wt/x", "origin/main")
    def f_own(d): g(d, "commit", "-q", "--allow-empty", "-m", "own")
    def f_edit(d): open(os.path.join(d, "f.txt"), "a").write("x\n")
    def f_staged(d): f_edit(d); g(d, "add", "f.txt")
    def f_untracked(d): open(os.path.join(d, "scratch.tmp"), "w").write("x\n")
    def f_noorigin(d): g(d, "update-ref", "-d", "refs/remotes/origin/main")

    contained = "NOT-PARKED: HEAD not contained in origin/main (rc=%d)"
    # (name, setup, repo trunk, probed trunk, where, stub, expected first line)
    fixtures = [
        ("parked", None, "main", "main", "", "", "PARKED"),
        ("parked-origin-ahead", f_ahead, "main", "main", "", "", "PARKED"),
        ("fresh-branch", f_branch, "main", "main", "", "", "NOT-PARKED: on a branch"),
        ("detached-own-commit", f_own, "main", "main", "", "", contained % 1),
        ("tracked-edit", f_edit, "main", "main", "", "", "NOT-PARKED: tracked tree not clean"),
        ("staged-edit", f_staged, "main", "main", "", "", "NOT-PARKED: tracked tree not clean"),
        ("untracked-only", f_untracked, "main", "main", "", "", "PARKED"),
        ("no-origin-ref", f_noorigin, "main", "main", "", "", contained % 128),
        ("trunk-dev", None, "dev", "dev", "", "", "PARKED"),
        ("trunk-dev-probed-as-main", None, "dev", "main", "", "", contained % 128),
        ("subdir-parked", None, "main", "main", "sub", "", "PARKED"),
        ("worktree-parked", None, "main", "main", "wt", "", "PARKED"),
        ("worktree-bisect", None, "main", "main", "wt+bisect", "",
         "NOT-PARKED: operation in progress (BISECT_LOG)"),
        ("stub-sym-128", None, "main", "main", "", "sym128", "NOT-PARKED: HEAD unreadable (rc=128)"),
        ("stub-status-128", None, "main", "main", "", "status128", "NOT-PARKED: tracked tree not clean"),
        ("stub-old-git", None, "main", "main", "", "oldgit", "NOT-PARKED: git-dir unreadable"),
        ("stub-two-line", None, "main", "main", "", "twoline", "NOT-PARKED: git-dir unreadable"),
        ("not-a-repo", None, "main", "main", "norepo", "", "NOT-PARKED: HEAD unreadable (rc=128)"),
    ] + [("marker-" + m, marker(m), "main", "main", "", "",
          "NOT-PARKED: operation in progress (%s)" % m) for m in MARKERS]

    dirs = {}
    for name, setup, repo_trunk, probe_trunk, where, stub, _ in fixtures:
        if where == "norepo":
            d = os.path.join(TMP, name); os.makedirs(d)
        else:
            d = base(name, repo_trunk)
            if setup:
                setup(d)
            if where.startswith("wt"):
                w = d + "-wt"
                g(d, "worktree", "add", "-q", "--detach", w, "origin/main")
                if where == "wt+bisect":
                    open(os.path.join(gitdir(w), "BISECT_LOG"), "w").close()
                d = w
            elif where:
                d = os.path.join(d, where)
        dirs[name] = (d, probe_trunk, stub)

    def verdict(block, d, trunk, stub):
        script = os.path.join(TMP, "probe.sh")
        open(script, "w").write(block.replace("<trunk>", trunk))
        env = dict(ENV, REAL_GIT=REAL_GIT, STUB=stub)
        if stub:
            env["PATH"] = stub_dir + os.pathsep + env["PATH"]
        try:
            r = subprocess.run(["bash", "-e", script], cwd=d, env=env,
                               capture_output=True, text=True, timeout=60)
        except subprocess.TimeoutExpired:
            return "TIMEOUT"
        if r.returncode != 0:
            return "EXIT %d" % r.returncode
        return (r.stdout.splitlines() or [""])[0]

    def failures(block):
        got = {f[0]: verdict(block, *dirs[f[0]]) for f in fixtures}
        return [(f[0], f[-1], got[f[0]]) for f in fixtures if got[f[0]] != f[-1]]

    bad = failures(BLOCK)
    if bad:
        miss("the shipped probe misclassifies: %s"
             % ", ".join("%s (want %r, got %r)" % b for b in bad))
    else:
        ok("the shipped probe classifies all %d fixtures" % len(fixtures))

    mutants = [
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
        ("no-one-line", '/*) [ "$gd" = "${gd%%$\'\\n\'*}" ] || gd= ;;', "/*) ;;"),
    ]
    marker_list = ml.group(1)
    for m in MARKERS:
        kept = " ".join(x for x in MARKERS if x != m)
        mutants.append(("drop:" + m, "for m in %s;" % marker_list, "for m in %s;" % kept))
    for name, old, new in mutants:
        if BLOCK.count(old) != 1:
            miss("PROBE mutant %s: anchor %r occurs %d times — re-read this script"
                 % (name, old, BLOCK.count(old)))
            continue
        killers = failures(BLOCK.replace(old, new))
        if killers:
            ok("PROBE mutant %s is killed by %s" % (name, ", ".join(k[0] for k in killers)))
        else:
            miss("PROBE mutant %s survives every fixture" % name)

try:
    probe_leg()
except (subprocess.CalledProcessError, OSError) as e:
    miss("PROBE leg could not run: %s — a fixture that was not built is not a pass" % e)
    finish()

# --- COVERAGE -----------------------------------------------------------------
def coverage(files, section_text):
    """files: {name: text}. Returns the list of problems."""
    if not files:
        return ["no command files matched %s" % CMD_GLOB]
    probs = ["%s.md never cites %s" % (n, CITE) for n, t in sorted(files.items()) if CITE not in t]
    named = [n for names, _ in table_rows(section_text) for n in names]
    for n in sorted(files):
        if named.count(n) != 1:
            probs.append("/cepa:%s appears %d times in 10f's table" % (n, named.count(n)))
    for n in sorted(set(named) - set(files)):
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
rows = table_rows(text)
if rows:
    if coverage(FILES, text.replace(rows[-1][1], "")):
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

def frontmatter(t):
    m = re.match(r"---\n(.*?)\n---\n", t, re.S)
    return m.group(1) if m else ""

def tools(files, section_text):
    probs = []
    probing = [n for names, row in table_rows(section_text)
               if "Run the probe" in row for n in names]
    if not probing:
        probs.append("no 10f row says `Run the probe` — nothing to check")
    if not VERBS:
        probs.append("no git verb found in the probe block")
    for n in probing:
        m = re.search(r"^allowed-tools:(.*)$", frontmatter(files.get(n, "")), re.M)
        if not m:
            continue
        for v in VERBS:
            if "Bash(git %s:*)" % v not in m.group(1):
                probs.append("%s.md runs the probe but its allowed-tools lacks Bash(git %s:*)" % (n, v))
    return probs, probing

probs, probing = tools(FILES, text)
if probs:
    for p in probs: miss("TOOLS: " + p)
else:
    ok("TOOLS: the probe-running commands (%s) grant %s or declare no allowed-tools"
       % (", ".join(probing), ", ".join(VERBS)))
for n in probing:
    t = FILES[n]
    fm = frontmatter(t)
    if not fm:
        miss("TOOLS mutant narrow:%s — %s.md has no frontmatter to mutate" % (n, n))
        continue
    narrowed = t.replace(fm, fm + "\nallowed-tools: Bash(git diff:*)", 1) \
        if "allowed-tools:" not in fm else re.sub(r"^allowed-tools:.*$", "allowed-tools: Bash(git diff:*)", t, count=1, flags=re.M)
    if tools(dict(FILES, **{n: narrowed}), text)[0]:
        ok("TOOLS mutant narrow:%s is killed" % n)
    else:
        miss("TOOLS mutant narrow:%s survives" % n)
if tools(FILES, text.replace("Run the probe", "Measure"))[0]:
    ok("TOOLS mutant no-probe-row is killed")
else:
    miss("TOOLS mutant no-probe-row survives")

finish()
PY
