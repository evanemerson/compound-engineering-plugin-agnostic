#!/usr/bin/env bash
# Controls for scripts/check-orca-nudge.sh. Each mutant is one substitution in
# a temp copy of plugins/cepa/scripts/orca-nudge.sh, or of orca-send.sh
# (SEND_MUTANTS). It must turn the check red
# with EXACTLY the MISS cases named beside it, so each mutant shows which case
# catches it and that no other case does.
# The unmutated copy must run with no MISS line, or every red below proves
# nothing. A mutant whose anchor text is gone is a MISS, never a skip: the
# shipped script changed shape and these mutants need re-reading.
#
# Every leg of the check (SEND, STATE, WAIT, LOOKUP, REFUSE, FAIL, ENDING, RETRY, STORE, REPLY, WDONE, SENDREF) has at least one
# mutant here that only its cases kill. WAIT runs on a fake clock, and the
# mutants run in parallel: the whole set took 3m19s on 2026-10-31 after L35
# (`time bash scripts/check-orca-nudge-controls.sh`).
#
# STATED LIMITS: a mutant is one substitution; two compensating edits are not
# modeled. The controls prove each named case can fail, not that the case list
# is complete.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

python3 - <<'PY'
import concurrent.futures, os, shutil, subprocess, tempfile

SCRIPT = "plugins/cepa/scripts/orca-nudge.sh"
CHECK = "scripts/check-orca-nudge.sh"
# (name, old, new, exact MISS case set)
MUTANTS = [
    # SEND
    ("send-interrupt", '--enter --json; then', '--enter --interrupt --json; then',
     {"RETRY killed call not retried", "RETRY send retry target left done", "RETRY send vsock once", "RETRY send vsock twice", "SEND done", "SEND never --interrupt", "WAIT working then done sends"}),
    ("send-content-spliced", 'check --peek --json"\n', 'check --peek --json $cepa_nudge_term"\n',
     {"RETRY killed call not retried", "RETRY send retry target left done", "RETRY send vsock once", "RETRY send vsock twice", "SEND cli path is ORCA_CLI_COMMAND", "SEND done", "SEND orca-dev", "SEND row in second worktree", "WAIT working then done sends"}),
    ("send-no-enter", '--text "$cepa_nudge_text" --enter --json', '--text "$cepa_nudge_text" --json', {"RETRY killed call not retried", "RETRY send retry target left done", "RETRY send vsock once", "RETRY send vsock twice", "SEND done", "WAIT working then done sends"}),
    # STATE
    ('state-waiting-idle', 'if state == "done":', 'if state in ("done", "waiting"):',
     # The decoy case's target row is `waiting` too, and so is the row a
     # wait ends on.
     {"STATE waiting", "STATE other row done", "WAIT working then waiting", "ENDING skip"}),
    ('state-blocked-idle', 'if state == "done":', 'if state in ("done", "blocked"):', {"STATE blocked"}),
    ('state-working-idle', 'if state == "done":', 'if state in ("done", "working"):',
     {"RETRY send retry target left done", "WAIT bound ignores env", "WAIT clock off the poll grid", "WAIT date gives no clock", "WAIT ps fails mid-wait", "WAIT sleep fails", "WAIT working past the bound", "WAIT working then done sends", "WAIT working then waiting"}),
    ("state-echoed-raw", 'elif isinstance(state, str) and re.fullmatch(r"[a-z_-]{1,20}", state):',
     "elif isinstance(state, str):", {"STATE not a word"}),
    ("state-missing-is-done", 'state = rows[0].get("state")', 'state = rows[0].get("state", "done")',
     {"STATE missing"}),
    ("state-first-of-many", "if len(rows) > 1:", "if len(rows) > 2:", {"STATE two rows"}),
    ("state-loose-match", 'if a.get("paneKey") == key]', 'if str(a.get("paneKey")).startswith(tab)]',
     {"STATE other row done"}),
    ("state-guard-gone", '[ "$cepa_nudge_state" = done ] || skip "$cepa_nudge_state"\n', "\n",
     {"STATE waiting", "STATE blocked", "STATE not a word", "STATE missing",
      "STATE no row", "STATE two rows", "STATE other row done",
      "LOOKUP show names another handle", "LOOKUP ps not ok", "LOOKUP show not ok", "LOOKUP show empty ids",
      "LOOKUP ps wrong shape", "WAIT working then waiting", "ENDING skip"}),
    # WAIT
    ("wait-bound-from-env", "cepa_nudge_wait=120\n", "cepa_nudge_wait=${CEPA_NUDGE_WAIT:-120}\n",
     {"WAIT bound ignores env"}),
    ("wait-bound-long", "cepa_nudge_wait=120\n", "cepa_nudge_wait=600\n",
     {"WAIT bound ignores env", "WAIT clock off the poll grid", "WAIT working past the bound"}),
    ("wait-poll-long", "cepa_nudge_poll=10\n", "cepa_nudge_poll=60\n",
     {"WAIT bound ignores env", "WAIT clock off the poll grid", "WAIT ps fails mid-wait", "WAIT working past the bound", "WAIT working then done sends", "WAIT working then waiting"}),
    ("wait-none", 'if [ "$cepa_nudge_state" = "the target is working" ]; then',
     'if false; then',
     {"WAIT bound ignores env", "WAIT clock off the poll grid", "WAIT date gives no clock", "WAIT ps fails mid-wait", "WAIT sleep fails", "WAIT working past the bound", "WAIT working then done sends", "WAIT working then waiting"}),
    ("wait-no-reread", "    cepa_nudge_read\n  done\n", "  done\n",
     {"WAIT clock off the poll grid", "WAIT ps fails mid-wait", "WAIT working then done sends", "WAIT working then waiting"}),
    ("wait-on-every-state", '  while [ "$cepa_nudge_state" = "the target is working" ]; do',
     '  while [ "$cepa_nudge_state" != done ]; do',
     {"WAIT working then waiting"}),
    ("wait-unbounded", '[ "$cepa_nudge_left" -gt 0 ] || skip', '[ 1 -gt 0 ] || skip',
     {"WAIT bound ignores env", "WAIT clock off the poll grid", "WAIT working past the bound"}),
    # #100 review of the wait: each of these survived the first WAIT leg.
    ("wait-ps-fail-first-only", '|| skip "worktree ps failed or timed out"',
     '|| { [ -z "${cepa_nudge_state:-}" ] && skip "worktree ps failed or timed out"; return; }',
     {"WAIT ps fails mid-wait"}),
    ("wait-date-unchecked", '|| skip "date gave no clock for the wait"', "|| true", {"WAIT date gives no clock"}),
    ("wait-no-clamp", '"$((cepa_nudge_left < cepa_nudge_poll ? cepa_nudge_left : cepa_nudge_poll))"',
     '"$cepa_nudge_poll"', {"WAIT clock off the poll grid"}),
    ("wait-bound-early", '[ "$cepa_nudge_left" -gt 0 ]', '[ "$cepa_nudge_left" -gt 5 ]',
     {"WAIT clock off the poll grid"}),
    ("wait-sleep-unchecked", ' \\\n      || skip "sleep failed in the wait"', "", {"WAIT sleep fails"}),
    # LOOKUP
    ("lookup-shape-uncaught", "except Exception:\n", "except ValueError:\n", {"LOOKUP ps wrong shape"}),
    ("lookup-handle-unchecked", 't.get("handle") != term or ', "", {"LOOKUP show names another handle"}),
    ("lookup-show-rc-ignored", '|| skip "terminal show failed or timed out"', "|| true",
     # The RETRY cases that end in a skip fail terminal show, as this case does.
     {"LOOKUP show fails", "RETRY NUL in stderr", "RETRY half the text", "RETRY other error", "RETRY other half of the text", "RETRY show vsock twice", "RETRY timed-out call not retried"}),
    ("lookup-ps-rc-ignored", '|| skip "worktree ps failed or timed out"', "|| true", {"LOOKUP ps fails", "WAIT ps fails mid-wait"}),
    ("lookup-ok-unchecked", 'if show.get("ok") is not True or ps.get("ok") is not True:', "if False:",
     {"LOOKUP ps not ok", "LOOKUP show not ok"}),
    ("lookup-show-ok-unchecked", 'show.get("ok") is not True or ', "", {"LOOKUP show not ok"}),
    ("lookup-empty-ids", " or not tab or not leaf:", ":", {"LOOKUP show empty ids"}),
    ("lookup-show-no-json", 'terminal show --terminal "$cepa_nudge_term" --json', 'terminal show --terminal "$cepa_nudge_term"',
     {"RETRY NUL in stderr", "RETRY half the text", "RETRY other error", "RETRY other half of the text", "RETRY show vsock once", "RETRY show vsock twice", "RETRY timed-out call not retried", "SEND lookup argv"}),
    ("lookup-ps-no-agent-wait", '"$cepa_nudge_tmp/ps.json" worktree ps --agent-wait --json', '"$cepa_nudge_tmp/ps.json" worktree ps --json', {"RETRY ps vsock once", "SEND lookup argv"}),
    ("lookup-first-worktree-only", '.get("worktrees") or [])', '.get("worktrees") or [])[:1]',
     {"SEND row in second worktree"}),
    # REFUSE
    ("refuse-bare-orca", "orca) [ \"$(uname -s 2>/dev/null)\" != Linux ] || refuse \"bare orca on Linux is the screen reader\" ;;",
     "orca) ;;", {"REFUSE cli bare orca"}),
    ("refuse-cli-flag", "''|-*|*[!A-Za-z0-9._/-]*) refuse", "''|*[!A-Za-z0-9._/-]*) refuse", {"REFUSE cli flag"}),
    ("refuse-cli-chars", "''|-*|*[!A-Za-z0-9._/-]*) refuse", "''|-*) refuse", {"REFUSE cli shell text"}),
    ("refuse-cli-any", "  orca-ide|orca-dev) ;;", "  orca-ide|orca-dev|bash) ;;", {"REFUSE cli not orca", "ENDING refuse cli"}),
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
     {"REFUSE handle upper", "REFUSE handle trailing", "REFUSE handle newline", "ENDING refuse handle is not printed"}),
    ("refuse-handle-case", "=~ ^term_[0-9a-f-]{36}$ ]]", "=~ ^term_[0-9a-fA-F-]{36}$ ]]", {"REFUSE handle upper"}),
    ("refuse-argc", "[ $# -eq 2 ]", "[ $# -ge 2 ]", {"REFUSE arg count", "ENDING refuse arg count"}),
    # FAIL
    ("fail-send-rc-ignored", '  fail "terminal send exited non-zero or timed out"\n', "  :\n",
     # A send that fails twice on the vsock error now reaches the ok check.
     {"ENDING fail", "FAIL send exits", "RETRY killed call not retried", "RETRY send vsock twice"}),
    ("fail-send-ok-unchecked", 'sys.exit(0 if json.load(open(sys.argv[1])).get("ok") is True else 1)',
     "sys.exit(0)", {"FAIL send not ok", "FAIL send ok truthy"}),
    ("fail-send-ok-truthy", '.get("ok") is True else 1)', '.get("ok") else 1)', {"FAIL send ok truthy"}),
    # ENDING (L28): the ending's first line after every outcome but sent.
    ("ending-skip-dropped", 'skip() { echo "Orca nudge skipped: $1"; cepa_nudge_ending; exit 1; }',
     'skip() { echo "Orca nudge skipped: $1"; exit 1; }', {"ENDING skip"}),
    ("ending-refuse-dropped", 'refuse() { echo "Orca nudge refused: $1"; cepa_nudge_ending; exit 2; }',
     'refuse() { echo "Orca nudge refused: $1"; exit 2; }',
     {"ENDING refuse cli", "ENDING refuse arg count", "ENDING refuse handle is not printed"}),
    ("ending-fail-dropped", 'fail() { echo "Orca nudge failed: $1"; cepa_nudge_ending; exit 3; }',
     'fail() { echo "Orca nudge failed: $1"; exit 3; }', {"ENDING fail"}),
    ("ending-on-send", 'echo "Orca nudge sent to $cepa_nudge_term"\n',
     'echo "Orca nudge sent to $cepa_nudge_term"\ncepa_nudge_ending\n',
     {"ENDING sent has no ending line", "SEND done", "SEND orca-dev", "SEND cli path is ORCA_CLI_COMMAND",
      "SEND row in second worktree", "WAIT working then done sends"}),
    # The newline handle, printed raw, adds a third output line.
    ("ending-raw-handle", "  if cepa_nudge_valid_term; then", "  if true; then",
     {"ENDING refuse handle is not printed", "REFUSE handle newline"}),
    ("ending-text-wrong", 'tell $cepa_nudge_term to check its Orca inbox"', 'tell $cepa_nudge_term to check Orca"',
     {"ENDING skip", "ENDING refuse cli", "ENDING refuse arg count", "ENDING fail"}),
    # RETRY (L28): once, only on the WSL interop error.
    ("retry-any-error",
     '  [[ $cepa_nudge_e == *UtilAcceptVsock* && $cepa_nudge_e == *"accept4 failed 110"* ]] || return 1\n', "",
     {"RETRY other error", "RETRY half the text", "RETRY other half of the text"}),
    ("retry-none", "  for try in 1 2; do\n", "  for try in 1; do\n", {"RETRY NUL in stderr", "RETRY ps vsock once", "RETRY send vsock once", "RETRY send vsock twice", "RETRY show vsock once", "RETRY show vsock twice"}),
    ("retry-after-timeout", ' && [ "$rc" != 124 ] && [ "$rc" != 137 ]', "", {"RETRY killed call not retried", "RETRY timed-out call not retried"}),
    ("retry-after-kill", ' && [ "$rc" != 137 ]', "", {"RETRY killed call not retried"}),
    ("retry-send-no-reread", '    if [ "$1 $2" = "terminal send" ]; then', "    if false; then", {"RETRY send retry target left done", "RETRY send vsock once"}),
    ("retry-nul-warning", '{ cepa_nudge_e=$(<"$cepa_nudge_tmp/err"); } 2>/dev/null', 'cepa_nudge_e=$(<"$cepa_nudge_tmp/err")', {"RETRY NUL in stderr"}),
    ("retry-vsock-text-only", ' && $cepa_nudge_e == *"accept4 failed 110"*', "", {"RETRY half the text"}),
    ("retry-accept-text-only", "$cepa_nudge_e == *UtilAcceptVsock* && ", "", {"RETRY other half of the text"}),
]
# orca-send.sh mutants (punch-list L33). Each runs the check with the shipped
# nudge as its first argument and the mutant send script, a copy of the shipped
# nudge beside it, as its second.
SEND_MUTANTS = [
    ('send-msg-id-any', 're.fullmatch(r"msg_[0-9a-f]{6,32}", mid)', 're.fullmatch(r"\\S+", mid)',
     {'STORE envelope uuid as message id'}),
    ('send-ok-truthy', 'if d.get("ok") is not True:', 'if not d.get("ok"):',
     {'STORE ok truthy'}),
    ('send-ok-unchecked', 'if d.get("ok") is not True:', 'if False:',
     {'REPLY ok false', 'STORE ok false', 'STORE ok false code not a word', 'STORE ok truthy', 'WDONE ok false'}),
    ('send-rc-unchecked', '    if rc != 0:\n', '    if False:\n',
     {'STORE ok reply with a non-zero exit'}),
    ('send-no-reread', '  1) fail "$cepa_send_id is not in the inbox for $cepa_send_to" ;;', '  1) ;;',
     {'STORE id in the inbox for another recipient', 'STORE inbox not ok', 'STORE id missing from the inbox'}),
    ('send-inbox-parse-ignored', '  *) fail "the inbox could not be parsed, so $cepa_send_id is unconfirmed" ;;', '  *) ;;',
     {'STORE inbox not JSON', 'STORE inbox wrong shape'}),
    ('send-inbox-ok-unchecked', 'rows = d["result"]["messages"] if d.get("ok") is True else []', 'rows = d["result"]["messages"]',
     {'STORE inbox not ok'}),
    ('send-reread-any-recipient', ' and x.get("to_handle") == sys.argv[3]', '',
     {'STORE id in the inbox for another recipient'}),
    ('send-inbox-fail-ignored', '|| fail "the inbox could not be re-read, so $cepa_send_id is unconfirmed"', '|| true',
     {'STORE inbox fails'}),
    ('send-fail-continues', 'cepa_send_ending; exit 5; }', 'cepa_send_ending; }',
     {'REPLY names no recipient', 'REPLY not threaded on the question', 'REPLY ok false', 'STORE JSON list', 'STORE bad message id', 'STORE bad recipient', 'STORE empty stdout', 'STORE envelope id without result.message', 'STORE envelope uuid as message id', 'STORE id in the inbox for another recipient', 'STORE id missing from the inbox', 'STORE inbox fails', 'STORE inbox not JSON', 'STORE inbox not ok', 'STORE inbox wrong shape', 'STORE not JSON', 'STORE ok false', 'STORE ok false code not a word', 'STORE ok reply with a non-zero exit', 'STORE ok truthy', 'STORE send timeout not retried', 'STORE send vsock twice', 'STORE warning-only result', 'WDONE empty stdout', 'WDONE no lifecycle', 'WDONE ok false', 'WDONE other dispatch', 'WDONE other task', 'WDONE wrong action'}),
    ('send-no-size-cap', '-le 28000 ]', '-le 99999999 ]',
     {'SENDREF cap counts bytes', 'SENDREF over the size cap'}),
    ('send-cap-counts-chars', 'cepa_send_bytes=$(LC_ALL=C; printf \'%s%s\' "$cepa_send_subject" "$cepa_send_body" | wc -c)', 'cepa_send_bytes=$(( ${#cepa_send_subject} + ${#cepa_send_body} ))',
     {'SENDREF cap counts bytes'}),
    ('send-nudge-any-target', 'nudge) [[ $cepa_send_target == term_* || $cepa_send_type == reply ]] ||', 'nudge) true ||',
     {'SENDREF nudge a run address'}),
    ('send-five-args-any', '[ $# -eq 5 ] && [ "$cepa_send_type" = worker_done ]', '[ $# -eq 5 ]',
     {'SENDREF five args for a send'}),
    # L36 #20: every send carries a request id, so its vsock retry replays.
    ('send-no-request-id', '  --type "$cepa_send_type" --subject "$cepa_send_subject" --body "$cepa_send_body" \\\n  --retry-request "$cepa_send_req" --json ;;', '  --type "$cepa_send_type" --subject "$cepa_send_subject" --body "$cepa_send_body" \\\n  --json ;;',
     {'STORE argv and order', 'STORE retry reuses the request id'}),
    # reply mode (punch-list L35)
    ('reply-thread-unchecked', 'if m.get("thread_id") != target:', 'if False:',
     {'REPLY not threaded on the question'}),
    ('reply-self-unchecked', 'sys.exit(3 if found and mine else 0 if found else 1)', 'sys.exit(0 if found else 1)',
     {'REPLY misaddressed is not nudged', 'REPLY to a message this session sent'}),
    ('reply-no-request-id', '--body "$cepa_send_body" --retry-request "$cepa_send_req" --json ;;', '--body "$cepa_send_body" --json ;;',
     {'REPLY argv', 'REPLY retry reuses the request id'}),
    ('reply-dispatch-nudged', 'if [[ $cepa_send_to != term_* ]]; then', 'if false; then',
     {'REPLY to a dispatch mailbox is not nudged'}),
    ('reply-target-loose', '[[ $cepa_send_target =~ ^msg_[0-9a-f]{6,32}$ ]] || refuse "a reply', 'true || refuse "a reply',
     {'REPLYREF target is a handle'}),
    # worker_done mode (punch-list L35)
    ('wd-target-loose', '    [[ $cepa_send_target =~ ^dispatch:ctx_[0-9a-f]{6,32}$ ]] || refuse', '    true || refuse',
     {'WDREF target not a dispatch'}),
    ('wd-action-unchecked', 'lc.get("action") != action \\', 'False \\',
     {'WDONE wrong action'}),
    ('wd-dispatch-unchecked', 'lc.get("dispatchId") != target[len("dispatch:"):]', 'False',
     {'WDONE other dispatch'}),
    ('wd-task-unchecked', 'or lc.get("taskId") != task:', ':',
     {'WDONE other task'}),
    ('wd-outcome-map', '      failed) cepa_send_outcome=failed ;;', '      failed) cepa_send_outcome=completed ;;',
     {'WDONE failed outcome'}),
    ('wd-task-arg-unchecked', '[[ $cepa_send_task =~ ^task_[0-9a-f]{6,32}$ ]] || refuse', 'true || refuse',
     {'WDREF bad task id'}),
    ('wd-no-request-id', '      --retry-request "$cepa_send_req" --json ;;\n  *)', '      --json ;;\n  *)',
     {'WDONE argv, no nudge', 'WDONE retry reuses the request id'}),
    ('send-reroute-nudged', 'if [ "$cepa_send_to" != "$cepa_send_target" ]; then', 'if false; then',
     {'STORE stored for another handle', 'STORE rerouted to a Run mailbox'}),
    ('send-no-vsock-retry', '  for try in 1 2; do\n    timeout -k 2 15', '  for try in 1; do\n    timeout -k 2 15',
     {'REPLY retry reuses the request id', 'REPLY vsock retry', 'STORE inbox vsock once', 'STORE retry reuses the request id', 'STORE send retry', 'STORE send vsock once', 'STORE send vsock twice', 'WDONE retry reuses the request id', 'WDONE vsock retry'}),
    ('send-timeout-retried', '[ "$cepa_send_rc" != 124 ] && [ "$cepa_send_rc" != 137 ] ||', 'true ||',
     {'STORE send timeout not retried'}),
    ('send-dashdash-body', '[[ $cepa_send_body != --* ]] || refuse "the body starts with --, which Orca reads as a flag"\n', '',
     {'REPLYREF body starts --', 'SENDREF body starts --'}),
    ('send-code-raw', 're.fullmatch(r"[a-z_]{1,40}", code)', 'code',
     {'STORE ok false code not a word'}),
    ('send-target-loose', '^(term_[0-9a-f-]{36}|run:', '(term_[0-9a-f-]{36}|run:',
     {'SENDREF target newline'}),
    ('send-empty-body-ok', '[ -n "${cepa_send_body//[[:space:]]/}" ] || refuse "the body is empty"\n', '',
     {'REPLYREF empty body', 'SENDREF empty body'}),
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

def run_mutant(m):
    name, old, new, want = m
    if src.count(old) != 1:
        return m, None, None
    path = os.path.join(TMP, name + ".sh")
    open(path, "w", encoding="utf-8").write(src.replace(old, new))
    return (m,) + run(path)

# Each check run makes its own temp dir, so the runs share nothing.
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    results = list(pool.map(run_mutant, MUTANTS))
for (name, old, new, want), rc, got in results:
    if rc is None:
        miss("%s: anchor found %d times, want 1" % (name, src.count(old))); continue
    if rc == 1 and got == want:
        ok("%s goes red on %s" % (name, ", ".join(sorted(want))))
    else:
        miss("%s: rc=%s, MISS set %r" % (name, rc, sorted(got)))

SEND = "plugins/cepa/scripts/orca-send.sh"
send_src = open(SEND, encoding="utf-8").read()

def run_send_mutant(m):
    name, old, new, want = m
    if send_src.count(old) != 1:
        return m, None, None
    d = os.path.join(TMP, "send-" + name)
    os.mkdir(d)
    open(os.path.join(d, "orca-send.sh"), "w", encoding="utf-8").write(send_src.replace(old, new))
    shutil.copy(SCRIPT, d)
    r = subprocess.run(["bash", CHECK, SCRIPT, os.path.join(d, "orca-send.sh")],
                       capture_output=True, text=True, timeout=300)
    return m, r.returncode, {l[5:].split(":", 1)[0] for l in r.stdout.splitlines() if l.startswith("MISS ")}

with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    results = list(pool.map(run_send_mutant, SEND_MUTANTS))
for (name, old, new, want), rc, got in results:
    if rc is None:
        miss("%s: anchor found %d times, want 1" % (name, send_src.count(old))); continue
    if rc == 1 and got == want:
        ok("%s goes red on %s" % (name, ", ".join(sorted(want))))
    else:
        miss("%s: rc=%s, MISS set %r" % (name, rc, sorted(got)))

shutil.rmtree(TMP, ignore_errors=True)
print("-- %d/%d controls passed --" % (passed, passed + failed))
raise SystemExit(1 if failed else 0)
PY
