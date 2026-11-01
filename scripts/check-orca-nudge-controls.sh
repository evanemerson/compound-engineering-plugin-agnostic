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
# Every leg of the check (SEND, STATE, WAIT, LOOKUP, REFUSE, FAIL, ENDING, RETRY, STORE, REPLY, WDONE, SENDREF,
# FIELDS, FILE, BLOCK, SESSION, GUARD, NUDGEFILE, ALERT, HEALTH, HEALTHREF) has at least one
# mutant here that only its cases kill. WAIT runs on a fake clock, and the
# mutants run in parallel.
#
# Each mutant runs only the half of the check that can see it
# (CEPA_NUDGE_CHECK_LEGS): an orca-nudge.sh mutant runs the nudge legs, and an
# orca-send.sh mutant runs the send legs. The send legs run the shipped nudge
# beside orca-send.sh, never argument 1, so a nudge mutant cannot change them;
# the nudge legs never run orca-send.sh. The unmutated copy runs whole and as
# both halves, and the halves must partition the whole run's cases. Cost, with
# `time bash scripts/check-orca-nudge-controls.sh` on a 16-core box: 3m33s
# when every mutant ran all 154 cases; see the PR #106 body for the time after
# the split. On a 4-vCPU CI runner the old cost hit the job's 10-minute bound.
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
     {'ALERT failed send writes one file', 'ALERT worker_done failure names its dispatch', 'REPLY ok false', 'STORE ok false', 'STORE ok false code not a word', 'STORE ok truthy', 'WDONE ok false'}),
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
    ('send-fail-continues', 'cepa_send_alert send_failed "$1"; cepa_send_ending; exit 5; }', 'cepa_send_alert send_failed "$1"; cepa_send_ending; }',
     {'ALERT failed send writes one file', 'ALERT relative directory is not used', 'ALERT unmakeable directory is reported', 'ALERT worker_done failure names its dispatch', 'GUARD mktemp fails', 'GUARD no python3', 'GUARD no timeout', 'REPLY ok false', 'SESSION failed send names it', 'STORE JSON list', 'STORE bad message id', 'STORE empty stdout', 'STORE envelope id without result.message', 'STORE envelope uuid as message id', 'STORE id in the inbox for another recipient', 'STORE id missing from the inbox', 'STORE inbox fails', 'STORE inbox not JSON', 'STORE inbox not ok', 'STORE inbox wrong shape', 'STORE not JSON', 'STORE ok false', 'STORE ok false code not a word', 'STORE ok reply with a non-zero exit', 'STORE ok truthy', 'STORE send timeout not retried', 'STORE send vsock twice', 'STORE warning-only result', 'WDONE empty stdout', 'WDONE ok false'}),
    ('send-no-size-cap', '-le 28000 ]', '-le 99999999 ]',
     {'SENDREF cap counts bytes', 'SENDREF over the size cap'}),
    ('send-cap-counts-chars', 'cepa_send_bytes=$(LC_ALL=C; printf \'%s%s\' "$cepa_send_subject" "$cepa_send_body" | wc -c)', 'cepa_send_bytes=$(( ${#cepa_send_subject} + ${#cepa_send_body} ))',
     {'SENDREF cap counts bytes'}),
    ('send-nudge-any-target', 'nudge) [[ $cepa_send_target == term_* || $cepa_send_type == reply ]] ||', 'nudge) true ||',
     {'SENDREF nudge a run address'}),
    # L36 #20: every send carries a request id, so its vsock retry replays.
    ('send-no-request-id', '  --type "$cepa_send_type" --subject "$cepa_send_subject" --body "$cepa_send_body" \\\n  --retry-request "$cepa_send_req" --json ;;', '  --type "$cepa_send_type" --subject "$cepa_send_subject" --body "$cepa_send_body" \\\n  --json ;;',
     {'BLOCK hostile message is sent as text', 'FIELDS any order sends the same argv', 'STORE argv and order', 'STORE retry reuses the request id'}),
    # reply mode (punch-list L35)
    ('reply-thread-unchecked', 'if m.get("thread_id") != target:', 'if False:',
     {'REPLY not threaded on the question'}),
    ('reply-self-unchecked', 'sys.exit(3 if found and mine else 0 if found else 1)', 'sys.exit(0 if found else 1)',
     {'REPLY addressed to this session, question out of window', 'REPLY misaddressed is not nudged', 'REPLY to a message this session sent'}),
    ('reply-no-request-id', '--body "$cepa_send_body" --retry-request "$cepa_send_req" --json ;;', '--body "$cepa_send_body" --json ;;',
     {'REPLY argv', 'REPLY retry reuses the request id'}),
    ('reply-dispatch-nudged', 'if [[ $cepa_send_to != term_* ]]; then', 'if false; then',
     {'REPLY to a dispatch mailbox is not nudged'}),
    ('reply-target-loose', '[[ $cepa_send_target =~ ^msg_[0-9a-f]{6,32}$ ]] || refuse "a reply', 'true || refuse "a reply',
     {'REPLYREF target is a handle'}),
    # #106 review: a reply Orca addressed to this session is misaddressed
    # even when the question is outside the re-read window.
    ('reply-to-me-unchecked', '(sys.argv[3] == me or any(', '(any(',
     {'REPLY addressed to this session, question out of window'}),
    ('reply-handle-unvalidated', 'if not re.fullmatch(r"term_[0-9a-f-]{36}", me):', 'if False:',
     {'REPLY handle not a term_ handle is ignored'}),
    ('unproven-says-nothing-stored', 'unproven "${cepa_send_got#UNPROVEN }"', 'fail "${cepa_send_got#UNPROVEN }"',
     {'ALERT unproven send writes one file', 'STORE bad recipient', 'REPLY not threaded on the question', 'REPLY names no recipient', 'WDONE no lifecycle', 'WDONE wrong action', 'WDONE other dispatch', 'WDONE other task'}),
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
     {'SESSION worker_done names it', 'WDREF bad task id'}),
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
     {'SENDREF target with text before the handle'}),
    ('send-empty-body-ok', '[ -n "${cepa_send_body//[[:space:]]/}" ] || refuse "the body is empty"\n', '',
     {'REPLYREF empty body', 'SENDREF empty body', 'SESSION reply names it'}),
    # ALERT (punch-list L34): exit 4 and 5 each write one checked alert file.
    ('alert-not-on-fail', 'cepa_send_alert send_failed "$1"; cepa_send_ending; exit 5; }', 'cepa_send_ending; exit 5; }',
     {'ALERT failed send writes one file', 'ALERT relative directory is not used', 'ALERT unmakeable directory is reported', 'ALERT worker_done failure names its dispatch'}),
    ('alert-not-on-refuse', 'cepa_send_alert send_refused "$1"; cepa_send_ending; exit 4; }', 'cepa_send_ending; exit 4; }',
     {'ALERT refused send writes one file', 'ALERT unchecked values are replaced'}),
    ('alert-not-on-unproven', 'cepa_send_alert send_unproven "$1"; cepa_send_ending; exit 5; }', 'cepa_send_ending; exit 5; }',
     {'ALERT unproven send writes one file'}),
    ('alert-sender-unchecked', '[[ $me =~ ^term_[0-9a-f-]{36}$ ]] || me=unknown', 'true || me=unknown',
     {'ALERT unchecked values are replaced'}),
    ('alert-target-unchecked', ']] || tgt=invalid', ']] || true',
     {'ALERT unchecked values are replaced'}),
    ('alert-relative-dir', '[[ $dir == /* ]] || { echo "Orca alert not recorded: the alert directory is not an absolute path"; return 0; }\n', '',
     {'ALERT relative directory is not used'}),
    ('alert-mkdir-unchecked', 'mkdir -p "$dir" 2>/dev/null || { echo', 'mkdir -p "$dir" 2>/dev/null; true || { echo',
     {'ALERT unmakeable directory is reported'}),
    # FILE (punch-list L41): the message is in a file, read once and removed.
    ('file-not-removed', '{ cepa_send_msg=$(cat -- "$cepa_send_file"); } 2>/dev/null && rm -f -- "$cepa_send_file" \\\n  && [ ! -e "$cepa_send_file" ] || refuse',
     '{ cepa_send_msg=$(cat -- "$cepa_send_file"); } 2>/dev/null || refuse',
     {'FILE removed after a stored send', 'FILE removed after a refused send', 'BLOCK hostile message is sent as text'}),
    ('file-symlink-allowed', '[ -f "$cepa_send_file" ] && [ ! -L "$cepa_send_file" ] && [ -O', '[ -f "$cepa_send_file" ] && [ -O',
     {'FILE a symlink'}),
    ('file-any-name', '/cepa-send-[A-Za-z0-9._-]{1,64}\\.txt$', '/[A-Za-z0-9._-]{1,64}$',
     {'FILE another name', 'FILE another name keeps the file'}),
    ('file-dotdot-allowed', ' && $cepa_send_file != */../* ]]', ' ]]',
     {'FILE dot-dot part', 'FILE dot-dot part keeps the file'}),
    ('file-in-repo-allowed', '[[ $cepa_send_file != "$cepa_send_top"/* ]]', 'true',
     {'FILE inside the repo', 'FILE inside the repo keeps the file'}),
    ('file-field-optional', '[[ $cepa_send_seen == *" file "* ]] || refuse "the file field is missing"\n', '',
     {'FILE field missing'}),
    ('heredoc-message-allowed', '[ -z "${cepa_send_rest//[[:space:]]/}" ] \\\n', 'true \\\n',
     {'FIELDS 1.43.0 block is refused', 'FIELDS message after a file field is refused'}),
    # FIELDS (punch-list L38, #19): the values are field lines on stdin.
    ('fields-args-allowed', '[ $# -eq 0 ] || refuse', 'true || refuse',
     {'FIELDS arguments are refused'}),
    ('fields-twice-allowed', '[[ $cepa_send_seen != *" $cepa_send_k "* ]] || refuse', 'true || refuse',
     {'FIELDS name given twice'}),
    ('fields-any-name', '    cli|target|type|nudge|outcome|task|session|file) ;;', '    cli|target|type|nudge|outcome|task|session|file|to) ;;',
     {'FIELDS unknown name'}),
    ('fields-cr-kept', "  cepa_send_line=${cepa_send_line%$'\\r'}\n", '',
     {'FIELDS any order, CR and trailing spaces', 'FIELDS any order sends the same argv'}),
    ('fields-spaces-kept', '  cepa_send_v=${cepa_send_v%"${cepa_send_v##*[![:space:]]}"}\n', '',
     {'FIELDS any order, CR and trailing spaces', 'FIELDS any order sends the same argv'}),
    ('fields-required-unchecked', 'for cepa_send_k in cli target type; do', 'for cepa_send_k in; do',
     {'FIELDS no cli', 'FIELDS no target', 'FIELDS no type'}),
    ('fields-wd-nudge-allowed', '[[ $cepa_send_seen != *" nudge "* ]] || refuse', 'true || refuse',
     {'FIELDS nudge on a worker_done'}),
    ('fields-send-task-allowed', '[[ $cepa_send_seen != *" outcome "* && $cepa_send_seen != *" task "* ]] \\\n', 'true \\\n',
     {'FIELDS outcome on a send', 'SENDREF task field on a send'}),
    ('fields-wd-task-unrequired', '  for cepa_send_k in outcome task; do', '  for cepa_send_k in outcome; do',
     {'WDREF no task id'}),
    # SESSION (punch-list L38, #21): the optional name in the ending lines.
    ('session-unchecked', '[[ $cepa_send_f_session =~ ^[A-Za-z0-9._@][A-Za-z0-9._@-]{0,99}$ ]] \\\n', 'true \\\n',
     {'SESSION bad name refused', 'SESSION name starting with - refused'}),
    ('session-dash-first', '^[A-Za-z0-9._@][A-Za-z0-9._@-]{0,99}$', '^[A-Za-z0-9._@-]{1,100}$',
     {'SESSION name starting with - refused'}),
    ('session-not-named', 'if [ -n "$cepa_send_session" ]; then echo "$cepa_send_session ($1)"; else', 'if false; then echo "$cepa_send_session ($1)"; else',
     {'SESSION failed send names it', 'SESSION refused send names it', 'SESSION nudge skip names it', 'NUDGEFILE missing names the session'}),
    ('session-nudge-line-kept', '    || cepa_send_line="Ending first line:', '    || true || cepa_send_line="Ending first line:',
     {'SESSION nudge skip names it'}),
    # L36 #22: the send's own cli checks, its guards, the nudge file, the
    # to_handle fallback.
    ('send-cli-bare-orca', 'orca) [ "$(uname -s 2>/dev/null)" != Linux ] || refuse "bare orca on Linux is the screen reader" ;;', 'orca) ;;',
     {'SENDREF cli bare orca'}),
    ('send-cli-any-abs-path', '/*) [ "$cepa_send_cli" = "${ORCA_CLI_COMMAND:-}" ] || refuse "a cli path must equal ORCA_CLI_COMMAND" ;;', '/*) ;;',
     {'SENDREF cli path not ORCA_CLI_COMMAND'}),
    ('send-cli-relative-path', '*/*) refuse "a cli path must be absolute and equal ORCA_CLI_COMMAND" ;;', '*/*) ;;',
     {'SENDREF cli relative path'}),
    ('send-cli-flag', "''|-*|*[!A-Za-z0-9._/-]*) refuse \"the cli is not a plain command name\"", "''|*[!A-Za-z0-9._/-]*) refuse \"the cli is not a plain command name\"",
     {'SENDREF cli flag'}),
    ('send-cli-path-unchecked', 'command -v "$cepa_send_cli" >/dev/null 2>&1 || refuse', 'true || refuse',
     {'SENDREF cli not on PATH'}),
    ('send-timeout-unchecked', 'command -v timeout >/dev/null 2>&1 || fail', 'true || fail',
     {'GUARD no timeout'}),
    ('send-python3-unchecked', 'command -v python3 >/dev/null 2>&1 || fail', 'true || fail',
     {'GUARD no python3'}),
    ('send-mktemp-unchecked', 'cepa_send_tmp=$(mktemp -d 2>/dev/null) || fail "mktemp failed"', 'cepa_send_tmp=$(mktemp -d 2>/dev/null) || true',
     {'GUARD mktemp fails'}),
    ('send-no-to-fallback', '    elif to is None:\n        to = target\n', '    elif False:\n        to = target\n',
     {'STORE no to_handle falls back to the target'}),
    ('nudge-file-unchecked', 'if [ ! -f "$cepa_send_nudge" ]; then', 'if false; then',
     {'NUDGEFILE missing', 'NUDGEFILE missing names the session'}),
    ('nudge-wont-start-ignored', 'if [ "$cepa_send_nrc" -gt 3 ]; then', 'if false; then',
     {'NUDGEFILE would not start'}),
    ('nudge-blank-line', '[ -z "$cepa_send_nout" ] || while', 'while',
     {'NUDGEFILE printed nothing, exit 0', 'NUDGEFILE printed nothing, exit 2', 'NUDGEFILE would not start'}),
    # PR #110 review fixes.
    ('nudge-silent-ok', 'if [ "$cepa_send_nrc" -le 3 ] && [ -z "$cepa_send_nout" ]; then', 'if false; then',
     {'NUDGEFILE printed nothing, exit 0', 'NUDGEFILE printed nothing, exit 2'}),
    ('session-bare-refused', '^([a-z]+):(\\ (.*))?$', '^([a-z]+):\\ ((.*))$',
     {'SESSION bare field is no name'}),
    ('fields-from-env', 'unset cepa_send_f_cli', ': cepa_send_f_cli',
     {'SESSION from the environment is ignored'}),
    ('fields-target-late', '    target) cepa_send_target=$cepa_send_v ;;\n', '',
     # Every refusal before the target is copied (the heredoc and file
     # checks, L41) then names "the target session".
     {'FIELDS 1.43.0 block is refused', 'FIELDS message after a file field is refused', 'FIELDS name given twice',
      'FILE a directory', 'FILE a symlink', 'FILE another name', 'FILE does not exist', 'FILE dot-dot part',
      'FILE field missing', 'FILE inside the repo', 'FILE relative path', 'FILE space in the path',
      'SENDREF target newline'}),
    ('subject-cr-kept', "  cepa_send_subject=${cepa_send_subject%$'\\r'}\n", '',
     {'FIELDS any order sends the same argv'}),
]
# orca-health.sh mutants (punch-list L34). Each runs only the health half,
# with the shipped nudge and send scripts as arguments 1 and 2.
HEALTH_MUTANTS = [
    ('health-stale-bound', 'HB_STALE, RUN_LONG, Q_WAIT, AWAIT = 30, 180, 10, 30', 'HB_STALE, RUN_LONG, Q_WAIT, AWAIT = 31, 180, 10, 30', {'HEALTH new stale period alerts again', 'HEALTH stale with no heartbeat counts from the dispatch', 'HEALTH stale at 30 minutes'}),
    ('health-long-bound', 'HB_STALE, RUN_LONG, Q_WAIT, AWAIT = 30, 180, 10, 30', 'HB_STALE, RUN_LONG, Q_WAIT, AWAIT = 30, 181, 10, 30', {'HEALTH long at 180 minutes'}),
    ('health-question-bound', 'HB_STALE, RUN_LONG, Q_WAIT, AWAIT = 30, 180, 10, 30', 'HB_STALE, RUN_LONG, Q_WAIT, AWAIT = 30, 180, 11, 30', {'HEALTH question that threads on itself is unanswered', 'HEALTH worker question at 10 minutes', "HEALTH asker's own follow-up is not an answer"}),
    ('health-await-bound', 'HB_STALE, RUN_LONG, Q_WAIT, AWAIT = 30, 180, 10, 30', 'HB_STALE, RUN_LONG, Q_WAIT, AWAIT = 30, 180, 10, 31', {'HEALTH awaited reply at 30 minutes'}),
    ('health-input-ignored', 'if "input" not in cats and mins(last)', 'if mins(last)', {'HEALTH pending ask is not stale'}),
    ('health-exited-ignored', 'if verdict == "exited":', 'if False:', {'HEALTH exited worker'}),
    ('health-wait-ignored', '        if wait:\n', '        if False:\n', {'HEALTH waiting worker, no stale beside it'}),
    ('health-repo-unfiltered', 'mine = repo == "unknown" or f["repo"] in (repo, "unknown")', 'mine = True', {'HEALTH alert file of another repo is not'}),
    ('health-worktree-unfiltered', '        mine = f["worktree"] == wt\n', '        mine = True\n', {'HEALTH alert file of another worktree is not'}),
    ('health-unknown-repo-filtered', 'if mine and not main and repo != "unknown":', 'if mine and not main:', {'HEALTH unknown repo shows every file'}),
    ('health-shape-unchecked', 'shaped = lines[:1] == ["cepa-orca-alert 1"] and all(', 'shaped = True or all(', {'HEALTH alert file with a bad field', 'HEALTH alert file in an unknown shape'}),
    ('health-reason-unchecked', 'why = f["reason"] if any(r.fullmatch(f["reason"]) for r in REASONS) else "an unrecognised reason"', 'why = f["reason"]', {'HEALTH unknown reason is not shown'}),
    ('health-reason-list-short', '    r"no request id could be made", ', '    ', {'HEALTH every orca-send.sh reason is shown'}),
    ('health-follow-up-answers', ' and x.get("from_handle") != sender.get(t):', ':', {"HEALTH asker's own follow-up is not an answer"}),
    ('health-acks-ignored', 'acked = set(listdir(acked_dir, "ack-dir"))', 'acked = set()', {'HEALTH acked unreadable is unknown, never ok', 'HEALTH unreadable alert directory', 'HEALTH acked key is not reported', 'HEALTH acked file is not reported'}),
    ('health-acks-shared', 'cepa_h_acked="$cepa_h_dir/acked/$cepa_h_wt"', 'cepa_h_acked="$cepa_h_dir/acked"', {'HEALTH ack marks keys for this worktree only', 'HEALTH acked unreadable is unknown, never ok', "HEALTH another worktree's ack does not hide it", 'HEALTH acked key is not reported'}),
    ('health-ack-missing-file-ok', '[[ $k == send-failed:* ]] && [ ! -f', '[[ $k == none ]] && [ ! -f', {'HEALTH ack of a missing alert file fails'}),
    ('health-ack-key-loose', 'send-failed:[0-9]{1,12}-[A-Za-z0-9]{1,20}\\.alert|', 'send-failed:[A-Za-z0-9_.-]{1,40}|', {'HEALTHREF ack temp file name'}),
    ('health-hidden-is-ok', 'if hidden and not seen:', 'if False:', {'HEALTH acked unreadable is unknown, never ok'}),
    ('health-run-notok-empty', 'r = d["result"]["run"] if d.get("ok") is True else sys.exit(1)', 'r = d["result"]["run"] if d.get("ok") is True else None', {'HEALTH run-current not ok'}),
    ('health-run-id-unchecked', 'if not (isinstance(i, str) and re.fullmatch(r"run_[A-Za-z0-9_-]{1,64}", i)):\n    sys.exit(1)\n', '', {'HEALTH run-current bad run id'}),
    ('health-workers-shape-loose', 'rows = d["result"]["workers"] if d.get("ok") is True else sys.exit(1)', 'rows = d["result"].get("workers", []) if d.get("ok") is True else sys.exit(1)', {'HEALTH worker-list with no workers field'}),
    ('health-cap-ignored', 'if len(ids) > 20 or (', 'if False and (', {'HEALTH more than 20 live workers', 'HEALTH worker-list with more pages'}),
    ('health-page-ignored', ' or (isinstance(page, dict) and page.get("hasMore") is not False and "hasMore" in page)', '', {'HEALTH worker-list with more pages'}),
    ('health-settled-read', '        if p["outcome"] != "in_progress":\n', '        if False:\n', {'HEALTH settled in worker-show is skipped'}),
    ('health-id-unchecked', 'if did != n[:-5] or not', 'if not', {'HEALTH worker-show names another dispatch'}),
    ('health-show-date-unchecked', ' or start is None:', ':', {'HEALTH worker-show with a bad date'}),
    ('health-hb-undated-ok', '        if hb is None and disp.get("lastHeartbeatAt") is not None:\n', '        if False:\n', {'HEALTH worker-show with a heartbeat time it cannot date'}),
    ('health-crash-exits-1', '    os._exit(3)', '    os._exit(1)', {'HEALTH a reader crash is an alert'}),
    ('health-alert-dir-silent', '    except OSError:\n        unreadable(what,', '    except OSError:\n        return []\n        unreadable(what,', {'HEALTH unreadable alert directory'}),
    ('health-run-fail-silent', 'if os.path.exists(os.path.join(tmp, "run.fail")):\n    unreadable("run-current")\n', '', {'HEALTH run-current with no run field', 'HEALTH run-current not ok', 'HEALTH run-current bad run id', 'HEALTH run-current fails'}),
    ('health-inbox-fail-silent', 'if not isinstance(rows, list):\n    unreadable("inbox")\n', 'if not isinstance(rows, list):\n    pass\n', {'HEALTH a timed-out call stops the rest', 'HEALTH inbox fails', 'HEALTH inbox with no messages field'}),
    ('health-no-wedge-stop', 'then cepa_h_wedged=1; return 1; fi', 'then return 1; fi', {'HEALTH no call after a timeout', 'HEALTH a timed-out call stops the rest'}),
    ('health-no-vsock-retry', '  for try in 1 2; do\n    t=$(date', '  for try in 1; do\n    t=$(date', {'HEALTH worker-list vsock once', 'HEALTH vsock retry runs worker-list twice'}),
    ('health-dir-relative', '[[ $cepa_h_dir == /* ]] || refuse "the alert directory is not an absolute path"\n', '', {'HEALTHREF relative alert directory'}),
    ('health-cli-any', '  orca-ide|orca-dev) ;;', '  orca-ide|orca-dev|bash) ;;', {'HEALTHREF cli not orca'}),
]
passed = failed = 0
TMP = tempfile.mkdtemp(prefix="cepa-nudge-ctl-")

def ok(msg):
    global passed; passed += 1; print("PASS", msg)

def miss(msg):
    global failed; failed += 1; print("MISS", msg)

def check(args, legs="all"):
    r = subprocess.run(["bash", CHECK] + args, capture_output=True, text=True, timeout=300,
                       env=dict(os.environ, CEPA_NUDGE_CHECK_LEGS=legs))
    lines = r.stdout.splitlines()
    return (r.returncode, {l[5:].split(":", 1)[0] for l in lines if l.startswith("MISS ")},
            {l[5:] for l in lines if l.startswith("PASS ")})

def run(script, legs="all"):
    return check([script], legs)[:2]

src = open(SCRIPT, encoding="utf-8").read()
clean = os.path.join(TMP, "clean.sh")
open(clean, "w", encoding="utf-8").write(src)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    (rc, misses, whole), (nrc, nmiss, nudge), (src_, smiss, send), (hrc, hmiss, hlth) = pool.map(
        lambda legs: check([clean], legs), ("all", "nudge", "send", "health"))
if rc == 0 and not misses:
    ok("unmutated copy runs with no MISS")
else:
    miss("unmutated copy: rc=%s, MISS %r" % (rc, sorted(misses)[:3]))
# The parts split the whole run: each case runs in exactly one part.
if nrc == src_ == hrc == 0 and not nmiss | smiss | hmiss and nudge and send and hlth \
        and not nudge & send and not nudge & hlth and not send & hlth and nudge | send | hlth == whole:
    ok("the nudge (%d), send (%d) and health (%d) parts partition the %d cases"
       % (len(nudge), len(send), len(hlth), len(whole)))
else:
    miss("parts: rc %s/%s/%s, %d+%d+%d cases, %d not in any"
         % (nrc, src_, hrc, len(nudge), len(send), len(hlth), len(whole - nudge - send - hlth)))

def run_mutant(m):
    name, old, new, want = m
    if src.count(old) != 1:
        return m, None, None
    path = os.path.join(TMP, name + ".sh")
    open(path, "w", encoding="utf-8").write(src.replace(old, new))
    return (m,) + run(path, "nudge")

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
    return (m,) + check([SCRIPT, os.path.join(d, "orca-send.sh")], "send")[:2]

with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    results = list(pool.map(run_send_mutant, SEND_MUTANTS))
for (name, old, new, want), rc, got in results:
    if rc is None:
        miss("%s: anchor found %d times, want 1" % (name, send_src.count(old))); continue
    if rc == 1 and got == want:
        ok("%s goes red on %s" % (name, ", ".join(sorted(want))))
    else:
        miss("%s: rc=%s, MISS set %r" % (name, rc, sorted(got)))

# BLOCK (punch-list L41): mutants of SKILL.md's rule 1 block, run by the
# send half against the shipped scripts.
SKILL = "plugins/cepa/skills/autonomy/SKILL.md"
skill_src = open(SKILL, encoding="utf-8").read()
SKILL_MUTANTS = [
    ("block-message-in-heredoc", "     file: <file>\n     CEPA_FIELDS\n",
     "     file: <file>\n\n     <subject, one line>\n     <body>\n     CEPA_FIELDS\n",
     {"BLOCK heredoc holds only field lines", "BLOCK hostile message is sent as text"}),
    ("block-no-file-field", "     session: <session>\n     file: <file>\n", "     session: <session>\n",
     {"BLOCK heredoc holds only field lines", "BLOCK hostile message is sent as text"}),
]

def run_skill_mutant(m):
    name, old, new, want = m
    if skill_src.count(old) != 1:
        return m, None, None
    path = os.path.join(TMP, "skill-" + name + ".md")
    open(path, "w", encoding="utf-8").write(skill_src.replace(old, new))
    return (m,) + check([SCRIPT, SEND, "plugins/cepa/scripts/orca-health.sh", path], "send")[:2]

with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    results = list(pool.map(run_skill_mutant, SKILL_MUTANTS))
for (name, old, new, want), rc, got in results:
    if rc is None:
        miss("%s: anchor found %d times, want 1" % (name, skill_src.count(old))); continue
    if rc == 1 and got == want:
        ok("%s goes red on %s" % (name, ", ".join(sorted(want))))
    else:
        miss("%s: rc=%s, MISS set %r" % (name, rc, sorted(got)))

HEALTH = "plugins/cepa/scripts/orca-health.sh"
health_src = open(HEALTH, encoding="utf-8").read()

def run_health_mutant(m):
    name, old, new, want = m
    if health_src.count(old) != 1:
        return m, None, None
    path = os.path.join(TMP, "health-" + name + ".sh")
    open(path, "w", encoding="utf-8").write(health_src.replace(old, new))
    return (m,) + check([SCRIPT, SEND, path], "health")[:2]

with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    results = list(pool.map(run_health_mutant, HEALTH_MUTANTS))
for (name, old, new, want), rc, got in results:
    if rc is None:
        miss("%s: anchor found %d times, want 1" % (name, health_src.count(old))); continue
    if rc == 1 and got == want:
        ok("%s goes red on %s" % (name, ", ".join(sorted(want))))
    else:
        miss("%s: rc=%s, MISS set %r" % (name, rc, sorted(got)))

shutil.rmtree(TMP, ignore_errors=True)
print("-- %d/%d controls passed --" % (passed, passed + failed))
raise SystemExit(1 if failed else 0)
PY
