#!/usr/bin/env bash
# Check for Orca detection: section 12a of plugins/cepa/skills/autonomy/SKILL.md.
# 12a holds the one ```bash block that decides whether a session runs under
# Orca. This script READS that block from there and never carries its own
# copy, or an edit to the shipped block would leave it green while it tested
# something nobody runs.
#
# Usage: check-orca-detection.sh [SKILL.md]
#   The optional path replaces the shipped skill file. Only
#   check-orca-detection-controls.sh passes one, to run this check against a
#   mutant; the CITES leg still reads the shipped command files.
#
# Legs, in order:
#   BLOCK    — 12a holds exactly one ```bash block.
#   FIXTURES — the block runs under `bash -e`, in a separate process per case,
#              with PATH set to two directories this script builds: stub CLIs
#              (orca-ide, orca-dev, orca, uname) and links to the few real
#              tools the block needs (timeout, python3; sleep, touch and cat for the stubs). No real
#              Orca CLI is reachable. Every case asserts the exact output line.
#              A stub bare `orca` marks a file when it runs; every Linux case
#              asserts that file is absent. A case that runs past 25 seconds
#              is a MISS (the block bounds its probe at 10 + 2).
#   CITES    — /cepa:handoff, /cepa:task and /cepa:lfg each cite 12a and 12b;
#              handoff.md (the one of the three that declares allowed-tools)
#              grants each `orca-ide` verb in GRANTS, and 12 names each verb.
#
# The controls (check-orca-detection-controls.sh) mutate the block one
# substitution at a time and require this script to go red on each.
#
# STATED LIMITS — a green run does not mean:
#   - the real Orca CLI answers as the stubs do. The stub output copies the
#     shape `orca-ide status --json` returned on Orca 1.4.244 (2026-10-30);
#     a later Orca can change it, and only a live run would show that.
#   - the session's permission layer admits the block. The block is a compound
#     command with a variable CLI name, so an allowed-tools prefix grant cannot
#     match all of it; a denied probe reads as absent, which is today's
#     behavior.
#   - an agent follows 12b. This tests detection and the citations, not the
#     model that reads them.
#   - non-Linux hosts are covered by more than one stubbed `uname` case. The
#     `timeout` here is GNU coreutils; a host with none reads as absent.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

CEPA_ORCA_SKILL="${1:-plugins/cepa/skills/autonomy/SKILL.md}" python3 - <<'PY'
import os, re, shutil, subprocess, sys, tempfile, time

HOME = os.environ["CEPA_ORCA_SKILL"]
SITES = ["plugins/cepa/commands/handoff.md", "plugins/cepa/commands/task.md",
         "plugins/cepa/commands/lfg.md"]
GRANTS = ["orca-ide status", "orca-ide skills get", "orca-ide orchestration send"]
TOOLS = ["timeout", "python3", "sleep", "touch", "cat"]
STATUS_OK = '{\n  "id": "local-status",\n  "ok": true,\n  "result": {"runtime": {"ok": true}}\n}'
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

# --- BLOCK ---
try:
    text = open(HOME).read()
except OSError as e:
    miss("cannot read %s: %s" % (HOME, e)); finish()
m = re.search(r"^### 12a\..*?(?=^### |\Z)", text, re.M | re.S)
if not m:
    miss("no ### 12a. section in %s" % HOME); finish()
blocks = re.findall(r"^```bash\n(.*?)^```$", m.group(0), re.M | re.S)
if len(blocks) != 1:
    miss("12a holds %d ```bash blocks, want exactly 1" % len(blocks)); finish()
ok("12a holds one bash block")
block = os.path.join(TMP, "block.sh")
open(block, "w").write(blocks[0])

# --- FIXTURES ---
def stub(d, name, body):
    p = os.path.join(d, name)
    open(p, "w").write("#!/bin/sh\n" + body + "\n")
    os.chmod(p, 0o755)

def run_case(name, want, stubs=(), env=None, uname="Linux", drop=(), max_s=25):
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
    stub(sd, "orca", "touch %s/orca\ncat <<'J'\n%s\nJ" % (marks, STATUS_OK))
    for cli, body in stubs:
        stub(sd, cli, "touch %s/%s\n%s" % (marks, cli, body))
    e = {"PATH": sd + ":" + td, "HOME": case}
    e.update(env or {})
    t0 = time.time()
    try:
        r = subprocess.run(["/bin/bash", "-e", block], env=e, cwd=case,
                           capture_output=True, text=True, timeout=max_s)
    except subprocess.TimeoutExpired:
        miss("%s: still running after %ds" % (name, max_s)); return
    took = time.time() - t0
    out = r.stdout.strip()
    bad = []
    if r.returncode != 0:
        bad.append("rc=%d stderr=%r" % (r.returncode, r.stderr.strip()[:200]))
    if out != want:
        bad.append("got %r, want %r" % (out, want))
    if uname == "Linux" and os.path.exists(os.path.join(marks, "orca")):
        bad.append("bare `orca` ran on Linux")
    if env and "ORCA_CLI_COMMAND" in env and os.listdir(marks):
        bad.append("probed %s although ORCA_CLI_COMMAND was set" % os.listdir(marks))
    if bad:
        miss("%s: %s" % (name, "; ".join(bad)))
    else:
        ok("%s (%.1fs)" % (name, took))

def emit(s):
    return "cat <<'J'\n%s\nJ" % s

ABSENT_BAD = 'ORCA: absent (orca-ide status did not return "ok": true)'
ABSENT_FAIL = "ORCA: absent (orca-ide status failed or timed out)"
run_case("unset-no-cli", "ORCA: absent (orca-ide not on PATH)")
run_case("env-set-no-probe", "ORCA: present cli=orca-ide via=ORCA_CLI_COMMAND",
         stubs=[("orca-ide", emit(STATUS_OK))], env={"ORCA_CLI_COMMAND": "orca-ide"})
run_case("status-ok", "ORCA: present cli=orca-ide via=status",
         stubs=[("orca-ide", emit(STATUS_OK))])
run_case("status-ok-false", ABSENT_BAD,
         stubs=[("orca-ide", emit('{"ok": false, "result": {"ok": true}}'))])
run_case("status-not-json", ABSENT_BAD,
         stubs=[("orca-ide", emit('"ok": true\nnot json'))])
run_case("status-ok-string", ABSENT_BAD,
         stubs=[("orca-ide", emit('{"ok": "true"}'))])
run_case("status-json-list", ABSENT_BAD,
         stubs=[("orca-ide", emit('[{"ok": true}]'))])
run_case("status-empty", ABSENT_BAD, stubs=[("orca-ide", "true")])
run_case("status-nonzero-exit", ABSENT_FAIL,
         stubs=[("orca-ide", emit(STATUS_OK) + "\nexit 3")])
run_case("status-hangs-ignoring-TERM", ABSENT_FAIL,
         stubs=[("orca-ide", "trap '' TERM\nsleep 60")])
run_case("no-timeout-tool", "ORCA: absent (no timeout command to bound the status probe)",
         stubs=[("orca-ide", emit(STATUS_OK))], drop=("timeout",))
run_case("no-python3", ABSENT_BAD,
         stubs=[("orca-ide", emit(STATUS_OK))], drop=("python3",))
run_case("dev-checkout", "ORCA: present cli=orca-dev via=status",
         stubs=[("orca-dev", emit(STATUS_OK)), ("orca-ide", "exit 9")],
         env={"ORCA_DEV_REPO_ROOT": "/x"})
run_case("non-linux-uses-orca", "ORCA: present cli=orca via=status", uname="Darwin")

# --- CITES ---
sec12 = re.search(r"^## 12\..*?(?=^## |\Z)", text, re.M | re.S)
for p in SITES:
    try:
        s = open(p).read()
    except OSError as e:
        miss("cannot read %s: %s" % (p, e)); continue
    for ref in ("§12a", "§12b"):
        (ok if ref in s else miss)("%s cites %s" % (p, ref))
handoff = open(SITES[0]).read()
fm = re.match(r"---\n(.*?)\n---\n", handoff, re.S)
tools = re.search(r"^allowed-tools:(.*)$", fm.group(1), re.M).group(1) if fm else ""
for g in GRANTS:
    (ok if "Bash(%s:*)" % g in tools else miss)("handoff.md grants Bash(%s:*)" % g)
    verb = g.split(" ", 1)[1]
    (ok if sec12 and ("`%s`" % verb.split()[-1] in sec12.group(0) or verb in sec12.group(0))
     else miss)("section 12 names the verb %r" % verb)
finish()
PY
