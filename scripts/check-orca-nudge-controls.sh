#!/usr/bin/env bash
# Controls for scripts/check-orca-nudge.sh. Each mutant is one substitution in
# a temp copy of plugins/cepa/scripts/orca-nudge.sh. It must turn the check red
# with EXACTLY the MISS cases named beside it, so each mutant shows which case
# catches it and that no other case does.
# The unmutated copy must run with no MISS line, or every red below proves
# nothing. A mutant whose anchor text is gone is a MISS, never a skip: the
# shipped script changed shape and these mutants need re-reading.
#
# Every leg of the check (SEND, STATE, LOOKUP, REFUSE, FAIL) has at least one
# mutant here that only its cases kill. The check has no slow cases, so the
# whole set runs in well under a minute.
#
# STATED LIMITS: a mutant is one substitution; two compensating edits are not
# modeled. The controls prove each named case can fail, not that the case list
# is complete.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

python3 - <<'PY'
import os, shutil, subprocess, tempfile

SCRIPT = "plugins/cepa/scripts/orca-nudge.sh"
CHECK = "scripts/check-orca-nudge.sh"
# (name, old, new, exact MISS case set)
MUTANTS = [
    # SEND
    ("send-interrupt", '--enter --json </dev/null >"$cepa_nudge_tmp/send.json"',
     '--enter --interrupt --json </dev/null >"$cepa_nudge_tmp/send.json"',
     {"SEND done", "SEND never --interrupt"}),
    ("send-content-spliced", 'check --peek --json"\n', 'check --peek --json $cepa_nudge_term"\n',
     {"SEND done", "SEND orca-dev", "SEND cli path is ORCA_CLI_COMMAND", "SEND row in second worktree"}),
    ("send-no-enter", '--text "$cepa_nudge_text" --enter --json', '--text "$cepa_nudge_text" --json', {"SEND done"}),
    # STATE
    ('state-waiting-idle', 'if state == "done":', 'if state in ("done", "waiting"):',
     # The decoy case's target row is `waiting` too.
     {"STATE waiting", "STATE other row done"}),
    ('state-blocked-idle', 'if state == "done":', 'if state in ("done", "blocked"):', {"STATE blocked"}),
    ('state-working-idle', 'if state == "done":', 'if state in ("done", "working"):', {"STATE working"}),
    ("state-echoed-raw", 'elif isinstance(state, str) and re.fullmatch(r"[a-z_-]{1,20}", state):',
     "elif isinstance(state, str):", {"STATE not a word"}),
    ("state-missing-is-done", 'state = rows[0].get("state")', 'state = rows[0].get("state", "done")',
     {"STATE missing"}),
    ("state-first-of-many", "if len(rows) > 1:", "if len(rows) > 2:", {"STATE two rows"}),
    ("state-loose-match", 'if a.get("paneKey") == key]', 'if str(a.get("paneKey")).startswith(tab)]',
     {"STATE other row done"}),
    ("state-guard-gone", '[ "$cepa_nudge_state" = done ] || skip "$cepa_nudge_state"\n', "\n",
     {"STATE waiting", "STATE blocked", "STATE working", "STATE not a word", "STATE missing",
      "STATE no row", "STATE two rows", "STATE other row done",
      "LOOKUP show names another handle", "LOOKUP ps not ok", "LOOKUP show not ok", "LOOKUP show empty ids"}),
    # LOOKUP
    ("lookup-handle-unchecked", 't.get("handle") != term or ', "", {"LOOKUP show names another handle"}),
    ("lookup-show-rc-ignored", '|| skip "terminal show failed or timed out"', "|| true", {"LOOKUP show fails"}),
    ("lookup-ps-rc-ignored", '|| skip "worktree ps failed or timed out"', "|| true", {"LOOKUP ps fails"}),
    ("lookup-ok-unchecked", 'if show.get("ok") is not True or ps.get("ok") is not True:', "if False:",
     {"LOOKUP ps not ok", "LOOKUP show not ok"}),
    ("lookup-show-ok-unchecked", 'show.get("ok") is not True or ', "", {"LOOKUP show not ok"}),
    ("lookup-empty-ids", " or not tab or not leaf:", ":", {"LOOKUP show empty ids"}),
    ("lookup-show-no-json", 'terminal show --terminal "$cepa_nudge_term" --json', 'terminal show --terminal "$cepa_nudge_term"',
     {"SEND lookup argv"}),
    ("lookup-ps-no-agent-wait", '"$cepa_nudge_cli" worktree ps --agent-wait --json', '"$cepa_nudge_cli" worktree ps --json', {"SEND lookup argv"}),
    ("lookup-first-worktree-only", '.get("worktrees") or [])', '.get("worktrees") or [])[:1]',
     {"SEND row in second worktree"}),
    # REFUSE
    ("refuse-bare-orca", "orca) [ \"$(uname -s 2>/dev/null)\" != Linux ] || refuse \"bare orca on Linux is the screen reader\" ;;",
     "orca) ;;", {"REFUSE cli bare orca"}),
    ("refuse-cli-flag", "''|-*|*[!A-Za-z0-9._/-]*) refuse", "''|*[!A-Za-z0-9._/-]*) refuse", {"REFUSE cli flag"}),
    ("refuse-cli-chars", "''|-*|*[!A-Za-z0-9._/-]*) refuse", "''|-*) refuse", {"REFUSE cli shell text"}),
    ("refuse-cli-any", "  orca-ide|orca-dev) ;;", "  orca-ide|orca-dev|bash) ;;", {"REFUSE cli not orca"}),
    ("refuse-cli-no-orca-dev", "  orca-ide|orca-dev) ;;", "  orca-ide) ;;",
     # The not-on-PATH case uses orca-dev too, and now meets the earlier refusal.
     {"SEND orca-dev", "REFUSE cli not on PATH"}),
    ("refuse-cli-any-abs-path", '/*) [ "$cepa_nudge_cli" = "${ORCA_CLI_COMMAND:-}" ] || refuse "a cli path must equal ORCA_CLI_COMMAND" ;;',
     "/*) ;;", {"REFUSE cli path not ORCA_CLI_COMMAND"}),
    ("refuse-cli-relative-path", '*/*) refuse "a cli path must be absolute and equal ORCA_CLI_COMMAND" ;;', "*/*) ;;",
     {"REFUSE cli relative path"}),
    ("refuse-cli-not-on-path", 'command -v "$cepa_nudge_cli" >/dev/null 2>&1 || refuse "$cepa_nudge_cli is not on PATH"\n', "",
     {"REFUSE cli not on PATH"}),
    ("refuse-handle-unanchored", "=~ ^term_[0-9a-f-]{36}$ ]]", "=~ ^term_ ]]",
     {"REFUSE handle upper", "REFUSE handle trailing", "REFUSE handle newline"}),
    ("refuse-handle-case", "=~ ^term_[0-9a-f-]{36}$ ]]", "=~ ^term_[0-9a-fA-F-]{36}$ ]]", {"REFUSE handle upper"}),
    ("refuse-argc", "[ $# -eq 2 ]", "[ $# -ge 2 ]", {"REFUSE arg count"}),
    # FAIL
    ("fail-send-rc-ignored", 'echo "Orca nudge failed: terminal send exited non-zero or timed out"; exit 3', ":",
     {"FAIL send exits"}),
    ("fail-send-ok-unchecked", 'sys.exit(0 if json.load(open(sys.argv[1])).get("ok") is True else 1)',
     "sys.exit(0)", {"FAIL send not ok", "FAIL send ok truthy"}),
    ("fail-send-ok-truthy", '.get("ok") is True else 1)', '.get("ok") else 1)', {"FAIL send ok truthy"}),
]
passed = failed = 0
TMP = tempfile.mkdtemp(prefix="cepa-nudge-ctl-")

def ok(msg):
    global passed; passed += 1; print("PASS", msg)

def miss(msg):
    global failed; failed += 1; print("MISS", msg)

def run(script):
    r = subprocess.run(["bash", CHECK, script], capture_output=True, text=True, timeout=300)
    return r.returncode, {l[5:].split(":", 1)[0] for l in r.stdout.splitlines() if l.startswith("MISS ")}

src = open(SCRIPT, encoding="utf-8").read()
clean = os.path.join(TMP, "clean.sh")
open(clean, "w", encoding="utf-8").write(src)
rc, misses = run(clean)
if rc == 0 and not misses:
    ok("unmutated copy runs with no MISS")
else:
    miss("unmutated copy: rc=%s, MISS %r" % (rc, sorted(misses)[:3]))

for name, old, new, want in MUTANTS:
    if src.count(old) != 1:
        miss("%s: anchor found %d times, want 1" % (name, src.count(old))); continue
    path = os.path.join(TMP, name + ".sh")
    open(path, "w", encoding="utf-8").write(src.replace(old, new))
    rc, got = run(path)
    if rc == 1 and got == want:
        ok("%s goes red on %s" % (name, ", ".join(sorted(want))))
    else:
        miss("%s: rc=%s, MISS set %r" % (name, rc, sorted(got)))

shutil.rmtree(TMP, ignore_errors=True)
print("-- %d/%d controls passed --" % (passed, passed + failed))
raise SystemExit(1 if failed else 0)
PY
