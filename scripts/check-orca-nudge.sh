#!/usr/bin/env bash
# Check for plugins/cepa/scripts/orca-nudge.sh, the one checked form of
# `cepa:autonomy` §12b rule 1's nudge, and for orca-send.sh beside it, the one
# checked form of rule 1's send, reply and worker_done (the STORE, REPLY,
# WDONE and SENDREF legs). It runs the script against a stub
# `orca-ide` on PATH and never reaches a real terminal: the stub answers
# `terminal show`, `worktree ps` and `terminal send` from env vars and logs
# every call it gets. Stub `sleep` and `date` on the same PATH give the script
# a fake clock, so the 120-second wait costs no real time. The script reads no
# env var for its clock or its bound; only the PATH is changed.
#
# Usage: check-orca-nudge.sh [orca-nudge.sh [orca-send.sh]]
#   The optional paths replace the shipped scripts. Only
#   check-orca-nudge-controls.sh sets them, to run this check against a mutant.
#   orca-send.sh runs the orca-nudge.sh in its own directory, so a mutant send
#   script needs a copy of the shipped nudge beside it.
#   CEPA_NUDGE_CHECK_LEGS=nudge runs only the legs that run orca-nudge.sh
#   directly (SEND through RETRY); =send runs only the orca-send.sh legs
#   (STORE through SENDREF). Unset runs both, which is what CI does. Only the
#   controls set it, so each mutant runs just the half that can see it.
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
#   ENDING   — the exact whole output of one case per outcome. Sent prints one
#              line. Skipped, refused (bad cli, wrong argument count) and
#              failed print a second line, `Ending first line: Needed from
#              you: tell <handle> to check its Orca inbox`. A refused handle
#              prints `the target session` in place of the handle, so a handle
#              that failed its check is never printed. Every other leg only
#              asserts that a second line, when there is one, starts
#              `Ending first line: `.
#   RETRY    — the WSL interop error (stderr with `UtilAcceptVsock` and
#              `accept4 failed 110`, exit 1) once on `terminal show`,
#              `worktree ps` or `terminal send`: that call runs twice and the
#              nudge is sent. The error twice: the call runs twice and the
#              run skips (show) or fails (send). Another error, or only one
#              of the two texts (either one): the call runs once, with no retry.
#   STORE    — orca-send.sh (punch-list L33). A send counts only with
#              `"ok": true`, a `result.message.id` shaped `msg_…`, exit 0, and
#              that id in a re-read inbox row for the reported recipient. The
#              send and inbox argv are pinned, the subject and body reach Orca
#              as single arguments byte for byte (trailing newlines aside), and the nudge runs only after
#              a confirmed store. Each of these prints `Orca send failed: no
#              message stored`, exits 5 and never nudges: an envelope `"id"`
#              with no `result.message`, `"ok": false` (its error code shown
#              only when it is a plain word), empty stdout (the WSL failure),
#              a warning-only result, a non-zero exit with an ok reply, a bad
#              message id, an id missing from the inbox or stored for another
#              recipient, and an inbox that cannot be read or parsed. A warning beside a
#              stored message still counts. A send stored for a `run:` mailbox
#              is not nudged. A failed nudge passes its own lines and exit
#              code through. The vsock retry runs once, never after a timeout, and
#              carries the first try's request id (L36 #20).
#   REPLY    — orca-send.sh's `reply` mode (§12b rule 7, punch-list L35). The
#              argv is pinned (`reply --id <q> --body <b> --retry-request
#              <uuid> --json`), and the vsock retry reuses the same request id.
#              It counts only when the stored message is threaded on the
#              question; the nudge goes to the handle Orca addressed it to,
#              and a `dispatch:` mailbox gets none. A reply to a message this
#              session sent (its row's `from_handle` is ORCA_TERMINAL_HANDLE)
#              exits 1 as misaddressed, with no nudge, and so does one Orca
#              addressed to that handle when the question is out of the
#              window. REPLYREF: a non-`msg_` target, an empty body or one
#              starting `--` is refused before any call.
#   WDONE    — orca-send.sh's `worker_done` mode (§12b rule 3, punch-list
#              L35). The argv is pinned, with the preamble's IDs and a request
#              id the retry reuses. It counts only when `result.lifecycle`
#              names the same dispatch and task and the action the outcome
#              asks for; it never nudges. A matching id with a wrong
#              lifecycle prints `not proven stored`, never `no message
#              stored`. WDREF: a bad target, task id or outcome, or a missing
#              task id, is refused before any call.
#   SENDREF  — orca-send.sh's argument checks: a bad cli, target, type
#              (heartbeat included), mode, subject or body
#              (empty, starting with `--`, over 28,000 bytes): exit 4, prints
#              `Orca send refused`, and the stub is never called. For the plain
#              send types its ending line names the target only when the
#              target passed its check.
#
# STATED LIMITS — a green run does not mean:
#   - Orca's real output has this shape. The stub replays the shape measured on
#     2026-10-30 (see the script's header); a later Orca may differ, and then
#     the script skips.
#   - the nudge is safe on a `done` target. `done` was the idle state in the
#     L26 probe; the check pins that the script trusts nothing else.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

CEPA_NUDGE_SCRIPT="${1:-plugins/cepa/scripts/orca-nudge.sh}" \
CEPA_SEND_SCRIPT="${2:-plugins/cepa/scripts/orca-send.sh}" python3 - <<'PY'
import json, os, shutil, subprocess, sys, tempfile

SCRIPT = os.path.abspath(os.environ["CEPA_NUDGE_SCRIPT"])
SEND_SCRIPT = os.path.abspath(os.environ["CEPA_SEND_SCRIPT"])
LEGS = os.environ.get("CEPA_NUDGE_CHECK_LEGS", "all")
if LEGS not in ("all", "nudge", "send"):
    print("MISS CEPA_NUDGE_CHECK_LEGS is %r, want nudge or send" % LEGS)
    sys.exit(1)
H = "term_5c81eb74-a55a-4a1e-b450-81e09827d825"
OTHER = "term_00000000-0000-0000-0000-000000000000"
KEY = "tab-1:leaf-1"
TEXT = "You have 1 orchestration message. Run orca-ide orchestration check --peek --json"
SEND_ARGV = ["terminal", "send", "--terminal", H, "--text", TEXT, "--enter", "--json"]

TMP = tempfile.mkdtemp(prefix="cepa-nudge-chk-")
BIN = os.path.join(TMP, "bin")
os.mkdir(BIN)
STUB = os.path.join(BIN, "orca-ide")
# Each call is logged as its argument count and then each argument, all
# NUL-terminated, so a space or newline inside an argument stays inside it.
# The stub is plain bash: it starts no python3, so a case costs the scripts'
# own work and not the stub's (L35 follow-up: the controls run this check
# about 100 times). STUB_ERR_VERB (`terminal show`, `worktree ps` or
# `terminal send`) makes the first STUB_ERR_TIMES calls of that verb print
# STUB_ERR to stderr and exit STUB_ERR_RC (default 1). STUB_ERR is printed
# with %b, so `\\0` in it becomes a NUL byte.
open(STUB, "w").write(r'''#!/usr/bin/env bash
printf '%s\0' "$#" "$@" >>"$STUB_LOG"
if [ "$1 $2" = "${STUB_ERR_VERB-}" ]; then
  read -r n <"$STUB_LOG.err"; n=$((n + 1)); echo "$n" >"$STUB_LOG.err"
  if [ "$n" -le "$STUB_ERR_TIMES" ]; then
    printf '%b\n' "$STUB_ERR" >&2; exit "${STUB_ERR_RC:-1}"
  fi
fi
case "$1 $2" in
  "terminal show") [ "$STUB_SHOW_RC" = 0 ] || exit "$STUB_SHOW_RC"; printf '%s' "$STUB_SHOW" ;;
  "worktree ps")
    # run() splits STUB_PS (one output, or a JSON list played in order with
    # the last repeated) into $STUB_PSDIR/out.N, and STUB_PS_RC_SEQ the same
    # way into rc.N. Each call adds STUB_PS_TICK seconds to the fake clock.
    # Past 100 calls it fails, so a mutant that never stops waiting ends
    # fast, as a skip. The count includes calls STUB_ERR failed.
    read -r n <"$STUB_LOG.ps"; n=$((n + 1)); echo "$n" >"$STUB_LOG.ps"
    [ "$STUB_PS_RC" = 0 ] || exit "$STUB_PS_RC"
    [ "$n" -le 100 ] || exit 99
    read -r c <"$STUB_CLOCK"; echo "$((c + ${STUB_PS_TICK:-0}))" >"$STUB_CLOCK"
    read -r rc <"$STUB_PSDIR/rc.$((n < STUB_PS_RCN ? n : STUB_PS_RCN))"
    [ "$rc" = 0 ] || exit "$rc"
    cat "$STUB_PSDIR/out.$((n < STUB_PS_N ? n : STUB_PS_N))" ;;
  "terminal send") printf '%s' "$STUB_SEND"; exit "$STUB_SEND_RC" ;;
  "orchestration send"|"orchestration reply") printf '%s' "${STUB_OSEND-}"; exit "${STUB_OSEND_RC:-0}" ;;
  "orchestration inbox") printf '%s' "${STUB_INBOX-}"; exit "${STUB_INBOX_RC:-0}" ;;
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
        send='{"ok": true}', send_rc=0, env_extra=None, path=None, script=None, stdin=""):
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
    # The checker may run inside an Orca terminal; its own handle must not
    # reach the script unless a case sets one.
    env.pop("ORCA_TERMINAL_HANDLE", None)
    env.update(env_extra or {})
    if path is not None:
        env["PATH"] = path
    for f in ("err", "ps"):
        open(log + "." + f, "w").write("0\n")
    psdir = os.path.join(TMP, "ps")
    shutil.rmtree(psdir, ignore_errors=True)
    os.mkdir(psdir)
    v = env["STUB_PS"]
    outs = json.loads(v) if v.startswith("[") else [v]
    rcs = json.loads(env.get("STUB_PS_RC_SEQ", "[0]"))
    for name, seq in (("out", outs), ("rc", rcs)):
        for i, x in enumerate(seq, 1):
            open(os.path.join(psdir, "%s.%d" % (name, i)), "w").write(x if name == "out" else "%d\n" % x)
    env.update(STUB_PSDIR=psdir, STUB_PS_N=str(len(outs)), STUB_PS_RCN=str(len(rcs)))
    try:
        r = subprocess.run(["bash", script or SCRIPT] + args, env=env, capture_output=True, text=True,
                           timeout=30, input=stdin)
        rc, out = r.returncode, r.stdout.strip().splitlines()
        STDERR[0] = r.stderr
    except subprocess.TimeoutExpired:
        rc, out = "timeout", []
        STDERR[0] = ""
    tok = open(log, "rb").read().decode("utf-8", "surrogateescape").split("\0")[:-1]
    calls, i = [], 0
    while i < len(tok):
        n = int(tok[i])
        calls.append(tok[i + 1:i + 1 + n])
        i += 1 + n
    global SLEPT
    SLEPT = [int(l) for l in open(slog) if l.strip()]
    return rc, out, calls

SLEPT = []
STDERR = [""]  # the last run's stderr

def sends(calls):
    return [c for c in calls if c[:2] == ["terminal", "send"]]

END = "Ending first line: "

def expect(name, args, rc, line, called=True, slept=(), **kw):
    got_rc, out, calls = run(args, **kw)
    why = []
    if SLEPT != list(slept):
        why.append("slept %r want %r" % (SLEPT, list(slept)))
    if got_rc != rc:
        why.append("rc=%s want %s" % (got_rc, rc))
    # The second line's text is the ENDING leg's; here it only has to be one.
    if not out or out[0] != line or len(out) > 2 or (len(out) == 2 and not out[1].startswith(END)):
        why.append("output %r want %r" % (out, line))
    if rc in (1, 2) and sends(calls):
        why.append("sent %r" % sends(calls))
    if not called and calls:
        why.append("called the cli %r" % calls)
    (miss if why else ok)("%s: %s" % (name, "; ".join(why)) if why else name)

# Names both halves use.
SK = "Orca nudge skipped: "
END_H = END + "Needed from you: tell %s to check its Orca inbox" % H
END_ANY = END + "Needed from you: tell the target session to check its Orca inbox"
VSOCK = "<3>WSL (2611 - Relay) ERROR: UtilAcceptVsock:273: accept4 failed 110"

# The nudge legs run orca-nudge.sh directly. They never run orca-send.sh.
if LEGS in ("all", "nudge"):
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

    # mktemp that fails: skipped before any Orca call.
    MKBIN = os.path.join(TMP, "mkbin")
    os.mkdir(MKBIN)
    open(os.path.join(MKBIN, "mktemp"), "w").write("#!/bin/sh\nexit 1\n")
    os.chmod(os.path.join(MKBIN, "mktemp"), 0o755)
    expect("LOOKUP mktemp fails", ["orca-ide", H], 1, SK + "mktemp failed", called=False,
           path=MKBIN + os.pathsep + BIN + os.pathsep + os.environ.get("PATH", ""))

    # --- FAIL ---
    expect("FAIL send exits", ["orca-ide", H], 3, "Orca nudge failed: terminal send exited non-zero or timed out",
           send_rc=1)
    expect("FAIL send not ok", ["orca-ide", H], 3, 'Orca nudge failed: terminal send did not return "ok": true',
           send='{"ok": false}')
    expect("FAIL send ok truthy", ["orca-ide", H], 3, 'Orca nudge failed: terminal send did not return "ok": true',
           send='{"ok": "yes"}')

    # --- ENDING ---

    def ending(name, args, want, **kw):
        rc, out, calls = run(args, **kw)
        (ok if out == want else miss)(name if out == want else "%s: output %r want %r" % (name, out, want))

    ending("ENDING sent has no ending line", ["orca-ide", H], ["Orca nudge sent to " + H])
    ending("ENDING skip", ["orca-ide", H], [SK + "the target is waiting", END_H], ps_json=ps(row("waiting")))
    ending("ENDING refuse cli", ["bash", H], [RF + "the cli does not name an Orca CLI", END_H])
    ending("ENDING refuse arg count", ["orca-ide", H, "x"], [RF + "usage: orca-nudge.sh <cli> <handle>", END_H])
    ending("ENDING refuse handle is not printed", ["orca-ide", "term_x;id"],
           [RF + "the handle is not a terminal handle", END_ANY])
    ending("ENDING fail", ["orca-ide", H], ["Orca nudge failed: terminal send exited non-zero or timed out", END_H],
           send_rc=1)

    # --- RETRY ---

    ARGV = {"terminal show": ["terminal", "show", "--terminal", H, "--json"],
            "worktree ps": ["worktree", "ps", "--agent-wait", "--json"],
            "terminal send": SEND_ARGV}

    def retry(name, verb, times, err, rc, line, n_calls, err_rc=1, n_ps=None, **kw):
        got_rc, out, calls = run(["orca-ide", H], env_extra={
            "STUB_ERR_VERB": verb, "STUB_ERR_TIMES": str(times), "STUB_ERR": err,
            "STUB_ERR_RC": str(err_rc)}, **kw)
        mine = [c for c in calls if c[:2] == verb.split()]
        ps_n = len([c for c in calls if c[:2] == ["worktree", "ps"]])
        # The retry runs the same argv as the first try, flag for flag.
        good = got_rc == rc and out[:1] == [line] and mine == [ARGV[verb]] * n_calls \
            and (n_ps is None or ps_n == n_ps) and STDERR[0] == ""
        (ok if good else miss)(name if good else "%s: rc=%s out=%r %s calls=%r ps=%d stderr=%r want rc=%s %d"
                               % (name, got_rc, out, verb, mine, ps_n, STDERR[0][:80], rc, n_calls))

    SENT = "Orca nudge sent to " + H
    retry("RETRY show vsock once", "terminal show", 1, VSOCK, 0, SENT, 2)
    retry("RETRY ps vsock once", "worktree ps", 1, VSOCK, 0, SENT, 2)
    # The send retry re-reads the row first: one more worktree ps.
    retry("RETRY send vsock once", "terminal send", 1, VSOCK, 0, SENT, 2, n_ps=2)
    retry("RETRY send retry target left done", "terminal send", 1, VSOCK, 1,
          SK + "the target is working before the send retry", 1, n_ps=2,
          ps_json=json.dumps([ps(row("done")), ps(row("working"))]))
    retry("RETRY timed-out call not retried", "terminal show", 1, VSOCK, 1,
          SK + "terminal show failed or timed out", 1, err_rc=124)
    retry("RETRY killed call not retried", "terminal send", 1, VSOCK, 3,
          "Orca nudge failed: terminal send exited non-zero or timed out", 1, err_rc=137, n_ps=1)
    retry("RETRY show vsock twice", "terminal show", 2, VSOCK, 1, SK + "terminal show failed or timed out", 2)
    retry("RETRY send vsock twice", "terminal send", 2, VSOCK, 3,
          "Orca nudge failed: terminal send exited non-zero or timed out", 2)
    retry("RETRY other error", "terminal show", 1, "error: connection refused", 1,
          SK + "terminal show failed or timed out", 1)
    retry("RETRY half the text", "terminal show", 1, "<3>WSL ERROR: UtilAcceptVsock:273: accept4 failed 22", 1,
          SK + "terminal show failed or timed out", 1)
    # bash warns on a NUL byte in a command substitution; the warning must not
    # reach the output ahead of the result line.
    retry("RETRY NUL in stderr", "terminal show", 2, VSOCK + "\\0x", 1, SK + "terminal show failed or timed out", 2)
    retry("RETRY other half of the text", "terminal show", 1, "<3>WSL ERROR: Relay: accept4 failed 110", 1,
          SK + "terminal show failed or timed out", 1)

# The send legs run orca-send.sh, which runs the orca-nudge.sh in its own
# directory. They never run the nudge script given as argument 1.
if LEGS in ("all", "send"):
    # --- STORE (orca-send.sh, punch-list L33) ---
    MID = "msg_5c81eb74a55a"
    SUBJ = "tab9@wt: L1 done"
    BODY = 'line 1\n"quoted" $HOME `x` \\ end\n\n- last'
    STDIN = SUBJ + "\n" + BODY + "\n"
    OSEND_ARGV = ["orchestration", "send", "--to", H, "--type", "question", "--subject", SUBJ,
                  "--body", BODY, "--retry-request", "<uuid>", "--json"]
    UUID_RE = r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
    import re as _re

    def strip_req(c):
        # The request id is fresh per run: pin its shape, then its position.
        c = list(c)
        if "--retry-request" in c:
            i = c.index("--retry-request") + 1
            if i < len(c) and _re.fullmatch(UUID_RE, c[i]):
                c[i] = "<uuid>"
        return c
    INBOX_ARGV = ["orchestration", "inbox", "--limit", "200", "--json"]
    WARN = [{"code": "legacy_terminal_recipient", "recipient": H}]

    def osend(mid=MID, to=H, ok=True, warnings=True, message=True, **extra):
        r = {}
        if message:
            r["message"] = {"id": mid, "to_handle": to, "subject": SUBJ}
        if warnings:
            r["warnings"] = WARN
        return json.dumps(dict({"id": "9232524a-511a-4305-ba28-37e1d28617d5", "ok": ok, "result": r}, **extra))

    def inbox(*rows, ok=True):
        rows = rows or ({"id": MID, "to_handle": H},)
        return json.dumps({"id": "b9da5171", "ok": ok, "result": {
            "messages": [{"id": "msg_000000000001", "to_handle": OTHER}] + list(rows), "count": len(rows) + 1}})

    STORED = "Orca send stored: %s for %s" % (MID, H)
    NOSTORE = "Orca send failed: no message stored — "
    UNPROVEN = "Orca send failed: not proven stored — "
    PASTE = END + "Needed from you: paste the block below into %s" % H
    PASTE_ANY = END + "Needed from you: paste the block below into the target session"

    def store(name, rc, want, mode="nudge", typ="question", target=H, osend_json=None, osend_rc=0,
              inbox_json=None, inbox_rc=0, stdin=STDIN, argv=None, called=True, env_extra=None, **kw):
        env = {"STUB_OSEND": osend_json if osend_json is not None else osend(), "STUB_OSEND_RC": str(osend_rc),
               "STUB_INBOX": inbox_json if inbox_json is not None else inbox(), "STUB_INBOX_RC": str(inbox_rc)}
        env.update(env_extra or {})
        args = argv if argv is not None else ["orca-ide", target, typ, mode]
        got_rc, out, calls = run(args, script=SEND_SCRIPT, stdin=stdin, env_extra=env, **kw)
        why = []
        if got_rc != rc:
            why.append("rc=%s want %s" % (got_rc, rc))
        if out != want:
            why.append("output %r want %r" % (out, want))
        # A send that stored nothing never nudges.
        if rc in (4, 5) and sends(calls):
            why.append("nudged %r" % sends(calls))
        if not called and calls:
            why.append("called the cli %r" % [[a[:60] for a in c] for c in calls])
        (miss if why else ok)("%s: %s" % (name, "; ".join(why)[:2000]) if why else name)
        return calls

    calls = store("STORE stored then nudged", 0, [STORED, "Orca nudge sent to " + H])
    os_calls = [c for c in calls if c[:2] == ["orchestration", "send"]]
    in_calls = [c for c in calls if c[:2] == ["orchestration", "inbox"]]
    # Send, then re-read, then the nudge's own calls: never the nudge first.
    order = [c[:2] for c in calls]
    check = [strip_req(c) for c in os_calls] == [OSEND_ARGV] and in_calls == [INBOX_ARGV] and sends(calls) == [SEND_ARGV] \
        and order[:2] == [["orchestration", "send"], ["orchestration", "inbox"]]
    (ok if check else miss)("STORE argv and order" if check else "STORE argv and order: %r" % calls)
    calls = store("STORE no-nudge stores only", 0, [STORED], mode="no-nudge")
    check = sends(calls) == [] and [c[:2] for c in calls] == [["orchestration", "send"], ["orchestration", "inbox"]]
    (ok if check else miss)("STORE no-nudge makes no nudge call" if check else
                             "STORE no-nudge makes no nudge call: %r" % calls)
    store("STORE warning beside a message counts", 0, [STORED], mode="no-nudge", osend_json=osend(warnings=True))
    store("STORE run address target", 0, ["Orca send stored: %s for run:run_abc" % MID], mode="no-nudge",
          target="run:run_abc", osend_json=osend(to="run:run_abc"),
          inbox_json=inbox({"id": MID, "to_handle": "run:run_abc"}))
    store("STORE rerouted to a Run mailbox", 0,
          ["Orca send stored: %s for run:run_abc" % MID,
           "Orca nudge not needed: Orca stored it in run:run_abc, a Run mailbox it prompts"],
          osend_json=osend(to="run:run_abc"), inbox_json=inbox({"id": MID, "to_handle": "run:run_abc"}))
    store("STORE stored for another handle", 1,
          ["Orca send stored: %s for %s" % (MID, OTHER), SK + "Orca stored it for %s, not the target" % OTHER,
           END + "Needed from you: tell %s to check its Orca inbox" % OTHER],
          osend_json=osend(to=OTHER), inbox_json=inbox({"id": MID, "to_handle": OTHER}))
    store("STORE nudge skip passes through", 1, [STORED, SK + "the target is waiting", END_H],
          ps_json=ps(row("waiting")))
    store("STORE nudge fail passes through", 3,
          [STORED, "Orca nudge failed: terminal send exited non-zero or timed out", END_H], send_rc=1)
    store("STORE envelope id without result.message", 5,
          [NOSTORE + "the reply has no result.message.id", PASTE], osend_json=osend(message=False, warnings=False))
    store("STORE warning-only result", 5, [NOSTORE + "the reply has no result.message.id", PASTE],
          osend_json=osend(message=False))
    store("STORE ok false", 5, [NOSTORE + 'Orca did not return "ok": true (missing_task_id)', PASTE],
          osend_rc=1, osend_json=json.dumps({"id": "local", "ok": False,
                                             "error": {"code": "missing_task_id", "message": "worker_done requires taskId."}}))
    store("STORE ok false code not a word", 5, [NOSTORE + 'Orca did not return "ok": true', PASTE],
          osend_rc=1, osend_json=json.dumps({"id": "local", "ok": False, "error": {"code": "x; rm -rf"}}))
    store("STORE ok truthy", 5, [NOSTORE + 'Orca did not return "ok": true', PASTE], osend_json=osend(ok="yes"))
    store("STORE empty stdout", 5, [NOSTORE + "the send exited 1 and printed nothing", PASTE],
          osend_json="", osend_rc=1)
    store("STORE not JSON", 5, [NOSTORE + "the send exited 0 and printed no JSON", PASTE], osend_json="sent msg_1")
    store("STORE JSON list", 5, [NOSTORE + "the send printed JSON of an unexpected shape", PASTE],
          osend_json="[]")
    store("STORE ok reply with a non-zero exit", 5, [NOSTORE + "the send exited 2", PASTE], osend_rc=2)
    store("STORE bad message id", 5, [NOSTORE + "the reply has no result.message.id", PASTE],
          osend_json=osend(mid="msg_X; rm"))
    store("STORE envelope uuid as message id", 5, [NOSTORE + "the reply has no result.message.id", PASTE],
          osend_json=osend(mid="9232524a-511a-4305-ba28-37e1d28617d5"))
    store("STORE bad recipient", 5, [UNPROVEN + "the reply names no valid recipient", PASTE],
          osend_json=osend(to="term_x; rm"))
    store("STORE id missing from the inbox", 5, [NOSTORE + "%s is not in the inbox for %s" % (MID, H), PASTE],
          inbox_json=inbox({"id": "msg_999999999999", "to_handle": H}))
    store("STORE id in the inbox for another recipient", 5,
          [NOSTORE + "%s is not in the inbox for %s" % (MID, H), PASTE],
          inbox_json=inbox({"id": MID, "to_handle": OTHER}))
    store("STORE inbox not ok", 5, [NOSTORE + "%s is not in the inbox for %s" % (MID, H), PASTE],
          inbox_json=inbox(ok=False))
    store("STORE inbox not JSON", 5, [NOSTORE + "the inbox could not be parsed, so %s is unconfirmed" % MID, PASTE],
          inbox_json="not json")
    store("STORE inbox wrong shape", 5, [NOSTORE + "the inbox could not be parsed, so %s is unconfirmed" % MID, PASTE],
          inbox_json=json.dumps({"ok": True, "result": {}}))
    # Bytes, not characters: 14,000 two-byte characters plus a 1-byte subject.
    store("SENDREF cap counts bytes", 4,
          ["Orca send refused: " + "subject and body are 28001 bytes; the limit is 28000 (WSL command-line limit)", PASTE],
          stdin="s\n" + "\u00e9" * 14000 + "\n", called=False)
    store("STORE inbox fails", 5, [NOSTORE + "the inbox could not be re-read, so %s is unconfirmed" % MID, PASTE],
          inbox_rc=1)

    def store_retry(name, verb, times, rc, want, n_calls, err_rc=1, **kw):
        calls = store(name, rc, want, mode="no-nudge", env_extra={
            "STUB_ERR_VERB": verb, "STUB_ERR_TIMES": str(times), "STUB_ERR": VSOCK, "STUB_ERR_RC": str(err_rc)}, **kw)
        n = len([c for c in calls if c[:2] == verb.split()])
        (ok if n == n_calls else miss)("%s: %s calls" % (name, verb) if n == n_calls else
                                       "%s: %d %s calls want %d" % (name, n, verb, n_calls))

    store_retry("STORE send vsock once", "orchestration send", 1, 0, [STORED], 2)
    store_retry("STORE send vsock twice", "orchestration send", 2, 5,
                [NOSTORE + "the send exited 1 and printed nothing", PASTE], 2)
    store_retry("STORE send timeout not retried", "orchestration send", 1, 5,
                [NOSTORE + "the send exited 124 and printed nothing", PASTE], 1, err_rc=124)
    store_retry("STORE inbox vsock once", "orchestration inbox", 1, 0, [STORED], 2)
    # L36 #20: the send's vsock retry is the first try replayed, by request id.
    calls = store("STORE send retry", 0, [STORED], mode="no-nudge", env_extra={
        "STUB_ERR_VERB": "orchestration send", "STUB_ERR_TIMES": "1", "STUB_ERR": VSOCK})
    ids = [c[c.index("--retry-request") + 1] for c in calls
           if c[:2] == ["orchestration", "send"] and "--retry-request" in c[:-1]]
    check = len(ids) == 2 and ids[0] == ids[1] and bool(_re.fullmatch(UUID_RE, ids[0]))
    (ok if check else miss)("STORE retry reuses the request id" if check else "STORE retry reuses the request id: %r" % ids)

    # --- REPLY (orca-send.sh reply mode, punch-list L35) ---
    QID = "msg_a3dc2b4b1de4"

    def oreply(mid=MID, to=H, thread=QID, ok=True):
        m = {"id": mid, "subject": "Re: q", "thread_id": thread}
        if to is not None:
            m["to_handle"] = to
        return json.dumps({"id": "fba9f64f-afb0-43cf-ac63-f350c5b929b5", "ok": ok, "result": {"message": m}})

    PASTE_Q = END + "Needed from you: paste the block below into the session that asked %s" % QID
    RARGS = ["orca-ide", QID, "reply", "nudge"]
    RBODY = BODY + "\n"

    def req_ids(calls, verb):
        out = []
        for c in calls:
            if c[:2] == verb and "--retry-request" in c:
                out.append(c[c.index("--retry-request") + 1])
        return out

    calls = store("REPLY stored then nudged the asker", 0, [STORED, "Orca nudge sent to " + H],
                  argv=RARGS, stdin=RBODY, osend_json=oreply())
    rc_ = [c for c in calls if c[:2] == ["orchestration", "reply"]]
    check = len(rc_) == 1 and len(rc_[0]) == 9 and rc_[0][:6] == ["orchestration", "reply", "--id", QID, "--body", BODY] \
        and rc_[0][6] == "--retry-request" and _re.fullmatch(UUID_RE, rc_[0][7] or "") and rc_[0][8:] == ["--json"] \
        and sends(calls) == [SEND_ARGV]
    (ok if check else miss)("REPLY argv" if check else "REPLY argv: %r" % calls)
    calls = store("REPLY no-nudge stores only", 0, [STORED], argv=["orca-ide", QID, "reply", "no-nudge"],
                  stdin=RBODY, osend_json=oreply())
    (ok if not sends(calls) else miss)("REPLY no-nudge makes no nudge call" if not sends(calls) else
                                       "REPLY no-nudge makes no nudge call: %r" % calls)
    calls = store("REPLY to a dispatch mailbox is not nudged", 0,
                  ["Orca send stored: %s for dispatch:ctx_abcdef" % MID,
                   "Orca nudge not needed: Orca stored it in dispatch:ctx_abcdef, a mailbox Orca delivers"],
                  argv=RARGS, stdin=RBODY, osend_json=oreply(to="dispatch:ctx_abcdef"),
                  inbox_json=inbox({"id": MID, "to_handle": "dispatch:ctx_abcdef"}))
    store("REPLY not threaded on the question", 5, [UNPROVEN + "the reply is not threaded on %s" % QID, PASTE_Q],
          argv=RARGS, stdin=RBODY, osend_json=oreply(thread="msg_000000000009"))
    store("REPLY names no recipient", 5, [UNPROVEN + "the reply names no valid recipient", PASTE_Q],
          argv=RARGS, stdin=RBODY, osend_json=oreply(to=None))
    store("REPLY ok false", 5, [NOSTORE + 'Orca did not return "ok": true (answer_conflict)', PASTE_Q],
          argv=RARGS, stdin=RBODY, osend_rc=1,
          osend_json=json.dumps({"id": "7d357c4f", "ok": False, "error": {"code": "answer_conflict"}}))
    MISADDR = ("Orca reply misaddressed: " + MID + " stored for %s, but " + QID
               + " was sent by this session, so the reply came back to it")
    calls = store("REPLY to a message this session sent", 1,
                  [MISADDR % H, END + "Needed from you: check which session asked %s" % QID],
                  argv=RARGS, stdin=RBODY, osend_json=oreply(),
                  inbox_json=inbox({"id": MID, "to_handle": H}, {"id": QID, "from_handle": OTHER, "to_handle": H}),
                  env_extra={"ORCA_TERMINAL_HANDLE": OTHER})
    (ok if not sends(calls) else miss)("REPLY misaddressed is not nudged" if not sends(calls) else
                                       "REPLY misaddressed is not nudged: %r" % calls)
    # #106 review: a question outside the re-read window is still caught when
    # Orca addressed the reply to this session's own handle.
    OWN = "term_11111111-2222-4333-8444-555555555555"
    calls = store("REPLY addressed to this session, question out of window", 1,
                  [MISADDR % OWN, END + "Needed from you: check which session asked %s" % QID],
                  argv=RARGS, stdin=RBODY, osend_json=oreply(to=OWN), inbox_json=inbox({"id": MID, "to_handle": OWN}),
                  env_extra={"ORCA_TERMINAL_HANDLE": OWN})
    (ok if not sends(calls) else miss)("REPLY addressed to this session is not nudged" if not sends(calls) else
                                       "REPLY addressed to this session is not nudged: %r" % calls)
    # Stated limit: with no handle and no question row, it cannot tell.
    store("REPLY no handle, question out of window", 0, ["Orca send stored: %s for run:run_abc" % MID],
          argv=["orca-ide", QID, "reply", "no-nudge"], stdin=RBODY, osend_json=oreply(to="run:run_abc"),
          inbox_json=inbox({"id": MID, "to_handle": "run:run_abc"}))
    store("REPLY handle not a term_ handle is ignored", 0, [STORED],
          argv=["orca-ide", QID, "reply", "no-nudge"], stdin=RBODY, osend_json=oreply(),
          inbox_json=inbox({"id": MID, "to_handle": H}, {"id": QID, "from_handle": H + "x", "to_handle": OTHER}),
          env_extra={"ORCA_TERMINAL_HANDLE": H + "x"})
    store("REPLY question from another session", 0, [STORED, "Orca nudge sent to " + H],
          argv=RARGS, stdin=RBODY, osend_json=oreply(),
          inbox_json=inbox({"id": MID, "to_handle": H}, {"id": QID, "from_handle": H, "to_handle": OTHER}),
          env_extra={"ORCA_TERMINAL_HANDLE": OTHER})
    calls = store("REPLY vsock retry", 0, [STORED], argv=["orca-ide", QID, "reply", "no-nudge"], stdin=RBODY,
                  osend_json=oreply(), env_extra={"STUB_ERR_VERB": "orchestration reply", "STUB_ERR_TIMES": "1",
                                                  "STUB_ERR": VSOCK})
    ids = req_ids(calls, ["orchestration", "reply"])
    check = len(ids) == 2 and ids[0] == ids[1]
    (ok if check else miss)("REPLY retry reuses the request id" if check else "REPLY retry reuses the request id: %r" % ids)
    for name, args, stdin, why, end in [
            ("REPLYREF target is a handle", ["orca-ide", H, "reply", "nudge"], RBODY,
             "a reply's target is not a msg_ message id",
             END + "Needed from you: paste the block below into the session that asked"),
            ("REPLYREF empty body", RARGS, " \n", "the body is empty", PASTE_Q),
            ("REPLYREF body starts --", RARGS, "--json\n", "the body starts with --, which Orca reads as a flag", PASTE_Q)]:
        store(name, 4, ["Orca send refused: " + why, end], argv=args, stdin=stdin, called=False)

    # --- WDONE (orca-send.sh worker_done mode, punch-list L35) ---
    DID, TID = "ctx_0cb768293e95", "task_ce89e0b1b529"
    WARGS = ["orca-ide", "dispatch:" + DID, "worker_done", "succeeded", TID]
    RUN = "run:run_ca27e456fd42"
    WSTORED = "Orca send stored: %s for %s" % (MID, RUN)
    PASTE_RC = END + "Needed from you: paste the block below into the Run coordinator"

    def owd(action="completed", disp=DID, task=TID, lifecycle=True):
        r = {"message": {"id": MID, "to_handle": RUN, "type": "worker_done"}}
        if lifecycle:
            r["lifecycle"] = {"action": action, "taskId": task, "dispatchId": disp}
        return json.dumps({"id": "193ad389", "ok": True, "result": r})

    WINBOX = inbox({"id": MID, "to_handle": RUN})
    calls = store("WDONE stored", 0, [WSTORED], argv=WARGS, osend_json=owd(), inbox_json=WINBOX)
    oc = [c for c in calls if c[:2] == ["orchestration", "send"]]
    check = len(oc) == 1 and len(oc[0]) == 17 and oc[0][:16] == ["orchestration", "send", "--type", "worker_done", "--subject", SUBJ,
                                            "--body", BODY, "--task-id", TID, "--dispatch-id", DID,
                                            "--outcome", "succeeded", "--retry-request", oc[0][15]] \
        and _re.fullmatch(UUID_RE, oc[0][15]) and oc[0][16:] == ["--json"] and not sends(calls)
    (ok if check else miss)("WDONE argv, no nudge" if check else "WDONE argv, no nudge: %r" % calls)
    store("WDONE failed outcome", 0, [WSTORED], argv=WARGS[:3] + ["failed", TID],
          osend_json=owd(action="failed"), inbox_json=WINBOX)
    for name, j in [("WDONE no lifecycle", owd(lifecycle=False)),
                    ("WDONE wrong action", owd(action="failed")),
                    ("WDONE other dispatch", owd(disp="ctx_000000000000")),
                    ("WDONE other task", owd(task="task_000000000000"))]:
        store(name, 5, [UNPROVEN + "Orca did not record the dispatch as completed", PASTE_RC],
              argv=WARGS, osend_json=j, inbox_json=WINBOX)
    store("WDONE ok false", 5, [NOSTORE + 'Orca did not return "ok": true (run_required)', PASTE_RC],
          argv=WARGS, osend_rc=1, osend_json=json.dumps({"id": "6be45a49", "ok": False, "error": {"code": "run_required"}}))
    store("WDONE empty stdout", 5, [NOSTORE + "the send exited 1 and printed nothing", PASTE_RC],
          argv=WARGS, osend_rc=1, osend_json="")
    calls = store("WDONE vsock retry", 0, [WSTORED], argv=WARGS, osend_json=owd(), inbox_json=WINBOX,
                  env_extra={"STUB_ERR_VERB": "orchestration send", "STUB_ERR_TIMES": "1", "STUB_ERR": VSOCK})
    ids = req_ids(calls, ["orchestration", "send"])
    check = len(ids) == 2 and ids[0] == ids[1]
    (ok if check else miss)("WDONE retry reuses the request id" if check else "WDONE retry reuses the request id: %r" % ids)
    for name, args, why in [
            ("WDREF target not a dispatch", ["orca-ide", H, "worker_done", "succeeded", TID],
             "a worker_done target is not dispatch:ctx_<id>"),
            ("WDREF no task id", WARGS[:4], "worker_done takes <outcome> <task id> after the type"),
            ("WDREF bad task id", WARGS[:4] + ["task_x;rm"], "the task id is not task_<id>"),
            ("WDREF bad outcome", WARGS[:3] + ["done", TID], "the worker_done outcome is not succeeded or failed")]:
        store(name, 4, ["Orca send refused: " + why, PASTE_RC], argv=args, called=False)

    # --- SENDREF ---
    SR = "Orca send refused: "
    for name, args, stdin, why, end in [
            ("SENDREF arg count", ["orca-ide", H, "status"], STDIN,
             "usage: orca-send.sh <cli> <target> <type> <nudge|no-nudge>, or <cli> dispatch:<id> worker_done <outcome> <task id>", PASTE),
            ("SENDREF cli not orca", ["bash", H, "status", "nudge"], STDIN, "the cli does not name an Orca CLI", PASTE),
            ("SENDREF cli shell text", ["orca-ide;id", H, "status", "nudge"], STDIN,
             "the cli is not a plain command name", PASTE),
            ("SENDREF target title", ["orca-ide", "coord@main", "status", "no-nudge"], STDIN,
             "the target is not a term_ handle, run: or dispatch: address", PASTE_ANY),
            ("SENDREF target flag", ["orca-ide", "--interrupt", "status", "no-nudge"], STDIN,
             "the target is not a term_ handle, run: or dispatch: address", PASTE_ANY),
            ("SENDREF target newline", ["orca-ide", H + "\n" + H, "status", "nudge"], STDIN,
             "the target is not a term_ handle, run: or dispatch: address", PASTE_ANY),
            ("SENDREF type heartbeat", ["orca-ide", H, "heartbeat", "nudge"], STDIN,
             "the type is not status, question, handoff, escalation, merge_ready, reply or worker_done", PASTE),
            ("SENDREF five args for a send", ["orca-ide", H, "status", "nudge", "task_abcdef"], STDIN,
             "usage: orca-send.sh <cli> <target> <type> <nudge|no-nudge>, or <cli> dispatch:<id> worker_done <outcome> <task id>", PASTE),
            ("SENDREF nudge a run address", ["orca-ide", "run:run_abc", "status", "nudge"], STDIN,
             "only a term_ handle is nudged", END + "Needed from you: paste the block below into run:run_abc"),
            ("SENDREF bad mode", ["orca-ide", H, "status", "yes"], STDIN,
             "the fourth argument is not nudge or no-nudge", PASTE),
            ("SENDREF no stdin", ["orca-ide", H, "status", "nudge"], "", "stdin has no subject line", PASTE),
            ("SENDREF empty subject", ["orca-ide", H, "status", "nudge"], "  \nbody\n", "the subject is empty", PASTE),
            ("SENDREF empty body", ["orca-ide", H, "status", "nudge"], SUBJ + "\n \n", "the body is empty", PASTE),
            ("SENDREF subject starts --", ["orca-ide", H, "status", "nudge"], "--json\nbody\n",
             "the subject starts with --, which Orca reads as a flag", PASTE),
            ("SENDREF body starts --", ["orca-ide", H, "status", "nudge"], SUBJ + "\n--json\n",
             "the body starts with --, which Orca reads as a flag", PASTE),
            ("SENDREF over the size cap", ["orca-ide", H, "status", "nudge"], "s\n" + "x" * 28000 + "\n",
             "subject and body are 28001 bytes; the limit is 28000 (WSL command-line limit)", PASTE)]:
        store(name, 4, [SR + why, end], argv=args, stdin=stdin, called=False)
    # At the cap exactly: sent.
    store("STORE at the size cap", 0, [STORED], mode="no-nudge", stdin="s\n" + "x" * 27999 + "\n")

shutil.rmtree(TMP, ignore_errors=True)
print("-- %d/%d checks passed --" % (passed, passed + failed))
sys.exit(1 if failed else 0)
PY
