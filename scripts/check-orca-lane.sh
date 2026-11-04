#!/usr/bin/env bash
# Check for plugins/cepa/scripts/orca-lane.sh, the one checked form of
# `cepa:autonomy` §12b rule 2's lane lifecycle (punch-list L55). It runs the
# script in throwaway git repos (a bare origin and a main clone, with real
# worktrees) against scripts/fixtures/orca-lane-stub.py as `orca-ide` on
# PATH, so it never reaches a real Orca. The stub returns Orca's UNC paths and
# logs every call.
#
# Usage: check-orca-lane.sh [orca-lane.sh [SKILL.md [orca-lane-reflog.sh]]]
#   The optional paths replace the shipped script, the autonomy skill whose
#   rule 2 lane block the BLOCK leg runs, and the reflog check orca-lane.sh
#   calls from its own directory. Only check-orca-lane-controls.sh sets them,
#   to run this check against a mutant. The script and the reflog check are
#   copied into one temp directory and run from there.
#   scripts/fixtures/orca-lane-gh-stub.py is `gh` on PATH, so the reflog
#   check never reaches GitHub.
#
# Every MISS line starts with its case name, so the controls can assert the
# exact set of cases each mutant breaks. Legs:
#   FIELDS — each bad field, missing field, extra line, argument, bad cli,
#            bad action, a field an action does not take, a bad lane or base,
#            rm without a confirm or with one that differs from the lane,
#            and a linked worktree as the caller: exit 4, `refused`, and the
#            stub is never called.
#   SCOPE  — a same-named lane of another repo is never selected, renamed or
#            removed; a path from another WSL distro reads as UNKNOWN.
#   READS  — a failed, truncated or host-omitting list, or a failed or
#            truncated ps, is UNKNOWN: kept, and no write call is made.
#   CREATE — happy create (exact create argv, parked detached, park branch
#            deleted, show by id); a name taken in Orca or in git; a park
#            branch that exists; a failed create; a suffixed path; a
#            suffixed branch; a non-fixed name; a park branch with a commit;
#            a stale show. Each mismatch keeps the lane and deletes nothing.
#            Resume (L58, #4): a lane left on its park branch, and one left
#            detached at the park tip, are parked; a lane on another branch
#            is not resumed. A stale local origin/<base> is re-fetched (#28).
#            L79: a create with no result (runtime_timeout, also at exit 0;
#            no JSON; a kill; no error code) reads Orca's list. A lane that
#            shows is parked by steps 3-6, with one create call. A lane that
#            never shows fails with exactly 12 reads, or fewer at the 120 s
#            clock (`date` and `sleep` are stubs), and its text says a lane
#            may appear and never says to run create. Two rows fail; a row
#            not settled is read again; a definite error is not polled; a
#            lane that shows after the poll ended is resumed.
#   NAME   — only automatic, non-main lanes with a <wt> basename are renamed,
#            by id; a second run renames none; a skip exits 1 with an Ending
#            line (#30); a failed set and a set that does not stick are
#            failures.
#   RM     — happy rm of a parked lane (ignored files listed, exact rm argv,
#            absent from both lists) and of a lane on a branch; refusals on
#            an untracked file, a tracked change, a HEAD on no origin ref, a
#            reflog-only commit, a live agent, two lanes with one basename;
#            a failed archive hook (kept, exit 3, output scrubbed); a reply
#            that says removed while the lane stays; a re-list that fails.
#            Reused lanes (L58, #1): a squash-merged, deleted branch's reflog
#            commits are landed by its MERGED PR's head (removed); an
#            unpushed commit the PR head lacks, a branch with no merged PR,
#            a PR into another base, a fork PR, a gh failure, a merge commit
#            whose parents landed, and a helper that exits 0 without a
#            `landed:` line keep the lane; an amended-away commit, a
#            `checkout HEAD~1` entry, and a detached commit with an equal
#            patch on the default branch are removed. The main checkout's
#            orca.yaml (#16): untracked, unpushed, or edited under
#            skip-worktree keeps the lane; pushed to the default is removed.
#            L77 items 1 and 5: the trunk, from the main checkout's
#            cepa.local.md, counts for a merged PR, an equal patch and the
#            orca.yaml comparison; a PR into the default still counts; a
#            malformed or doubled override is unknown. L77 items 2, 3, 4, 6:
#            each Ending line, and the remedy each names is run for real.
#   HOOKS  — L76: Orca's saved hookSettings (stubbed per case) against
#            orca.yaml. create: unset, shared-only, local-only matching, and
#            run-both with no local script create; local-only differing or
#            empty, unset with a local script (Orca reads it as local-only),
#            and run-both with a local script refuse before `worktree
#            create`; an unknown policy, a missing scripts map or
#            hookSettings, a non-string script, and an orca.yaml block
#            scalar, flow value or duplicate key refuse as unknown; a quoted scalar is
#            read; no orca.yaml matches an empty local-only setup. rm: the
#            same rule on scripts.archive from the main checkout's orca.yaml.
#            PR #133 review: a BOM, a quoted top-level key, an indented
#            document and a YAML null refuse as unknown; a local script that
#            only JS trim keeps refuses; origin's current orca.yaml is read,
#            not a stale local ref; a base origin lacks and a failed fetch
#            refuse before any worktree read; a resume onto a shadow fails (exit 3).
#   BLOCK  — §12b rule 2's lane block, extracted and run under `bash -e`:
#            it runs `name`; shell text in a field runs nothing; with the
#            script absent it prints the skipped line. L79: rule 2 and the
#            script no longer tell a session to re-run a failed create.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

CEPA_LANE_SCRIPT="$(realpath "${1:-plugins/cepa/scripts/orca-lane.sh}")" \
CEPA_LANE_SKILL="$(realpath "${2:-plugins/cepa/skills/autonomy/SKILL.md}")" \
CEPA_LANE_HELPER="$(realpath "${3:-plugins/cepa/scripts/orca-lane-reflog.sh}")" \
python3 - <<'PY'
import json, os, re, shutil, subprocess, sys, tempfile, textwrap

SKILL = os.environ["CEPA_LANE_SKILL"]
STUB = os.path.realpath("scripts/fixtures/orca-lane-stub.py")
GHSTUB = os.path.realpath("scripts/fixtures/orca-lane-gh-stub.py")
# orca-lane.sh finds orca-lane-reflog.sh beside itself: run both from one dir.
PLUGS = tempfile.mkdtemp(prefix="cepa-lane-plug-")
SCRIPT = os.path.join(PLUGS, "orca-lane.sh")
HELPER = os.path.join(PLUGS, "orca-lane-reflog.sh")
shutil.copy(os.environ["CEPA_LANE_SCRIPT"], SCRIPT)
shutil.copy(os.environ["CEPA_LANE_HELPER"], HELPER)
RESOLVE = os.path.realpath("plugins/cepa/scripts/resolve-plugin-root.sh")
passed = failed = 0
DISTRO = "Ubuntu-24.04"
RID, RID2 = "11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222"


def ok(name):
    global passed
    passed += 1


def miss(name):
    global failed
    failed += 1
    print("MISS " + name)


def sh(*a, cwd=None, check=True):
    r = subprocess.run(list(a), cwd=cwd, capture_output=True, text=True,
                       env=dict(os.environ, GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1"))
    if check and r.returncode:
        raise RuntimeError("%s: %s" % (a, r.stderr))
    return r.stdout.strip()


def unc(p):
    return "\\\\wsl.localhost\\" + DISTRO + p.replace("/", "\\")


class World:
    """A bare origin, a main clone, an Orca workspace dir, a stub on PATH."""

    def __init__(self, tag):
        self.d = tempfile.mkdtemp(prefix="cepa-lane-%s-" % tag)
        self.origin = os.path.join(self.d, "origin.git")
        self.main = os.path.join(self.d, "repo")
        self.other = os.path.join(self.d, "other")
        sh("git", "init", "-q", "--bare", "-b", "main", self.origin)
        sh("git", "clone", "-q", self.origin, self.main)
        self.git("checkout", "-q", "-b", "main")
        open(os.path.join(self.main, ".gitignore"), "w").write("node_modules/\n")
        open(os.path.join(self.main, "f.txt"), "w").write("a\n")
        self.git("add", ".")
        self.commit("init")
        self.git("push", "-q", "origin", "main")
        self.git("fetch", "-q", "origin")
        os.makedirs(self.other)
        self.ws = os.path.join(self.d, "ws")
        os.makedirs(self.ws)
        self.bin = os.path.join(self.d, "bin")
        os.makedirs(self.bin)
        os.symlink(STUB, os.path.join(self.bin, "orca-ide"))
        os.symlink(GHSTUB, os.path.join(self.bin, "gh"))
        # `sleep` logs and returns; `date +%s` is a clock that moves
        # STUB_DATE_STEP per read, so the poll's 120 s bound runs in no time.
        for n, t in (("sleep", '#!/bin/sh\n[ -z "$STUB_SLEEP_LOG" ] || echo "$1" >>"$STUB_SLEEP_LOG"\n'),
                     ("date", '#!/bin/sh\n[ -n "$STUB_DATE_STEP" ] || exec /usr/bin/env -i PATH=/usr/bin:/bin date "$@"\n'
                              'n=$(cat "$STUB_CLOCK" 2>/dev/null || echo 0)\necho "$n"\necho $((n + STUB_DATE_STEP)) >"$STUB_CLOCK"\n')):
            open(os.path.join(self.bin, n), "w").write(t)
            os.chmod(os.path.join(self.bin, n), 0o755)
        self.gh = os.path.join(self.d, "gh.json")
        self.ghlog = os.path.join(self.d, "gh.log")
        json.dump({}, open(self.gh, "w"))
        self.state = os.path.join(self.d, "state.json")
        self.log = os.path.join(self.d, "calls.log")
        self.st = {"distro": DISTRO, "ws": self.ws,
                   "repos": [{"id": RID, "path": self.main}, {"id": RID2, "path": self.other}],
                   "wts": [{"repoId": RID, "path": self.main, "name": "main", "mode": "automatic", "main": True}]}
        self.save()

    def git(self, *a, cwd=None):
        return sh("git", *a, cwd=cwd or self.main)

    def commit(self, msg, cwd=None):
        self.git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", msg, cwd=cwd)

    def save(self):
        json.dump(self.st, open(self.state, "w"))

    def load(self):
        self.st = json.load(open(self.state))
        return self.st

    def lane(self, name, where="ws", mode="fixed", repo=RID, branch=None, register=True):
        """A real worktree, parked at origin/main unless a branch is given."""
        p = os.path.join(self.ws, "repo", name) if where == "ws" else os.path.join(self.main, ".claude", "worktrees", name)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        if branch:
            self.git("worktree", "add", "-q", "-b", branch, p, "origin/main")
        else:
            self.git("worktree", "add", "-q", "--detach", p, "origin/main")
        if register:
            self.load()
            self.st["wts"].append({"repoId": repo, "path": p, "name": name, "mode": mode, "main": False})
            self.save()
        return p

    def wid(self, p, repo=RID):
        return repo + "::" + unc(p)

    def run(self, fields, mode="", cwd=None, args=(), env=None, script=None):
        open(self.log, "w").close()
        self.sleeps = os.path.join(self.d, "sleeps.log")
        open(self.sleeps, "w").close()
        clock = os.path.join(self.d, "clock")
        if os.path.exists(clock):
            os.remove(clock)
        self.load(); self.st["lists"] = 0; self.save()
        e = dict(os.environ, PATH=self.bin + ":" + os.environ["PATH"], STUB_STATE=self.state, STUB_LOG=self.log,
                 STUB_MODE=mode, WSL_DISTRO_NAME=DISTRO, GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1",
                 STUB_GH=self.gh, STUB_GH_LOG=self.ghlog, STUB_SLEEP_LOG=self.sleeps, STUB_CLOCK=clock)
        e.pop("ORCA_CLI_COMMAND", None)
        e.update(env or {})
        r = subprocess.run(["bash", script or SCRIPT, *args], input=fields, cwd=cwd or self.main, capture_output=True,
                           text=True, env=e, timeout=120)
        calls = [json.loads(l) for l in open(self.log) if l.strip()]
        return r.returncode, r.stdout.splitlines(), calls

    def done(self):
        shutil.rmtree(self.d, ignore_errors=True)


def F(**kw):
    """Field lines. rm gets `confirm: <lane>` unless confirm is given (None
    leaves it out)."""
    if kw.get("action") == "rm" and "lane" in kw and "confirm" not in kw:
        kw["confirm"] = kw["lane"]
    order = ["cli", "action", "lane", "base", "confirm"]
    return "".join("%s: %s\n" % (k, kw[k]) for k in order if kw.get(k) is not None)


def expect(name, got, rc=None, first=None, has=(), lacks=(), calls_none=False, verbs_lack=()):
    rc_, out, calls = got
    why = []
    if rc is not None and rc_ != rc:
        why.append("rc=%s want %s" % (rc_, rc))
    if first is not None and not (out and out[0].startswith(first)):
        why.append("first line %r want %r…" % (out[:1], first))
    text = "\n".join(out)
    for h in has:
        if h not in text:
            why.append("missing %r" % h)
    for h in lacks:
        if h in text:
            why.append("has %r" % h)
    if calls_none and calls:
        why.append("stub called %r" % calls[:2])
    for v in verbs_lack:
        if any(c[:2] == v for c in calls):
            why.append("made a %s call" % " ".join(v))
    (miss if why else ok)("%s: %s | out=%r" % (name, "; ".join(why), out[:4]) if why else name)


def verbs(calls):
    return [c[:2] for c in calls]


CLI = "orca-ide"
W = World("fields")
# ---- FIELDS
R = "ORCA lane refused: "
cases = [
    ("FIELDS argument", F(cli=CLI, action="name"), ("x",), "orca-lane.sh takes no arguments"),
    ("FIELDS not a field line", "cli orca-ide\n", (), "a heredoc line is not a <name>: <value> field"),
    ("FIELDS unknown field", F(cli=CLI, action="name") + "run: x\n", (), "a field name is not cli, action, lane, base or confirm"),
    ("FIELDS duplicate", F(cli=CLI, action="name") + "cli: orca-ide\n", (), "the cli field is given twice"),
    ("FIELDS line after fields", F(cli=CLI, action="name") + "\nrm -rf x\n", (), "the heredoc holds a line after its fields"),
    ("FIELDS missing cli", "action: name\n", (), "the cli field is missing"),
    ("FIELDS cli with shell text", "cli: orca-ide$(touch x)\naction: name\n", (), "the cli is not a plain command name"),
    ("FIELDS cli not orca", F(cli="bash", action="name"), (), "the cli does not name an Orca CLI"),
    ("FIELDS cli relative path", F(cli="bin/orca-ide", action="name"), (), "a cli path must be absolute"),
    ("FIELDS missing action", "cli: orca-ide\n", (), "the action field is missing"),
    ("FIELDS bad action", F(cli=CLI, action="remove"), (), "the action is not create, name or rm"),
    ("FIELDS name with lane", F(cli=CLI, action="name", lane="x"), (), "name takes no lane field"),
    ("FIELDS name with base", F(cli=CLI, action="name", base="main"), (), "name takes no base field"),
    ("FIELDS rm with base", F(cli=CLI, action="rm", lane="x", base="main"), (), "rm takes no base field"),
    ("FIELDS rm without lane", F(cli=CLI, action="rm"), (), "the lane field is missing"),
    ("FIELDS create without base", F(cli=CLI, action="create", lane="x"), (), "the base field is missing"),
    ("FIELDS create without lane", F(cli=CLI, action="create", base="main"), (), "the lane field is missing"),
    ("FIELDS lane double dash", F(cli=CLI, action="rm", lane="a--b"), (), "the lane is not a <wt> name"),
    ("FIELDS lane leading dash", F(cli=CLI, action="rm", lane="-x"), (), "the lane is not a <wt> name"),
    ("FIELDS lane slash", F(cli=CLI, action="rm", lane="a/b"), (), "the lane is not a <wt> name"),
    ("FIELDS lane shell text", F(cli=CLI, action="rm", lane="x$(touch m)"), (), "the lane is not a <wt> name"),
    ("FIELDS lane too long", F(cli=CLI, action="rm", lane="a" * 65), (), "the lane is not a <wt> name"),
    ("FIELDS lane main", F(cli=CLI, action="rm", lane="main"), (), "the lane may not be main"),
    ("FIELDS base leading dash", F(cli=CLI, action="create", lane="x", base="-main"), (), "the base is not a branch name"),
    ("FIELDS base dotdot", F(cli=CLI, action="create", lane="x", base="a..b"), (), "the base is not a valid branch name"),
    ("FIELDS rm without confirm", F(cli=CLI, action="rm", lane="x", confirm=None), (), "rm needs a confirm field"),
    ("FIELDS rm confirm differs", F(cli=CLI, action="rm", lane="x", confirm="y"), (), "the confirm field does not repeat the lane"),
    ("FIELDS name with confirm", F(cli=CLI, action="name", confirm="x"), (), "name takes no confirm field"),
    ("FIELDS create with confirm", F(cli=CLI, action="create", lane="x", base="main", confirm="x"), (),
     "create takes no confirm field"),
]
for name, fields, args, reason in cases:
    expect(name, W.run(fields, args=args), rc=4, first=R + reason, calls_none=True)
lp = W.lane("linked", register=False)
expect("FIELDS linked worktree caller", W.run(F(cli=CLI, action="name"), cwd=lp), rc=4,
       first=R + "run it from the main checkout", calls_none=True)
W.done()

# ---- SCOPE
W = World("scope")
W.lane("alpha", mode="automatic", repo=RID2)  # a worktree of the main clone, registered to ANOTHER repo id
W.load(); W.st["wts"].append({"repoId": RID2, "path": W.other, "name": "other", "mode": "automatic", "main": True}); W.save()
got = W.run(F(cli=CLI, action="rm", lane="alpha"), mode="leak")
expect("SCOPE rm never selects another repo's lane", got, rc=1, first="ORCA lane: kept alpha — no lane of this repo",
       verbs_lack=[["worktree", "rm"]])
got = W.run(F(cli=CLI, action="name"), mode="leak")
expect("SCOPE name never renames another repo's lane", got, rc=0, has=("named 0 lane(s)",), verbs_lack=[["worktree", "set"]])
rc_, out, calls = got
lists = [c for c in calls if c[:2] == ["worktree", "list"]]
(ok if lists and all("--repo" in c and c[c.index("--repo") + 1] == "id:" + RID for c in lists) else miss)(
    "SCOPE list is scoped by repo id" + ("" if lists else ": no list call"))
W.done()
W = World("distro")
W.lane("beta", mode="automatic")
expect("SCOPE another distro's path is UNKNOWN", W.run(F(cli=CLI, action="name"), mode="otherdistro"), rc=1,
       first="ORCA lane: no lane renamed — worktree list was not a complete read", verbs_lack=[["worktree", "set"]])
W.done()

# ---- READS
W = World("reads")
W.lane("gamma", mode="automatic")
# One lane per rm case, so a mutant that lets one removal through cannot
# change what a later case sees.
for m in ("listfail", "listpartial", "listomitted", "listcount"):
    expect("READS %s is UNKNOWN for name" % m, W.run(F(cli=CLI, action="name"), mode=m), rc=1,
           first="ORCA lane: no lane renamed", verbs_lack=[["worktree", "set"]])
    W.lane("g-" + m)
    expect("READS %s is UNKNOWN for rm" % m, W.run(F(cli=CLI, action="rm", lane="g-" + m), mode=m), rc=1,
           first="ORCA lane: g-%s unchanged — worktree list was not a complete read" % m, verbs_lack=[["worktree", "rm"]])
    expect("READS %s is UNKNOWN for create" % m, W.run(F(cli=CLI, action="create", lane="new1", base="main"), mode=m),
           rc=1, first="ORCA lane: new1 unchanged", verbs_lack=[["worktree", "create"]])
for m, why in (("psfail", "worktree ps failed"), ("pspartial", "worktree ps was not a complete read"),
               ("psmissing", "worktree ps was not a complete read")):
    W.lane("g-" + m)
    expect("READS %s keeps the lane" % m, W.run(F(cli=CLI, action="rm", lane="g-" + m), mode=m), rc=1,
           first="ORCA lane: kept g-%s — %s" % (m, why), verbs_lack=[["worktree", "rm"]])
expect("READS repo list failure", W.run(F(cli=CLI, action="name"), mode="repofail"), rc=1,
       first="ORCA lane: lanes unchanged — repo list failed")
W.done()

# ---- CREATE
W = World("create")
got = W.run(F(cli=CLI, action="create", lane="delta", base="main"))
rc_, out, calls = got
p = os.path.join(W.ws, "repo", "delta")
expect("CREATE happy", got, rc=0, first="ORCA lane: created delta at " + p, has=("parked detached at", "named delta (fixed)",
       "setup policy run-by-default", "Orca reports no setup result"))
cr = [c for c in calls if c[:2] == ["worktree", "create"]]
want = ["worktree", "create", "--repo", "id:" + RID, "--name", "delta", "--branch", "chore/delta/park",
        "--base-branch", "origin/main", "--no-parent", "--setup", "inherit", "--json"]
(ok if cr == [want] else miss)("CREATE exact create argv" + ("" if cr == [want] else ": %r" % cr))
br = sh("git", "-C", W.main, "branch", "--list", "chore/delta/park")
head = sh("git", "-C", p, "rev-parse", "HEAD") if os.path.isdir(p) else ""
sym = subprocess.run(["git", "-C", p, "symbolic-ref", "-q", "HEAD"], capture_output=True).returncode if os.path.isdir(p) else 0
(ok if not br and head == sh("git", "-C", W.main, "rev-parse", "origin/main") and sym == 1 else miss)(
    "CREATE parks detached at origin/main and deletes the park branch" +
    ("" if not br and sym == 1 else ": branch=%r detached=%s" % (br, sym == 1)))
sh_ = [c for c in calls if c[:2] == ["worktree", "show"]]
(ok if sh_ == [["worktree", "show", "--worktree", "id:" + W.wid(p), "--json"]] else miss)(
    "CREATE show by full id" + ("" if len(sh_) == 1 else ": %r" % sh_))
expect("CREATE name taken in Orca", W.run(F(cli=CLI, action="create", lane="delta", base="main")), rc=1,
       first="ORCA lane: not created — Orca already lists a worktree named delta", verbs_lack=[["worktree", "create"]])
W.lane("eps", where="claude", register=False)
expect("CREATE name taken in git only", W.run(F(cli=CLI, action="create", lane="eps", base="main")), rc=1,
       first="ORCA lane: not created — git worktree list already has a worktree named eps",
       verbs_lack=[["worktree", "create"]])
pn = W.lane("plainbase")
W.load(); W.st["wts"][-1]["name"] = "shown"; W.save()
expect("CREATE name taken as a display name only", W.run(F(cli=CLI, action="create", lane="shown", base="main")), rc=1,
       first="ORCA lane: not created — Orca already lists a worktree named shown", verbs_lack=[["worktree", "create"]])
W.git("branch", "chore/zeta/park", "origin/main")
expect("CREATE park branch exists", W.run(F(cli=CLI, action="create", lane="zeta", base="main")), rc=1,
       first="ORCA lane: not created — branch chore/zeta/park already exists", verbs_lack=[["worktree", "create"]])
expect("CREATE create fails", W.run(F(cli=CLI, action="create", lane="eta", base="main"), mode="createfail"), rc=3,
       first="ORCA lane failed: worktree create failed (runtime_error)")
expect("CREATE suffixed path kept", W.run(F(cli=CLI, action="create", lane="theta", base="main"), mode="suffix"), rc=3,
       first="ORCA lane failed: Orca placed the lane at " + os.path.join(W.ws, "repo", "theta-2"),
       verbs_lack=[["worktree", "rm"]])
(ok if os.path.isdir(os.path.join(W.ws, "repo", "theta-2")) else miss)("CREATE suffixed path left on disk")
got = W.run(F(cli=CLI, action="create", lane="iota", base="main"), mode="branchsuffix")
expect("CREATE suffixed branch kept", got, rc=3, first="ORCA lane failed: the new lane is on branch 'chore/iota/park-2'")
(ok if sh("git", "-C", W.main, "branch", "--list", "chore/iota/park-2") else miss)("CREATE suffixed branch not deleted")
expect("CREATE name not fixed", W.run(F(cli=CLI, action="create", lane="kappa", base="main"), mode="automatic"), rc=3,
       first="ORCA lane failed: the new lane's display name is 'kappa' (automatic)")
got = W.run(F(cli=CLI, action="create", lane="lam", base="main"), mode="aheadcommit")
expect("CREATE park branch with a commit kept", got, rc=3, first="ORCA lane failed: chore/lam/park has 1 commit(s)")
(ok if sh("git", "-C", W.main, "branch", "--list", "chore/lam/park") else miss)("CREATE park branch with a commit not deleted")
expect("CREATE stale show", W.run(F(cli=CLI, action="create", lane="mu", base="main"), mode="showstale"), rc=3,
       first="ORCA lane failed: the lane is created and parked", has=("'mu automatic'",))
# Resume (#4): the shapes a create leaves when it stops in its park step.
pr1 = W.lane("res1", branch="chore/res1/park")
got = W.run(F(cli=CLI, action="create", lane="res1", base="main"))
expect("CREATE resumes a lane left on its park branch", got, rc=0, first="ORCA lane: resumed and created res1 at " + pr1,
       verbs_lack=[["worktree", "create"]])
(ok if not sh("git", "-C", W.main, "branch", "--list", "chore/res1/park")
 and subprocess.run(["git", "-C", pr1, "symbolic-ref", "-q", "HEAD"], capture_output=True).returncode == 1 else miss)(
    "CREATE resume parks detached and deletes the park branch")
pr2 = W.lane("res2")
W.git("branch", "chore/res2/park", "origin/main")
expect("CREATE resumes a lane detached at its park tip", W.run(F(cli=CLI, action="create", lane="res2", base="main")),
       rc=0, first="ORCA lane: resumed and created res2", verbs_lack=[["worktree", "create"]])
pr3 = W.lane("res3", branch="feat/res3/work")
W.git("branch", "chore/res3/park", "origin/main")
expect("CREATE does not resume a lane on another branch", W.run(F(cli=CLI, action="create", lane="res3", base="main")),
       rc=1, first="ORCA lane: not created — Orca already lists a worktree named res3",
       has=("it is neither on chore/res3/park nor detached at its tip",), verbs_lack=[["worktree", "create"]])
(ok if sh("git", "-C", W.main, "branch", "--list", "chore/res3/park") else miss)("CREATE refused resume deletes nothing")
# A stale local origin/main (#28): origin moved on, the stub's create fetched
# the new tip without updating the caller's remote-tracking ref.
up = os.path.join(W.d, "pusher")
sh("git", "clone", "-q", W.origin, up)
W.commit("moved on", cwd=up)
sh("git", "-C", up, "push", "-q", "origin", "HEAD:main")
expect("CREATE re-fetches a stale origin/base", W.run(F(cli=CLI, action="create", lane="nu1", base="main"), mode="freshbase"),
       rc=0, first="ORCA lane: created nu1")
W.done()

# ---- CREATE, L79: Orca keeps creating after its CLI gives up. The first read
# after the create sees no lane, so a single read would miss every one of these.
W = World("poll")


def lists(calls):
    return len([c for c in calls if c[:2] == ["worktree", "list"]]) - 1  # the first is step 1's


def creates(calls):
    return len([c for c in calls if c[:2] == ["worktree", "create"]])


def slept():
    return [l.strip() for l in open(W.sleeps)]


NORES = "ORCA lane: worktree create gave no result "
got = W.run(F(cli=CLI, action="create", lane="p1", base="main"), mode="createlate")
pp = os.path.join(W.ws, "repo", "p1")
expect("CREATE timeout then the lane shows", got, rc=0, first=NORES + "(runtime_timeout)",
       has=("ORCA lane: Orca's list shows p1 at " + pp, "ORCA lane: created p1 at " + pp, "named p1 (fixed)"))
(ok if creates(got[2]) == 1 and lists(got[2]) == 2 and slept() == ["10"] else miss)(
    "CREATE timeout makes one create and reads again: %d %d %r" % (creates(got[2]), lists(got[2]), slept()))
(ok if not sh("git", "-C", W.main, "branch", "--list", "chore/p1/park")
 and subprocess.run(["git", "-C", pp, "symbolic-ref", "-q", "HEAD"], capture_output=True).returncode == 1 else miss)(
    "CREATE timeout parks detached and deletes the park branch")
for tag, lane, m, why in (("no JSON", "p2", "createnojson", "(no JSON; the 180 s bound may have killed it)"),
                          ("a kill", "p3", "createkilled", "(no JSON; the 180 s bound may have killed it)"),
                          ("no error code", "p4", "createnocode", "(no error code)"),
                          ("a timeout at exit 0", "p5", "create0timeout", "(runtime_timeout)")):
    expect("CREATE %s is polled" % tag, W.run(F(cli=CLI, action="create", lane=lane, base="main"), mode=m), rc=0,
           first=NORES + why, has=("ORCA lane: created %s at" % lane,))
got = W.run(F(cli=CLI, action="create", lane="q1", base="main"), mode="createnever")
expect("CREATE no lane after the poll", got, rc=3, first=NORES + "(runtime_timeout)",
       has=("ORCA lane failed: worktree create gave no result (runtime_timeout), and Orca's list shows no lane q1",
            "(12 of 12 reads complete)", "a lane may still appear"), lacks=("run create", "run again", "create again"))
(ok if got[1][-1:] == ["Ending first line: Needed from you: do not start another create: re-check Orca's worktree list "
                       "for q1 in a few minutes; when it lists q1, ask this session to resume it; if it stays absent, "
                       "say how to proceed"] else miss)("CREATE no lane Ending line: %r" % got[1][-1:])
(ok if creates(got[2]) == 1 and lists(got[2]) == 12 and slept() == ["10"] * 11 else miss)(
    "CREATE poll is 12 reads, 10 s apart: %d %d %r" % (creates(got[2]), lists(got[2]), slept()))
got = W.run(F(cli=CLI, action="create", lane="q2", base="main"), mode="createnever", env={"STUB_DATE_STEP": "40"})
(ok if lists(got[2]) == 3 and "(3 of 3 reads complete)" in "\n".join(got[1]) else miss)(
    "CREATE poll stops at the 120 s clock: %d reads" % lists(got[2]))
expect("CREATE poll counts incomplete reads", W.run(F(cli=CLI, action="create", lane="q3", base="main"),
       mode="createnever,listfail23"), rc=3, has=("(10 of 12 reads complete)",))
got = W.run(F(cli=CLI, action="create", lane="q4", base="main"), mode="createdup")
expect("CREATE two rows after a timeout", got, rc=3, has=("Orca's list now shows 2 worktrees named q4; all are kept",),
       verbs_lack=[["worktree", "rm"]])
(ok if os.path.isdir(os.path.join(W.ws, "repo", "q4")) and os.path.isdir(os.path.join(W.ws, "repo", "q4-2")) else miss)(
    "CREATE two rows are left on disk")
got = W.run(F(cli=CLI, action="create", lane="q5", base="main"), mode="createunsettled")
expect("CREATE a row not settled is read again", got, rc=0, has=("ORCA lane: created q5 at",))
(ok if lists(got[2]) == 4 else miss)("CREATE reads until the row settles: %d" % lists(got[2]))
expect("CREATE a row that never settles goes to step 3", W.run(F(cli=CLI, action="create", lane="q6", base="main"),
       mode="createstuck"), rc=3, has=("ORCA lane failed: the new lane's display name is 'q6' (automatic)",))
got = W.run(F(cli=CLI, action="create", lane="q7", base="main"), mode="createfail")
expect("CREATE a definite error is not polled", got, rc=3, first="ORCA lane failed: worktree create failed (runtime_error)",
       has=("check Orca's worktree list for q7",))
(ok if lists(got[2]) == 0 and not slept() else miss)("CREATE a definite error reads no list: %d" % lists(got[2]))
# The lane shows only after the poll ended: the failure says to resume it.
expect("CREATE lane later than the poll", W.run(F(cli=CLI, action="create", lane="q8", base="main"), mode="createverylate"),
       rc=3, has=("a lane may still appear",))
W.load(); W.st["pending"]["at"] = 1; W.save()
got = W.run(F(cli=CLI, action="create", lane="q8", base="main"))
expect("CREATE resumes a lane that showed after the poll", got, rc=0, first="ORCA lane: resumed and created q8",
       verbs_lack=[["worktree", "create"]])
W.done()

# ---- NAME
W = World("name")
pa = W.lane("alpha", mode="automatic", where="claude")
W.lane("fixedone", mode="fixed")
W.lane("bad.name", mode="automatic", where="claude")
got = W.run(F(cli=CLI, action="name"))
rc_, out, calls = got
expect("NAME renames automatic non-main lanes only", got, rc=1, has=("ORCA lane: named alpha", "named 1 lane(s); 1 already fixed; 1 skipped",
       "skipped " + os.path.join(W.main, ".claude", "worktrees", "bad.name")))
(ok if out and out[-1].startswith("Ending first line: Needed from you: name the 1 skipped lane(s)") else miss)(
    "NAME a skip ends with an Ending line: %r" % out[-1:])
sets = [c for c in calls if c[:2] == ["worktree", "set"]]
want = [["worktree", "set", "--worktree", "id:" + W.wid(pa), "--display-name", "alpha", "--json"]]
(ok if sets == want else miss)("NAME set by full id only" + ("" if sets == want else ": %r" % sets))
expect("NAME second run is a no-op", W.run(F(cli=CLI, action="name")), rc=1, has=("named 0 lane(s); 2 already fixed; 1 skipped",),
       verbs_lack=[["worktree", "set"]])
W.lane("dup", mode="automatic")
W.lane("other", mode="fixed")
W.load(); W.st["wts"][-1]["name"] = "dup"; W.save()
expect("NAME skips a name another lane shows", W.run(F(cli=CLI, action="name")), rc=1,
       has=("another lane already shows the name dup",), lacks=("ORCA lane: named dup",))
W.lane("beta", mode="automatic")
expect("NAME set fails", W.run(F(cli=CLI, action="name"), mode="setfail"), rc=3, has=("ORCA lane failed: worktree set failed",))
expect("NAME set that does not stick", W.run(F(cli=CLI, action="name"), mode="setnoop"), rc=3,
       has=("ORCA lane failed: after worktree set, beta reads 'automatic beta'",))
expect("NAME re-list fails", W.run(F(cli=CLI, action="name"), mode="listfail2"), rc=3,
       has=("ORCA lane failed: renamed 1 lane(s), but the re-list was not complete",))
W.done()

# ---- RM
W = World("rm")
p = W.lane("nu")
os.makedirs(os.path.join(p, "node_modules"))
open(os.path.join(p, "node_modules", "x.js"), "w").write("x")
got = W.run(F(cli=CLI, action="rm", lane="nu"))
rc_, out, calls = got
expect("RM happy parked", got, rc=0, has=("ORCA lane: deleting ignored node_modules/",
       "ORCA lane: removed nu (" + p + ") — absent from Orca's list and git worktree list; 1 ignored path(s) deleted; it held no branch"))
rms = [c for c in calls if c[:2] == ["worktree", "rm"]]
want = [["worktree", "rm", "--worktree", "id:" + W.wid(p), "--run-hooks", "--json"]]
(ok if rms == want else miss)("RM exact rm argv (no --force, no waiver)" + ("" if rms == want else ": %r" % rms))
(ok if not os.path.exists(p) and p not in W.git("worktree", "list") else miss)("RM lane gone from git")
p = W.lane("xi", branch="feat/xi/work")
expect("RM lane on a pushed branch", W.run(F(cli=CLI, action="rm", lane="xi")), rc=0,
       has=("Orca deleted branch feat/xi/work",))
p = W.lane("omicron", branch="feat/omicron/work")
expect("RM branch Orca keeps", W.run(F(cli=CLI, action="rm", lane="omicron"), mode="keepbranch"), rc=0,
       has=("Orca kept branch feat/omicron/work",))
# One lane per case, so a mutant that lets one removal through cannot change
# what a later case sees.
p = W.lane("pi1")
open(os.path.join(p, "new.txt"), "w").write("x")
expect("RM untracked file", W.run(F(cli=CLI, action="rm", lane="pi1")), rc=1, first="ORCA lane: kept pi1 — it has changes (?? new.txt)",
       verbs_lack=[["worktree", "rm"]])
p = W.lane("pi2")
open(os.path.join(p, "f.txt"), "w").write("changed\n")
expect("RM tracked change", W.run(F(cli=CLI, action="rm", lane="pi2")), rc=1, first="ORCA lane: kept pi2 — it has changes ( M f.txt)",
       verbs_lack=[["worktree", "rm"]])
p = W.lane("pi3")
W.commit("local", cwd=p)
expect("RM HEAD on no origin ref", W.run(F(cli=CLI, action="rm", lane="pi3")), rc=1, first="ORCA lane: kept pi3 — HEAD",
       has=("is on no origin ref",), verbs_lack=[["worktree", "rm"]])
p = W.lane("pi4")
W.commit("local", cwd=p)
W.git("checkout", "-q", "--detach", "origin/main", cwd=p)
expect("RM reflog-only commit", W.run(F(cli=CLI, action="rm", lane="pi4")), rc=1,
       first="ORCA lane: kept pi4 — HEAD reflog holds a commit that is on no origin ref and not landed",
       has=("held by no branch",), verbs_lack=[["worktree", "rm"]])
p = W.lane("rho1")
expect("RM live agent", W.run(F(cli=CLI, action="rm", lane="rho1"), env={"STUB_AGENT_ON": "rho1"}), rc=1,
       first="ORCA lane: kept rho1 — 1 agent(s) on it", verbs_lack=[["worktree", "rm"]])
p = W.lane("rho2")
expect("RM archive hook fails", W.run(F(cli=CLI, action="rm", lane="rho2"), mode="hookfail"), rc=3,
       first="ORCA lane failed: the archive hook failed (exit 1; its output is not relayed", lacks=("Command failed",))
(ok if os.path.isdir(p) else miss)("RM archive hook failure keeps the lane")
W.lane("rho3")
expect("RM reply says removed but lane stays", W.run(F(cli=CLI, action="rm", lane="rho3"), mode="rmnoop"), rc=3,
       first="ORCA lane failed: removal not proved — rho3 is still in Orca's list")
W.lane("rho4")
expect("RM re-list fails after rm", W.run(F(cli=CLI, action="rm", lane="rho4"), mode="listfail2"), rc=3,
       first="ORCA lane failed: removal not proved — the re-list")
W.lane("rho5")
expect("RM Orca drops the row but git keeps the worktree", W.run(F(cli=CLI, action="rm", lane="rho5"), mode="gitkeeps"), rc=3,
       first="ORCA lane failed: removal not proved — " + os.path.join(W.ws, "repo", "rho5") + " is still in git worktree list")
alien = os.path.join(W.ws, "repo", "alien")
sh("git", "init", "-q", alien)
W.load(); W.st["wts"].append({"repoId": RID, "path": alien, "name": "alien", "mode": "fixed", "main": False}); W.save()
expect("RM row not in git worktree list", W.run(F(cli=CLI, action="rm", lane="alien")), rc=1,
       first="ORCA lane: kept alien — " + alien + " is not in this repo's git worktree list", verbs_lack=[["worktree", "rm"]])
W.lane("phi")
W.load(); W.st["wts"][-1]["name"] = "other"; W.save()
expect("RM fixed sidebar name differs", W.run(F(cli=CLI, action="rm", lane="phi")), rc=1,
       first="ORCA lane: kept phi — the sidebar shows it as 'other'", verbs_lack=[["worktree", "rm"]])
W.lane("chi")
W.lane("chi-2")
W.load(); W.st["wts"][-1]["name"] = "chi"; W.save()
expect("RM another lane shows the name", W.run(F(cli=CLI, action="rm", lane="chi")), rc=1,
       first="ORCA lane: kept chi — another lane (" + os.path.join(W.ws, "repo", "chi-2") + ") also shows the name chi",
       verbs_lack=[["worktree", "rm"]])
p = W.lane("psi", branch="feat/psi/work")
W.git("push", "-q", "origin", "feat/psi/work")
W.commit("pushed then deleted", cwd=p)
W.git("push", "-q", "origin", "feat/psi/work", cwd=p)
W.git("fetch", "-q", "origin")
sh("git", "--git-dir", W.origin, "branch", "-q", "-D", "feat/psi/work")
expect("RM stale origin ref does not vouch", W.run(F(cli=CLI, action="rm", lane="psi")), rc=1,
       first="ORCA lane: kept psi — HEAD", has=("is on no origin ref",), verbs_lack=[["worktree", "rm"]])
W.lane("sigma")
W.lane("sigma", where="claude")
expect("RM two lanes with one basename", W.run(F(cli=CLI, action="rm", lane="sigma")), rc=1,
       first="ORCA lane: kept sigma — 2 lanes", verbs_lack=[["worktree", "rm"]])
expect("RM unknown lane", W.run(F(cli=CLI, action="rm", lane="tau")), rc=1, first="ORCA lane: kept tau — no lane")
W.done()

# ---- RM, reused lanes (L58 #1): a squash merge puts a NEW commit on origin;
# the branch's own commits stay only in the lane's HEAD reflog.
W = World("reuse")


def squashed(name, n=1, unpushed=0, detour=False, base="main"):
    """A lane that worked on feat/<name>/work, pushed it, saw it squash-merged
    as one new commit on origin/main, deleted the branch and parked. Returns
    the lane, the branch, and the pushed head (the PR's headRefOid).
    unpushed: commits made after the push and never pushed. detour: a
    `checkout HEAD~1` and back, which the reflog logs as typed."""
    p = W.lane(name)
    b = "feat/%s/work" % name
    W.git("checkout", "-q", "--detach", "origin/" + base, cwd=p)
    W.git("checkout", "-q", "-b", b, cwd=p)
    for i in range(n):
        open(os.path.join(p, "%s%d.txt" % (name, i)), "w").write("x\n")
        W.git("add", ".", cwd=p)
        W.commit("work %d" % i, cwd=p)
    if detour:
        W.git("checkout", "-q", "HEAD~1", cwd=p)
        W.git("checkout", "-q", b, cwd=p)
    W.git("push", "-q", "origin", b, cwd=p)
    head = W.git("rev-parse", "HEAD", cwd=p)
    for i in range(unpushed):
        open(os.path.join(p, "%s-late%d.txt" % (name, i)), "w").write("late\n")
        W.git("add", ".", cwd=p)
        W.commit("late %d" % i, cwd=p)
    W.git("checkout", "-q", base)
    W.git("pull", "-q", "origin", base)
    W.git("merge", "-q", "--squash", "origin/" + b)
    W.commit("squash " + b)
    W.git("push", "-q", "origin", base)
    W.git("push", "-q", "origin", "--delete", b)
    W.git("fetch", "-q", "--prune", "origin")
    W.git("checkout", "-q", "--detach", "origin/" + base, cwd=p)
    W.git("branch", "-q", "-D", b)
    return p, b, head


def gh(prs=None, fail=False, default="main"):
    json.dump({"prs": prs or {}, "default": default, "fail": fail}, open(W.gh, "w"))


KEPT = "HEAD reflog holds a commit that is on no origin ref and not landed"
p, b, h = squashed("up1", 2)
gh({b: [[7, "MERGED", "main", h, False]]})
expect("RM reused lane after a squash merge", W.run(F(cli=CLI, action="rm", lane="up1")), rc=0,
       first="ORCA lane: removed up1", has=("reflog landed: 2 reflog commit(s) origin lacks — 2 in a merged PR's head",))
# The PR #123 review's P1: a commit made after the push, before the merge.
p, b, h = squashed("up2", 2, unpushed=1)
gh({b: [[8, "MERGED", "main", h, False]]})
expect("RM unpushed commit the PR head lacks", W.run(F(cli=CLI, action="rm", lane="up2")), rc=1,
       first="ORCA lane: kept up2 — " + KEPT, has=("no merged PR of " + b + " has it in its head",),
       verbs_lack=[["worktree", "rm"]])
# Two commits each from here, so a squash's patch equals no single commit:
# only the PR-head rule can land them (a one-commit squash IS an equal patch).
p, b, h = squashed("up3", 2)
gh({b: [[9, "CLOSED", "main", h, False], [10, "OPEN", "main", h, False]]})
expect("RM branch with no merged PR", W.run(F(cli=CLI, action="rm", lane="up3")), rc=1,
       first="ORCA lane: kept up3 — " + KEPT, has=("no merged PR of " + b + " has it in its head",),
       verbs_lack=[["worktree", "rm"]])
p, b, h = squashed("up4", 2)
gh(fail=True)
# Without origin/HEAD the default branch comes from gh too (the cases above
# read it there): set origin/HEAD, so the PR read is the call that fails.
W.git("remote", "set-head", "origin", "main")
expect("RM gh fails", W.run(F(cli=CLI, action="rm", lane="up4")), rc=1,
       first="ORCA lane: kept up4 — HEAD reflog holds a commit no origin ref has, and whether it landed is unknown",
       has=("gh pr list failed",), verbs_lack=[["worktree", "rm"]])
W.git("remote", "set-head", "origin", "-d")
p, b, h = squashed("up6", 2)
gh({b: [[11, "MERGED", "feat/base/x", h, False]]})
expect("RM PR into another base", W.run(F(cli=CLI, action="rm", lane="up6")), rc=1,
       first="ORCA lane: kept up6 — " + KEPT, verbs_lack=[["worktree", "rm"]])
p, b, h = squashed("up7", 2)
gh({b: [[12, "MERGED", "main", h, True]]})
expect("RM fork PR", W.run(F(cli=CLI, action="rm", lane="up7")), rc=1,
       first="ORCA lane: kept up7 — " + KEPT, verbs_lack=[["worktree", "rm"]])
p, b, h = squashed("up8", 2, detour=True)
gh({b: [[13, "MERGED", "main", h, False]]})
expect("RM checkout HEAD~1 in the reflog", W.run(F(cli=CLI, action="rm", lane="up8")), rc=0,
       first="ORCA lane: removed up8")
# An amend: the pre-amend commit is in no head, its replacement is.
p = W.lane("up9")
b = "feat/up9/work"
W.git("checkout", "-q", "-b", b, cwd=p)
for i in range(2):
    open(os.path.join(p, "up9-%d.txt" % i), "w").write("x\n")
    W.git("add", ".", cwd=p)
    W.commit("work %d" % i, cwd=p)
open(os.path.join(p, "up9-1.txt"), "w").write("amended\n")
W.git("add", ".", cwd=p)
W.git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--amend", "-m", "work 1 amended", cwd=p)
W.git("push", "-q", "origin", b, cwd=p)
h = W.git("rev-parse", "HEAD", cwd=p)
W.git("checkout", "-q", "main")
W.git("pull", "-q", "origin", "main")
W.git("merge", "-q", "--squash", "origin/" + b)
W.commit("squash " + b)
W.git("push", "-q", "origin", "main")
W.git("push", "-q", "origin", "--delete", b)
W.git("fetch", "-q", "--prune", "origin")
W.git("checkout", "-q", "--detach", "origin/main", cwd=p)
W.git("branch", "-q", "-D", b)
gh({b: [[14, "MERGED", "main", h, False]]})
expect("RM amended-away commit", W.run(F(cli=CLI, action="rm", lane="up9")), rc=0,
       first="ORCA lane: removed up9", has=("1 replaced by a landed amend",))
# A commit made detached, then landed on main as a rebased copy (equal patch).
p = W.lane("up5")
open(os.path.join(p, "up5.txt"), "w").write("x\n")
W.git("add", ".", cwd=p)
W.commit("detached work", cwd=p)
c = W.git("rev-parse", "HEAD", cwd=p)
W.git("checkout", "-q", "main")
W.git("pull", "-q", "origin", "main")
W.commit("main moved on")  # so the copy gets a new parent, hence a new SHA
W.git("-c", "user.name=t", "-c", "user.email=t@t", "cherry-pick", c)
W.git("push", "-q", "origin", "main")
W.git("fetch", "-q", "origin")
W.git("checkout", "-q", "--detach", "origin/main", cwd=p)
gh()
expect("RM detached commit landed as an equal patch", W.run(F(cli=CLI, action="rm", lane="up5")), rc=0,
       first="ORCA lane: removed up5", has=("1 by an equal patch on origin/main",))
# A merge commit whose parent's patch landed: git cherry never lists the merge
# itself, so its own content must keep the lane (PR #123 review).
p = W.lane("upm")
W.git("checkout", "-q", "-b", "side", "origin/main")
open(os.path.join(W.main, "side.txt"), "w").write("s\n")
W.git("add", ".")
W.commit("side work")
W.git("push", "-q", "origin", "side")
s = W.git("rev-parse", "HEAD")
W.git("checkout", "-q", "main")
W.git("fetch", "-q", "origin")
W.git("-c", "user.name=t", "-c", "user.email=t@t", "merge", "-q", "--no-ff", "--no-commit", "origin/side", cwd=p)
open(os.path.join(p, "evil.txt"), "w").write("only here\n")
W.git("add", ".", cwd=p)
W.commit("merge side, plus more", cwd=p)
W.git("pull", "-q", "origin", "main")
W.commit("main moved on again")
W.git("-c", "user.name=t", "-c", "user.email=t@t", "cherry-pick", s)
W.git("push", "-q", "origin", "main")
W.git("push", "-q", "origin", "--delete", "side")
W.git("branch", "-q", "-D", "side")
W.git("fetch", "-q", "--prune", "origin")
W.git("checkout", "-q", "--detach", "origin/main", cwd=p)
gh()
expect("RM merge commit whose parent landed", W.run(F(cli=CLI, action="rm", lane="upm")), rc=1,
       first="ORCA lane: kept upm — " + KEPT, verbs_lack=[["worktree", "rm"]])
# A helper that exits 0 but prints no `landed:` line (truncated or stubbed).
p, b, h = squashed("upz", 2)
gh({b: [[15, "MERGED", "main", h, False]]})
stubd = os.path.join(W.d, "stubhelper")
os.makedirs(stubd)
shutil.copy(SCRIPT, os.path.join(stubd, "orca-lane.sh"))
open(os.path.join(stubd, "orca-lane-reflog.sh"), "w").write("exit 0\n")
expect("RM helper exits 0 without a landed line", W.run(F(cli=CLI, action="rm", lane="upz"),
       script=os.path.join(stubd, "orca-lane.sh")), rc=1,
       first="ORCA lane: kept upz — HEAD reflog holds a commit no origin ref has, and whether it landed is unknown",
       verbs_lack=[["worktree", "rm"]])
W.done()

# ---- RM, the main checkout's orca.yaml (#16): Orca reads the archive hook
# from its working tree.
W = World("yaml")
# One lane per case, so a mutant that lets one removal through cannot change
# what a later case sees.
for y in ("y1", "y2", "y3", "y4"):
    W.lane(y)
open(os.path.join(W.main, "orca.yaml"), "w").write("archive: echo hi\n")
expect("RM main orca.yaml uncommitted", W.run(F(cli=CLI, action="rm", lane="y1")), rc=1,
       first="ORCA lane: kept y1 — the main checkout's orca.yaml is not committed as it is (?? orca.yaml)",
       verbs_lack=[["worktree", "rm"]])
W.git("add", "orca.yaml")
W.commit("hook")
expect("RM main orca.yaml unpushed", W.run(F(cli=CLI, action="rm", lane="y2")), rc=1,
       first="ORCA lane: kept y2 — the main checkout's orca.yaml is not the one origin/main holds",
       verbs_lack=[["worktree", "rm"]])
W.git("push", "-q", "origin", "main")
W.git("fetch", "-q", "origin")
W.git("update-index", "--skip-worktree", "orca.yaml")
open(os.path.join(W.main, "orca.yaml"), "w").write("archive: rm -rf /\n")
expect("RM main orca.yaml edited under skip-worktree", W.run(F(cli=CLI, action="rm", lane="y3")), rc=1,
       first="ORCA lane: kept y3 — the main checkout's orca.yaml is not the one origin/main holds",
       verbs_lack=[["worktree", "rm"]])
W.git("update-index", "--no-skip-worktree", "orca.yaml")
W.git("checkout", "--", "orca.yaml")
expect("RM main orca.yaml pushed", W.run(F(cli=CLI, action="rm", lane="y4")), rc=0, first="ORCA lane: removed y4")
W.done()

# ---- RM, the resolved trunk (L77 items 1 and 5): a repo whose work lands on
# dev while origin's default is main. cepa.local.md is the main checkout's.
W = World("trunk")
W.git("push", "-q", "origin", "main:dev")
W.git("fetch", "-q", "origin")
W.git("checkout", "-q", "-b", "dev", "origin/dev")


def override(text):
    open(os.path.join(W.main, "cepa.local.md"), "w").write(text)


TRUNK = "# cepa\n\n## Conventions\n\n- trunk: dev\n\n## Other\n\ntrunk: nosuch\n"
# One lane per case, so a mutant that lets one removal through cannot change
# what a later case sees.
p, b, h = squashed("t0", 2, base="dev")
gh({b: [[19, "MERGED", "dev", h, False]]})
expect("RM PR into dev with no override keeps the lane", W.run(F(cli=CLI, action="rm", lane="t0")), rc=1,
       first="ORCA lane: kept t0 — " + KEPT, verbs_lack=[["worktree", "rm"]])
override(TRUNK)
p, b, h = squashed("t1", 2, base="dev")
gh({b: [[20, "MERGED", "dev", h, False]]})
expect("RM PR into the trunk lands", W.run(F(cli=CLI, action="rm", lane="t1")), rc=0, first="ORCA lane: removed t1",
       has=("2 in a merged PR's head",))
p, b, h = squashed("t2", 2, base="dev")
gh({b: [[21, "MERGED", "main", h, False]]})
expect("RM PR into the default still lands with a trunk set", W.run(F(cli=CLI, action="rm", lane="t2")), rc=0,
       first="ORCA lane: removed t2")
p, b, h = squashed("t3", 2, base="dev")
gh({b: [[22, "MERGED", "feat/base/x", h, False]]})
expect("RM PR into neither trunk nor default", W.run(F(cli=CLI, action="rm", lane="t3")), rc=1,
       first="ORCA lane: kept t3 — " + KEPT, verbs_lack=[["worktree", "rm"]])
p, b, h = squashed("t4", 2, base="dev")
gh({b: [[23, "MERGED", "dev", h, False]]}, default="")
expect("RM a trunk with no default read lands", W.run(F(cli=CLI, action="rm", lane="t4")), rc=0, first="ORCA lane: removed t4")
# A detached commit cherry-picked onto dev: only the equal-patch rule lands it.
p = W.lane("t5")
open(os.path.join(p, "t5.txt"), "w").write("x\n")
W.git("add", ".", cwd=p)
W.commit("detached work", cwd=p)
c = W.git("rev-parse", "HEAD", cwd=p)
W.git("pull", "-q", "origin", "dev")
W.commit("dev moved on")
W.git("-c", "user.name=t", "-c", "user.email=t@t", "cherry-pick", c)
W.git("push", "-q", "origin", "dev")
W.git("fetch", "-q", "origin")
W.git("checkout", "-q", "--detach", "origin/dev", cwd=p)
gh()
expect("RM equal patch on the trunk lands", W.run(F(cli=CLI, action="rm", lane="t5")), rc=0,
       first="ORCA lane: removed t5", has=("1 by an equal patch on origin/dev or origin/main",))
p, b, h = squashed("t6", 2, base="dev")
gh({b: [[24, "MERGED", "dev", h, False]]})
override("## Conventions\ntrunk: gone\n")
expect("RM a trunk origin lacks is unknown", W.run(F(cli=CLI, action="rm", lane="t6")), rc=1,
       first="ORCA lane: kept t6 — HEAD reflog holds a commit no origin ref has, and whether it landed is unknown",
       has=("origin has no trunk branch gone",), verbs_lack=[["worktree", "rm"]])
# orca.yaml: on dev only, with the main checkout on dev (artist360's shape).
open(os.path.join(W.main, "orca.yaml"), "w").write("scripts:\n  archive: echo bye\n")
W.git("add", "orca.yaml")
W.commit("orca.yaml on dev")
W.git("push", "-q", "origin", "dev")
W.git("fetch", "-q", "origin")
YK = "the main checkout's orca.yaml is not the one origin/main holds"
TU = "the trunk is unknown"
for tag, lane, text, rc_, first in (
        ("no override compares the default", "y1", "", 1, "ORCA lane: kept y1 — " + YK),
        ("override compares the trunk", "y2", TRUNK, 0, "ORCA lane: removed y2"),
        ("override with origin/ and backticks", "y3", "## Conventions\n* `trunk`: `origin/dev`\n", 0, "ORCA lane: removed y3"),
        ("override outside Conventions is not read", "y4", "## Other\ntrunk: dev\n", 1, "ORCA lane: kept y4 — " + YK),
        ("malformed override is unknown", "y5", "## Conventions\ntrunk: a b\n", 1,
         "ORCA lane: kept y5 — " + TU + " (cepa.local.md's trunk: is not a branch name)"),
        ("doubled override is unknown", "y6", "## Conventions\ntrunk: dev\ntrunk: main\n", 1,
         "ORCA lane: kept y6 — " + TU + " (cepa.local.md gives trunk: 2 times)")):
    W.lane(lane)
    override(text)
    expect("RM orca.yaml %s" % tag, W.run(F(cli=CLI, action="rm", lane=lane)), rc=rc_, first=first)
W.done()

# ---- RM, Ending lines (L77 items 2, 3, 4, 6). Every remedy a line names is
# run, so a line that cannot work goes red.
W = World("end")
W.commit("second")
W.git("push", "-q", "origin", "main")
W.git("fetch", "-q", "origin")


def move_origin():
    W.commit("origin moved on")
    W.git("push", "-q", "origin", "main")
    W.git("fetch", "-q", "origin")


def expire(p):
    W.git("reflog", "expire", "--expire=now", "--expire-unreachable=now", "HEAD", cwd=p)


def remedy(out):
    m = re.search(r"\((git -C .*?)\)", out[-1]) if out else None
    for cmd in (m.group(1).split(", then ") if m else []):
        subprocess.run(cmd.split(), capture_output=True, text=True, check=True)
    return bool(m)


p = W.lane("e1")
expire(p)
got = W.run(F(cli=CLI, action="rm", lane="e1"))
expect("RM empty reflog at the tip", got, rc=1, first="ORCA lane: kept e1 — HEAD reflog is empty",
       has=("re-park e1 at origin/main to write a landed entry", "checkout --detach origin/main~1, then git -C "),
       verbs_lack=[["worktree", "rm"]])
remedy(got[1])
expect("RM the at-tip remedy clears an empty reflog", W.run(F(cli=CLI, action="rm", lane="e1")), rc=0, first="ORCA lane: removed e1")
p = W.lane("e2")
move_origin()
expire(p)
got = W.run(F(cli=CLI, action="rm", lane="e2"))
expect("RM empty reflog behind the tip", got, rc=1, first="ORCA lane: kept e2 — HEAD reflog is empty",
       has=("re-park e2 at origin/main",), lacks=("~1",), verbs_lack=[["worktree", "rm"]])
remedy(got[1])
expect("RM the behind-tip remedy clears an empty reflog", W.run(F(cli=CLI, action="rm", lane="e2")), rc=0, first="ORCA lane: removed e2")
TERM = {"handle": "term_aaa", "tabId": "a", "leafId": "b", "orphaned": False}
TERM2 = {"handle": "term_bbb", "tabId": "x", "leafId": "y", "orphaned": True}
PLAIN = "term_ccc"


def terms(lane, rows):
    W.load(); W.st.setdefault("terms", {})[lane] = rows; W.save()


AG = "ORCA lane: kept %s — 1 agent(s) on it in worktree ps"
W.lane("a1")
terms("a1", [TERM, {"handle": PLAIN, "tabId": "c", "leafId": "d", "orphaned": False}])
got = W.run(F(cli=CLI, action="rm", lane="a1"), env={"STUB_AGENT_ON": "a1"})
expect("RM done agent names its terminal", got, rc=1, first=AG % "a1",
       has=("orca-ide terminal close --terminal <handle>: term_aaa; then ask again",), lacks=(PLAIN,),
       verbs_lack=[["worktree", "rm"]])
tl = [c for c in got[2] if c[:2] == ["terminal", "list"]]
(ok if tl == [["terminal", "list", "--worktree", "id:" + W.wid(os.path.join(W.ws, "repo", "a1")), "--limit", "500", "--json"]] else miss)(
    "RM terminal list by full id, no --full: %r" % tl)
W.lane("a2")
terms("a2", [TERM])
expect("RM live agent keeps the plain advice", W.run(F(cli=CLI, action="rm", lane="a2"),
       env={"STUB_AGENT_ON": "a2", "STUB_AGENT_STATE": "working"}), rc=1, first=AG % "a2",
       has=("close the agent in a2, then ask again",), lacks=("term_aaa",), verbs_lack=[["worktree", "rm"]])
W.lane("a3")
expect("RM done agent with no terminal", W.run(F(cli=CLI, action="rm", lane="a3"), env={"STUB_AGENT_ON": "a3"}), rc=1,
       first=AG % "a3", has=("clear the finished agent row(s) of a3 in Orca",), verbs_lack=[["worktree", "rm"]])
W.lane("a4")
terms("a4", [TERM, TERM2])
expect("RM orphaned terminal is named", W.run(F(cli=CLI, action="rm", lane="a4"), env={"STUB_AGENT_ON": "a4"}), rc=1,
       first=AG % "a4", has=("<handle>: term_aaa term_bbb; then ask again",), verbs_lack=[["worktree", "rm"]])
W.lane("a5")
terms("a5", [TERM])
expect("RM done agents, one with no terminal", W.run(F(cli=CLI, action="rm", lane="a5"),
       env={"STUB_AGENT_ON": "a5", "STUB_AGENT_PANES": "a:b,z:z"}), rc=1, first="ORCA lane: kept a5 — 2 agent(s)",
       has=("term_aaa; also clear 1 agent row(s) with no terminal in Orca; then ask again",), verbs_lack=[["worktree", "rm"]])
W.lane("a6")
terms("a6", [TERM])
expect("RM terminal read fails", W.run(F(cli=CLI, action="rm", lane="a6"), mode="termfail", env={"STUB_AGENT_ON": "a6"}), rc=1,
       first=AG % "a6", has=("close the agent in a6, then ask again",), verbs_lack=[["worktree", "rm"]])
p = W.lane("d1")
got = W.run(F(cli=CLI, action="rm", lane="d1"), mode="rmpartial")
expect("RM partial removal is Orca's", got, rc=3,
       first="ORCA lane failed: worktree rm failed (runtime_error), and Orca's partial removal deleted 1 tracked path(s) in d1 (f.txt",
       has=("these are not operator changes", "restore them (git -C " + p + " restore .), then ask again"))
got = W.run(F(cli=CLI, action="rm", lane="d1"))
expect("RM retry after a partial removal", got, rc=1,
       first="ORCA lane: kept d1 — it has changes ( D f.txt), all of them deleted tracked files; after a failed rm, that is Orca's partial removal",
       has=("restore the files (git -C " + p + " restore .), then ask again",), verbs_lack=[["worktree", "rm"]])
remedy(got[1])
expect("RM the partial-removal remedy clears the lane", W.run(F(cli=CLI, action="rm", lane="d1")), rc=0, first="ORCA lane: removed d1")
W.lane("d2")
expect("RM a failure with no deletion stays plain", W.run(F(cli=CLI, action="rm", lane="d2"), mode="rmerror"), rc=3,
       first="ORCA lane failed: worktree rm failed (runtime_error); d2 may be kept", lacks=("partial removal",))
p = W.lane("d3")
os.remove(os.path.join(p, "f.txt"))
open(os.path.join(p, "new.txt"), "w").write("x")
expect("RM a mixed change is not called a partial removal", W.run(F(cli=CLI, action="rm", lane="d3")), rc=1,
       first="ORCA lane: kept d3 — it has changes", lacks=("partial removal",), verbs_lack=[["worktree", "rm"]])
HK = "ORCA lane failed: the archive hook failed (exit "
p = W.lane("h1")
move_origin()
got = W.run(F(cli=CLI, action="rm", lane="h1"), mode="hookfail2")
expect("RM hook exit 2 behind the tip names the re-park", got, rc=3, first=HK + "2;",
       has=("re-park the clean lane (git -C " + p + " checkout --detach origin/main), then ask again",))
remedy(got[1])
expect("RM the re-park lets rm pass", W.run(F(cli=CLI, action="rm", lane="h1")), rc=0, first="ORCA lane: removed h1")
W.lane("h2")
expect("RM hook exit 2 at the tip stays plain", W.run(F(cli=CLI, action="rm", lane="h2"), mode="hookfail2"), rc=3,
       first=HK + "2;", has=("fix the repo's archive hook",), lacks=("re-park",))
W.lane("h3")
move_origin()
expect("RM hook exit 1 behind the tip stays plain", W.run(F(cli=CLI, action="rm", lane="h3"), mode="hookfail"), rc=3,
       first=HK + "1;", lacks=("re-park",))
W.done()

# ---- HOOKS (L76): Orca's saved hook settings can shadow orca.yaml. The
# stub serves each hookSettings shape; orca.yaml is pushed to origin/main.
W = World("hooks")
open(os.path.join(W.main, "orca.yaml"), "w").write(
    "# lane config\nscripts:\n  setup: make init  # builds\n  archive: 'make clean'\nsetupAgentStartupPolicy: wait-for-setup\n")
W.git("add", "orca.yaml")
W.commit("orca.yaml")
W.git("push", "-q", "origin", "main")
W.git("fetch", "-q", "origin")


def hook(h):
    W.load()
    W.st["repos"][0]["hook"] = h
    W.save()


def hs(policy=None, setup="", archive="", start="start-immediately"):
    h = {"mode": "auto", "setupRunPolicy": "run-by-default", "setupAgentStartupPolicy": start,
         "scripts": {"setup": setup, "archive": archive}}
    if policy is not None:
        h["commandSourcePolicy"] = policy
    return h


SH = "ORCA lane: not created — Orca's saved hook settings shadow orca.yaml: "
UNK = "ORCA lane: not created — Orca's saved hook settings for this repo, or orca.yaml's scripts.setup, have a shape"
NOCREATE = [["worktree", "create"]]
hook(hs())
expect("HOOKS unset creates", W.run(F(cli=CLI, action="create", lane="h1", base="main")), rc=0,
       first="ORCA lane: created h1")
hook(hs(policy="shared-only", setup="npm install"))
expect("HOOKS shared-only with a local script creates", W.run(F(cli=CLI, action="create", lane="h2", base="main")),
       rc=0, first="ORCA lane: created h2")
hook(hs("local-only", setup="  make init\n"))
expect("HOOKS local-only matching creates", W.run(F(cli=CLI, action="create", lane="h3", base="main")), rc=0,
       first="ORCA lane: created h3")
hook(hs("local-only", setup="npm install"))
got = W.run(F(cli=CLI, action="create", lane="h4", base="main"))
expect("HOOKS local-only differing refuses", got, rc=1,
       first=SH + "commandSourcePolicy local-only runs the local setup script (differs), not the orca.yaml one (present)",
       has=("Needed from you: in Orca, open Settings",), verbs_lack=NOCREATE)
hook(hs("local-only", setup=""))
expect("HOOKS local-only empty refuses", W.run(F(cli=CLI, action="create", lane="h5", base="main")), rc=1,
       first=SH + "commandSourcePolicy local-only runs the local setup script (empty)", verbs_lack=NOCREATE)
hook(hs(None, setup="npm install"))
expect("HOOKS unset with a local script refuses", W.run(F(cli=CLI, action="create", lane="h6", base="main")), rc=1,
       first=SH + "commandSourcePolicy unset (Orca reads it as local-only", verbs_lack=NOCREATE)
hook(hs("run-both", setup="npm install"))
expect("HOOKS run-both with a local script refuses", W.run(F(cli=CLI, action="create", lane="h7", base="main")), rc=1,
       first=SH + "commandSourcePolicy run-both runs the local setup script as well", verbs_lack=NOCREATE)
hook(hs("run-both"))
expect("HOOKS run-both with no local script creates", W.run(F(cli=CLI, action="create", lane="h8", base="main")),
       rc=0, first="ORCA lane: created h8")
# One lane per case, so a mutant that lets one create through cannot change
# what a later case sees.
for tag, lane, h in (("unknown policy", "u1", hs("local-first")), ("no scripts map", "u2", {"mode": "auto"}),
                     ("hookSettings missing", "u3", None), ("non-string script", "u4", hs(setup=["npm"]))):
    hook(h)
    expect("HOOKS %s refuses" % tag, W.run(F(cli=CLI, action="create", lane=lane, base="main")), rc=1, first=UNK,
           verbs_lack=NOCREATE)
# orca.yaml shapes: a block scalar is unknown under local-only; a quoted
# scalar is read; with no orca.yaml, an empty local-only setup matches.
for tag, lane, text, want_rc, first in (
        ("block scalar", "hb", "scripts:\n  setup: |\n    make init\n", 1, UNK),
        ("flow value", "hf", "scripts:\n  setup: [make init]\n", 1, UNK),
        ("quoted match", "hq", "scripts:\n  setup: \"make init\"\n", 0, "ORCA lane: created hq"),
        ("duplicate key", "hd", "scripts:\n  setup: make init\n  setup: make init\n", 1, UNK)):
    open(os.path.join(W.main, "orca.yaml"), "w").write(text)
    W.git("add", "orca.yaml")
    W.commit(tag)
    W.git("push", "-q", "origin", "main")
    hook(hs("local-only", setup="make init"))
    expect("HOOKS orca.yaml %s" % tag, W.run(F(cli=CLI, action="create", lane=lane, base="main")), rc=want_rc,
           first=first)
W.git("rm", "-q", "orca.yaml")
W.commit("no orca.yaml")
W.git("push", "-q", "origin", "main")
hook(hs("local-only"))
expect("HOOKS no orca.yaml and empty local-only creates", W.run(F(cli=CLI, action="create", lane="hn", base="main")),
       rc=0, first="ORCA lane: created hn")
# rm: Orca reads scripts.archive from the main checkout's orca.yaml.
open(os.path.join(W.main, "orca.yaml"), "w").write("scripts:\n  archive: make clean\n")
W.git("add", "orca.yaml")
W.commit("archive")
W.git("push", "-q", "origin", "main")
W.git("fetch", "-q", "origin")
NORM = [["worktree", "rm"]]
for tag, lane, h, first in (
        ("local-only empty archive refuses", "r1", hs("local-only"),
         "Orca's saved hook settings shadow orca.yaml: commandSourcePolicy local-only runs the local archive script (empty)"),
        ("unset with a local archive refuses", "r2", hs(None, archive="echo bye"),
         "Orca's saved hook settings shadow orca.yaml: commandSourcePolicy unset"),
        ("unknown shape refuses", "r3", hs("sometimes"),
         "Orca's saved hook settings for this repo, or orca.yaml's scripts.archive")):
    W.lane(lane)
    hook(h)
    expect("HOOKS rm %s" % tag, W.run(F(cli=CLI, action="rm", lane=lane)), rc=1,
           first="ORCA lane: kept %s — %s" % (lane, first), verbs_lack=NORM)
W.lane("r4")
hook(hs("local-only", archive="make clean"))
expect("HOOKS rm local-only matching archive removes", W.run(F(cli=CLI, action="rm", lane="r4")), rc=0,
       first="ORCA lane: removed r4")
W.done()

# ---- HOOKS, PR #133 review: shapes the reader must refuse, the JS trim set,
# a stale local ref, a base origin lacks, a broken origin, and a resume.
W = World("hooks2")
open(os.path.join(W.main, "orca.yaml"), "w").write("scripts:\n  setup: make init\n")
W.git("add", "orca.yaml")
W.commit("orca.yaml")
W.git("push", "-q", "origin", "main")
W.git("fetch", "-q", "origin")
for tag, lane, text in (("BOM", "k1", "\ufeffscripts:\n  setup: make init\n"),
                        ("quoted top-level key", "k2", "\"scripts\":\n  setup: make init\n"),
                        ("indented document", "k3", "  scripts:\n    setup: make init\n"),
                        ("null value", "k4", "scripts:\n  setup: null\n")):
    up = os.path.join(W.d, "up-" + lane)
    sh("git", "clone", "-q", W.origin, up)
    open(os.path.join(up, "orca.yaml"), "w", encoding="utf-8").write(text)
    sh("git", "-C", up, "add", "orca.yaml")
    W.commit(tag, cwd=up)
    sh("git", "-C", up, "push", "-q", "origin", "HEAD:main")
    hook(hs("local-only"))
    expect("HOOKS orca.yaml %s refuses" % tag, W.run(F(cli=CLI, action="create", lane=lane, base="main")), rc=1,
           first=UNK, verbs_lack=NOCREATE)
# Restore a plain orca.yaml on origin; main's origin/main is left stale.
up = os.path.join(W.d, "up-restore")
sh("git", "clone", "-q", W.origin, up)
open(os.path.join(up, "orca.yaml"), "w").write("scripts:\n  setup: make init\n")
sh("git", "-C", up, "add", "orca.yaml")
W.commit("restore", cwd=up)
sh("git", "-C", up, "push", "-q", "origin", "HEAD:main")
W.git("fetch", "-q", "origin")
hook(hs(None, setup="\x85"))
expect("HOOKS a local script Python would strip but JS keeps refuses",
       W.run(F(cli=CLI, action="create", lane="k5", base="main")), rc=1,
       first=SH + "commandSourcePolicy unset (Orca reads it as local-only", verbs_lack=NOCREATE)
# Origin's orca.yaml changes; this checkout's origin/main does not see it.
open(os.path.join(up, "orca.yaml"), "w").write("scripts:\n  setup: make init-v2\n")
sh("git", "-C", up, "add", "orca.yaml")
W.commit("setup v2", cwd=up)
sh("git", "-C", up, "push", "-q", "origin", "HEAD:main")
hook(hs("local-only", setup="make init"))
expect("HOOKS checks origin's current orca.yaml, not a stale local ref",
       W.run(F(cli=CLI, action="create", lane="k6", base="main")), rc=1,
       first=SH + "commandSourcePolicy local-only runs the local setup script (differs)", verbs_lack=NOCREATE)
expect("HOOKS a base origin lacks refuses", W.run(F(cli=CLI, action="create", lane="k7", base="nosuch")), rc=1,
       first="ORCA lane: k7 unchanged — origin has no branch nosuch", verbs_lack=[["worktree", "list"], ["worktree", "create"]])
W.git("remote", "set-url", "origin", os.path.join(W.d, "gone.git"))
expect("HOOKS a failed fetch refuses", W.run(F(cli=CLI, action="create", lane="k8", base="main")), rc=1,
       first="ORCA lane: k8 unchanged — git fetch of origin/main failed", verbs_lack=[["worktree", "list"], ["worktree", "create"]])
W.git("remote", "set-url", "origin", W.origin)
W.git("fetch", "-q", "origin")
# A resume skipped the pre-create check: the lane's own orca.yaml is checked.
pk = W.lane("k9", branch="chore/k9/park")
W.git("-C", pk, "reset", "-q", "--hard", "origin/main")
hook(hs("local-only", setup="make init"))
expect("HOOKS a resume onto a shadow fails", W.run(F(cli=CLI, action="create", lane="k9", base="main")), rc=3,
       first="ORCA lane failed: the lane is created and parked at " + pk + ", but Orca's saved hook settings shadow its orca.yaml")
W.done()

# ---- BLOCK
W = World("block")
text = open(SKILL).read()
blocks = [textwrap.dedent(b) for b in re.findall(r"```bash\n(.*?)\n[ \t]*```", text, re.S) if 'scripts/orca-lane.sh" <<' in b]
b = blocks[0] if len(blocks) == 1 else ""
(ok if b else miss)("BLOCK exactly one lane block in rule 2" + ("" if b else ": found %d" % len(blocks)))
hm = re.search(r"<<'CEPA_FIELDS' \|\| true\n(.*?)\nCEPA_FIELDS\n", b, re.S)
h = hm.group(1).split("\n") if hm else []
(ok if [l.split(":", 1)[0] for l in h] == ["cli", "action", "lane", "base", "confirm"] else miss)(
    "BLOCK quoted heredoc holds cli, action, lane, base, confirm: %r" % h[:6])
plug = os.path.join(W.d, "plug")
os.makedirs(os.path.join(plug, "scripts"))
shutil.copy(SCRIPT, os.path.join(plug, "scripts", "orca-lane.sh"))
shutil.copy(HELPER, os.path.join(plug, "scripts", "orca-lane-reflog.sh"))
shutil.copy(RESOLVE, os.path.join(plug, "scripts", "resolve-plugin-root.sh"))
open(os.path.join(plug, "scripts", "brain-client.sh"), "w").write("#!/bin/sh\nexit 0\n")
os.chmod(os.path.join(plug, "scripts", "brain-client.sh"), 0o755)
mark = os.path.join(W.d, "ran")


def fill(lane=None, base=None, action="name", confirm=None):
    t = b
    if len(h) == 5:
        t = t.replace(h[0], "cli: orca-ide").replace(h[1], "action: " + action)
        t = t.replace(h[2] + "\n", "" if lane is None else "lane: %s\n" % lane)
        t = t.replace(h[3] + "\n", "" if base is None else "base: %s\n" % base)
        t = t.replace(h[4] + "\n", "" if confirm is None else "confirm: %s\n" % confirm)
    return t


def run_block(name, t, rc_want, first, plugdir=plug):
    bp = os.path.join(W.d, "block.sh")
    open(bp, "w").write("set -e\n" + t)
    e = dict(os.environ, PATH=W.bin + ":" + os.environ["PATH"], STUB_STATE=W.state, STUB_LOG=W.log, STUB_MODE="",
             WSL_DISTRO_NAME=DISTRO, CEPA_PLUGIN_ROOT=plugdir, CLAUDE_PLUGIN_ROOT="", CEPA_DEV="",
             HOME=os.path.join(W.d, "home"), GIT_CONFIG_GLOBAL="/dev/null")
    r = subprocess.run(["bash", bp], cwd=W.main, capture_output=True, text=True, env=e, timeout=120)
    lines = r.stdout.splitlines()
    why = []
    if r.returncode != rc_want:
        why.append("rc=%s" % r.returncode)
    if not (lines and lines[0].startswith(first)):
        why.append("out=%r" % lines[:2])
    if os.path.exists(mark):
        why.append("a filled value ran as a shell command")
    (miss if why else ok)("%s: %s" % (name, "; ".join(why)) if why else name)


# L79: the advice that made a duplicate lane stays out of both owners.
flat = " ".join(text.split())
(ok if "run again as is" not in flat and "is not run again while the lane is absent" in flat else miss)(
    "BLOCK rule 2 does not re-run a failed create")
(ok if "run again as is" not in " ".join(open(SCRIPT).read().split()) else miss)("BLOCK the script does not re-run a failed create")
run_block("BLOCK runs name", fill(), 0, "ORCA lane: named 0 lane(s)")
run_block("BLOCK shell text in the lane runs nothing", fill(lane="x$(touch %s)" % mark, action="rm", confirm="x"), 0,
          "ORCA lane refused: the lane is not a <wt> name")
run_block("BLOCK with the script absent is skipped", fill(), 0,
          "ORCA lane skipped: orca-lane.sh not found (set CEPA_PLUGIN_ROOT)", plugdir=os.path.join(W.d, "none"))
W.done()

shutil.rmtree(PLUGS, ignore_errors=True)
print("-- %d/%d checks passed --" % (passed, passed + failed))
sys.exit(1 if failed else 0)
PY
