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
#              `READ-ONLY:` (the token a deny-by-default isolation hook, where
#              an operator has one, admits a dispatch on) and names every
#              forbidden verb below. The second ```text block carries both
#              source lines. The plan-review persona template, the one brief
#              that is a file, carries the line with only <why> filled in.
#   SITES    — every command or skill that declares a dispatch tier (11a's
#              home excluded) cites 11a and 11b and tells the orchestrator to
#              put the READ-ONLY line in the prompt; lfg names the parallel
#              writer's `isolation: "worktree"`. Zero sites is a MISS. This is
#              a substring test per file: it proves each file names the rule,
#              not that every dispatch in the file carries the line.
#   TOOLS    — every site that declares `allowed-tools` grants each
#              `git <verb>` the 11b blocks run. The verbs are read from the
#              blocks.
#   CLEANUP  — the shipped blocks run, under `bash -e` in a separate process,
#              against fixture repos with planted agent worktrees, with the
#              agent ids substituted as an orchestrator would (a planted quote
#              included). Each fixture asserts the snapshot's output, the
#              cleanup's exact output lines AND what is left on disk
#              (worktree directory, branch, a planted marker file). A stub
#              `git` on PATH makes `status` or `worktree list` fail.
#   MUTANTS  — each is built from the shipped text by one substitution and must
#              turn its leg red. A mutant whose anchor text is gone is a MISS,
#              never a skip.
#
# STATED LIMITS — a green run does not mean:
#   - an agent obeys the READ-ONLY line, or that an orchestrator substitutes
#     the right paths. This tests the text and the blocks, not the model.
#   - the Agent tool reports a kept worktree's path; 11c says so.
#   - the snapshot block's own run-name check is NOT covered: the cleanup
#     repeats it, so dropping either one alone changes no output, and neither
#     is mutated. Nor are the `HEAD unreadable`, `HEAD reflog unreadable` and
#     `git branch -D failed` branches: no fixture reaches them once the
#     guards before them pass.
#   - an id line equal to the heredoc terminator CEPA_IDS. The orchestrator's
#     `^[a-z0-9]+$` check rejects it before substitution; the block cannot.
#   - SITES covers files that declare a dispatch tier (the TIER pattern); a
#     dispatch site that declares none is out of scope here and is
#     check-model-pins.sh's to find.
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
         "`git stash`", "`git commit`", "`git push`", "`gh pr checkout`", "detach HEAD"]
SOURCE = ["`git show <sha>:<path>`", "`git diff <base>...<sha>`",
          "Do not assume this checkout is on that commit.",
          "Read the files in this checkout as they are."]
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

def source_block(text):
    blocks = re.findall(r"^```text\n(.*?)^```$", text, re.M | re.S)
    return blocks[1] if len(blocks) > 1 else ""

def brief(text, template):
    probs = []
    src = source_block(text)
    for s in SOURCE:
        if s not in src:
            probs.append("11a's source-line block does not carry %r" % s)
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
SRC = source_block(S11A)
brief_mutants = [("drop-line", S11A.replace(LINE, ""), TPL),
                 ("drop-prefix", S11A.replace(LINE, LINE.replace("READ-ONLY: ", "Note: ", 1)), TPL),
                 ("drop-source-block", S11A.replace(SRC, ""), TPL),
                 ("template-drops-line", S11A, "\n".join(l for l in TPL.splitlines() if not l.startswith("READ-ONLY:")))]
brief_mutants += [("drop-verb:" + v, S11A.replace(LINE, LINE.replace(v, "x")), TPL) for v in VERBS]
brief_mutants += [("drop-source:" + s[:24], S11A.replace(SRC, SRC.replace(s, "x")), TPL) for s in SOURCE]
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
# Quoted strings are messages ("KEPT ...: not its own git toplevel"), not
# commands; strip them before reading the verbs.
_code = re.sub(r"'[^'\n]*'|\"[^\"\n]*\"", "''", SNAP + CLEAN)
BVERBS = sorted(set(re.findall(r"\bgit ([a-z][a-z-]*)", _code)))

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
    ENV = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
    ENV.update(GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1",
               GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t", GIT_COMMITTER_NAME="t",
               GIT_COMMITTER_EMAIL="t@t", LC_ALL="C")
    TMP = os.path.realpath(tempfile.mkdtemp(prefix="dispatch-iso-"))
    ENV["GIT_CEILING_DIRECTORIES"] = TMP
    stub_dir = os.path.join(TMP, "stub")
    os.makedirs(stub_dir)
    with open(os.path.join(stub_dir, "git"), "w") as f:
        f.write("""#!/bin/bash
case "$STUB" in
  list-fail) [ "$1" = worktree ] && [ "$2" = list ] && exit 128 ;;
  status-fail) [ "$1" = status ] && exit 128 ;;
esac
exec "$REAL_GIT" "$@"
""")
    os.chmod(os.path.join(stub_dir, "git"), 0o755)

    def g(cwd, *args):
        subprocess.run([GIT, *args], cwd=cwd, env=ENV, check=True, timeout=60,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def out(cwd, *args):
        return subprocess.run([GIT, *args], cwd=cwd, env=ENV, check=True, timeout=60,
                              capture_output=True, text=True).stdout.strip()

    def run_block(block, cwd, stub="", **subs):
        script = os.path.join(TMP, "block.sh")
        for k, v in subs.items():
            block = block.replace("<%s>" % k, v)
        with open(script, "w") as f:
            f.write(block)
        env = dict(ENV, REAL_GIT=GIT, STUB=stub)
        if stub:
            env["PATH"] = stub_dir + os.pathsep + env["PATH"]
        try:
            r = subprocess.run(["bash", "-e", script], cwd=cwd, env=env,
                               capture_output=True, text=True, timeout=60)
        except subprocess.TimeoutExpired:
            return ["TIMEOUT"]
        if r.returncode != 0:
            return ["EXIT %d" % r.returncode]
        return r.stdout.splitlines()

    def wtp(m, name):
        return os.path.join(m, ".claude", "worktrees", name)

    def agent(m, name, base="origin/main"):
        w = wtp(m, name)
        g(m, "worktree", "add", "-q", "-b", "worktree-" + name, w, base)
        return w

    def review_detach(w):
        # What a review agent does: leave its worktree-agent-* branch for the
        # PR head, which is on origin.
        g(w, "checkout", "-q", "--detach", "origin/pr")

    def planted_agent(m, name="agent-a1"):
        w = agent(m, name); review_detach(w); return w

    # setup(m, ctx) builds state, calling ctx.before() where the run takes its
    # snapshot. It returns (cwd, ids, expected lines, {path: exists?},
    # {branch: exists?}). {name} in an expected line is wtp(m, name).
    class Case:
        def __init__(self, name, setup, mode="remove", run="review", snap=True, stub=""):
            self.name, self.setup, self.mode, self.run, self.snap, self.stub = name, setup, mode, run, snap, stub

    REMOVED = "REMOVED {agent-a1}; deleted branch worktree-agent-a1"
    def planted(m, c):
        c.before(); w = planted_agent(m)
        return m, "a1", [REMOVED], {w: False}, {"worktree-agent-a1": False}
    def from_linked(m, c):
        s = wtp(m, "roles"); g(m, "worktree", "add", "-q", "-b", "fix/roles/x", s, "origin/main")
        c.before(s); w = planted_agent(m)
        return s, "a1", [REMOVED], {w: False}, {"worktree-agent-a1": False}
    def report(m, c):
        c.before(); w = planted_agent(m)
        return m, "a1", ["WOULD-REMOVE {agent-a1} (branch worktree-agent-a1)"], {w: True}, {"worktree-agent-a1": True}
    def report_beside_worker(m, c):
        c.before()                       # the worker's remove-mode snapshot
        if run_block(c.snap_block, m, run="review", mode="report") != \
                ["SNAPSHOT %s/.git/cepa-dispatch-before-review-report" % m]:
            raise RuntimeError("report-mode snapshot printed an unexpected line")
        if run_block(c.clean_block, m, run="review", mode="report", ids="") != []:
            raise RuntimeError("an empty report-mode cleanup printed output")
        w = planted_agent(m)
        return m, "a1", [REMOVED], {w: False}, {"worktree-agent-a1": False}
    def injection(m, c):
        c.before(); w = planted_agent(m)
        return m, "a1'; touch %s/PWNED; : '" % m, ["KEPT agent id a1…: not [a-z0-9]+",
                        "UNCLAIMED {agent-a1}: new since this run's snapshot, not one of its own dispatches — left alone"], \
               {w: True, os.path.join(m, "PWNED"): False}, {"worktree-agent-a1": True}
    def not_agent(m, c):
        c.before(); w = agent(m, "feature1"); review_detach(w)
        return m, "x/../feature1", ["KEPT agent id x…: not [a-z0-9]+"], {w: True}, {"worktree-feature1": True}
    def glob_id(m, c):
        c.before(); w = planted_agent(m)
        return m, "*", ["KEPT agent id …: not [a-z0-9]+",
                        "UNCLAIMED {agent-a1}: new since this run's snapshot, not one of its own dispatches — left alone"], \
               {w: True}, {"worktree-agent-a1": True}
    def unregistered(m, c):
        c.before(); w = wtp(m, "agent-zz"); os.makedirs(w)
        return m, "zz", ["KEPT {agent-zz}: not a worktree of this repo"], {w: True}, {}
    def pre_existing(m, c):
        w = planted_agent(m, "agent-old"); c.before()
        return m, "old", ["KEPT {agent-old}: existed before this run's dispatch"], {w: True}, {"worktree-agent-old": True}
    def pre_existing_unnamed(m, c):
        w = planted_agent(m, "agent-old"); c.before()
        return m, "", [], {w: True}, {"worktree-agent-old": True}
    def missing_dotgit(m, c):
        c.before(); w = planted_agent(m); os.remove(os.path.join(w, ".git"))
        return m, "a1", ["KEPT {agent-a1}: not its own git toplevel"], {w: True}, {"worktree-agent-a1": True}
    def untracked(m, c):
        c.before(); w = planted_agent(m); open(os.path.join(w, "u.txt"), "w").write("x\n")
        return m, "a1", ["KEPT {agent-a1}: has status lines (?? u.txt)"], {w: True}, {"worktree-agent-a1": True}
    def untracked_config_no(m, c):
        c.before(); w = planted_agent(m); g(m, "config", "status.showUntrackedFiles", "no")
        os.makedirs(os.path.join(w, "d")); open(os.path.join(w, "d", "u.txt"), "w").write("x\n")
        return m, "a1", ["KEPT {agent-a1}: has status lines (?? d/u.txt)"], {w: True}, {"worktree-agent-a1": True}
    def ignored_only(m, c):
        c.before(); w = planted_agent(m); open(os.path.join(w, "x.log"), "w").write("x\n")
        return m, "a1", ["KEPT {agent-a1}: has status lines (!! x.log)"], {w: True}, {"worktree-agent-a1": True}
    def tracked_edit(m, c):
        c.before(); w = planted_agent(m); open(os.path.join(w, "f.txt"), "a").write("y\n")
        return m, "a1", ["KEPT {agent-a1}: has status lines ( M f.txt)"], {w: True}, {"worktree-agent-a1": True}
    def status_fails(m, c):
        c.before(); w = planted_agent(m)
        return m, "a1", ["KEPT {agent-a1}: has status lines (git status failed)"], {w: True}, {"worktree-agent-a1": True}
    def list_fails(m, c):
        c.before(); w = planted_agent(m)
        return m, "a1", ["KEPT agent-a1: git worktree list failed"], {w: True}, {"worktree-agent-a1": True}
    def local_head(m, c):
        c.before(); w = planted_agent(m)
        g(w, "commit", "-q", "--allow-empty", "-m", "local")
        g(m, "branch", "keep-local", out(w, "rev-parse", "HEAD"))
        return m, "a1", ["KEPT {agent-a1}: HEAD <sha> is on no origin ref"], {w: True}, {"worktree-agent-a1": True}
    def reflog_lost(m, c):
        c.before(); w = planted_agent(m)
        g(w, "commit", "-q", "--allow-empty", "-m", "detached-work")
        g(w, "checkout", "-q", "--detach", "origin/pr")
        return m, "a1", ["KEPT {agent-a1}: HEAD reflog holds a commit no origin ref has"], {w: True}, {"worktree-agent-a1": True}
    def no_snapshot(m, c):
        w = planted_agent(m)
        return m, "a1", ["KEPT {agent-a1}: no pre-dispatch snapshot"], {w: True}, {"worktree-agent-a1": True}
    def consumed(m, c):
        c.before()
        if run_block(c.clean_block, m, run="review", mode="remove", ids="") != []:
            raise RuntimeError("an empty first cleanup printed output")
        w = planted_agent(m)
        return m, "a1", ["KEPT {agent-a1}: no pre-dispatch snapshot"], {w: True}, {"worktree-agent-a1": True}
    def bad_run(m, c):
        c.before(); w = planted_agent(m)
        return m, "a1", ["KEPT {agent-a1}: no pre-dispatch snapshot"], {w: True}, {"worktree-agent-a1": True}
    def locked(m, c):
        c.before(); w = planted_agent(m); g(m, "worktree", "lock", w)
        return m, "a1", ["KEPT {agent-a1}: git worktree remove refused"], {w: True}, {"worktree-agent-a1": True}
    def no_branch(m, c):
        c.before(); w = planted_agent(m); g(m, "branch", "-D", "worktree-agent-a1")
        return m, "a1", ["REMOVED {agent-a1}; no branch worktree-agent-a1"], {w: False}, {}
    def branch_unique(m, c):
        # The branch gains a commit origin lacks, made outside the worktree,
        # so the worktree's own HEAD reflog stays on origin.
        c.before(); w = planted_agent(m)
        extra = out(m, "commit-tree", "origin/main^{tree}", "-p", "origin/main", "-m", "on-branch")
        g(m, "update-ref", "refs/heads/worktree-agent-a1", extra)
        return m, "a1", ["REMOVED {agent-a1}; kept branch worktree-agent-a1: tip <sha> is on no origin ref"], \
               {w: False}, {"worktree-agent-a1": True}
    def branch_held(m, c):
        c.before(); w = planted_agent(m); h = wtp(m, "holder")
        g(m, "worktree", "add", "-q", h, "worktree-agent-a1")
        return m, "a1", ["REMOVED {agent-a1}; kept branch worktree-agent-a1: a worktree holds it"], \
               {w: False, h: True}, {"worktree-agent-a1": True}
    def unclaimed(m, c):
        c.before(); w = planted_agent(m); o = planted_agent(m, "agent-b2")
        return m, "a1", [REMOVED, "UNCLAIMED {agent-b2}: new since this run's snapshot, not one of its own dispatches — left alone"], \
               {w: False, o: True}, {"worktree-agent-b2": True}

    cases = [Case("planted", planted), Case("from-linked-worktree", from_linked),
             Case("report-mode", report, mode="report"), Case("unknown-mode", report, mode="delete"),
             Case("report-beside-worker", report_beside_worker),
             Case("injection", injection), Case("not-agent", not_agent), Case("glob-id", glob_id),
             Case("unregistered", unregistered), Case("pre-existing", pre_existing),
             Case("pre-existing-unnamed", pre_existing_unnamed), Case("missing-dotgit", missing_dotgit),
             Case("untracked", untracked), Case("untracked-config-no", untracked_config_no),
             Case("ignored-only", ignored_only), Case("tracked-edit", tracked_edit),
             Case("status-fails", status_fails, stub="status-fail"),
             Case("list-fails", list_fails, stub="list-fail"),
             Case("local-only-head", local_head), Case("reflog-lost", reflog_lost),
             Case("no-snapshot", no_snapshot, snap=False), Case("snapshot-consumed", consumed),
             Case("bad-run-name", bad_run, run="Review!"), Case("locked", locked),
             Case("no-branch", no_branch), Case("branch-unique-commit", branch_unique),
             Case("branch-held", branch_held), Case("unclaimed", unclaimed)]

    class Ctx:
        pass

    def build(case, snap_block, clean_block, dirname):
        m = os.path.join(TMP, dirname)
        os.makedirs(m)
        g(m, "init", "-q", "-b", "main")
        open(os.path.join(m, ".gitignore"), "w").write("*.log\n.claude/\n")
        open(os.path.join(m, "f.txt"), "w").write("a\n")
        g(m, "add", "-A"); g(m, "commit", "-q", "-m", "c1")
        g(m, "update-ref", "refs/remotes/origin/main", "HEAD")
        pr = out(m, "commit-tree", "HEAD^{tree}", "-p", "HEAD", "-m", "pr-head")
        g(m, "update-ref", "refs/remotes/origin/pr", pr)
        ctx = Ctx(); ctx.snap_block, ctx.clean_block, ctx.snap_out = snap_block, clean_block, None
        def before(cwd=m):
            if case.snap:
                ctx.snap_out = (run_block(snap_block, cwd, run=case.run, mode=case.mode),
                                out(cwd, "rev-parse", "--path-format=absolute", "--git-dir"))
        ctx.before = before
        return m, ctx, case.setup(m, ctx)

    def expand(lines, m):
        return [re.sub(r"\{([a-z0-9-]+)\}", lambda mm: wtp(m, mm.group(1)), l) for l in lines]

    def outcome(snap_block, clean_block, tag):
        """[(case, problem)] for every case the blocks get wrong."""
        bad = []
        for case in cases:
            try:
                m, ctx, (cwd, ids, want, exists, branches) = build(case, snap_block, clean_block,
                                                                   "%s-%s" % (tag, case.name))
            except RuntimeError as e:
                # A setup step that runs the blocks under test saw them misbehave.
                bad.append((case.name, "setup: %s" % e))
                continue
            if ctx.snap_out is not None:
                got_snap, gd = ctx.snap_out
                mode = case.mode if case.mode in ("remove", "report") else "report"
                want_snap = ["SNAPSHOT %s/cepa-dispatch-before-%s-%s" % (gd, case.run, mode)] \
                    if re.match(r"^[a-z-]+$", case.run) else ["SNAPSHOT-FAILED: run name is not [a-z-]+"]
                if got_snap != want_snap:
                    bad.append((case.name, "snapshot printed %r, want %r" % (got_snap, want_snap)))
                    continue
            want = expand(want, m)
            got = [re.sub(r"\b[0-9a-f]{40}\b", "<sha>", l)
                   for l in run_block(clean_block, cwd, stub=case.stub, run=case.run, mode=case.mode, ids=ids)]
            if got != want:
                bad.append((case.name, "want %r, got %r" % (want, got)))
                continue
            for p, e in exists.items():
                if os.path.exists(p) != e:
                    bad.append((case.name, "%s %s" % (p, "is gone" if e else "exists")))
            for b, e in branches.items():
                has = subprocess.run([GIT, "rev-parse", "--verify", "-q", "refs/heads/" + b], cwd=m,
                                     env=ENV, capture_output=True, timeout=60).returncode == 0
                if has != e:
                    bad.append((case.name, "branch %s %s" % (b, "is gone" if e else "still exists")))
        return bad

    bad = outcome(SNAP, CLEAN, "shipped")
    if bad:
        for b in bad: miss("CLEANUP shipped blocks misclassify %s: %s" % b)
    else:
        ok("CLEANUP: the shipped blocks classify all %d fixtures, output and disk state" % len(cases))

    HEREDOC = "ids=\nIFS= read -r -d '' ids <<'CEPA_IDS' || true\n<ids>\nCEPA_IDS\n"
    # (name, block, old, new). block "clean" mutates the cleanup; "both" makes
    # the same substitution in the snapshot and the cleanup.
    mutants = [
        ("clean", "no-snapshot-guard", 'if [ -z "$snap" ]; then echo "KEPT $wt: no pre-dispatch snapshot"; continue; fi', ":"),
        ("clean", "no-list-guard", 'if [ -z "$now" ]; then echo "KEPT agent-$id: git worktree list failed"; continue; fi', ":"),
        ("clean", "no-id-validation", 'case "$id" in *[!a-z0-9]*) echo "KEPT agent id ${id%%[!a-z0-9]*}…: not [a-z0-9]+"; continue ;; esac', ":"),
        ("clean", "quoted-substitution", HEREDOC, "ids='<ids>'\n"),
        ("clean", "no-registered", 'case "$nl$now$nl" in *"${nl}worktree $wt$nl"*) ;; *) echo "KEPT $wt: not a worktree of this repo"; continue ;; esac', ":"),
        ("clean", "no-prior", 'case "$nl$snap$nl" in *"${nl}worktree $wt$nl"*) echo "KEPT $wt: existed before this run\'s dispatch"; continue ;; esac', ":"),
        ("clean", "no-toplevel", 'if [ "$top" != "$wt" ]; then', "if false; then"),
        ("clean", "no-ignored", "git status --porcelain --ignored --untracked-files=all", "git status --porcelain --untracked-files=all"),
        ("clean", "no-untracked-all", "git status --porcelain --ignored --untracked-files=all", "git status --porcelain --ignored"),
        ("clean", "no-status", 'if [ -n "$st" ]; then', "if false; then"),
        ("clean", "status-fail-open", "|| st='git status failed'", "|| st="),
        ("clean", "no-origin", 'if [ -z "$on" ]; then', "if false; then"),
        ("clean", "origin-any-ref", "\"$head\" --format='%(refname)' refs/remotes/origin/", "\"$head\" --format='%(refname)' refs/"),
        ("clean", "no-reflog-check", 'if [ -n "$lost" ]; then', "if false; then"),
        ("clean", "report-removes", 'if [ "$mode" != remove ]; then', "if false; then"),
        ("clean", "unknown-mode-removes", "remove|report) ;; *) mode=report ;;", "remove|report) ;; *) mode=remove ;;"),
        ("clean", "force", 'git worktree remove "$wt"', 'git worktree remove --force --force "$wt"'),
        ("clean", "no-branch-check", 'if [ -z "$tip" ]; then echo "REMOVED $wt; no branch $br"; continue; fi', ":"),
        ("clean", "no-held-check", 'case "$nl$held$nl" in *"${nl}branch refs/heads/$br$nl"*) echo "REMOVED $wt; kept branch $br: a worktree holds it"; continue ;; esac', ":"),
        ("clean", "no-tip-check", 'if [ -z "$bon" ]; then', "if false; then"),
        ("clean", "unclaimed-ignores-snapshot", '    case "$nl$snap$nl" in *"${nl}worktree $p$nl"*) continue ;; esac\n', ""),
        ("clean", "no-unclaimed-report", 'echo "UNCLAIMED $p', 'true "UNCLAIMED $p'),
        ("clean", "snapshot-not-consumed", 'if [ -n "$snapf" ] && [ -f "$snapf" ]; then : > "$snapf"; fi', ":"),
        ("both", "snapshot-not-keyed-by-mode", "cepa-dispatch-before-$run-$mode", "cepa-dispatch-before-$run"),
    ]
    for i, (which, name, old, new) in enumerate(mutants):
        counts = [CLEAN.count(old)] if which == "clean" else [SNAP.count(old), CLEAN.count(old)]
        if (which == "clean" and counts != [1]) or 0 in counts:
            miss("CLEANUP mutant %s: anchor occurs %s times — re-read this script" % (name, counts))
            continue
        snap_m = SNAP.replace(old, new) if which == "both" else SNAP
        killers = outcome(snap_m, CLEAN.replace(old, new), "m%d" % i)
        if killers:
            ok("CLEANUP mutant %s is killed by %s" % (name, ", ".join(sorted(set(k[0] for k in killers)))))
        else:
            miss("CLEANUP mutant %s survives every fixture" % name)

try:
    cleanup_leg()
except Exception as e:
    miss("CLEANUP leg could not run: %s: %s — a fixture that was not built is not a pass" % (type(e).__name__, e))

finish()
PY
