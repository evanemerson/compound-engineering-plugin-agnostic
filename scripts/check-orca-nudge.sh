#!/usr/bin/env bash
# Check for plugins/cepa/scripts/orca-nudge.sh, the one checked form of
# `cepa:autonomy` §12b rule 1's nudge. It runs the script against a stub
# `orca-ide` on PATH and never reaches a real terminal: the stub answers
# `terminal show`, `worktree ps` and `terminal send` from env vars and logs
# every call it gets. Stub `sleep` and `date` on the same PATH give the script
# a fake clock, so the 120-second wait costs no real time. The script reads no
# env var for its clock or its bound; only the PATH is changed.
#
# Usage: check-orca-nudge.sh [orca-nudge.sh]
#   The optional path replaces the shipped script. Only
#   check-orca-nudge-controls.sh sets it, to run this check against a mutant.
#
# Every MISS line starts with its case name, so the controls can assert the
# exact set of cases each mutant breaks. Cases, by leg:
#   SEND     — state `done`: exit 0, prints `sent`, and makes exactly one
#              `terminal send` whose argv is the fixed list (the text is one
#              argument, `--enter`, no `--interrupt`). The `terminal show` and
#              `worktree ps` argv are pinned too. `orca-dev`, a cli path equal
#              to ORCA_CLI_COMMAND, and a row in a later worktree also send.
#   STATE    — `waiting`, `blocked`, a state that is not a plain word, no
#              state, no agent row, two rows, and a `done` row that is not the
#              target's while the target's is `waiting`: each exits 1, prints
#              `skipped` with its reason, never sends, and never sleeps.
#   WAIT     — `working`: the script re-reads the row every 10 seconds for at
#              most 120. Turning `done` sends; turning `waiting` skips at once
#              with that reason; still `working` at the bound exits 1 with
#              "still working after 120 seconds" having slept exactly 120, the
#              last sleep clamped when the clock is off the poll grid. An env
#              var named like the bound does not change it. A `worktree ps`
#              failure mid-wait, a bad clock, or a failed sleep each skips
#              with its own reason.
#   LOOKUP   — `terminal show` echoes another handle, gives empty tab/leaf
#              ids, fails, or is not ok; `worktree ps` fails, is not ok, or is
#              JSON of the wrong shape:
#              each is skipped, no send.
#   REFUSE   — a bad cli (a path that is not ORCA_CLI_COMMAND included, or a
#              name not on PATH) or handle, or the wrong argument count: exit 2,
#              prints `refused`, and the stub is never called.
#   FAIL     — `terminal send` exits non-zero, or returns `"ok"` that is not
#              the value true:
#              exit 3, prints `failed`.
#
# STATED LIMITS — a green run does not mean:
#   - Orca's real output has this shape. The stub replays the shape measured on
#     2026-10-30 (see the script's header); a later Orca may differ, and then
#     the script skips.
#   - the nudge is safe on a `done` target. `done` was the idle state in the
#     L26 probe; the check pins that the script trusts nothing else.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

CEPA_NUDGE_SCRIPT="${1:-plugins/cepa/scripts/orca-nudge.sh}" python3 - <<'PY'
import json, os, shutil, subprocess, sys, tempfile

SCRIPT = os.path.abspath(os.environ["CEPA_NUDGE_SCRIPT"])
H = "term_5c81eb74-a55a-4a1e-b450-81e09827d825"
OTHER = "term_00000000-0000-0000-0000-000000000000"
KEY = "tab-1:leaf-1"
TEXT = "You have 1 orchestration message. Run orca-ide orchestration check --peek --json"
SEND_ARGV = ["terminal", "send", "--terminal", H, "--text", TEXT, "--enter", "--json"]

TMP = tempfile.mkdtemp(prefix="cepa-nudge-chk-")
BIN = os.path.join(TMP, "bin")
os.mkdir(BIN)
STUB = os.path.join(BIN, "orca-ide")
# One call per line, argv as a JSON list, so a space inside an argument stays
# inside it.
open(STUB, "w").write(r'''#!/usr/bin/env bash
python3 -I -c 'import json, sys; open(sys.argv[1], "a").write(json.dumps(sys.argv[2:]) + "\n")' "$STUB_LOG" "$@"
case "$1 $2" in
  "terminal show") [ "$STUB_SHOW_RC" = 0 ] || exit "$STUB_SHOW_RC"; printf '%s' "$STUB_SHOW" ;;
  "worktree ps") [ "$STUB_PS_RC" = 0 ] || exit "$STUB_PS_RC"
    # STUB_PS is one output, or a JSON list played in order with the last
    # repeated; STUB_PS_RC_SEQ is the same for the exit code. Each call adds
    # STUB_PS_TICK seconds to the fake clock. Past 100 calls it fails, so a
    # mutant that never stops waiting ends fast, as a skip.
    python3 -I -c '
import json, os, sys
n = sum(1 for l in open(os.environ["STUB_LOG"]) if l.startswith("[\"worktree\", \"ps\""))
if n > 100: sys.exit(99)
c = os.environ["STUB_CLOCK"]
now = int(open(c).read()) + int(os.environ.get("STUB_PS_TICK", "0"))
open(c, "w").write("%d\n" % now)
rcs = json.loads(os.environ.get("STUB_PS_RC_SEQ", "[0]"))
if rcs[min(n, len(rcs)) - 1]: sys.exit(rcs[min(n, len(rcs)) - 1])
v = os.environ["STUB_PS"]
seq = json.loads(v) if v.startswith("[") else [v]
sys.stdout.write(seq[min(n, len(seq)) - 1])' ;;
  "terminal send") printf '%s' "$STUB_SEND"; exit "$STUB_SEND_RC" ;;
  *) exit 64 ;;
esac
''')
os.chmod(STUB, 0o755)
# The same stub answers to orca and orca-dev, so a mutant that admits bare
# `orca` calls the stub and never the GNOME screen reader.
for alias in ("orca", "orca-dev"):
    os.symlink(STUB, os.path.join(BIN, alias))
# The fake clock: `date +%s` prints the clock file, `sleep N` adds N to it and
# logs N. Any other use of either is a failure the check can see.
# STUB_DATE replaces the clock's answer; STUB_SLEEP_RC makes sleep fail.
open(os.path.join(BIN, "date"), "w").write('''#!/usr/bin/env bash
[ "$*" = "+%s" ] || exit 64
[ -z "${STUB_DATE-}" ] || { echo "$STUB_DATE"; exit 0; }
cat "$STUB_CLOCK"
''')
open(os.path.join(BIN, "sleep"), "w").write('''#!/usr/bin/env bash
[ $# -eq 1 ] && [[ $1 =~ ^[0-9]+$ ]] || exit 64
[ "${STUB_SLEEP_RC:-0}" = 0 ] || exit "$STUB_SLEEP_RC"
echo "$1" >>"$STUB_SLEEPS"
echo $(( $(cat "$STUB_CLOCK") + $1 )) >"$STUB_CLOCK"
''')
for f in ("date", "sleep"):
    os.chmod(os.path.join(BIN, f), 0o755)

def show(handle=H, tab="tab-1", leaf="leaf-1"):
    return json.dumps({"ok": True, "result": {"terminal": {"handle": handle, "tabId": tab, "leafId": leaf}}})

def ps(*rows, later=()):
    wts = [{"agents": list(rows)}] + ([{"agents": list(later)}] if later else [])
    return json.dumps({"ok": True, "result": {"worktrees": wts}})

def row(state, key=KEY, **kw):
    r = {"paneKey": key, "displayName": "target", **kw}
    if state is not None:
        r["state"] = state
    return r

passed = failed = 0

def ok(msg):
    global passed; passed += 1; print("PASS", msg)

def miss(msg):
    global failed; failed += 1; print("MISS", msg)

def run(args, show_json=None, ps_json=None, show_rc=0, ps_rc=0,
        send='{"ok": true}', send_rc=0, env_extra=None, path=None):
    log, clock, slog = (os.path.join(TMP, f) for f in ("log", "clock", "sleeps"))
    open(log, "w").close()
    open(slog, "w").close()
    open(clock, "w").write("1000000\n")
    env = dict(os.environ, PATH=BIN + os.pathsep + os.environ.get("PATH", ""),
               STUB_LOG=log, STUB_CLOCK=clock, STUB_SLEEPS=slog, STUB_SHOW=show_json if show_json is not None else show(),
               STUB_PS=ps_json if ps_json is not None else ps(row("done")),
               STUB_SHOW_RC=str(show_rc), STUB_PS_RC=str(ps_rc),
               STUB_SEND=send, STUB_SEND_RC=str(send_rc))
    env.pop("ORCA_CLI_COMMAND", None)
    env.update(env_extra or {})
    if path is not None:
        env["PATH"] = path
    try:
        r = subprocess.run(["bash", SCRIPT] + args, env=env, capture_output=True, text=True, timeout=30)
        rc, out = r.returncode, r.stdout.strip().splitlines()
    except subprocess.TimeoutExpired:
        rc, out = "timeout", []
    calls = [json.loads(l) for l in open(log) if l.strip()]
    global SLEPT
    SLEPT = [int(l) for l in open(slog) if l.strip()]
    return rc, out, calls

SLEPT = []

def sends(calls):
    return [c for c in calls if c[:2] == ["terminal", "send"]]

def expect(name, args, rc, line, called=True, slept=(), **kw):
    got_rc, out, calls = run(args, **kw)
    why = []
    if SLEPT != list(slept):
        why.append("slept %r want %r" % (SLEPT, list(slept)))
    if got_rc != rc:
        why.append("rc=%s want %s" % (got_rc, rc))
    if len(out) != 1 or out[0] != line:
        why.append("output %r want %r" % (out, line))
    if rc in (1, 2) and sends(calls):
        why.append("sent %r" % sends(calls))
    if not called and calls:
        why.append("called the cli %r" % calls)
    (miss if why else ok)("%s: %s" % (name, "; ".join(why)) if why else name)

# --- SEND ---
rc, out, calls = run(["orca-ide", H])
s = sends(calls)
check = rc == 0 and out == ["Orca nudge sent to " + H] and s == [SEND_ARGV] and SLEPT == []
(ok if check else miss)("SEND done: one fixed send" if check else
                         "SEND done: rc=%s out=%r sends=%r slept=%r" % (rc, out, s, SLEPT))
check = all("--interrupt" not in c for c in calls)
(ok if check else miss)("SEND never --interrupt" if check else "SEND never --interrupt: %r" % calls)
look = [c for c in calls if c[:2] != ["terminal", "send"]]
check = look == [["terminal", "show", "--terminal", H, "--json"], ["worktree", "ps", "--agent-wait", "--json"]]
(ok if check else miss)("SEND lookup argv" if check else "SEND lookup argv: %r" % look)

def sends_text(name, args, text, **kw):
    rc, out, calls = run(args, **kw)
    s = sends(calls)
    good = rc == 0 and out == ["Orca nudge sent to " + H] and len(s) == 1 and s[0][5] == text and SLEPT == []
    (ok if good else miss)(name if good else "%s: rc=%s out=%r sends=%r slept=%r" % (name, rc, out, s, SLEPT))

sends_text("SEND orca-dev", ["orca-dev", H], TEXT.replace("orca-ide", "orca-dev"))
sends_text("SEND cli path is ORCA_CLI_COMMAND", [STUB, H], TEXT.replace("orca-ide", STUB),
           env_extra={"ORCA_CLI_COMMAND": STUB})
sends_text("SEND row in second worktree", ["orca-ide", H], TEXT,
           ps_json=ps(row("working", key="tab-7:leaf-7"), later=[row("done")]))

# --- STATE ---
SK = "Orca nudge skipped: "
for st in ("waiting", "blocked"):
    expect("STATE " + st, ["orca-ide", H], 1, SK + "the target is " + st, ps_json=ps(row(st)))
expect("STATE not a word", ["orca-ide", H], 1, SK + "the target state is unknown",
       ps_json=ps(row("Done; rm")))
expect("STATE missing", ["orca-ide", H], 1, SK + "the target state is unknown", ps_json=ps(row(None)))
expect("STATE no row", ["orca-ide", H], 1, SK + "the target has no agent row",
       ps_json=ps(row("done", key="tab-2:leaf-2")))
expect("STATE two rows", ["orca-ide", H], 1, SK + "the target matches 2 agent rows",
       ps_json=ps(row("done"), row("done")))
# A `done` row whose title matches is not the target: only paneKey decides.
expect("STATE other row done", ["orca-ide", H], 1, SK + "the target is waiting",
       ps_json=ps(row("done", key="tab-1:leaf-9"), row("waiting")))

# --- WAIT ---
W = row("working")
rc, out, calls = run(["orca-ide", H], ps_json=json.dumps([ps(W), ps(W), ps(row("done"))]))
n_ps = len([c for c in calls if c[:2] == ["worktree", "ps"]])
check = rc == 0 and out == ["Orca nudge sent to " + H] and sends(calls) == [SEND_ARGV] \
    and SLEPT == [10, 10] and n_ps == 3
(ok if check else miss)("WAIT working then done sends" if check else
                         "WAIT working then done sends: rc=%s out=%r sends=%r slept=%r ps=%d"
                         % (rc, out, sends(calls), SLEPT, n_ps))
expect("WAIT working then waiting", ["orca-ide", H], 1, SK + "the target is waiting",
       slept=[10], ps_json=json.dumps([ps(W), ps(row("waiting"))]))
expect("WAIT working past the bound", ["orca-ide", H], 1,
       SK + "the target is still working after 120 seconds", slept=[10] * 12, ps_json=ps(W))
expect("WAIT bound ignores env", ["orca-ide", H], 1,
       SK + "the target is still working after 120 seconds", slept=[10] * 12, ps_json=ps(W),
       env_extra={"CEPA_NUDGE_WAIT": "1", "cepa_nudge_wait": "1", "cepa_nudge_poll": "1"})
# A ps call that takes 3 s puts the clock off the poll grid: the last sleep
# is clamped to what is left, and the bound is exact.
expect("WAIT clock off the poll grid", ["orca-ide", H], 1,
       SK + "the target is still working after 120 seconds", slept=[10] * 9 + [3], ps_json=ps(W),
       env_extra={"STUB_PS_TICK": "3"})
expect("WAIT ps fails mid-wait", ["orca-ide", H], 1, SK + "worktree ps failed or timed out",
       slept=[10], ps_json=ps(W), env_extra={"STUB_PS_RC_SEQ": "[0, 1]"})
expect("WAIT date gives no clock", ["orca-ide", H], 1, SK + "date gave no clock for the wait",
       ps_json=ps(W), env_extra={"STUB_DATE": "12x"})
expect("WAIT sleep fails", ["orca-ide", H], 1, SK + "sleep failed in the wait",
       ps_json=ps(W), env_extra={"STUB_SLEEP_RC": "1"})

# --- LOOKUP ---
expect("LOOKUP show names another handle", ["orca-ide", H], 1,
       SK + "terminal show did not describe this handle", show_json=show(handle=OTHER))
expect("LOOKUP show empty ids", ["orca-ide", H], 1,
       SK + "terminal show did not describe this handle", show_json=show(tab="", leaf=""),
       ps_json=ps(row("done", key=":")))
expect("LOOKUP show not ok", ["orca-ide", H], 1, SK + 'an Orca call did not return "ok": true',
       show_json=json.dumps({"ok": False, "result": {"terminal": {"handle": H, "tabId": "tab-1", "leafId": "leaf-1"}}}))
expect("LOOKUP show fails", ["orca-ide", H], 1, SK + "terminal show failed or timed out", show_rc=1)
expect("LOOKUP ps fails", ["orca-ide", H], 1, SK + "worktree ps failed or timed out", ps_rc=1)
expect("LOOKUP ps not ok", ["orca-ide", H], 1, SK + 'an Orca call did not return "ok": true',
       ps_json=json.dumps({"ok": False}))
expect("LOOKUP ps wrong shape", ["orca-ide", H], 1, SK + "the Orca output has an unexpected shape",
       ps_json="null")

# --- REFUSE ---
RF = "Orca nudge refused: "
for name, args, why in [
        ("REFUSE cli bare orca", ["orca", H], "bare orca on Linux is the screen reader"),
        ("REFUSE cli flag", ["-orca-ide", H], "the cli is not a plain command name"),
        ("REFUSE cli shell text", ["orca-ide;id", H], "the cli is not a plain command name"),
        ("REFUSE cli not orca", ["bash", H], "the cli does not name an Orca CLI"),
        ("REFUSE cli path not ORCA_CLI_COMMAND", [STUB, H], "a cli path must equal ORCA_CLI_COMMAND"),
        ("REFUSE cli relative path", ["bin/orca-ide", H], "a cli path must be absolute and equal ORCA_CLI_COMMAND"),
        ("REFUSE handle run address", ["orca-ide", "run:abc"], "the handle is not a terminal handle"),
        ("REFUSE handle upper", ["orca-ide", H.upper().replace("TERM_", "term_")], "the handle is not a terminal handle"),
        ("REFUSE handle flag", ["orca-ide", "--interrupt"], "the handle is not a terminal handle"),
        ("REFUSE handle trailing", ["orca-ide", H + "x"], "the handle is not a terminal handle"),
        ("REFUSE handle newline", ["orca-ide", H + "\n" + H], "the handle is not a terminal handle"),
        ("REFUSE arg count", ["orca-ide", H, "--interrupt"], "usage: orca-nudge.sh <cli> <handle>")]:
    if os.uname().sysname != "Linux" and name == "REFUSE cli bare orca":
        continue
    expect(name, args, 2, RF + why, called=False)
# PATH without the stub bin: the name is valid but resolves to nothing.
expect("REFUSE cli not on PATH", ["orca-dev", H], 2, RF + "orca-dev is not on PATH", called=False,
       path="/usr/bin:/bin")

# --- FAIL ---
expect("FAIL send exits", ["orca-ide", H], 3, "Orca nudge failed: terminal send exited non-zero or timed out",
       send_rc=1)
expect("FAIL send not ok", ["orca-ide", H], 3, 'Orca nudge failed: terminal send did not return "ok": true',
       send='{"ok": false}')
expect("FAIL send ok truthy", ["orca-ide", H], 3, 'Orca nudge failed: terminal send did not return "ok": true',
       send='{"ok": "yes"}')

shutil.rmtree(TMP, ignore_errors=True)
print("-- %d/%d checks passed --" % (passed, passed + failed))
sys.exit(1 if failed else 0)
PY
