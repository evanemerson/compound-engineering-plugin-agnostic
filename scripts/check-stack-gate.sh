#!/usr/bin/env bash
# Check for plugins/cepa/scripts/stack-gate.sh, the gate every worktree stack
# start goes through (punch-list L66). It runs the script with
# scripts/fixtures/stack-gate-docker-stub.py as `docker` on PATH, a fixture
# file as meminfo (CEPA_STACK_GATE_MEMINFO) and a throwaway HOME, so it never
# reaches Docker or the real config.
#
# Usage: check-stack-gate.sh [stack-gate.sh]
#   The optional path replaces the shipped script. Only
#   check-stack-gate-controls.sh sets it, to run this check against a mutant.
#
# Every MISS line starts with its case name, so the controls can assert the
# exact set of cases each mutant breaks. Every refused or usage case also
# asserts the start command did not run. Legs:
#   USAGE     — no arguments, no `--`, no command, a project without `-wt-`
#               or with shell text, `--count` with an argument, `--build`
#               with no compose command, HOME unset: exit 2.
#   CONFIG    — defaults (6 / 2048); a value is read; `010` is ten, not
#               octal eight; a bad, 7-digit or unknown entry WARNs and keeps
#               the default; shell text in the file never runs; a file that
#               exists but cannot be read refuses (skipped as root).
#   COUNT     — distinct projects, not containers; stopped (exited, created)
#               stacks, non-`-wt-` and non-compose containers and the
#               caller's own running stack are not counted; paused and
#               restarting stacks are; an empty working_dir label does not
#               shift the fields; a docker failure refuses; `docker ps` is
#               called, and never with -a.
#   MEM       — below the minimum refuses; exactly the minimum passes; a
#               missing file or a file with no MemAvailable refuses.
#   RUN       — one ok line, then the command; its exit code and argv come
#               through unchanged.
#   LOCK      — two starts on one count: the second waits and is refused; a
#               process the command leaves running does not hold the lock; a
#               held lock refuses after lock_wait_seconds and says it waited;
#               a gate nested for the same project runs at once, for another
#               project it waits and is refused. Ordering is by
#               sentinel (the first start's command touches a file; an outside
#               holder prints `ready` under flock), never by a sleep.
#   LIST      — a refusal lists every running `-wt-` stack, unknown idle
#               first, then longest idle first, with repo and lane; a hostile
#               label prints as `?`; a failed `docker inspect` is said.
#   COUNTMODE — `--count` prints its one line, exits 1 when docker fails or
#               the config cannot be read, takes no lock, creates nothing.
#   BUILD     — `--build` (L70 item 1) skips, with no lock, when every image
#               the project lists exists, read with the project name; it
#               builds when one is missing, the list is empty or cannot be
#               read; `--rebuild` always builds; the build's exit code comes
#               through; two builds run one at a time, and the waiting one
#               says so with the 3600 s default; a held build lock refuses
#               after build_wait_seconds; the build lock and the start lock
#               never wait on each other; the lock outlives a gate killed
#               mid-build; a build inside a gated command refuses; a failed
#               or killed build leaves a marker so the next --build builds,
#               and a success clears it; a build that waited for the same
#               project's build skips; an image name that is not a plain
#               reference builds and never reaches `docker image inspect`;
#               an unreadable config refuses (skipped as root).
#
# The stub is strict where the gate depends on docker's behavior: unknown ps
# flags exit 64, ids are 12 characters without --no-trunc, `label=` and
# `status=` filters apply. Temp dirs and lock holders are removed at exit.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

CEPA_SG_SCRIPT="$(realpath "${1:-plugins/cepa/scripts/stack-gate.sh}")" \
python3 - <<'PY'
import atexit, datetime, hashlib, json, os, shutil, subprocess, sys, tempfile, time

SCRIPT = os.environ["CEPA_SG_SCRIPT"]
STUB = os.path.realpath("scripts/fixtures/stack-gate-docker-stub.py")
passed = failed = 0
DIRS, PROCS = [], []


def cleanup():
    for pr in PROCS:
        try:
            pr.kill()
        except Exception:
            pass
    for d in DIRS:
        shutil.rmtree(d, ignore_errors=True)


atexit.register(cleanup)


def hexid(name):
    return hashlib.sha256(name.encode()).hexdigest()


def ago(sec):
    # Relative to the moment the fixture is built, not to the check's start:
    # a case that waits must not shift a later case's idle times.
    now = datetime.datetime.now(datetime.timezone.utc)
    return (now - datetime.timedelta(seconds=sec)).strftime("%Y-%m-%dT%H:%M:%S.123456789Z")


def miss(case, why):
    global failed
    failed += 1
    print(f"MISS {case}: {why}")


def ok():
    global passed
    passed += 1


class Env:
    def __init__(self, containers=(), conf=None, mem_mib=8000, meminfo=None, images=(), listed=""):
        self.root = tempfile.mkdtemp(prefix="cepa-sg-")
        DIRS.append(self.root)
        self.home = os.path.join(self.root, "home")
        os.makedirs(self.home)
        bindir = os.path.join(self.root, "bin")
        os.makedirs(bindir)
        # A wrapper, not a symlink: a stub that lost its exec bit would let
        # PATH fall through to the real docker and count this machine's stacks.
        with open(os.path.join(bindir, "docker"), "w") as f:
            f.write(f'#!/bin/sh\nexec python3 "{STUB}" "$@"\n')
        os.chmod(os.path.join(bindir, "docker"), 0o755)
        self.state = os.path.join(self.root, "state.json")
        with open(self.state, "w") as f:
            json.dump(list(containers), f)
        self.log = os.path.join(self.root, "docker.log")
        self.marker = os.path.join(self.root, "ran")
        self.meminfo = os.path.join(self.root, "meminfo")
        if meminfo is None:
            meminfo = f"MemTotal:       32000000 kB\nMemFree:  100 kB\nMemAvailable:   {mem_mib * 1024} kB\n"
        if meminfo is not False:
            with open(self.meminfo, "w") as f:
                f.write(meminfo)
        if conf is not None:
            os.makedirs(os.path.join(self.home, ".config", "cepa"))
            with open(os.path.join(self.home, ".config", "cepa", "stack-gate.conf"), "w") as f:
                f.write(conf)
        self.env = dict(os.environ, HOME=self.home, PATH=bindir + ":" + os.environ["PATH"],
                        STUB_DOCKER_STATE=self.state, STUB_DOCKER_LOG=self.log,
                        CEPA_STACK_GATE_MEMINFO=self.meminfo)
        self.env.pop("CEPA_STACK_GATE_CONF", None)
        self.env.pop("CEPA_STACK_GATE_HELD", None)
        self.images = os.path.join(self.root, "images.json")
        with open(self.images, "w") as f:
            json.dump(list(images), f)
        self.blog = os.path.join(self.root, "builds")
        self.env.update(STUB_DOCKER_IMAGES=self.images, STUB_COMPOSE_IMAGES=listed,
                        STUB_BUILD_LOG=self.blog)

    def builds(self):
        if not os.path.exists(self.blog):
            return []
        return [l.split() for l in open(self.blog).read().splitlines()]

    def hold_build_lock(self, secs):
        lockdir = os.path.join(self.home, ".config", "cepa")
        os.makedirs(lockdir, exist_ok=True)
        pr = subprocess.Popen(["flock", os.path.join(lockdir, "build.lock"), "sh", "-c",
                               f"echo ready; exec sleep {secs}"], stdout=subprocess.PIPE, text=True)
        PROCS.append(pr)
        if pr.stdout.readline().strip() != "ready":
            raise SystemExit("MISS harness: build lock holder never took the lock")
        return pr

    def touch_cmd(self):
        return ["touch", self.marker]

    def ran(self):
        return os.path.exists(self.marker)

    def run(self, args, extra_env=None, timeout=60, unset=(), stdin=None):
        env = dict(self.env, **(extra_env or {}))
        for k in unset:
            env.pop(k, None)
        try:
            return subprocess.run(["bash", SCRIPT] + args, env=env, capture_output=True,
                                  text=True, timeout=timeout, cwd=self.root)
        except subprocess.TimeoutExpired:
            return subprocess.CompletedProcess(args, -9, "", f"timed out after {timeout}s")

    def ps_logged(self):
        if not os.path.exists(self.log):
            return []
        return [a for a in (json.loads(l) for l in open(self.log)) if a and a[0] == "ps"]

    def hold_lock(self, secs):
        """Hold the gate's lock from outside; return only once it is held."""
        lockdir = os.path.join(self.home, ".config", "cepa")
        os.makedirs(lockdir, exist_ok=True)
        pr = subprocess.Popen(["flock", lockdir, "sh", "-c", f"echo ready; exec sleep {secs}"],
                              stdout=subprocess.PIPE, text=True)
        PROCS.append(pr)
        if pr.stdout.readline().strip() != "ready":
            raise SystemExit("MISS harness: lock holder never took the lock")
        return pr

    def popen(self, args):
        return subprocess.Popen(["bash", SCRIPT] + args, env=self.env, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, text=True, cwd=self.root)


def wt(project, n=1, state="running", wd=None, started=3600, idp=None):
    wd = wd if wd is not None else f"/home/u/webapps/{project.split('-wt-')[0]}/.claude/worktrees/{project.split('-wt-')[1]}"
    return [{"project": project, "wd": wd, "id": hexid(f"{idp or project}-c{k}"), "state": state,
             "started": ago(started)} for k in range(n)]


def stacks(k, prefix="r-wt-s"):
    out = []
    for i in range(k):
        out += wt(f"{prefix}{i}", started=600 * (i + 1))
    return out


def gate_line(out):
    return [l for l in out.splitlines() if l.startswith("STACK gate:")]


def expect_refused(case, e, r, must=()):
    if r.returncode != 3:
        return miss(case, f"rc {r.returncode}, want 3; out={r.stdout!r} err={r.stderr!r}")
    if e.ran():
        return miss(case, "start command ran on a refusal")
    lines = gate_line(r.stdout)
    if len(lines) != 1 or not lines[0].startswith("STACK gate: refused — "):
        return miss(case, f"want one refused line, got {r.stdout!r}")
    for m in must:
        if m not in lines[0]:
            return miss(case, f"{m!r} not in {lines[0]!r}")
    ok()


def expect_ok(case, e, r, must=(), warn=None):
    if r.returncode != 0:
        return miss(case, f"rc {r.returncode}, want 0; out={r.stdout!r} err={r.stderr!r}")
    if not e.ran():
        return miss(case, "start command did not run")
    lines = gate_line(r.stdout)
    if len(lines) != 1 or not lines[0].startswith("STACK gate: ok — ") or not r.stdout.startswith("STACK gate: ok"):
        return miss(case, f"want one ok line first, got {r.stdout!r}")
    for m in must:
        if m not in lines[0]:
            return miss(case, f"{m!r} not in {lines[0]!r}")
    if warn is not None:
        if warn not in r.stderr:
            return miss(case, f"no WARN {warn!r} on stderr: {r.stderr!r}")
        if "WARN" in r.stdout:
            return miss(case, "WARN on stdout")
    ok()


# ---------------- USAGE ----------------
for case, args in [
    ("USAGE no arguments", []),
    ("USAGE no --", ["a-wt-b", "TOUCH"]),
    ("USAGE no command", ["a-wt-b", "--"]),
    ("USAGE project without -wt-", ["dpcpro", "--", "TOUCH"]),
    ("USAGE project with shell text", ["a-wt-$(id)", "--", "TOUCH"]),
    ("USAGE --count with argument", ["--count", "x"]),
    ("USAGE --build with no command", ["--build", "a-wt-b", "--"]),
]:
    e = Env()
    args = [a if a != "TOUCH" else "touch" for a in args] + ([e.marker] if "TOUCH" in args else [])
    r = e.run(args)
    if r.returncode != 2:
        miss(case, f"rc {r.returncode}, want 2; out={r.stdout!r} err={r.stderr!r}")
    elif e.ran():
        miss(case, "start command ran")
    else:
        ok()

e = Env()
r = e.run(["n-wt-x", "--"] + e.touch_cmd(), unset=("HOME",))
if r.returncode != 2 or e.ran() or "STACK gate: usage — HOME is not set" not in r.stderr:
    miss("USAGE HOME unset", f"rc {r.returncode}, ran {e.ran()}, err {r.stderr!r}")
else:
    ok()

# ---------------- CONFIG ----------------
e = Env(stacks(5)); expect_ok("CONFIG default limit 6 passes 5", e, e.run(["n-wt-x", "--"] + e.touch_cmd()), ["limit 6", "minimum 2048 MiB"])
e = Env(stacks(6)); expect_refused("CONFIG default limit 6 refuses 6", e, e.run(["n-wt-x", "--"] + e.touch_cmd()), ["limit 6"])
e = Env(stacks(2), conf="max_running=2\n"); expect_refused("CONFIG limit is read", e, e.run(["n-wt-x", "--"] + e.touch_cmd()), ["limit 2"])
e = Env(stacks(9), conf="# limit\n\nmax_running = 010 \r\n"); expect_ok("CONFIG leading zero is decimal", e, e.run(["n-wt-x", "--"] + e.touch_cmd()), ["limit 10"])
e = Env(stacks(5), conf="max_running=abc\n"); expect_ok("CONFIG bad value warns, default kept", e, e.run(["n-wt-x", "--"] + e.touch_cmd()), ["limit 6"], warn="WARN")
e = Env(stacks(6), conf="max_running=1234567\n"); r = e.run(["n-wt-x", "--"] + e.touch_cmd())
if "WARN" not in r.stderr:
    miss("CONFIG seven digits warns, default kept", f"no WARN: {r.stderr!r}")
else:
    expect_refused("CONFIG seven digits warns, default kept", e, r, ["limit 6"])
e = Env(stacks(1), conf="colour=9\n"); expect_ok("CONFIG unknown key warns", e, e.run(["n-wt-x", "--"] + e.touch_cmd()), ["limit 6"], warn="unknown key")
e = Env(stacks(1))
pwn = os.path.join(e.root, "PWN")
os.makedirs(os.path.join(e.home, ".config", "cepa"))
with open(os.path.join(e.home, ".config", "cepa", "stack-gate.conf"), "w") as f:
    f.write(f"max_running=$(touch {pwn}1)\nmax_running=1; touch {pwn}2\ntouch {pwn}3\nmax_running=`touch {pwn}4`\n")
r = e.run(["n-wt-x", "--"] + e.touch_cmd())
if any(os.path.exists(f"{pwn}{k}") for k in range(1, 5)):
    miss("CONFIG shell text never runs", "a config line ran")
else:
    expect_ok("CONFIG shell text never runs", e, r, ["limit 6"], warn="WARN")
e = Env(stacks(1), conf="max_running=1\n")
os.chmod(os.path.join(e.home, ".config", "cepa", "stack-gate.conf"), 0)
if os.access(os.path.join(e.home, ".config", "cepa", "stack-gate.conf"), os.R_OK):
    ok()  # running as root: an unreadable file cannot be made; nothing to test
else:
    expect_refused("CONFIG unreadable file refuses", e, e.run(["n-wt-x", "--"] + e.touch_cmd()), ["cannot read the config"])
e = Env(conf="min_available_mib=4000\n", mem_mib=3000)
expect_refused("CONFIG minimum memory is read", e, e.run(["n-wt-x", "--"] + e.touch_cmd()), ["3000 MiB available, minimum 4000 MiB"])

# ---------------- COUNT ----------------
e = Env(wt("big-wt-a", n=4), conf="max_running=2\n")
expect_ok("COUNT projects, not containers", e, e.run(["n-wt-x", "--"] + e.touch_cmd()), ["1 other running -wt- stacks"])
e = Env(wt("r-wt-a", state="exited") + wt("r-wt-b", state="exited"), conf="max_running=1\n")
expect_ok("COUNT stopped stacks not counted", e, e.run(["n-wt-x", "--"] + e.touch_cmd()), ["0 other running"])
if not e.ps_logged():
    miss("COUNT stopped stacks not counted", "docker ps was never called")
elif any("-a" in a or "--all" in a for a in e.ps_logged()):
    miss("COUNT stopped stacks not counted", "docker ps was called with -a")
e = Env(wt("r-wt-p", state="paused") + wt("r-wt-q", state="restarting") + wt("r-wt-c", state="created"),
        conf="max_running=2\n")
expect_refused("COUNT paused and restarting stacks count", e, e.run(["n-wt-x", "--"] + e.touch_cmd()),
               ["2 running -wt- stacks other than n-wt-x"])
e = Env(wt("r-wt-e", wd=""), conf="max_running=1\n")
expect_refused("COUNT empty working_dir label still counts", e, e.run(["n-wt-x", "--"] + e.touch_cmd()),
               ["r-wt-e (repo r, lane unknown, idle 1h0m)"])
e = Env([{"project": p, "wd": "/x/" + p, "id": hexid(p), "state": "running", "started": ago(60)}
         for p in ("dpcpro", "helm", "traefik")]
        + [{"id": hexid("plain"), "state": "running", "started": ago(60)}], conf="max_running=1\n")
expect_ok("COUNT non-wt projects not counted", e, e.run(["n-wt-x", "--"] + e.touch_cmd()), ["0 other running"])
e = Env(wt("n-wt-x", n=2), conf="max_running=1\n")
expect_ok("COUNT own running stack not counted", e, e.run(["n-wt-x", "--"] + e.touch_cmd()), ["0 other running", "already running"])
e = Env(stacks(1)); expect_refused("COUNT docker failure refuses", e, e.run(["n-wt-x", "--"] + e.touch_cmd(), {"STUB_DOCKER_FAIL": "ps"}), ["cannot count"])

# ---------------- MEM ----------------
e = Env(mem_mib=1000); expect_refused("MEM below minimum refuses", e, e.run(["n-wt-x", "--"] + e.touch_cmd()), ["1000 MiB available"])
e = Env(mem_mib=2048); expect_ok("MEM exactly the minimum passes", e, e.run(["n-wt-x", "--"] + e.touch_cmd()), ["2048 MiB available"])
e = Env(meminfo=False); expect_refused("MEM missing file refuses", e, e.run(["n-wt-x", "--"] + e.touch_cmd()), ["MemAvailable"])
e = Env(meminfo="MemTotal: 100 kB\nMemFree: 99999999 kB\n"); expect_refused("MEM no MemAvailable line refuses", e, e.run(["n-wt-x", "--"] + e.touch_cmd()), ["MemAvailable"])

# ---------------- RUN ----------------
e = Env()
r = e.run(["n-wt-x", "--", "bash", "-c", f"touch {e.marker}; exit 7"])
if r.returncode != 7:
    miss("RUN exit code comes through", f"rc {r.returncode}, want 7: {r.stdout!r} {r.stderr!r}")
elif not e.ran() or not r.stdout.startswith("STACK gate: ok — "):
    miss("RUN exit code comes through", f"command not run after the ok line: {r.stdout!r}")
else:
    ok()
e = Env()
r = e.run(["n-wt-x", "--", "printf", "%s|", "a b", "$HOME", "*", "x;y"])
want = "a b|$HOME|*|x;y|"
if r.returncode != 0 or r.stdout.split("\n", 1)[-1] != want:
    miss("RUN argv kept", f"want {want!r} after the gate line, got {r.stdout!r}")
else:
    ok()

# ---------------- LOCK ----------------
e = Env(conf="max_running=1\n")
add = lambda p, d: ["bash", "-c", f'touch {e.root}/entered-{p}; sleep {d}; python3 "$0" add {p} /w/{p} {hexid(p)}; echo {p} >> {e.root}/started', STUB]
pa = e.popen(["a-wt-a", "--"] + add("a-wt-a", 1.5))
PROCS.append(pa)
deadline = time.time() + 30
while not os.path.exists(f"{e.root}/entered-a-wt-a") and time.time() < deadline:
    time.sleep(0.05)
pb = e.popen(["b-wt-b", "--"] + add("b-wt-b", 0))
PROCS.append(pb)
try:
    ra, rb = pa.communicate(timeout=60), pb.communicate(timeout=60)
except subprocess.TimeoutExpired:
    rb = ("timed out", "")
started = open(f"{e.root}/started").read().split() if os.path.exists(f"{e.root}/started") else []
if pa.returncode != 0 or pb.returncode != 3 or started != ["a-wt-a"]:
    miss("LOCK two starts on one count", f"a rc {pa.returncode}, b rc {pb.returncode}, started {started}; b out {rb[0]!r}")
else:
    ok()
e = Env(conf="lock_wait_seconds=2\n")
r1 = e.run(["a-wt-a", "--", "bash", "-c", "sleep 8 >/dev/null 2>&1 & exit 0"])
r2 = e.run(["b-wt-b", "--"] + e.touch_cmd())
if r1.returncode != 0 or r2.returncode != 0 or not e.ran():
    miss("LOCK not held by a process the command leaves", f"rc {r1.returncode}/{r2.returncode}; {r2.stdout!r}")
else:
    ok()
e = Env(conf="lock_wait_seconds=1\n")
e.hold_lock(6)
r = e.run(["n-wt-x", "--"] + e.touch_cmd())
expect_refused("LOCK held lock refuses after the wait", e, r, ["lock busy"])
if "STACK gate: waiting up to 1s" not in r.stderr:
    miss("LOCK a waiting start says so", f"no waiting line on stderr: {r.stderr!r}")
else:
    ok()
e = Env(conf="lock_wait_seconds=2\n")
r = e.run(["n-wt-x", "--", "bash", SCRIPT, "n-wt-x", "--"] + e.touch_cmd())
if r.returncode != 0 or not e.ran() or "nested inside a gate" not in r.stdout:
    miss("LOCK nested gate for the same project runs", f"rc {r.returncode}, ran {e.ran()}, out {r.stdout!r}")
else:
    ok()
e = Env(conf="lock_wait_seconds=1\n")
r = e.run(["n-wt-x", "--", "bash", SCRIPT, "o-wt-y", "--"] + e.touch_cmd(), timeout=20)
# The inner gate's own line is what matters; the outer passes its rc through.
if e.ran() or "STACK gate: refused — lock busy" not in r.stdout:
    miss("LOCK nested gate for another project waits", f"rc {r.returncode}, ran {e.ran()}, out {r.stdout!r}")
else:
    ok()

# ---------------- LIST ----------------
conts = (wt("dpcpro-wt-apgar-765bd2", n=3, wd="/home/u/webapps/dpc-pro/.claude/worktrees/apgar", started=7200)
         + wt("contexthub-wt-lorena-9da911", wd="/home/u/orca/workspaces/contexthub/lorena", started=300)
         + wt("helm-wt-lane1-3e9f61", wd="/srv/odd/lane1", started=90000))
# the newest container of a stack sets its idle time: one dpcpro container started 2h ago, one 1h ago
conts[1]["started"] = ago(3600)
e = Env(conts, conf="max_running=3\n")
r = e.run(["n-wt-x", "--"] + e.touch_cmd())
want = ("running -wt- stacks, unknown idle then longest idle first: "
        "helm-wt-lane1-3e9f61 (repo helm, lane lane1, idle 1d1h); "
        "dpcpro-wt-apgar-765bd2 (repo dpc-pro, lane apgar, idle 1h0m); "
        "contexthub-wt-lorena-9da911 (repo contexthub, lane lorena, idle 5m)")
expect_refused("LIST every stack, longest idle first, repo and lane", e, r, [want])
e = Env(wt("x-wt-y", wd="/w/$(id);`id` \x1b[31mred"), conf="max_running=1\n")
r = e.run(["n-wt-x", "--"] + e.touch_cmd())
lines = gate_line(r.stdout)
bad = [c for c in "$`\x1b" if lines and c in lines[0]]
if r.returncode != 3 or not lines or bad or "lane ??id???id????31mred," not in lines[0]:
    miss("LIST hostile label prints as ?", f"rc {r.returncode}, bad {bad}, line {lines!r}")
else:
    ok()

conts = wt("a-wt-old", started=18000) + wt("b-wt-bad", started=60)
conts[1]["started"] = "not-a-date"
e = Env(conts, conf="max_running=2\n")
expect_refused("LIST unreadable start time sorts first", e, e.run(["n-wt-x", "--"] + e.touch_cmd()),
               ["first: b-wt-bad (repo b, lane bad, idle unknown); a-wt-old (repo a, lane old, idle 5h0m)"])
e = Env(stacks(2), conf="max_running=2\n")
r = e.run(["n-wt-x", "--"] + e.touch_cmd(), {"STUB_DOCKER_FAIL": "inspect"})
expect_refused("LIST inspect failure is said", e, r, ["idle unknown", "(docker inspect failed: idle times unknown)"])

# ---------------- COUNTMODE ----------------
e = Env(stacks(2) + wt("r-wt-z", state="exited") + [{"project": "helm", "wd": "/h", "id": hexid("h"), "state": "running", "started": ago(5)}])
r = e.run(["--count"])
if r.returncode != 0 or r.stdout != "STACK count: running=2 limit=6\n":
    miss("COUNTMODE one line", f"rc {r.returncode}, out {r.stdout!r}")
else:
    ok()
e = Env(conf="max_running=3\n")
r = e.run(["--count"], {"STUB_DOCKER_FAIL": "ps"})
if r.returncode != 1 or not r.stdout.startswith("STACK count: running=unknown limit=3 — ") or r.stdout.count("\n") != 1:
    miss("COUNTMODE docker failure is unknown", f"rc {r.returncode}, out {r.stdout!r}")
else:
    ok()
e = Env(stacks(1), conf="max_running=1\n")
os.chmod(os.path.join(e.home, ".config", "cepa", "stack-gate.conf"), 0)
r = e.run(["--count"])
if os.access(os.path.join(e.home, ".config", "cepa", "stack-gate.conf"), os.R_OK):
    ok()
elif r.returncode != 1 or not r.stdout.startswith("STACK count: running=unknown"):
    miss("COUNTMODE unreadable config is unknown", f"rc {r.returncode}, out {r.stdout!r}")
else:
    ok()
e = Env(stacks(1), conf="lock_wait_seconds=30\n")
e.hold_lock(8)
t0 = time.time()
r = e.run(["--count"])
if r.returncode != 0 or time.time() - t0 > 4:
    miss("COUNTMODE takes no lock", f"rc {r.returncode}, {time.time() - t0:.1f}s")
else:
    ok()
e = Env(stacks(1))
r = e.run(["--count"])
if r.returncode != 0 or os.path.exists(os.path.join(e.home, ".config")):
    miss("COUNTMODE creates nothing", f"rc {r.returncode}, .config exists: {os.path.exists(os.path.join(e.home, '.config'))}")
else:
    ok()

# ---------------- BUILD ----------------
COMPOSE = ["docker", "compose", "-f", "dev.yml"]
LISTED = "{p}-web,{p}-worker,postgres:16"


def bargs(proj="n-wt-x", mode="--build"):
    return [mode, proj, "--"] + COMPOSE


def built(e, proj="n-wt-x"):
    return [b for b in e.builds() if b[0] == "start" and b[1] == proj]


have = ["n-wt-x-web", "n-wt-x-worker", "postgres:16"]
e = Env(images=have, listed=LISTED)
e.hold_build_lock(8)
t0 = time.time()
r = e.run(bargs())
if (r.returncode != 0 or time.time() - t0 > 4 or built(e)
        or r.stdout != "STACK build: skipped — n-wt-x: all 3 images exist (--rebuild builds anyway)\n"):
    miss("BUILD skip when every image exists, no lock", f"rc {r.returncode}, {time.time() - t0:.1f}s, builds {e.builds()}, out {r.stdout!r}")
else:
    ok()
for case, imgs, listed, env in [
    ("BUILD a missing image builds", have[:2], LISTED, None),
    ("BUILD an empty image list builds", have, "", None),
    ("BUILD an unreadable image list builds", have, LISTED, {"STUB_DOCKER_FAIL": "config"}),
]:
    e = Env(images=imgs, listed=listed)
    r = e.run(bargs(), env)
    if r.returncode != 0 or len(built(e)) != 1 or not r.stdout.startswith("STACK build: building — n-wt-x: "):
        miss(case, f"rc {r.returncode}, builds {e.builds()}, out {r.stdout!r} err {r.stderr!r}")
    else:
        ok()
e = Env(images=have, listed=LISTED)
r = e.run(bargs(mode="--rebuild"))
if r.returncode != 0 or len(built(e)) != 1 or "STACK build: building — n-wt-x: rebuild asked" not in r.stdout:
    miss("BUILD --rebuild always builds", f"rc {r.returncode}, builds {e.builds()}, out {r.stdout!r}")
else:
    ok()
e = Env(listed=LISTED)
r = e.run(bargs(), {"STUB_BUILD_RC": "5"})
if r.returncode != 5 or len(built(e)) != 1:
    miss("BUILD exit code comes through", f"rc {r.returncode}, want 5; builds {e.builds()}")
else:
    ok()
# Two builds of different lanes: the second starts only after the first ends.
e = Env(listed=LISTED)
e.env["STUB_BUILD_SLEEP"] = "2"
pa = e.popen(bargs("a-wt-a"))
PROCS.append(pa)
deadline = time.time() + 30
while not built(e, "a-wt-a") and time.time() < deadline:
    time.sleep(0.05)
pb = e.popen(bargs("b-wt-b"))
PROCS.append(pb)
try:
    oa, ob = pa.communicate(timeout=60), pb.communicate(timeout=60)
except subprocess.TimeoutExpired:
    oa = ob = ("timed out", "")
ev = {(b[0], b[1]): float(b[2]) for b in e.builds()}
if (pa.returncode != 0 or pb.returncode != 0 or len(ev) != 4
        or ev[("start", "b-wt-b")] < ev[("end", "a-wt-a")]):
    miss("BUILD two builds run one at a time", f"rc {pa.returncode}/{pb.returncode}, builds {e.builds()}")
else:
    ok()
if "STACK build: waiting up to 3600s for another build's lock" not in ob[1]:
    miss("BUILD a waiting build says so, default 3600 s", f"no waiting line: {ob[1]!r}")
else:
    ok()
e = Env(listed=LISTED, conf="build_wait_seconds=1\n")
e.hold_build_lock(6)
r = e.run(bargs())
if r.returncode != 3 or built(e) or not r.stdout.startswith("STACK build: refused — lock busy"):
    miss("BUILD held build lock refuses after the wait", f"rc {r.returncode}, builds {e.builds()}, out {r.stdout!r}")
else:
    ok()
e = Env(listed=LISTED, conf="lock_wait_seconds=1\nbuild_wait_seconds=1\n")
e.hold_lock(6)
r = e.run(bargs())
e2 = Env(conf="lock_wait_seconds=1\nbuild_wait_seconds=1\n")
e2.hold_build_lock(6)
r2 = e2.run(["n-wt-x", "--"] + e2.touch_cmd())
if r.returncode != 0 or len(built(e)) != 1 or r2.returncode != 0 or not e2.ran():
    miss("BUILD build lock and start lock are separate", f"build rc {r.returncode} {r.stdout!r}; start rc {r2.returncode} {r2.stdout!r}")
else:
    ok()
# A gate killed mid-build: its build still runs, so the lock must stay held.
e = Env(listed=LISTED, conf="build_wait_seconds=1\n")
e.env["STUB_BUILD_SLEEP"] = "5"
pa = e.popen(bargs("a-wt-a"))
PROCS.append(pa)
deadline = time.time() + 30
while not built(e, "a-wt-a") and time.time() < deadline:
    time.sleep(0.05)
pa.kill()
pa.wait()
e.env["STUB_BUILD_SLEEP"] = "0"
r2 = e.run(bargs("b-wt-b"))
if r2.returncode != 3 or built(e, "b-wt-b") or "lock busy" not in r2.stdout:
    miss("BUILD lock outlives a gate killed mid-build", f"rc {r2.returncode}, builds {e.builds()}, out {r2.stdout!r}")
else:
    ok()
if not os.path.exists(os.path.join(e.home, ".config", "cepa", "build-failed.a-wt-a")):
    miss("BUILD a killed build leaves its marker", "no build-failed marker after the gate was killed")
else:
    ok()
# A failed rebuild (which still tagged images) must not let the next --build skip.
e = Env(images=have, listed=LISTED)
r1 = e.run(bargs(mode="--rebuild"), {"STUB_BUILD_RC": "5"})
r2 = e.run(bargs())
r3 = e.run(bargs())
if (r1.returncode != 5 or r2.returncode != 0 or len(built(e)) != 2
        or "last build of this project failed" not in r2.stdout or not r3.stdout.startswith("STACK build: skipped")):
    miss("BUILD a failed build is built again, a success clears it",
         f"rc {r1.returncode}/{r2.returncode}/{r3.returncode}, builds {e.builds()}, out2 {r2.stdout!r} out3 {r3.stdout!r}")
else:
    ok()
# Two --build calls for ONE project: the second waits, then finds the images.
e = Env(listed=LISTED)
e.env["STUB_BUILD_SLEEP"] = "2"
pa = e.popen(bargs())
PROCS.append(pa)
deadline = time.time() + 30
while not built(e) and time.time() < deadline:
    time.sleep(0.05)
pb = e.popen(bargs())
PROCS.append(pb)
try:
    oa, ob = pa.communicate(timeout=60), pb.communicate(timeout=60)
except subprocess.TimeoutExpired:
    ob = ("timed out", "")
if pa.returncode != 0 or pb.returncode != 0 or len(built(e)) != 1 or "built while this one waited" not in ob[0]:
    miss("BUILD a waiter skips once the same project was built", f"rc {pa.returncode}/{pb.returncode}, builds {e.builds()}, out {ob[0]!r}")
else:
    ok()
# An image name that is not a plain reference builds, even when it "exists".
e = Env(images=have + ["-x", "a b", "/web:"], listed=LISTED + ",-x,a b,/web:")
r = e.run(bargs())
inspected = [a for a in (json.loads(l) for l in open(e.log)) if a[:2] == ["image", "inspect"]] if os.path.exists(e.log) else []
if r.returncode != 0 or len(built(e)) != 1 or "not a plain reference" not in r.stdout or inspected:
    miss("BUILD a name that is not a plain reference builds", f"rc {r.returncode}, builds {e.builds()}, inspected {inspected}, out {r.stdout!r}")
else:
    ok()
e = Env(listed=LISTED, conf="build_wait_seconds=5\n")
cf = os.path.join(e.home, ".config", "cepa", "stack-gate.conf")
os.chmod(cf, 0)
if os.access(cf, os.R_OK):
    ok()  # running as root: an unreadable file cannot be made
else:
    r = e.run(bargs())
    if r.returncode != 3 or built(e) or "STACK build: refused — cannot read the config" not in r.stdout:
        miss("BUILD unreadable config refuses", f"rc {r.returncode}, builds {e.builds()}, out {r.stdout!r}")
    else:
        ok()
e = Env(listed=LISTED)
r = e.run(bargs(), {"CEPA_STACK_GATE_HELD": "n-wt-x"})
if r.returncode != 3 or e.builds() or not r.stdout.startswith("STACK build: refused — inside a gated command"):
    miss("BUILD inside a gated command refuses", f"rc {r.returncode}, builds {e.builds()}, out {r.stdout!r}")
else:
    ok()

print(f"check-stack-gate: {passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
PY
