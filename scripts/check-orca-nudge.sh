#!/usr/bin/env bash
# Check for plugins/cepa/scripts/orca-nudge.sh, the one checked form of
# `cepa:autonomy` §12b rule 1's nudge. It runs the script against a stub
# `orca-ide` on PATH and never reaches a real terminal: the stub answers
# `terminal show`, `worktree ps` and `terminal send` from env vars and logs
# every call it gets.
#
# Usage: check-orca-nudge.sh [orca-nudge.sh]
#   The optional path replaces the shipped script. Only
#   check-orca-nudge-controls.sh sets it, to run this check against a mutant.
#
# Every MISS line starts with its case name, so the controls can assert the
# exact set of cases each mutant breaks. Cases, by leg:
#   SEND     — state `done`: exit 0, prints `sent`, and makes exactly one
#              `terminal send` whose argv is the fixed list (the text is one
#              argument, `--enter`, no `--interrupt`).
#   STATE    — `waiting`, `blocked`, `working`, a state that is not a plain
#              word, no state, no agent row, two rows, and a `done` row that
#              is not the target's while the target's is `waiting`: each
#              exits 1, prints `skipped` with its reason, and never sends.
#   LOOKUP   — `terminal show` echoes another handle, or fails: skipped, no
#              send. `worktree ps` fails: skipped, no send.
#   REFUSE   — a bad cli or handle, or the wrong argument count: exit 2,
#              prints `refused`, and the stub is never called.
#   FAIL     — `terminal send` exits non-zero, or returns no `"ok": true`:
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
  "worktree ps") [ "$STUB_PS_RC" = 0 ] || exit "$STUB_PS_RC"; printf '%s' "$STUB_PS" ;;
  "terminal send") printf '%s' "$STUB_SEND"; exit "$STUB_SEND_RC" ;;
  *) exit 64 ;;
esac
''')
os.chmod(STUB, 0o755)
# The same stub answers to orca and orca-dev, so a mutant that admits bare
# `orca` calls the stub and never the GNOME screen reader.
for alias in ("orca", "orca-dev"):
    os.symlink(STUB, os.path.join(BIN, alias))

def show(handle=H, tab="tab-1", leaf="leaf-1"):
    return json.dumps({"ok": True, "result": {"terminal": {"handle": handle, "tabId": tab, "leafId": leaf}}})

def ps(*rows):
    return json.dumps({"ok": True, "result": {"worktrees": [{"agents": list(rows)}]}})

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
        send='{"ok": true}', send_rc=0):
    log = os.path.join(TMP, "log")
    open(log, "w").close()
    env = dict(os.environ, PATH=BIN + os.pathsep + os.environ.get("PATH", ""),
               STUB_LOG=log, STUB_SHOW=show_json if show_json is not None else show(),
               STUB_PS=ps_json if ps_json is not None else ps(row("done")),
               STUB_SHOW_RC=str(show_rc), STUB_PS_RC=str(ps_rc),
               STUB_SEND=send, STUB_SEND_RC=str(send_rc))
    env.pop("ORCA_CLI_COMMAND", None)
    r = subprocess.run(["bash", SCRIPT] + args, env=env, capture_output=True, text=True, timeout=60)
    calls = [json.loads(l) for l in open(log) if l.strip()]
    return r.returncode, r.stdout.strip().splitlines(), calls

def sends(calls):
    return [c for c in calls if c[:2] == ["terminal", "send"]]

def expect(name, args, rc, line, called=True, **kw):
    got_rc, out, calls = run(args, **kw)
    why = []
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
check = rc == 0 and out == ["Orca nudge sent to " + H] and s == [SEND_ARGV]
(ok if check else miss)("SEND done: one fixed send" if check else
                         "SEND done: rc=%s out=%r sends=%r" % (rc, out, s))
check = all("--interrupt" not in c for c in calls)
(ok if check else miss)("SEND never --interrupt" if check else "SEND never --interrupt: %r" % calls)

# --- STATE ---
SK = "Orca nudge skipped: "
for st in ("waiting", "blocked", "working"):
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

# --- LOOKUP ---
expect("LOOKUP show names another handle", ["orca-ide", H], 1,
       SK + "terminal show did not describe this handle", show_json=show(handle=OTHER))
expect("LOOKUP show fails", ["orca-ide", H], 1, SK + "terminal show failed or timed out", show_rc=1)
expect("LOOKUP ps fails", ["orca-ide", H], 1, SK + "worktree ps failed or timed out", ps_rc=1)
expect("LOOKUP ps not ok", ["orca-ide", H], 1, SK + 'an Orca call did not return "ok": true',
       ps_json=json.dumps({"ok": False}))

# --- REFUSE ---
RF = "Orca nudge refused: "
for name, args, why in [
        ("REFUSE cli bare orca", ["orca", H], "bare orca on Linux is the screen reader"),
        ("REFUSE cli flag", ["-orca-ide", H], "the cli is not a plain command name"),
        ("REFUSE cli shell text", ["orca-ide;id", H], "the cli is not a plain command name"),
        ("REFUSE cli not orca", ["bash", H], "the cli does not name an Orca CLI"),
        ("REFUSE handle run address", ["orca-ide", "run:abc"], "the handle is not a terminal handle"),
        ("REFUSE handle upper", ["orca-ide", H.upper().replace("TERM_", "term_")], "the handle is not a terminal handle"),
        ("REFUSE handle flag", ["orca-ide", "--interrupt"], "the handle is not a terminal handle"),
        ("REFUSE handle trailing", ["orca-ide", H + "x"], "the handle is not a terminal handle"),
        ("REFUSE handle newline", ["orca-ide", H + "\n" + H], "the handle is not a terminal handle"),
        ("REFUSE arg count", ["orca-ide", H, "--interrupt"], "usage: orca-nudge.sh <cli> <handle>")]:
    if os.uname().sysname != "Linux" and name == "REFUSE cli bare orca":
        continue
    expect(name, args, 2, RF + why, called=False)

# --- FAIL ---
expect("FAIL send exits", ["orca-ide", H], 3, "Orca nudge failed: terminal send exited non-zero or timed out",
       send_rc=1)
expect("FAIL send not ok", ["orca-ide", H], 3, 'Orca nudge failed: terminal send did not return "ok": true',
       send='{"ok": false}')

shutil.rmtree(TMP, ignore_errors=True)
print("-- %d/%d checks passed --" % (passed, passed + failed))
sys.exit(1 if failed else 0)
PY
