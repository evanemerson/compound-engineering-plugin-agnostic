#!/usr/bin/env bash
# Check for plugins/cepa/scripts/orca-attention.sh, the one checked form of
# `cepa:autonomy` §12b rule 7's attention flag (punch-list L57). It runs the
# script in a throwaway git repo (a main checkout and one linked worktree)
# against scripts/fixtures/orca-attention-stub.py as `orca-ide` on PATH, so it
# never reaches a real Orca. The stub returns Orca's UNC paths and logs every
# call.
#
# Usage: check-orca-attention.sh [orca-attention.sh [SKILL.md]]
#   The optional paths replace the shipped script and the autonomy skill whose
#   rule 7 attention block the BLOCK leg runs. Only
#   check-orca-attention-controls.sh sets them, to run this check against a
#   mutant.
#
# Every MISS line starts with its case name, so the controls can assert the
# exact set of cases each mutant breaks. Legs:
#   FIELDS — each bad field, missing or extra field, extra line, argument,
#            bad cli (shell text, not Orca, a relative or foreign absolute
#            path, bare orca on Linux; an absolute path equal to
#            ORCA_CLI_COMMAND passes), bad action, bad question file (name, relative, symlink,
#            inside the repo directly or through a symlinked directory,
#            more than one line, a control character, empty,
#            too long), and a caller outside git: exit 4, `refused`, and the
#            stub is never called. A file that passed its path check is gone.
#   SCOPE  — the worktree `current` returns must be this checkout's: another
#            worktree's row, another WSL distro's path, WSL_DISTRO_NAME
#            unset, an id that is not `<repoId>::<path>`, or no row is a
#            failure with no set call; the
#            set names the linked worktree's own full id, and from the main
#            checkout the main checkout's.
#   MARK   — exact set argv and the stored flag; shell text in the question
#            is stored as text and runs nothing; a leading `NEEDS YOU:` is not
#            doubled; 200 characters pass; a failed set, a set that does not
#            stick, a failed, wrong-id or unknown-shape re-read, and a
#            failed current, and a set that stores the comment but not the
#            dot are failures; a hung call is cut at 15 s; the
#            WSL interop error is retried and no other error is.
#   CLEAR  — exact set argv and the cleared flag; a comment that is not a
#            NEEDS YOU flag (`NEEDS YOUR …` included) is left alone with no
#            set call, and the line says when the dot is still set; a set
#            that clears the comment but not the dot is a failure; a set that does
#            not stick and a failed show are failures.
#   Not pinned: the `-O` ownership check (a test run cannot make a file
#   another user owns) and the `cd` to the top level (the stub, like Orca,
#   resolves any directory inside a worktree to that worktree).
#   BLOCK  — §12b rule 7's attention block, extracted and run under
#            `bash -e`: it marks from a file and clears; shell text in the
#            file field runs nothing; with the script absent it prints the
#            skipped line.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

CEPA_AT_SCRIPT="$(realpath "${1:-plugins/cepa/scripts/orca-attention.sh}")" \
CEPA_AT_SKILL="$(realpath "${2:-plugins/cepa/skills/autonomy/SKILL.md}")" \
python3 - <<'PY'
import json, os, re, shutil, subprocess, sys, tempfile, textwrap

SCRIPT = os.environ["CEPA_AT_SCRIPT"]
SKILL = os.environ["CEPA_AT_SKILL"]
STUB = os.path.realpath("scripts/fixtures/orca-attention-stub.py")
RESOLVE = os.path.realpath("plugins/cepa/scripts/resolve-plugin-root.sh")
passed = failed = 0
DISTRO = "Ubuntu-24.04"
RID, RID2 = "11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222"
GENV = {"GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1"}


def ok(name):
    global passed
    passed += 1


def miss(name):
    global failed
    failed += 1
    print("MISS " + name)


def sh(*a, cwd=None):
    r = subprocess.run(list(a), cwd=cwd, capture_output=True, text=True, env=dict(os.environ, **GENV))
    if r.returncode:
        raise RuntimeError("%s: %s" % (a, r.stderr))
    return r.stdout.strip()


def unc(p):
    return "\\\\wsl.localhost\\" + DISTRO + p.replace("/", "\\")


class World:
    """A main checkout with one linked worktree, a scratch dir, a stub on PATH."""

    def __init__(self, tag):
        self.d = os.path.realpath(tempfile.mkdtemp(prefix="cepa-at-%s-" % tag))
        self.main = os.path.join(self.d, "repo")
        os.makedirs(self.main)
        sh("git", "init", "-q", "-b", "main", self.main)
        sh("git", "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", "i",
           cwd=self.main)
        self.lane = os.path.join(self.main, ".claude", "worktrees", "lane")
        sh("git", "worktree", "add", "-q", "--detach", self.lane, cwd=self.main)
        self.other = os.path.join(self.d, "other")
        os.makedirs(self.other)
        self.scratch = os.path.join(self.d, "scratch")
        os.makedirs(self.scratch)
        self.outside = os.path.join(self.d, "outside")
        os.makedirs(self.outside)
        self.bin = os.path.join(self.d, "bin")
        os.makedirs(self.bin)
        os.symlink(STUB, os.path.join(self.bin, "orca-ide"))
        self.state = os.path.join(self.d, "state.json")
        self.log = os.path.join(self.d, "calls.log")
        self.n = 0
        self.reset()

    def reset(self, lane_comment="", lane_unread=False):
        self.st = {"distro": DISTRO, "wts": [
            {"repoId": RID, "path": self.main, "comment": "", "unread": False},
            {"repoId": RID, "path": self.lane, "comment": lane_comment, "unread": lane_unread},
            {"repoId": RID2, "path": self.other, "comment": "", "unread": False}]}
        json.dump(self.st, open(self.state, "w"))

    def wt(self, path):
        for w in json.load(open(self.state))["wts"]:
            if w["path"] == path:
                return w

    def wid(self, p, repo=RID):
        return repo + "::" + unc(p)

    def qfile(self, text, where=None, name=None):
        self.n += 1
        p = os.path.join(where or self.scratch, name or "cepa-attention-t-%d.txt" % self.n)
        open(p, "w").write(text)
        return p

    def run(self, fields, mode="", cwd=None, args=(), env=None):
        open(self.log, "w").close()
        e = dict(os.environ, PATH=self.bin + ":" + os.environ["PATH"], STUB_STATE=self.state, STUB_LOG=self.log,
                 STUB_MODE=mode, WSL_DISTRO_NAME=DISTRO, **GENV)
        e.pop("ORCA_CLI_COMMAND", None)
        e.update(env or {})
        r = subprocess.run(["bash", SCRIPT, *args], input=fields, cwd=cwd or self.lane, capture_output=True,
                           text=True, env=e, timeout=120)
        calls = [json.loads(l) for l in open(self.log) if l.strip()]
        return r.returncode, r.stdout.splitlines(), calls

    def done(self):
        shutil.rmtree(self.d, ignore_errors=True)


def F(**kw):
    order = ["cli", "action", "file"]
    return "".join("%s: %s\n" % (k, kw[k]) for k in order if k in kw)


def expect(name, got, rc=None, first=None, calls_none=False, sets_none=False, set_argv=None, extra=(), has=()):
    rc_, out, calls = got
    why = []
    for x in has:
        if x not in "\n".join(out):
            why.append("missing %r" % x)
    if rc is not None and rc_ != rc:
        why.append("rc=%s want %s" % (rc_, rc))
    if first is not None and not (out and out[0].startswith(first)):
        why.append("first line %r want %r…" % (out[:1], first))
    if calls_none and calls:
        why.append("stub called %r" % calls[:2])
    sets = [c for c in calls if c[:2] == ["worktree", "set"]]
    if sets_none and sets:
        why.append("made a set call %r" % sets[:1])
    if set_argv is not None and sets != [set_argv]:
        why.append("set calls %r want %r" % (sets, [set_argv]))
    for cond, msg in extra:
        if not cond():
            why.append(msg)
    (miss if why else ok)("%s: %s | out=%r" % (name, "; ".join(why), out[:3]) if why else name)


CLI = "orca-ide"
W = World("main")
LANE_ID = W.wid(W.lane)
MAIN_ID = W.wid(W.main)

# ---- FIELDS
R = "ORCA attention refused: "
q = lambda: W.qfile("Merge PR #9?\n")
cases = [
    ("FIELDS argument", F(cli=CLI, action="clear"), ("x",), "orca-attention.sh takes no arguments"),
    ("FIELDS not a field line", "cli orca-ide\n", (), "a heredoc line is not a <name>: <value> field"),
    ("FIELDS unknown field", F(cli=CLI, action="clear") + "run: x\n", (), "a field name is not cli, action or file"),
    ("FIELDS duplicate", F(cli=CLI, action="clear") + "cli: orca-ide\n", (), "the cli field is given twice"),
    ("FIELDS line after fields", F(cli=CLI, action="clear") + "\nrm -rf x\n", (),
     "the heredoc holds a line after its fields"),
    ("FIELDS missing cli", "action: clear\n", (), "the cli field is missing"),
    ("FIELDS cli with shell text", "cli: orca-ide$(touch x)\naction: clear\n", (), "the cli is not a plain command name"),
    ("FIELDS cli not orca", F(cli="bash", action="clear"), (), "the cli does not name an Orca CLI"),
    ("FIELDS relative cli path", F(cli="bin/orca-ide", action="clear"), (),
     "a cli path must be absolute and equal ORCA_CLI_COMMAND"),
    ("FIELDS bad action", F(cli=CLI, action="set"), (), "the action is not mark or clear"),
    ("FIELDS mark without file", F(cli=CLI, action="mark"), (), "mark needs a file field"),
    ("FIELDS clear with file", F(cli=CLI, action="clear", file=q()), (), "clear takes no file field"),
    ("FIELDS file wrong name", F(cli=CLI, action="mark", file=W.qfile("q\n", name="cepa-send-t-1.txt")), (),
     "the question file is not an absolute path to a cepa-attention-<name>.txt file"),
    ("FIELDS file relative", F(cli=CLI, action="mark", file="scratch/cepa-attention-x.txt"), (),
     "the question file is not an absolute path to a cepa-attention-<name>.txt file"),
    ("FIELDS file with a dot segment", F(cli=CLI, action="mark", file=W.scratch + "/./cepa-attention-dot.txt"), (),
     "the question file is not an absolute path to a cepa-attention-<name>.txt file"),
    ("FIELDS absolute cli not ORCA_CLI_COMMAND", F(cli="/usr/bin/orca-ide", action="clear"), (),
     "a cli path must equal ORCA_CLI_COMMAND"),
    ("FIELDS bare orca on Linux", F(cli="orca", action="clear"), (), "bare orca on Linux is the screen reader"),
]
for name, fields, args, reason in cases:
    expect(name, W.run(fields, args=args), rc=4, first=R + reason, calls_none=True)

# A symlinked file is refused and kept.
real = W.qfile("q\n", name="real.txt")
link = os.path.join(W.scratch, "cepa-attention-link.txt")
os.symlink(real, link)
expect("FIELDS file symlink", W.run(F(cli=CLI, action="mark", file=link)), rc=4,
       first=R + "the question file is not a regular file this user owns", calls_none=True)
# Inside the checkout, and inside the main checkout from a linked worktree.
p_in = W.qfile("q\n", where=W.lane)
expect("FIELDS file inside this checkout", W.run(F(cli=CLI, action="mark", file=p_in)), rc=4,
       first=R + "the question file is inside the repo", calls_none=True,
       extra=[(lambda: os.path.exists(p_in), "a refused path's file was removed")])
# A scratch directory that is a symlink into the checkout: the physical
# path is inside, so it is refused and the file is kept.
os.makedirs(os.path.join(W.lane, "sub"), exist_ok=True)
lnk = os.path.join(W.scratch, "into-lane")
os.symlink(os.path.join(W.lane, "sub"), lnk)
p_lnk = W.qfile("q\n", where=os.path.join(W.lane, "sub"))
p_via = os.path.join(lnk, os.path.basename(p_lnk))
expect("FIELDS file through a symlinked directory into the checkout", W.run(F(cli=CLI, action="mark", file=p_via)),
       rc=4, first=R + "the question file is inside the repo", calls_none=True,
       extra=[(lambda: os.path.exists(p_lnk), "the file inside the checkout was removed")])
p_main = W.qfile("q\n", where=W.main)
expect("FIELDS file inside the main checkout", W.run(F(cli=CLI, action="mark", file=p_main)), rc=4,
       first=R + "the question file is inside the repo", calls_none=True)
for name, text, reason in [
    ("FIELDS question two lines", "Merge?\nrm -rf x\n", "the question is not one line"),
    ("FIELDS question control character", "Merge\x1b[2J?\n", "the question holds a control character"),
    ("FIELDS question empty", "NEEDS YOU:   \n", "the question is empty"),
    ("FIELDS question too long", "x" * 201 + "\n", "the question is longer than 200 characters"),
]:
    p = W.qfile(text)
    expect(name, W.run(F(cli=CLI, action="mark", file=p)), rc=4, first=R + reason, calls_none=True,
           extra=[(lambda p=p: not os.path.exists(p), "a file that passed its path check was kept")])
W.reset()
expect("FIELDS absolute cli equal to ORCA_CLI_COMMAND passes",
       W.run(F(cli=os.path.join(W.bin, "orca-ide"), action="clear"),
             env={"ORCA_CLI_COMMAND": os.path.join(W.bin, "orca-ide")}), rc=0, first="ORCA attention: ok")
expect("FIELDS outside git", W.run(F(cli=CLI, action="clear"), cwd=W.outside), rc=4,
       first=R + "not inside a git checkout", calls_none=True)

# ---- SCOPE
for name, mode in [("SCOPE another worktree's row", "currentother"), ("SCOPE another distro's path", "currentdistro"),
                   ("SCOPE id not repoId::path", "currentbadid")]:
    W.reset()
    expect(name, W.run(F(cli=CLI, action="mark", file=q()), mode=mode), rc=3,
           first="ORCA attention failed: worktree current did not return this checkout's own worktree",
           sets_none=True)
W.reset()
expect("SCOPE WSL_DISTRO_NAME unset", W.run(F(cli=CLI, action="mark", file=q()), env={"WSL_DISTRO_NAME": ""}),
       rc=3, first="ORCA attention failed: worktree current did not return this checkout's own worktree",
       sets_none=True)
# A git repo Orca does not know.
sh("git", "init", "-q", W.outside)
W.reset()
# Orca 1.4.245 exits 1 with `selector_not_found` here (measured L57).
expect("SCOPE checkout Orca does not know", W.run(F(cli=CLI, action="clear"), cwd=W.outside), rc=3,
       first="ORCA attention failed: worktree current failed", sets_none=True)
W.reset()
expect("SCOPE linked worktree sets its own id", W.run(F(cli=CLI, action="mark", file=q())), rc=0,
       first="ORCA attention: marked",
       set_argv=["worktree", "set", "--worktree", "id:" + LANE_ID, "--unread", "--comment", "NEEDS YOU: Merge PR #9?",
                 "--json"],
       extra=[(lambda: W.wt(W.main)["comment"] == "", "the main checkout's row changed")])
W.reset()
sub = os.path.join(W.main, "sub")
os.makedirs(sub, exist_ok=True)
expect("SCOPE main checkout sets its own id", W.run(F(cli=CLI, action="mark", file=q()), cwd=sub), rc=0,
       first="ORCA attention: marked",
       set_argv=["worktree", "set", "--worktree", "id:" + MAIN_ID, "--unread", "--comment", "NEEDS YOU: Merge PR #9?",
                 "--json"])

# ---- MARK
mark = os.path.join(W.d, "ran")
W.reset()
evil = "Deploy? $(touch %s) `touch %s`" % (mark, mark)
expect("MARK shell text is stored as text", W.run(F(cli=CLI, action="mark", file=W.qfile(evil + "\n"))), rc=0,
       first="ORCA attention: marked",
       extra=[(lambda: W.wt(W.lane) == {"repoId": RID, "path": W.lane, "comment": "NEEDS YOU: " + evil,
                                        "unread": True}, "stored flag is wrong"),
              (lambda: not os.path.exists(mark), "question text ran as a shell command")])
W.reset()
expect("MARK prefix not doubled", W.run(F(cli=CLI, action="mark", file=W.qfile("NEEDS YOU: Merge?\n"))), rc=0,
       first="ORCA attention: marked",
       extra=[(lambda: W.wt(W.lane)["comment"] == "NEEDS YOU: Merge?", "comment %r" % W.wt(W.lane)["comment"])])
W.reset()
expect("MARK 200 characters pass", W.run(F(cli=CLI, action="mark", file=W.qfile("y" * 200 + "\n"))), rc=0,
       first="ORCA attention: marked")
for name, mode, first in [
    ("MARK set fails", "setfail", "ORCA attention failed: worktree set failed"),
    ("MARK set does not stick", "setnostick", "ORCA attention failed: after worktree set"),
    ("MARK set stores the comment only", "setcommentonly", "ORCA attention failed: after worktree set"),
    ("MARK re-read fails", "showfail", "ORCA attention failed: worktree set ran, but the re-read"),
    ("MARK re-read of another id", "showwrongid", "ORCA attention failed: worktree set ran, but the re-read"),
]:
    W.reset()
    expect(name, W.run(F(cli=CLI, action="mark", file=q()), mode=mode), rc=3, first=first)
W.reset()
expect("MARK current fails", W.run(F(cli=CLI, action="mark", file=q()), mode="currentfail"), rc=3,
       first="ORCA attention failed: worktree current failed", sets_none=True)
W.reset()
expect("MARK other errors are not retried", W.run(F(cli=CLI, action="mark", file=q()), mode="currentfail"), rc=3,
       first="ORCA attention failed: worktree current failed",
       extra=[(lambda: [json.loads(l)[:2] for l in open(W.log)].count(["worktree", "current"]) == 1,
               "worktree current was called more than once")])
W.reset()
expect("MARK a hung call is bounded", W.run(F(cli=CLI, action="mark", file=q()), mode="hang"), rc=3,
       first="ORCA attention failed: worktree current failed", sets_none=True)
W.reset()
expect("MARK re-read of an unknown shape", W.run(F(cli=CLI, action="mark", file=q()), mode="showshape"), rc=3,
       first="ORCA attention failed: worktree set ran, but the re-read")
W.reset()
expect("MARK interop error is retried", W.run(F(cli=CLI, action="mark", file=q()), mode="interop"), rc=0,
       first="ORCA attention: marked")

# ---- CLEAR
W.reset(lane_comment="NEEDS YOU: Merge?", lane_unread=True)
expect("CLEAR clears a NEEDS YOU flag", W.run(F(cli=CLI, action="clear")), rc=0, first="ORCA attention: cleared",
       set_argv=["worktree", "set", "--worktree", "id:" + LANE_ID, "--read", "--comment", " ", "--json"],
       extra=[(lambda: (W.wt(W.lane)["comment"], W.wt(W.lane)["unread"]) == (" ", False), "flag still set")])
W.reset(lane_comment="operator note", lane_unread=True)
expect("CLEAR leaves another comment alone", W.run(F(cli=CLI, action="clear")), rc=0,
       first="ORCA attention: ok — nothing to clear", sets_none=True,
       extra=[(lambda: (W.wt(W.lane)["comment"], W.wt(W.lane)["unread"]) == ("operator note", True), "row changed")])
W.reset(lane_comment="NEEDS YOUR note", lane_unread=False)
expect("CLEAR a NEEDS YOUR note is not a flag", W.run(F(cli=CLI, action="clear")), rc=0,
       first="ORCA attention: ok — nothing to clear", sets_none=True)
W.reset(lane_comment="operator note", lane_unread=True)
expect("CLEAR says the dot is still set", W.run(F(cli=CLI, action="clear")), rc=0,
       first="ORCA attention: ok — nothing to clear", has=["the unread dot is still set"])
W.reset(lane_comment="NEEDS YOU: Merge?", lane_unread=True)
expect("CLEAR set does not stick", W.run(F(cli=CLI, action="clear"), mode="setnostick"), rc=3,
       first="ORCA attention failed: after worktree set")
W.reset(lane_comment="NEEDS YOU: Merge?", lane_unread=True)
expect("CLEAR set clears the comment only", W.run(F(cli=CLI, action="clear"), mode="setcommentonly"), rc=3,
       first="ORCA attention failed: after worktree set")
W.reset(lane_comment="NEEDS YOU: Merge?", lane_unread=True)
expect("CLEAR show fails", W.run(F(cli=CLI, action="clear"), mode="showfail"), rc=3,
       first="ORCA attention failed: worktree show failed", sets_none=True)
W.done()

# ---- BLOCK
W = World("block")
text = open(SKILL).read()
blocks = [textwrap.dedent(b) for b in re.findall(r"```bash\n(.*?)\n[ \t]*```", text, re.S)
          if 'scripts/orca-attention.sh" <<' in b]
b = blocks[0] if len(blocks) == 1 else ""
(ok if b else miss)("BLOCK exactly one attention block in rule 7" + ("" if b else ": found %d" % len(blocks)))
hm = re.search(r"<<'CEPA_FIELDS' \|\| true\n(.*?)\nCEPA_FIELDS\n", b, re.S)
h = hm.group(1).split("\n") if hm else []
(ok if [l.split(":", 1)[0] for l in h] == ["cli", "action", "file"] else miss)(
    "BLOCK quoted heredoc holds cli, action, file: %r" % h[:4])
plug = os.path.join(W.d, "plug")
os.makedirs(os.path.join(plug, "scripts"))
shutil.copy(SCRIPT, os.path.join(plug, "scripts", "orca-attention.sh"))
shutil.copy(RESOLVE, os.path.join(plug, "scripts", "resolve-plugin-root.sh"))
open(os.path.join(plug, "scripts", "brain-client.sh"), "w").write("#!/bin/sh\nexit 0\n")
os.chmod(os.path.join(plug, "scripts", "brain-client.sh"), 0o755)
ran = os.path.join(W.d, "ran")


def fill(action, file=None):
    t = b
    if len(h) == 3:
        t = t.replace(h[0], "cli: orca-ide").replace(h[1], "action: " + action)
        t = t.replace(h[2] + "\n", "" if file is None else "file: %s\n" % file)
    return t


def run_block(name, t, first, plugdir=plug, extra=()):
    bp = os.path.join(W.d, "block.sh")
    open(bp, "w").write("set -e\n" + t)
    e = dict(os.environ, PATH=W.bin + ":" + os.environ["PATH"], STUB_STATE=W.state, STUB_LOG=W.log, STUB_MODE="",
             WSL_DISTRO_NAME=DISTRO, CEPA_PLUGIN_ROOT=plugdir, CLAUDE_PLUGIN_ROOT="", CEPA_DEV="",
             HOME=os.path.join(W.d, "home"), **GENV)
    open(W.log, "w").close()
    r = subprocess.run(["bash", bp], cwd=W.lane, capture_output=True, text=True, env=e, timeout=120)
    lines = r.stdout.splitlines()
    why = []
    if r.returncode != 0:
        why.append("rc=%s" % r.returncode)
    if not (lines and lines[0].startswith(first)):
        why.append("out=%r" % lines[:2])
    if os.path.exists(ran):
        why.append("a filled value ran as a shell command")
    for cond, msg in extra:
        if not cond():
            why.append(msg)
    (miss if why else ok)("%s: %s" % (name, "; ".join(why)) if why else name)


run_block("BLOCK marks from a file", fill("mark", W.qfile("Merge PR #9?\n")), "ORCA attention: marked",
          extra=[(lambda: W.wt(W.lane)["comment"] == "NEEDS YOU: Merge PR #9?", "flag not stored")])
run_block("BLOCK clears", fill("clear"), "ORCA attention: cleared",
          extra=[(lambda: W.wt(W.lane)["comment"] == " ", "flag not cleared")])
run_block("BLOCK shell text in the file field runs nothing",
          fill("mark", "/x$(touch %s)/cepa-attention-x.txt" % ran),
          "ORCA attention refused: the question file is not an absolute path")
run_block("BLOCK with the script absent is skipped", fill("clear"),
          "ORCA attention skipped: orca-attention.sh not found (set CEPA_PLUGIN_ROOT)",
          plugdir=os.path.join(W.d, "none"))
W.done()

print("-- %d/%d checks passed --" % (passed, passed + failed))
sys.exit(1 if failed else 0)
PY
