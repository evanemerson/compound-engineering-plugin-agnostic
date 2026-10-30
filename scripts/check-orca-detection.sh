#!/usr/bin/env bash
# Check for Orca detection: section 12a of plugins/cepa/skills/autonomy/SKILL.md.
# 12a holds the one ```bash block that decides whether a session runs under
# Orca. This script READS that block from there and never carries its own
# copy, or an edit to the shipped block would leave it green while it tested
# something nobody runs.
#
# Usage: check-orca-detection.sh [SKILL.md]
#   The optional path replaces the shipped skill file, and CEPA_ORCA_SITES
#   replaces the commands directory. Only check-orca-detection-controls.sh sets
#   either, to run this check against a mutant.
#
# Legs, in order:
#   BLOCK    — 12a holds exactly one ```bash block.
#   BOUNDS   — the block sets its probe bounds on exactly two lines,
#              `cepa_orca_wait=3 cepa_orca_kill=0.5` (ORCA_CLI_COMMAND path)
#              then `cepa_orca_wait=10 cepa_orca_kill=2` (every other path),
#              as literal text. FIXTURES then runs a copy of the block whose
#              lines say `cepa_orca_wait=0.3 cepa_orca_kill=0.1` and
#              `cepa_orca_wait=2 cepa_orca_kill=0.3`, so the hang cases wait
#              about 0.4 s and 2.3 s, not 3.5 s and 12 s. The two test bounds
#              are far apart, and env-stale-hangs must finish under 1.2 s, so
#              a block that gives the ORCA_CLI_COMMAND path the other path's
#              bound goes red even when both lines still read as shipped.
#              A BOUNDS miss stops the run, as a BLOCK miss does. The shorter bounds
#              live only in this script's private copy: no environment variable
#              sets it, so no session can shorten or lengthen the shipped
#              probe by accident. BOUNDS pins the shipped values; FIXTURES
#              proves the block obeys whatever that line says.
#   FIXTURES — the block runs under `bash -e`, in a separate process per case,
#              with PATH set to two directories this script builds: stub CLIs
#              (orca-ide, orca-dev, orca, uname) and links to the real tools
#              the block and the stubs need (TOOLS below). No real Orca CLI is
#              reachable. stdin is a pipe this script holds open, so a block
#              that lets the CLI read stdin waits. Every case asserts the exact
#              output line and an upper bound on its run time. A probe stub
#              answers ok:true only to `status --json`. Every stub marks a
#              file when it runs; every Linux case asserts bare `orca` did not
#              run, and every ORCA_CLI_COMMAND case asserts exactly which stubs
#              ran (the named CLI when the value is valid, none when not).
#   TITLE-BLOCK — 12b rule 6 holds exactly one ```bash block (indented under
#              its list item). A miss stops the run.
#   TITLE-BOUNDS — that block bounds the rename with the literal
#              `timeout -k 0.5 3 <cli> terminal rename `, exactly once. TITLE
#              runs it with `timeout -k 0.1 0.3`, so rename-hangs waits about
#              0.4 s. A miss stops the run.
#   TITLE    — the block runs under `bash -e`, one process per case, as the
#              agent runs it: `<cli>` becomes a stub orca-ide that writes each
#              argv word on its own line, and the name and handle go between
#              their heredoc lines. The cwd is a real git repo built here, whose
#              main checkout (`cepa-main`) and linked worktree (`cepa-main-wt`)
#              have different names, so a block that derives `<repo>` from
#              --show-toplevel goes red. Each case asserts the exact output
#              line, rc 0 (a failed rename never fails the run), the exact argv
#              (the title is ONE argument with the U+00B7 separator), that a
#              skipped case never ran the stub, and that no name was evaluated
#              as shell.
#   CITES    — section 12's prose names both do-not-paste first lines and
#              the title format `<repo> · <role>@<wt>`;
#              /cepa:handoff, /cepa:task and /cepa:lfg each carry 12's citation
#              sentence; task and lfg cite 12b rule 3 and handoff 12b rule 1;
#              handoff.md (the one of the three that declares allowed-tools)
#              grants each `orca-ide` verb in GRANTS, and 12's prose outside the
#              block names each verb.
#
# The controls mutate the block, the skill file and the command files one
# substitution at a time, and require the named case of this script to go red.
#
# STATED LIMITS — a green run does not mean:
#   - the real Orca CLI answers as the stubs do. The stub output copies the
#     shape `orca-ide status --json` returned on Orca 1.4.244 (2026-10-30);
#     a later Orca can change it, and only a live run would show that.
#   - the shipped bounds (3 s and 10 s) have run: BOUNDS pins them as text,
#     and the hang cases run the same lines with the shorter test bounds.
#   - the session's permission layer admits the block. 12a states why a
#     prefix grant cannot.
#   - an agent follows 12b. This tests detection and the citations, not the
#     model that reads them.
#   - the real `terminal rename` answers as the stub does. Its flags come
#     from `--help` on Orca 1.4.244; no live rename was run (the worker brief
#     that built TITLE forbade renaming a real tab).
#   - non-Linux hosts are covered by more than stubbed `uname` cases. The
#     `timeout` here is GNU coreutils; a host with none reads as absent.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

CEPA_ORCA_SKILL="${1:-plugins/cepa/skills/autonomy/SKILL.md}" python3 - <<'PY'
import os, re, shutil, subprocess, sys, tempfile, time

HOME = os.environ["CEPA_ORCA_SKILL"]
SITES_DIR = os.environ.get("CEPA_ORCA_SITES", "plugins/cepa/commands")
CITE = ("apply `cepa:autonomy` §12 — §12a's detection first, then §12b and §12c "
        "only on `ORCA: present`.")
RULE_CITES = {"handoff.md": "§12b rule 1", "task.md": "§12b rule 3", "lfg.md": "§12b rule 3"}
GRANTS = {"orca-ide status": "`status`",
          "orca-ide skills get": "`<cli> skills get orchestration`",
          "orca-ide orchestration send": "`orchestration send`",
          "orca-ide orchestration ask": "Orca's `ask`",
          "orca-ide terminal rename": "`terminal rename --help`"}
TITLE_FORMAT = "`<repo> · <role>@<wt>`"
TOOLS = ["timeout", "python3", "mktemp", "rm", "sleep", "touch", "cat", "setsid"]
DO_NOT_PASTE = ["`Sent to coord@main via Orca — do not paste.`",
                "`Sent to coord@<wt> via Orca — do not paste.`"]
SHIPPED_BOUNDS = [("3", "0.5"), ("10", "2")]
TEST_BOUNDS = [("0.3", "0.1"), ("2", "0.3")]
STATUS_OK = '{\n  "id": "local-status",\n  "ok": true,\n  "result": {"runtime": {"reachable": true}}\n}'
passed = failed = 0
TMP = tempfile.mkdtemp(prefix="cepa-orca-")

def ok(msg):
    global passed; passed += 1; print("PASS", msg)

def miss(msg):
    global failed; failed += 1; print("MISS", msg)

def finish():
    shutil.rmtree(TMP, ignore_errors=True)
    print("-- %d/%d checks passed --" % (passed, passed + failed))
    sys.exit(1 if failed else 0)

def flat(s):
    return re.sub(r"\s+", " ", s)

# --- BLOCK ---
try:
    text = open(HOME).read()
except OSError as e:
    miss("cannot read %s: %s" % (HOME, e)); finish()
m = re.search(r"^### 12a\..*?(?=^### |\Z)", text, re.M | re.S)
if not m:
    miss("BLOCK: no ### 12a. section in %s" % HOME); finish()
blocks = re.findall(r"^```bash\n(.*?)^```$", m.group(0), re.M | re.S)
if len(blocks) != 1:
    miss("BLOCK: 12a holds %d ```bash blocks, want exactly 1" % len(blocks)); finish()
ok("BLOCK: 12a holds one bash block")

# --- BOUNDS ---
code = blocks[0]
bounds = list(re.finditer(r"^(\s*)cepa_orca_wait=(\S+) cepa_orca_kill=(\S+)$", code, re.M))
got = [(b.group(2), b.group(3)) for b in bounds]
if got == SHIPPED_BOUNDS:
    ok("BOUNDS: probe bounds are %s" % got)
else:
    miss("BOUNDS: probe bounds are %s, want %s" % (got, SHIPPED_BOUNDS)); finish()
for b, (w, k) in reversed(list(zip(bounds, TEST_BOUNDS))):
    code = code[:b.start()] + "%scepa_orca_wait=%s cepa_orca_kill=%s" % (
        b.group(1), w, k) + code[b.end():]
block = os.path.join(TMP, "block.sh")
open(block, "w").write(code)

# --- FIXTURES ---
def stub(d, name, body):
    p = os.path.join(d, name)
    open(p, "w").write("#!/bin/sh\n" + body + "\n")
    os.chmod(p, 0o755)

def answer(json_text, after=""):
    # ok:true only for the exact argv the block must use.
    return ('if [ "$*" = "status --json" ]; then\ncat <<\'J\'\n%s\nJ\n%s\n'
            'else echo "unexpected argv: $*"; fi' % (json_text, after))

def run_case(name, want, stubs=(), env=None, uname="Linux", drop=(), max_took=4.0, ran=None):
    case = os.path.join(TMP, name)
    sd, td = os.path.join(case, "stubs"), os.path.join(case, "tools")
    os.makedirs(sd); os.makedirs(td)
    for t in TOOLS:
        if t in drop:
            continue
        real = shutil.which(t)
        if not real:
            miss("%s: real tool %s missing on this host" % (name, t)); return
        os.symlink(real, os.path.join(td, t))
    marks = os.path.join(case, "marks")
    os.makedirs(marks)
    stub(sd, "uname", "echo %s" % uname)
    # A bare `orca` that marks itself and answers ok:true, so a block that ran
    # it would also print "present cli=orca".
    stub(sd, "orca", "touch %s/orca\n%s" % (marks, answer(STATUS_OK)))
    for cli, body in stubs:
        stub(sd, cli, "touch %s/%s\n%s" % (marks, cli, body))
    e = {"PATH": sd + ":" + td, "HOME": case}
    for k, v in (env or {}).items():
        e[k] = v.replace("{STUBS}", sd)
    rfd, wfd = os.pipe()  # held open: a CLI reading this stdin never sees EOF
    t0 = time.time()
    try:
        r = subprocess.run(["/bin/bash", "-e", block], env=e, cwd=case, stdin=rfd,
                           capture_output=True, text=True, timeout=15)
    except subprocess.TimeoutExpired:
        miss("%s: still running after 15s" % name); return
    finally:
        os.close(rfd); os.close(wfd)
    took = time.time() - t0
    out = r.stdout.strip()
    bad = []
    if r.returncode != 0:
        bad.append("rc=%d stderr=%r" % (r.returncode, r.stderr.strip()[:200]))
    if out != want:
        bad.append("got %r, want %r" % (out, want))
    if took > max_took:
        bad.append("took %.1fs, bound %.0fs" % (took, max_took))
    if uname == "Linux" and os.path.exists(os.path.join(marks, "orca")):
        bad.append("bare `orca` ran on Linux")
    if env and env.get("ORCA_CLI_COMMAND") and sorted(os.listdir(marks)) != sorted(ran or []):
        bad.append("stubs that ran: %s, want %s" % (sorted(os.listdir(marks)), sorted(ran or [])))
    if bad:
        miss("%s: %s" % (name, "; ".join(bad)))
    else:
        ok("%s (%.1fs)" % (name, took))

OK_STUB = [("orca-ide", answer(STATUS_OK))]
ABSENT_BAD = 'ORCA: absent (orca-ide status did not return "ok": true)'
ABSENT_FAIL = "ORCA: absent (orca-ide status failed or timed out)"
# Ignores TERM and outlives every bound, so only the kill ends it in time.
HANG = "trap '' TERM\nsleep 8"
NOT_PLAIN = "ORCA: absent (ORCA_CLI_COMMAND is not a plain command name)"

run_case("unset-no-cli", "ORCA: absent (orca-ide not on PATH)")
run_case("status-ok", "ORCA: present cli=orca-ide via=status", stubs=OK_STUB)
run_case("status-ok-false", ABSENT_BAD,
         stubs=[("orca-ide", answer('{"ok": false, "result": {"ok": true}}'))])
run_case("status-not-json", ABSENT_BAD, stubs=[("orca-ide", answer('"ok": true\nnot json'))])
run_case("status-ok-string", ABSENT_BAD, stubs=[("orca-ide", answer('{"ok": "true"}'))])
run_case("status-json-list", ABSENT_BAD, stubs=[("orca-ide", answer('[{"ok": true}]'))])
run_case("status-empty", ABSENT_BAD, stubs=[("orca-ide", "true")])
run_case("status-nonzero-exit", ABSENT_FAIL,
         stubs=[("orca-ide", answer(STATUS_OK, "exit 3"))])
run_case("status-hangs-ignoring-TERM", ABSENT_FAIL,
         stubs=[("orca-ide", HANG)])
run_case("setsid-grandchild-holds-stdout", ABSENT_FAIL,
         stubs=[("orca-ide", "trap '' TERM\nsetsid sleep 30 &\nsleep 8")])
run_case("bg-child-holds-stdout", "ORCA: present cli=orca-ide via=status",
         stubs=[("orca-ide", answer(STATUS_OK, "sleep 30 &"))])
run_case("stdin-reader", "ORCA: present cli=orca-ide via=status",
         stubs=[("orca-ide", "cat >/dev/null\n" + answer(STATUS_OK))])
run_case("no-timeout-tool", "ORCA: absent (no timeout command to bound the status probe)",
         stubs=OK_STUB, drop=("timeout",))
run_case("no-python3", "ORCA: absent (no python3 to parse the status probe)",
         stubs=OK_STUB, drop=("python3",))
run_case("dev-checkout", "ORCA: present cli=orca-dev via=status",
         stubs=[("orca-dev", answer(STATUS_OK)), ("orca-ide", "exit 9")],
         env={"ORCA_DEV_REPO_ROOT": "/x"})
run_case("non-linux-uses-orca", "ORCA: present cli=orca via=status", uname="Darwin")
# ORCA_CLI_COMMAND: a valid value is probed at 0.5 s; an invalid one is absent
# with no probe.
ENV_IDE = {"ORCA_CLI_COMMAND": "orca-ide"}
run_case("env-set-probes-ok", "ORCA: present cli=orca-ide via=ORCA_CLI_COMMAND",
         stubs=OK_STUB, env=ENV_IDE, ran=["orca-ide"])
run_case("env-stale-fails", ABSENT_FAIL, stubs=[("orca-ide", answer(STATUS_OK, "exit 3"))],
         env=ENV_IDE, ran=["orca-ide"])
run_case("env-stale-hangs", ABSENT_FAIL, stubs=[("orca-ide", HANG)], env=ENV_IDE,
         ran=["orca-ide"], max_took=1.2)
run_case("env-stale-not-ok", ABSENT_BAD, stubs=[("orca-ide", answer('{"ok": false}'))],
         env=ENV_IDE, ran=["orca-ide"])
run_case("env-no-timeout-tool", "ORCA: absent (no timeout command to bound the status probe)",
         stubs=OK_STUB, env=ENV_IDE, drop=("timeout",))
run_case("env-abs-path", "ORCA: present cli={STUBS}/orca-ide via=ORCA_CLI_COMMAND".replace(
         "{STUBS}", os.path.join(TMP, "env-abs-path", "stubs")),
         stubs=OK_STUB, env={"ORCA_CLI_COMMAND": "{STUBS}/orca-ide"}, ran=["orca-ide"])
run_case("env-empty-probes", "ORCA: present cli=orca-ide via=status",
         stubs=OK_STUB, env={"ORCA_CLI_COMMAND": ""})
run_case("env-space", NOT_PLAIN, stubs=OK_STUB, env={"ORCA_CLI_COMMAND": "orca-ide x"})
run_case("env-dash", NOT_PLAIN, stubs=OK_STUB, env={"ORCA_CLI_COMMAND": "-orca-ide"})
run_case("env-inject", NOT_PLAIN, stubs=OK_STUB, env={"ORCA_CLI_COMMAND": "orca-ide;touch x"})
run_case("env-bare-orca-linux", "ORCA: absent (ORCA_CLI_COMMAND names bare orca on Linux)",
         env={"ORCA_CLI_COMMAND": "orca"})
run_case("env-bare-orca-darwin", "ORCA: present cli=orca via=ORCA_CLI_COMMAND",
         uname="Darwin", env={"ORCA_CLI_COMMAND": "orca"}, ran=["orca"])
run_case("env-not-orca", "ORCA: absent (ORCA_CLI_COMMAND does not name an Orca CLI)",
         env={"ORCA_CLI_COMMAND": "cat"})
run_case("env-not-on-path", "ORCA: absent (ORCA_CLI_COMMAND=orca-dev is not on PATH)",
         env={"ORCA_CLI_COMMAND": "orca-dev"})

# --- TITLE ---
# 12b rule 6's block, run as the agent runs it: <cli> becomes a stub, the name
# and handle go between their heredoc lines. The repo is a real git repo whose
# main checkout and linked worktree have different names, so a block that
# reads --show-toplevel names the worktree and goes red.
m6 = re.search(r"^6\. \*\*Each tab carries.*?(?=^\S)", text, re.M | re.S)
tblocks = re.findall(r"^( *)```bash\n(.*?)^\1```$", m6.group(0), re.M | re.S) if m6 else []
if len(tblocks) != 1:
    miss("TITLE-BLOCK: 12b rule 6 holds %d ```bash blocks, want exactly 1" % len(tblocks)); finish()
ok("TITLE-BLOCK: 12b rule 6 holds one bash block")
ind, tcode = tblocks[0]
tcode = re.sub(r"^" + ind, "", tcode, flags=re.M)
TITLE_BOUND = "timeout -k 0.5 3 <cli> terminal rename "
if tcode.count(TITLE_BOUND) == 1:
    ok("TITLE-BOUNDS: the rename is bounded by `timeout -k 0.5 3`")
else:
    miss("TITLE-BOUNDS: want exactly one %r in the block" % TITLE_BOUND); finish()
tcode = tcode.replace(TITLE_BOUND, "timeout -k 0.1 0.3 <cli> terminal rename ")
for ph in ("<session>@<wt>\nCEPA_NAME", "self\nCEPA_TERM", "<cli>"):
    if ph not in tcode:
        miss("TITLE-BLOCK: placeholder %r is gone" % ph); finish()

def git(*a):
    subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@t", "-c",
                    "init.defaultBranch=main"] + list(a), check=True, capture_output=True)
GROOT = os.path.join(TMP, "git")
REPOS = {}
for repo in ("cepa-main", "my repo"):
    main_dir = os.path.join(GROOT, repo)
    git("init", "-q", main_dir)
    git("-C", main_dir, "commit", "-q", "--allow-empty", "-m", "x")
    git("-C", main_dir, "worktree", "add", "-q", "--detach", os.path.join(GROOT, repo + "-wt"))
    REPOS[repo] = main_dir
os.makedirs(os.path.join(GROOT, "nogit"))
# Records each argv word on its own line, so a split title shows.
RENAME_OK = 'printf "%s\\n" "$@" >ARGV\necho \'{"id": "r", "ok": true, "result": {}}\''
TERM_ENV = {"ORCA_TERMINAL_HANDLE": "term_self-1"}

def run_title(name, want, cwd, stub_body=RENAME_OK, sname="tab7@roles", term="self",
              env=None, argv=None, max_took=4.0):
    name = "title-" + name
    case = os.path.join(TMP, name)
    sd, td = os.path.join(case, "stubs"), os.path.join(case, "tools")
    os.makedirs(sd); os.makedirs(td)
    for t in TOOLS + ["git", "printf"]:
        real = shutil.which(t)
        if not real:
            miss("%s: real tool %s missing on this host" % (name, t)); return
        os.symlink(real, os.path.join(td, t))
    argv_file = os.path.join(case, "argv")
    stub(sd, "orca-ide", "touch %s/ran\n%s" % (case, stub_body.replace("ARGV", argv_file)))
    body = (tcode.replace("<session>@<wt>\nCEPA_NAME", sname + "\nCEPA_NAME")
            .replace("self\nCEPA_TERM", term + "\nCEPA_TERM").replace("<cli>", "orca-ide"))
    script = os.path.join(case, "title.sh")
    open(script, "w").write(body)
    e = {"PATH": sd + ":" + td, "HOME": case}
    e.update(env or {})
    t0 = time.time()
    try:
        r = subprocess.run(["/bin/bash", "-e", script], env=e, cwd=cwd, stdin=subprocess.DEVNULL,
                           capture_output=True, text=True, timeout=15)
    except subprocess.TimeoutExpired:
        miss("%s: still running after 15s" % name); return
    took = time.time() - t0
    bad = []
    if r.returncode != 0:
        bad.append("rc=%d stderr=%r" % (r.returncode, r.stderr.strip()[:200]))
    if r.stdout.strip() != want:
        bad.append("got %r, want %r" % (r.stdout.strip(), want))
    if took > max_took:
        bad.append("took %.1fs, bound %.0fs" % (took, max_took))
    ran = os.path.exists(os.path.join(case, "ran"))
    if want.startswith("ORCA title: skipped") and ran:
        bad.append("the rename ran on a skipped case")
    if argv is not None:
        got = open(argv_file).read().split("\n")[:-1] if os.path.exists(argv_file) else None
        if got != argv:
            bad.append("argv %r, want %r" % (got, argv))
    if os.path.exists(os.path.join(cwd, "pwned")):
        bad.append("a name was evaluated as shell")
    if bad:
        miss("%s: %s" % (name, "; ".join(bad)))
    else:
        ok("%s (%.1fs)" % (name, took))

WT = REPOS["cepa-main"] + "-wt"
TITLE = "cepa-main · tab7@roles"
def rename_argv(term, title=TITLE):
    return ["terminal", "rename", "--terminal", term, "--title", title, "--json"]
def skipped(why):
    return "ORCA title: skipped (%s)" % why
BAD_NAME = skipped("the session name holds a character outside [A-Za-z0-9._@-]")
BAD_TERM = skipped("the terminal handle is not a plain handle")

run_title("self-linked-worktree", 'ORCA title: set "%s" on term_self-1' % TITLE, WT,
          env=TERM_ENV, argv=rename_argv("term_self-1"))
run_title("self-main-checkout", 'ORCA title: set "cepa-main · coord@main" on term_self-1',
          REPOS["cepa-main"], sname="coord@main", env=TERM_ENV,
          argv=rename_argv("term_self-1", "cepa-main · coord@main"))
run_title("worker-handle", 'ORCA title: set "%s" on term_w-2' % TITLE, WT, term="term_w-2",
          env=TERM_ENV, argv=rename_argv("term_w-2"))
run_title("self-no-handle", skipped("ORCA_TERMINAL_HANDLE is unset, so this tab has no known handle"), WT)
run_title("self-dash-handle", BAD_TERM, WT, env={"ORCA_TERMINAL_HANDLE": "-x"})
run_title("worker-inject-handle", BAD_TERM, WT, term="term_1;touch pwned")
run_title("name-inject", BAD_NAME, WT, sname="tab7@roles;touch pwned", env=TERM_ENV)
run_title("name-subst", BAD_NAME, WT, sname="tab7@$(touch pwned)", env=TERM_ENV)
run_title("name-space", BAD_NAME, WT, sname="tab7 @roles", env=TERM_ENV)
run_title("name-quote", BAD_NAME, WT, sname="tab7@ro'les", env=TERM_ENV)
run_title("repo-space", skipped("the repo name holds a character outside [A-Za-z0-9._@-]"),
          REPOS["my repo"] + "-wt", env=TERM_ENV)
run_title("not-a-repo", skipped("git rev-parse --git-common-dir gave no <repo>/.git path"),
          os.path.join(GROOT, "nogit"), env=TERM_ENV)
run_title("rename-fails", "ORCA title: failed (orca-ide terminal rename failed or timed out)", WT,
          stub_body="exit 3", env=TERM_ENV)
run_title("rename-not-ok", 'ORCA title: failed (orca-ide terminal rename did not return "ok": true)',
          WT, stub_body='echo \'{"ok": "true"}\'', env=TERM_ENV)
run_title("rename-hangs", "ORCA title: failed (orca-ide terminal rename failed or timed out)", WT,
          stub_body=HANG, env=TERM_ENV, max_took=1.2)

# --- CITES ---
sec12 =re.search(r"^## 12\..*?(?=^## |\Z)", text, re.M | re.S)
prose = flat(re.sub(r"^( *)```bash\n.*?^\1```$", "", sec12.group(0), flags=re.M | re.S)) if sec12 else ""
if not sec12:
    miss("CITES: no ## 12. section in %s" % HOME)
for line in DO_NOT_PASTE + [TITLE_FORMAT]:
    (ok if line in prose else miss)("CITES: section 12 prose names %s" % line)
sites = {}
for n in RULE_CITES:
    p = os.path.join(SITES_DIR, n)
    try:
        sites[n] = open(p).read()
    except OSError as e:
        miss("CITES: cannot read %s: %s" % (p, e)); continue
    s = flat(sites[n])
    (ok if CITE in s else miss)("CITES: %s carries the §12 citation sentence" % n)
    (ok if RULE_CITES[n] in s else miss)("CITES: %s cites %s" % (n, RULE_CITES[n]))
fm = re.match(r"---\n(.*?)\n---\n", sites.get("handoff.md", ""), re.S)
tl = re.search(r"^allowed-tools:(.*)$", fm.group(1), re.M) if fm else None
if not tl:
    miss("CITES: handoff.md has no allowed-tools line in its frontmatter")
tools = tl.group(1) if tl else ""
for g, named in GRANTS.items():
    (ok if "Bash(%s:*)" % g in tools else miss)("CITES: handoff.md grants Bash(%s:*)" % g)
    (ok if named in prose else miss)("CITES: section 12 prose names %s" % named)
finish()
PY
