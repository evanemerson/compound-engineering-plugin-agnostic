#!/usr/bin/env bash
# Control for dispatch isolation: section 11 of
# plugins/cepa/skills/autonomy/SKILL.md. 11a says which dispatch needs a
# worktree and holds the READ-ONLY brief line a reader's prompt opens with;
# 11b holds the snapshot and cleanup blocks that remove the agent-* worktrees
# a dispatch left. This script READS both from there and never carries its own
# copy, or an edit to the shipped text would leave it green while it tested
# something nobody runs.
#
# Legs, in order:
#   BRIEF    — 11a's first ```text block is one line. It opens with
#              `READ-ONLY:` (the token a deny-by-default isolation hook admits
#              a dispatch on) and names every forbidden verb below. The
#              plan-review persona template, the one brief that is a file,
#              carries it with only <why> filled in.
#   SITES    — every command or skill that declares a dispatch tier (11a's
#              home excluded) cites 11a and 11b and tells the orchestrator to
#              put the READ-ONLY line in the prompt; lfg names the parallel
#              writer's `isolation: "worktree"`. Zero sites is a MISS.
#   TOOLS    — every site that declares `allowed-tools` grants each
#              `git <verb>` the 11b blocks run. The verbs are read from the
#              blocks.
#   CLEANUP  — the shipped blocks run, under `bash -e` in a separate process,
#              against fixture repos with planted agent worktrees. Each
#              fixture asserts the exact output lines AND what is left on disk
#              (worktree directory, branch). One fixture per refusal.
#   MUTANTS  — each is built from the shipped text by one substitution and must
#              turn its leg red. A mutant whose anchor text is gone is a MISS,
#              never a skip.
#
# STATED LIMITS — a green run does not mean:
#   - an agent obeys the READ-ONLY line, or that an orchestrator substitutes
#     the right paths. This tests the text and the blocks, not the model.
#   - the Agent tool reports a kept worktree's path; 11c says so.
#   - the snapshot block's own run-name check is covered: the cleanup repeats
#     it, so dropping either one alone changes no output. Neither is mutated.
# Not registered in the mutation sweep, matching check-coord-write-guard.sh:
# the mutants above are this script's own per-leg proof.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

python3 - <<'PY'
import glob, os, re, shutil, subprocess, sys, tempfile

HOME = "plugins/cepa/skills/autonomy/SKILL.md"
TEMPLATE = "plugins/cepa/skills/plan-review/references/subagent-template.md"
SITE_GLOBS = ["plugins/cepa/commands/*.md", "plugins/cepa/skills/*/SKILL.md"]
TIER = re.compile(r"model: (sonnet|opus|haiku)|no model override|model-pin:")
VERBS = ["`git checkout`", "`git switch`", "`git worktree`", "`git fetch`",
         "`git stash`", "`gh pr checkout`", "detach"]
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

def section(lines, prefix):
    start = next((i for i, l in enumerate(lines) if l.startswith(prefix)), None)
    if start is None:
        return None
    out, fence = [], False
    for l in lines[start + 1:]:
        if l.lstrip().startswith("```"):
            fence = not fence
        if not fence and re.match(r"#{1,3} ", l):
            break
        out.append(l)
    return "\n".join(out)

skill = read(HOME).splitlines()
S11A = section(skill, "### 11a.")
S11B = section(skill, "### 11b.")
if S11A is None or S11B is None:
    miss("%s lacks a '### 11a.' or '### 11b.' heading" % HOME)
    finish()

# --- BRIEF --------------------------------------------------------------------
def brief_line(text):
    blocks = re.findall(r"^```text\n(.*?)^```$", text, re.M | re.S)
    return blocks[0].rstrip("\n") if blocks else None

def brief(text, template):
    probs = []
    line = brief_line(text)
    if line is None or "\n" in line or not line.strip():
        return ["11a's first ```text block must be exactly one non-empty line"]
    if not re.match(r"READ-ONLY:[^\S\n]*\S", line):
        probs.append("the brief line does not open with `READ-ONLY: <why>`")
    for v in VERBS:
        if v not in line:
            probs.append("the brief line does not name %s" % v)
    if "<why>" not in line:
        probs.append("the brief line has no <why> slot")
    else:
        pat = re.compile("^" + re.escape(line).replace(re.escape("<why>"), r"[^\n]+") + "$", re.M)
        if not pat.search(template):
            probs.append("%s does not carry the brief line" % TEMPLATE)
    return probs

TPL = read(TEMPLATE)
probs = brief(S11A, TPL)
if probs:
    for p in probs: miss("BRIEF: " + p)
else:
    ok("BRIEF: 11a's line opens with READ-ONLY, names %d verbs, and the persona template carries it" % len(VERBS))
LINE = brief_line(S11A) or ""
brief_mutants = [("drop-line", S11A.replace(LINE, ""), TPL),
                 ("drop-prefix", S11A.replace("READ-ONLY: ", "Note: ", 1), TPL),
                 ("template-drops-line", S11A, "\n".join(l for l in TPL.splitlines() if not l.startswith("READ-ONLY:")))]
brief_mutants += [("drop-verb:" + v, S11A.replace(LINE, LINE.replace(v, "x")), TPL) for v in VERBS]
for name, text, tpl in brief_mutants:
    if brief(text, tpl):
        ok("BRIEF mutant %s is killed" % name)
    else:
        miss("BRIEF mutant %s survives" % name)

# --- SITES --------------------------------------------------------------------
def site_files():
    out = {}
    for g in SITE_GLOBS:
        for p in sorted(glob.glob(g)):
            if os.path.normpath(p) == os.path.normpath(HOME):
                continue
            t = read(p)
            if TIER.search(t):
                out[p] = t
    return out

def sites(files):
    if not files:
        return ["no dispatch-tier file matched %s" % ", ".join(SITE_GLOBS)]
    probs = []
    for p, t in sorted(files.items()):
        for need in ("§11a", "§11b", "READ-ONLY line"):
            if need not in t:
                probs.append("%s lacks %r" % (p, need))
    lfg = [p for p in files if p.endswith("commands/lfg.md")]
    if not lfg:
        probs.append("commands/lfg.md is not among the dispatch sites")
    elif 'isolation: "worktree"' not in files[lfg[0]]:
        probs.append("lfg.md does not name the parallel writer's isolation: \"worktree\"")
    return probs

FILES = site_files()
probs = sites(FILES)
if probs:
    for p in probs: miss("SITES: " + p)
else:
    ok("SITES: %d dispatch sites cite §11a and §11b and place the READ-ONLY line (%s)"
       % (len(FILES), ", ".join(os.path.basename(os.path.dirname(p)) + "/" + os.path.basename(p) for p in FILES)))
for p in sorted(FILES):
    for need in ("§11a", "§11b", "READ-ONLY line"):
        # Built at runtime: a literal broken citation in this file would be a
        # real finding for check-model-pins.sh, which scans scripts/.
        mutated = dict(FILES, **{p: FILES[p].replace(need, need[:-1] + "x")})
        if sites(mutated):
            ok("SITES mutant drop:%s:%s is killed" % (os.path.basename(p), need))
        else:
            miss("SITES mutant drop:%s:%s survives" % (os.path.basename(p), need))
lfgp = [p for p in FILES if p.endswith("commands/lfg.md")]
if lfgp and sites(dict(FILES, **{lfgp[0]: FILES[lfgp[0]].replace('isolation: "worktree"', "isolation")})):
    ok("SITES mutant lfg-drops-isolation is killed")
else:
    miss("SITES mutant lfg-drops-isolation survives")
if sites({}):
    ok("SITES mutant empty-glob is killed")
else:
    miss("SITES mutant empty-glob survives")

# --- blocks -------------------------------------------------------------------
blocks = re.findall(r"^```bash\n(.*?)^```$", S11B, re.M | re.S)
if len(blocks) != 2:
    miss("11b must hold exactly two bash blocks (snapshot, cleanup); found %d" % len(blocks))
    finish()
SNAP, CLEAN = blocks
ok("11b holds the snapshot and cleanup blocks")

# --- TOOLS --------------------------------------------------------------------
BVERBS = sorted(set(re.findall(r"\bgit ([a-z][a-z-]*)", SNAP + CLEAN)))

def frontmatter(t):
    m = re.match(r"---\n(.*?)\n---\n", t, re.S)
    return m.group(1) if m else ""

def tools(files):
    probs = []
    if not BVERBS:
        probs.append("no git verb found in the 11b blocks")
    for p, t in sorted(files.items()):
        m = re.search(r"^allowed-tools:(.*)$", frontmatter(t), re.M)
        if not m:
            continue
        for v in BVERBS:
            if "Bash(git %s:*)" % v not in m.group(1):
                probs.append("%s declares allowed-tools without Bash(git %s:*)" % (p, v))
    return probs

probs = tools(FILES)
declaring = [p for p in FILES if re.search(r"^allowed-tools:", frontmatter(FILES[p]), re.M)]
if probs:
    for p in probs: miss("TOOLS: " + p)
else:
    ok("TOOLS: %d declaring sites grant %s" % (len(declaring), ", ".join(BVERBS)))
for p in declaring:
    narrowed = re.sub(r"^allowed-tools:.*$", "allowed-tools: Bash(git diff:*)", FILES[p], count=1, flags=re.M)
    if tools(dict(FILES, **{p: narrowed})):
        ok("TOOLS mutant narrow:%s is killed" % os.path.basename(p))
    else:
        miss("TOOLS mutant narrow:%s survives" % os.path.basename(p))

# --- CLEANUP ------------------------------------------------------------------
def cleanup_leg():
    global TMP
    GIT = shutil.which("git")
    ENV = dict(os.environ, GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1",
               GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t", GIT_COMMITTER_NAME="t",
               GIT_COMMITTER_EMAIL="t@t", LC_ALL="C")
    TMP = tempfile.mkdtemp(prefix="dispatch-iso-")
    TMP = os.path.realpath(TMP)
    ENV["GIT_CEILING_DIRECTORIES"] = TMP

    def g(cwd, *args):
        subprocess.run([GIT, *args], cwd=cwd, env=ENV, check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def out(cwd, *args):
        return subprocess.run([GIT, *args], cwd=cwd, env=ENV, check=True,
                              capture_output=True, text=True).stdout.strip()

    def run_block(block, cwd, **subs):
        script = os.path.join(TMP, "block.sh")
        for k, v in subs.items():
            block = block.replace("<%s>" % k, v)
        open(script, "w").write(block)
        try:
            r = subprocess.run(["bash", "-e", script], cwd=cwd, env=ENV,
                               capture_output=True, text=True, timeout=60)
        except subprocess.TimeoutExpired:
            return ["TIMEOUT"]
        if r.returncode != 0:
            return ["EXIT %d" % r.returncode]
        return r.stdout.splitlines()

    def agent(m, name, base="origin/main"):
        w = os.path.join(m, ".claude", "worktrees", name)
        g(m, "worktree", "add", "-q", "-b", "worktree-" + name, w, base)
        return w

    def review_detach(w):
        # What a review agent does: leave its worktree-agent-* branch for the
        # PR head, which is on origin.
        g(w, "checkout", "-q", "--detach", "origin/pr")

    CUR = {}

    class Case:
        def __init__(self, name, setup, mode="remove", run="review", snap=True):
            self.name, self.setup, self.mode, self.run, self.snap = name, setup, mode, run, snap

    # Each setup(m, before) builds state; `before` runs the snapshot. It
    # returns (cwd, paths, expected lines, {path: exists?}, {branch: exists?}).
    def planted(m, before):
        before(); w = agent(m, "agent-a1"); review_detach(w)
        return m, [w], ["REMOVED {agent-a1}; deleted branch worktree-agent-a1"], {w: False}, {"worktree-agent-a1": False}
    def from_linked(m, before):
        s = os.path.join(m, ".claude", "worktrees", "roles")
        g(m, "worktree", "add", "-q", "-b", "fix/roles/x", s, "origin/main")
        before(s); w = agent(m, "agent-a1"); review_detach(w)
        return s, [w], ["REMOVED {agent-a1}; deleted branch worktree-agent-a1"], {w: False}, {"worktree-agent-a1": False}
    def report(m, before):
        before(); w = agent(m, "agent-a1"); review_detach(w)
        return m, [w], ["WOULD-REMOVE {agent-a1} (branch worktree-agent-a1)"], {w: True}, {"worktree-agent-a1": True}
    def not_agent(m, before):
        before(); w = agent(m, "feature1"); review_detach(w)
        return m, [w], ["KEPT {feature1}: not <main>/.claude/worktrees/agent-<id>"], {w: True}, {}
    def other_dir(m, before):
        before()
        w = os.path.join(TMP, os.path.basename(m) + "-elsewhere", ".claude", "worktrees", "agent-a1")
        g(m, "worktree", "add", "-q", "-b", "worktree-agent-a1", w, "origin/main"); review_detach(w)
        return m, [w], ["KEPT %s: not <main>/.claude/worktrees/agent-<id>" % w], {w: True}, {"worktree-agent-a1": True}
    def traversal(m, before):
        before(); w = agent(m, "agent-a1"); review_detach(w)
        p = w + "/../agent-a1"
        return m, [p], ["KEPT %s: not <main>/.claude/worktrees/agent-<id>" % p, "UNCLAIMED {agent-a1}: new since this run's snapshot, not named by its agents — left alone"], {w: True}, {"worktree-agent-a1": True}
    def unregistered(m, before):
        before(); w = os.path.join(m, ".claude", "worktrees", "agent-zz"); os.makedirs(w)
        return m, [w], ["KEPT {agent-zz}: not a worktree of this repo"], {w: True}, {}
    def pre_existing(m, before):
        w = agent(m, "agent-old"); review_detach(w); before()
        return m, [w], ["KEPT {agent-old}: existed before this run's dispatch"], {w: True}, {"worktree-agent-old": True}
    def untracked(m, before):
        before(); w = agent(m, "agent-a1"); review_detach(w)
        open(os.path.join(w, "u.txt"), "w").write("x\n")
        return m, [w], ["KEPT {agent-a1}: has status lines (?? u.txt)"], {w: True}, {"worktree-agent-a1": True}
    def ignored_only(m, before):
        before(); w = agent(m, "agent-a1"); review_detach(w)
        open(os.path.join(w, "x.log"), "w").write("x\n")
        return m, [w], ["KEPT {agent-a1}: has status lines (!! x.log)"], {w: True}, {"worktree-agent-a1": True}
    def tracked_edit(m, before):
        before(); w = agent(m, "agent-a1"); review_detach(w)
        open(os.path.join(w, "f.txt"), "a").write("y\n")
        return m, [w], ["KEPT {agent-a1}: has status lines ( M f.txt)"], {w: True}, {"worktree-agent-a1": True}
    def status_fails(m, before):
        before(); w = agent(m, "agent-a1"); review_detach(w)
        open(os.path.join(w, ".git"), "w").write("gitdir: /nonexistent\n")
        return m, [w], ["KEPT {agent-a1}: has status lines (git status failed)"], {w: True}, {"worktree-agent-a1": True}
    def local_head(m, before):
        before(); w = agent(m, "agent-a1"); review_detach(w)
        g(w, "commit", "-q", "--allow-empty", "-m", "local")
        g(m, "branch", "keep-local", out(w, "rev-parse", "HEAD"))
        return m, [w], ["KEPT {agent-a1}: HEAD <sha> is on no origin ref"], {w: True}, {"worktree-agent-a1": True}
    def no_snapshot(m, before):
        w = agent(m, "agent-a1"); review_detach(w)
        return m, [w], ["KEPT {agent-a1}: no pre-dispatch snapshot"], {w: True}, {"worktree-agent-a1": True}
    def consumed(m, before):
        before()
        if run_block(CUR["clean"], m, run="review", mode="remove", paths="") != []:
            raise RuntimeError("an empty first cleanup printed output")
        w = agent(m, "agent-a1"); review_detach(w)
        return m, [w], ["KEPT {agent-a1}: no pre-dispatch snapshot"], {w: True}, {"worktree-agent-a1": True}
    def glob_path(m, before):
        before(); w = agent(m, "agent-a1"); review_detach(w)
        p = os.path.join(m, ".claude", "worktrees", "agent-*")
        return m, [p], ["KEPT %s: not <main>/.claude/worktrees/agent-<id>" % p, "UNCLAIMED {agent-a1}: new since this run's snapshot, not named by its agents — left alone"], {w: True}, {"worktree-agent-a1": True}
    def locked(m, before):
        before(); w = agent(m, "agent-a1"); review_detach(w); g(m, "worktree", "lock", w)
        return m, [w], ["KEPT {agent-a1}: git worktree remove refused"], {w: True}, {"worktree-agent-a1": True}
    def branch_unique(m, before):
        before(); w = agent(m, "agent-a1")
        g(w, "commit", "-q", "--allow-empty", "-m", "on-branch"); review_detach(w)
        return m, [w], ["REMOVED {agent-a1}; kept branch worktree-agent-a1: tip <sha> is on no origin ref"], {w: False}, {"worktree-agent-a1": True}
    def branch_held(m, before):
        before(); w = agent(m, "agent-a1"); review_detach(w)
        h = os.path.join(m, ".claude", "worktrees", "holder")
        g(m, "worktree", "add", "-q", h, "worktree-agent-a1")
        return m, [w], ["REMOVED {agent-a1}; kept branch worktree-agent-a1: a worktree holds it"], {w: False, h: True}, {"worktree-agent-a1": True}
    def unclaimed(m, before):
        before(); w = agent(m, "agent-a1"); review_detach(w); o = agent(m, "agent-b2"); review_detach(o)
        return m, [w], ["REMOVED {agent-a1}; deleted branch worktree-agent-a1",
                        "UNCLAIMED {agent-b2}: new since this run's snapshot, not named by its agents — left alone"], \
               {w: False, o: True}, {"worktree-agent-b2": True}

    cases = [Case("planted", planted), Case("from-linked-worktree", from_linked),
             Case("report-mode", report, mode="report"), Case("unknown-mode", report, mode="delete"),
             Case("not-agent", not_agent), Case("other-dir", other_dir), Case("traversal", traversal),
             Case("unregistered", unregistered), Case("pre-existing", pre_existing),
             Case("untracked", untracked), Case("ignored-only", ignored_only),
             Case("tracked-edit", tracked_edit), Case("status-fails", status_fails),
             Case("local-only-head", local_head), Case("no-snapshot", no_snapshot, snap=False),
             Case("snapshot-consumed", consumed), Case("bad-run-name", report, run="Review!"),
             Case("glob-path", glob_path), Case("locked", locked),
             Case("branch-unique-commit", branch_unique), Case("branch-held", branch_held),
             Case("unclaimed", unclaimed)]
    expect_override = {"bad-run-name": ["KEPT {agent-a1}: no pre-dispatch snapshot"]}

    def build(case, snap_block, dirname):
        m = os.path.join(TMP, dirname)
        os.makedirs(m)
        g(m, "init", "-q", "-b", "main")
        open(os.path.join(m, ".gitignore"), "w").write("*.log\n.claude/\n")
        open(os.path.join(m, "f.txt"), "w").write("a\n")
        g(m, "add", "-A"); g(m, "commit", "-q", "-m", "c1")
        g(m, "update-ref", "refs/remotes/origin/main", "HEAD")
        pr = out(m, "commit-tree", "HEAD^{tree}", "-p", "HEAD", "-m", "pr-head")
        g(m, "update-ref", "refs/remotes/origin/pr", pr)
        def before(cwd=m):
            if case.snap:
                run_block(snap_block, cwd, run=case.run)
        return m, case.setup(m, before)

    def norm(lines):
        return [re.sub(r"\b[0-9a-f]{40}\b", "<sha>", l) for l in lines]

    def expand(lines, m):
        wtd = os.path.join(m, ".claude", "worktrees")
        res = []
        for l in lines:
            l = re.sub(r"\{([a-z0-9-]+)\}", lambda mm: os.path.join(wtd, mm.group(1)), l)
            res.append(l)
        return res

    def outcome(snap_block, clean_block, tag):
        """[(case, problem)] for every case the blocks get wrong."""
        CUR["clean"] = clean_block
        bad = []
        for case in cases:
            saved = case.name
            m, (cwd, paths, want, exists, branches) = build(case, snap_block, "%s-%s" % (tag, saved))
            want = expand(expect_override.get(saved, want), m)
            got = norm(run_block(clean_block, cwd, run=case.run, mode=case.mode, paths=" ".join(paths)))
            if got != want:
                bad.append((saved, "want %r, got %r" % (want, got)))
                continue
            for p, e in exists.items():
                if os.path.exists(p) != e:
                    bad.append((saved, "%s %s" % (p, "is gone" if e else "still exists")))
            for b, e in branches.items():
                has = subprocess.run([GIT, "rev-parse", "--verify", "-q", "refs/heads/" + b], cwd=m,
                                     env=ENV, capture_output=True).returncode == 0
                if has != e:
                    bad.append((saved, "branch %s %s" % (b, "is gone" if e else "still exists")))
        return bad

    bad = outcome(SNAP, CLEAN, "shipped")
    if bad:
        for b in bad: miss("CLEANUP shipped blocks misclassify %s: %s" % b)
    else:
        ok("CLEANUP: the shipped blocks classify all %d fixtures, output and disk state" % len(cases))

    mutants = [
        ("no-snapshot-guard", 'if [ -z "$snap" ]; then echo "KEPT $wt: no pre-dispatch snapshot"; continue; fi', ":"),
        ("no-path-guard", 'if [ -z "$name" ] || [ "$wt" != "$main/.claude/worktrees/$name" ]; then', "if false; then"),
        ("no-main-anchor", '[ "$wt" != "$main/.claude/worktrees/$name" ]', "false"),
        ("no-registered", 'case "$nl$now$nl" in *"${nl}worktree $wt$nl"*) ;; *) echo "KEPT $wt: not a worktree of this repo"; continue ;; esac', ":"),
        ("no-prior", 'case "$nl$snap$nl" in *"${nl}worktree $wt$nl"*) echo "KEPT $wt: existed before this run\'s dispatch"; continue ;; esac', ":"),
        ("no-ignored", "git status --porcelain --ignored", "git status --porcelain"),
        ("no-status", 'if [ -n "$st" ]; then', "if false; then"),
        ("status-fail-open", "|| st='git status failed'", "|| st="),
        ("no-origin", 'if [ -z "$on" ]; then', "if false; then"),
        ("origin-any-ref", "\"$head\" --format='%(refname)' refs/remotes/origin/", "\"$head\" --format='%(refname)' refs/"),
        ("report-removes", 'if [ "$mode" != remove ]; then', "if false; then"),
        ("unknown-mode-removes", "*) mode=report ;;", "*) mode=remove ;;"),
        ("force", 'git worktree remove "$wt"', 'git worktree remove --force --force "$wt"'),
        ("no-held-check", 'case "$nl$held$nl" in *"${nl}branch refs/heads/$br$nl"*) echo "REMOVED $wt; kept branch $br: a worktree holds it"; continue ;; esac', ":"),
        ("no-tip-check", 'if [ -z "$bon" ]; then', "if false; then"),
        ("glob-expands", "set -f\n", "\n"),
        ("snapshot-not-consumed", 'if [ -n "$snapf" ] && [ -f "$snapf" ]; then : > "$snapf"; fi', ":"),
        ("no-unclaimed-report", 'echo "UNCLAIMED $p', 'true "UNCLAIMED $p'),
    ]
    for i, (name, old, new) in enumerate(mutants):
        if CLEAN.count(old) != 1:
            miss("CLEANUP mutant %s: anchor occurs %d times — re-read this script" % (name, CLEAN.count(old)))
            continue
        killers = outcome(SNAP, CLEAN.replace(old, new), "m%d" % i)
        if killers:
            ok("CLEANUP mutant %s is killed by %s" % (name, ", ".join(sorted(set(k[0] for k in killers)))))
        else:
            miss("CLEANUP mutant %s survives every fixture" % name)

try:
    cleanup_leg()
except (subprocess.CalledProcessError, OSError, RuntimeError) as e:
    miss("CLEANUP leg could not run: %s — a fixture that was not built is not a pass" % e)

finish()
PY
