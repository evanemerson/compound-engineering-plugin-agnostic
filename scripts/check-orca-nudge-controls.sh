#!/usr/bin/env bash
# Controls for scripts/check-orca-nudge.sh. Each mutant is one substitution in
# a temp copy of plugins/cepa/scripts/orca-nudge.sh, of orca-send.sh
# (SEND_MUTANTS), of orca-health.sh (HEALTH_MUTANTS), of orca-rebind.sh
# (REBIND_MUTANTS), or of the autonomy skill's rule 1 block (SKILL_MUTANTS) or its
# rule 2 and 8 blocks (SKILLH_MUTANTS, run by the health legs). It must turn the check red with
# EXACTLY the MISS cases named beside it, so each mutant shows which case
# catches it and that no other case does.
# The unmutated copy must run with no MISS line, or every red below proves
# nothing. A mutant whose anchor text is gone is a MISS, never a skip: the
# shipped script changed shape and these mutants need re-reading.
#
# Every leg of the check (SEND, STATE, WAIT, LOOKUP, REFUSE, FAIL, ENDING, RETRY, STORE, REPLY, REPLYTHREAD,
# CHATREPLY, CHATSENDER, BOT, BOTRUN, WDONE, SENDREF,
# FIELDS, FILE, BLOCK, SESSION, GUARD, NUDGEFILE, ALERT, HEALTH, HEALTHREF, REBIND, REBINDREF, RULE2BLOCK,
# HEALTHBLOCK) has at least one
# mutant here that only its cases kill. WAIT runs on a fake clock, and the
# mutants run in parallel.
#
# Each mutant runs only the half of the check that can see it
# (CEPA_NUDGE_CHECK_LEGS): an orca-nudge.sh mutant runs the nudge legs, and an
# orca-send.sh or skill mutant runs the send legs. The send legs run the shipped nudge
# beside orca-send.sh, never argument 1, so a nudge mutant cannot change them;
# the nudge legs never run orca-send.sh. The unmutated copy runs whole and as
# each part, and the parts must partition the whole run's cases.
#
# `--shard I/N` runs only mutants I, I+N, I+2N, ... of the one list that holds
# every nudge, send, health and skill mutant in order (no argument means 1/1,
# every mutant). Each shard still runs the unmutated copy and the partition control
# first. CI runs shards 1/N to N/N as N parallel jobs (punch-list L42). Controls
# here fail unless residual-integrity.yml runs each shard exactly once, one per
# job, never disabled, and unless every shard of that N is non-empty; planted
# workflow edits prove that check can fail. So a dropped job cannot silently
# drop mutants. Cost history: 3m33s on a 16-core box when every mutant ran all
# 154 cases; the PR #106 body has the time after the part split; after PR #110
# the one hosted job took 7m24s-7m58s of its 10-minute bound (runs 41264491281,
# 41265227855); the PR #111 body has the per-shard times. With 319 mutants, 4
# hosted shards hit the 10-minute bound (run 44033973810), so PR #139 went to
# 12: shard 1/12 took 2m36s locally, about 1m40s of it the fixed baseline.
# With 403 mutants hosted shard 1/12 was cancelled at the bound (run
# 44612546947), so PR #146 went to 32; residual-integrity.yml's orca-nudge-32
# job has the local and hosted times.
#
# STATED LIMITS: a mutant is one substitution; two compensating edits are not
# modeled. The controls prove each named case can fail, not that the case list
# is complete.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }
shard=1/1
if [[ $# -eq 2 && $1 == --shard ]]; then
  shard=$2
elif [[ $# -ne 0 ]]; then
  echo "MISS usage: $0 [--shard I/N]"; exit 1
fi

CEPA_NUDGE_CONTROLS_SHARD=$shard python3 - <<'PY'
import concurrent.futures, os, re, shutil, subprocess, tempfile

SCRIPT = "plugins/cepa/scripts/orca-nudge.sh"
CHECK = "scripts/check-orca-nudge.sh"
# (name, old, new, exact MISS case set)
MUTANTS = [
    # SEND
    ("send-interrupt", '--enter --json; then', '--enter --interrupt --json; then',
     {"RETRY killed call not retried", "RETRY send retry target left done", "RETRY send vsock once", "RETRY send vsock twice", "SEND done", "SEND never --interrupt", "WAIT working then done sends"}),
    ("send-content-spliced", 'check --peek --full --json"\n', 'check --peek --full --json $cepa_nudge_term"\n',
     {"RETRY killed call not retried", "RETRY send retry target left done", "RETRY send vsock once", "RETRY send vsock twice", "SEND cli path is ORCA_CLI_COMMAND", "SEND done", "SEND orca-dev", "SEND row in second worktree", "WAIT working then done sends"}),
    # L73: the nudge names `check --full`, or the target reads Orca 1.4.246's
    # short form, with no deliveryId to ack.
    ("send-drops-full", 'check --peek --full --json"\n', 'check --peek --json"\n',
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
    ("refuse-bare-orca", "*) refuse \"bare orca on Linux is the screen reader\" ;;",
     "*) ;;", {"REFUSE cli bare orca"}),
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
     {'ALERT worker_done failure names its dispatch', 'REPLY ok false', 'ALERT failed send writes one file', 'STORE ok truthy', 'WDONE ok false', 'READBACK ok false is a result, no read', 'STORE ok false', 'READBACK ok false makes no inbox call', 'STORE ok false code not a word'}),
    ('send-rc-unchecked', '    if rc != 0:\n', '    if False:\n', {'FOLLOWUP that exited non-zero fails', 'STORE ok reply with a non-zero exit'}),
    ('send-no-reread', '  1) fail "$cepa_send_id is not in the inbox for $cepa_send_to" ;;', '  1) ;;', {'BOT chat row missing from the inbox', 'BOTRUN row for another Run is not stored', 'BOTRUN row missing from the inbox', "HOSTON row only in this machine's inbox does not count", 'STORE downgraded send missing from the inbox', 'STORE id in the inbox for another recipient', 'STORE id missing from the inbox', 'STORE inbox not ok'}),
    ('send-inbox-parse-ignored', '  *) fail "the inbox could not be parsed, so $cepa_send_id is unconfirmed" ;;', '  *) ;;',
     {'STORE inbox not JSON', 'STORE inbox wrong shape', 'STORE inbox in the 1.4.246 short shape'}),
    ('send-inbox-ok-unchecked', 'rows = d["result"]["messages"] if d.get("ok") is True else []', 'rows = d["result"]["messages"]',
     {'STORE inbox not ok'}),
    ('send-reread-any-recipient', ' and x.get("to_handle") == sys.argv[3]', '',
     {'BOT chat row missing from the inbox', 'BOTRUN row for another Run is not stored', 'STORE downgraded send missing from the inbox', 'STORE id in the inbox for another recipient'}),
    ('send-inbox-fail-ignored', '|| fail "the inbox could not be re-read, so $cepa_send_id is unconfirmed"', '|| true',
     {'STORE inbox fails'}),
    ('send-fail-continues', 'cepa_send_alert send_failed "$1"; cepa_send_ending; exit 5; }', 'cepa_send_alert send_failed "$1"; cepa_send_ending; }', {'ALERT failed send writes one file', 'ALERT relative directory is not used', 'ALERT unmakeable directory is reported', 'ALERT worker_done failure names its dispatch', 'BOT chat row missing from the inbox', 'BOT read back skips a row for another address', 'BOT with no recipient and no row is not stored', 'BOTRUN row for another Run is not stored', 'BOTRUN row missing from the inbox', 'FOLLOWUP shape for a term_ target fails', 'FOLLOWUP shape on a worker_done is not a follow-up', 'FRESH timed-out worker_done is not re-read', 'GUARD mktemp fails', 'GUARD no python3', 'GUARD no timeout', 'HOSTON read-back sender form of another handle fails', "HOSTON row only in this machine's inbox does not count", "READBACK from a chat skips another sender's row", 'READBACK host sender form without on fails', 'READBACK inbox read fails', 'READBACK no clock makes no inbox call', 'READBACK no clock makes no read-back', 'READBACK ok false is a result, no read', 'READBACK ok false makes no inbox call', "READBACK reply is not read back on the question's root", 'READBACK reply on another thread fails', 'READBACK reply to a reply with no question row fails', 'READBACK row from another sender', 'READBACK row of another type', 'READBACK row older than the window', 'READBACK row stored for another recipient fails', 'READBACK row with a bad id', 'READBACK row with another body', 'READBACK row with another subject', 'READBACK row with no date', 'READBACK run target needs that run', 'READBACK worker_done row of another dispatch fails', 'READBACK worker_done row of another task fails', 'READBACK worker_done row with another outcome fails', 'REPLY ok false', 'SESSION failed send names it', 'STORE JSON list', 'STORE bad message id', 'STORE downgraded send missing from the inbox', 'STORE downgraded send that stored nothing', 'STORE empty stdout', 'STORE envelope id without result.message', 'STORE envelope uuid as message id', 'STORE id in the inbox for another recipient', 'STORE id missing from the inbox', 'STORE inbox fails', 'STORE inbox in the 1.4.246 short shape', 'STORE inbox not JSON', 'STORE inbox not ok', 'STORE inbox wrong shape', 'STORE not JSON', 'STORE ok false', 'STORE ok false code not a word', 'STORE ok reply with a non-zero exit', 'STORE ok truthy', 'STORE send output in the 1.4.246 short shape', 'STORE send timeout not retried', 'STORE send vsock twice', 'STORE warning-only result', 'WDONE empty stdout', 'WDONE ok false'}),
    ('send-no-size-cap', '-le 28000 ]', '-le 99999999 ]',
     {'SENDREF cap counts bytes', 'SENDREF over the size cap'}),
    ('send-cap-counts-chars', 'cepa_send_bytes=$(LC_ALL=C; printf \'%s%s\' "$cepa_send_subject" "$cepa_send_body" | wc -c)', 'cepa_send_bytes=$(( ${#cepa_send_subject} + ${#cepa_send_body} ))',
     {'SENDREF cap counts bytes'}),
    # L47: a run: or dispatch: target keeps no `nudge` mode; it is downgraded.
    ('send-nudge-any-target', 'nudge) [[ $cepa_send_target == term_* || $cepa_send_target == coord:* || $cepa_send_type == reply ]] \\', 'nudge) true \\', {"BOT read back from the bot's chat", "BOT send to a bot's chat counts", 'BOT with no recipient is read back from its chat', "BOTRUN read back from the bot's Run counts", "BOTRUN send stored for the bot's Run counts", "BOTRUN with no recipient is read back from the bot's Run", 'CHAIN with nudge says it is not needed', 'FOLLOWUP with nudge says it is not needed', 'FRESH with nudge says it is not needed', 'READBACK dispatch send rewritten to a follow-up', 'STORE nudge to a dispatch address is sent as no-nudge', 'STORE nudge to a run address is sent as no-nudge'}),
    # L36 #20: every send carries a request id, so its vsock retry replays.
    ('send-no-request-id', '  --type "$cepa_send_type" --subject "$cepa_send_subject" --body "$cepa_send_body" \\\n  --retry-request "$cepa_send_req" --json --full ;;', '  --type "$cepa_send_type" --subject "$cepa_send_subject" --body "$cepa_send_body" \\\n  --json --full ;;',
     {'BLOCK hostile message is sent as text', 'BOT argv and order, no nudge', 'BOTRUN argv and order, no nudge', 'FIELDS any order sends the same argv', 'HOSTON argv carries --on', 'STORE argv and order', 'STORE retry reuses the request id'}),
    # reply mode (punch-list L35)
    ('reply-thread-unchecked', '        if th != target:\n', '        if False:\n',
     {'REPLY not threaded on the question', 'REPLY thread missing', 'REPLY thread not a message id', 'REPLYTHREAD another row of the thread quotes the question', 'REPLYTHREAD another row of the thread quotes the question is not nudged', 'REPLYTHREAD question is a root', 'REPLYTHREAD question is a root is not nudged', 'REPLYTHREAD question on another thread', 'REPLYTHREAD question on another thread is not nudged', 'REPLYTHREAD question out of the window', 'REPLYTHREAD question out of the window is not nudged'}),
    ('reply-self-unchecked', 'sys.exit(1 if not found else 3 if mine else 4 if not threaded else 0)', 'sys.exit(1 if not found else 4 if not threaded else 0)',
     {'CHATSENDER reply Orca addressed to this chat is misaddressed', 'CHATSENDER reply to a question this chat sent is misaddressed', 'REPLY addressed to this session, question out of window', 'REPLY misaddressed is not nudged', 'REPLY to a message this session sent', 'REPLYTHREAD reply addressed to this session wins over the thread', 'REPLYTHREAD reply to its own reply is misaddressed'}),
    ('reply-no-request-id', '--body "$cepa_send_body" --retry-request "$cepa_send_req" --json --full ;;', '--body "$cepa_send_body" --json --full ;;',
     {'REPLY argv', 'REPLY retry reuses the request id'}),
    ('reply-dispatch-nudged', 'if [[ $cepa_send_to != term_* ]]; then', 'if false; then',
     {'REPLY to a dispatch mailbox is not nudged'}),
    ('reply-target-loose', '[[ $cepa_send_target =~ ^msg_[0-9a-f]{6,32}$ ]] || refuse "a reply', 'true || refuse "a reply',
     {'REPLYREF target is a handle'}),
    # #106 review: a reply Orca addressed to this session is misaddressed
    # even when the question is outside the re-read window.
    ('reply-to-me-unchecked', '(sys.argv[3] == me or any(', '(any(',
     {'CHATSENDER reply Orca addressed to this chat is misaddressed', 'REPLY addressed to this session, question out of window', 'REPLYTHREAD reply addressed to this session wins over the thread'}),
    ('reply-handle-unvalidated', 'elif ! [[ $cepa_send_me =~ ^term_[0-9a-f-]{36}$ ]]; then\n  cepa_send_me=\n', 'elif false; then\n  cepa_send_me=\n',
     {'REPLY handle not a term_ handle is ignored'}),
    ('unproven-says-nothing-stored', 'unproven "${cepa_send_got#UNPROVEN }"', 'fail "${cepa_send_got#UNPROVEN }"',
     {'ALERT unproven send writes one file', 'BOT stored for a dispatch is not a bot', 'BOT stored for the bot address is not a chat', 'CHATREPLY a term_ send stored for a chat is not proven', 'CHATREPLY bot address as a recipient', 'CHATREPLY chat address with no id', 'CHATREPLY chat address with shell text', 'REPLY names no recipient', 'REPLY thread missing', 'REPLY thread not a message id', 'STORE bad recipient', 'WDONE no lifecycle', 'WDONE other dispatch', 'WDONE other task', 'WDONE wrong action'}),
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
    ('wd-no-request-id', '      --retry-request "$cepa_send_req" --json --full ;;\n  *)', '      --json --full ;;\n  *)',
     {'WDONE argv, no nudge', 'WDONE retry reuses the request id'}),
    ('send-reroute-nudged', 'if [ "$cepa_send_to" != "$cepa_send_target" ]; then', 'if false; then',
     {'HOSTON row stored for another handle is still a skip', 'STORE rerouted to a Run mailbox', 'STORE stored for another handle'}),
    ('send-no-vsock-retry', '  for try in 1 2; do\n    timeout -k 2 "$cepa_send_bound"', '  for try in 1; do\n    timeout -k 2 "$cepa_send_bound"',
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
     {'FILE subject only', 'FILE subject only, no newline', 'REPLYREF empty body', 'SENDREF empty body',
      'SESSION reply names it'}),
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
    # L65: a nudge that did not run to a decision writes a nudge_skipped file.
    ('alert-not-on-nudge-loss', '      cepa_send_alert nudge_skipped "${cepa_send_line#Orca nudge *: }" ;;', '      : ;;',
     {'ALERT nudge lost to a failed worktree ps writes one file', 'ALERT nudge lost to a failed terminal show writes one file',
      'ALERT nudge lost to a failed terminal send writes one file', 'ALERT nudge lost to a send that is not ok writes one file',
      'ALERT nudge lost to an Orca reply that is not ok writes one file'}),
    ('alert-nudge-target-row-alerts', 'the target state is unknown") ;;', 'the target state is unknown") cepa_send_alert nudge_skipped x ;;',
     {'ALERT busy target skip writes none', 'ALERT nudge skip writes none'}),
    ('alert-nudge-failed-silent', '    "Orca nudge skipped: "* | "Orca nudge failed: "*)', '    "Orca nudge skipped: "*)',
     {'ALERT nudge lost to a failed terminal send writes one file', 'ALERT nudge lost to a send that is not ok writes one file'}),
    ('nudgefile-missing-silent', '  cepa_send_alert nudge_skipped "orca-nudge.sh not found beside orca-send.sh"\n', '',
     {'NUDGEFILE missing writes an alert'}),
    ('nudgefile-nostart-silent', '  cepa_send_alert nudge_skipped "orca-nudge.sh would not start (exit $cepa_send_nrc)"\n', '',
     {'NUDGEFILE would not start writes an alert'}),
    ('nudgefile-empty-silent', '  cepa_send_alert nudge_skipped "orca-nudge.sh exited $cepa_send_nrc and printed nothing"\n', '',
     {'NUDGEFILE printed nothing writes an alert'}),
    ('alert-mkdir-unchecked', 'mkdir -p "$dir" 2>/dev/null || { echo', 'mkdir -p "$dir" 2>/dev/null; true || { echo',
     {'ALERT unmakeable directory is reported'}),
    # FILE (punch-list L41): the message is in a file, read once and removed.
    ('file-not-removed', 'rm -f -- "$cepa_send_file" 2>/dev/null\n[ ! -e "$cepa_send_file" ] || refuse "the message file could not be removed"\n', '',
     {'FILE removed after a refused send', 'FILE unremovable', 'BLOCK hostile message is sent as text', 'FILE removed after a stored send', 'FILE unreadable is still removed'}),
    # L47: a path to no file names the retry; a dangling symlink is still FREG.
    ('file-missing-reason-dropped', '[ -e "$cepa_send_file" ] || [ -L "$cepa_send_file" ] \\\n', 'true \\\n',
     {'FILE does not exist'}),
    ('file-dangling-link-as-missing', '[ -e "$cepa_send_file" ] || [ -L "$cepa_send_file" ] \\', '[ -e "$cepa_send_file" ] \\',
     {'FILE a dangling symlink'}),
    # L47: `nudge` to a run: or dispatch: target is sent as no-nudge, with a line.
    ('nudge-run-refused-again', '|| { cepa_send_mode=no-nudge cepa_send_downgraded=1; } ;;', '|| refuse "only a term_ handle is nudged" ;;', {"BOT a chat id quoted in a title is not the bot's", 'BOT a chat with no closed field is not proven', "BOT a closed chat is not the bot's", "BOT another chat id is not the bot's", 'BOT argv and order, no nudge', 'BOT chat row missing from the inbox', 'BOT chats not JSON are unreadable', 'BOT chats not ok are unreadable', 'BOT chats of another bot are unreadable', 'BOT chats that fail are unreadable', "BOT read back from the bot's chat", 'BOT read back of a Run row with no bot request is not proven', 'BOT read back skips a row for another address', "BOT send to a bot's chat counts", 'BOT stored for a Run with no bot request is not proven', 'BOT stored for a dispatch is not a bot', 'BOT stored for the bot address is not a chat', 'BOT with no recipient and no row is not stored', 'BOT with no recipient is read back from its chat', 'BOTRUN a Home flag quoted as text is not proven', 'BOTRUN a Run with a terminal coordinator is not proven', 'BOTRUN a Run with no coordinator field is unreadable', 'BOTRUN a bot request on another msg id does not count', 'BOTRUN a closed Home chat is not proven', 'BOTRUN a null payload is not proven', "BOTRUN a payload given as an object, not Orca's string, is not proven", 'BOTRUN a payload with no botRequest is not proven', 'BOTRUN a run-show not JSON is unreadable', 'BOTRUN a run-show not ok is unreadable', 'BOTRUN a run-show of another Run is not proven', 'BOTRUN a run-show that fails is unreadable', 'BOTRUN argv and order, no nudge', 'BOTRUN botRequest in a payload that is not JSON is not proven', 'BOTRUN botRequest quoted as a payload value is not proven', 'BOTRUN botRequest quoted in the body is not proven', 'BOTRUN botRequest that is not an object is not proven', 'BOTRUN chats of another bot are unreadable', 'BOTRUN chats that fail are unreadable', 'BOTRUN no payload is not proven', 'BOTRUN only a chat that is not Home is not proven', "BOTRUN read back from the bot's Run counts", 'BOTRUN row for another Run is not stored', 'BOTRUN row missing from the inbox', "BOTRUN send stored for the bot's Run counts", "BOTRUN with no recipient is read back from the bot's Run", 'CHAIN with nudge says it is not needed', 'FOLLOWUP with nudge says it is not needed', 'FRESH with nudge says it is not needed', 'READBACK dispatch send rewritten to a follow-up', 'STORE downgraded send missing from the inbox', 'STORE downgraded send rerouted to a term_ handle', 'STORE downgraded send that stored nothing', 'STORE nudge to a dispatch address is sent as no-nudge', 'STORE nudge to a run address is sent as no-nudge'}),
    ('nudge-downgrade-silent', 'if [ -n "$cepa_send_downgraded" ]; then', 'if false; then',
     {"BOT read back from the bot's chat", "BOT send to a bot's chat counts", 'BOT with no recipient is read back from its chat', "BOTRUN read back from the bot's Run counts", "BOTRUN send stored for the bot's Run counts", "BOTRUN with no recipient is read back from the bot's Run", 'READBACK dispatch send rewritten to a follow-up', 'STORE downgraded send rerouted to a term_ handle', 'STORE nudge to a dispatch address is sent as no-nudge', 'STORE nudge to a run address is sent as no-nudge'}),
    ('nudge-downgrade-always', 'if [ -n "$cepa_send_downgraded" ]; then', 'if [ "$cepa_send_type" != reply ] && [[ $cepa_send_target != term_* ]]; then',
     # A worker_done targets dispatch: with no-nudge too, so it is caught as well.
     {'BOT a name of 105 characters is accepted', 'BOT no-nudge prints no downgrade', 'BOT to an earlier chat of the bot counts', 'READBACK worker_done row and a completed dispatch count', 'STORE no-nudge to a dispatch address prints no downgrade', 'STORE run address target', 'WDONE failed outcome', 'WDONE stored', 'WDONE vsock retry'}),
    ('file-dir-unsearchable-unchecked', '[ -d "${cepa_send_file%/*}/" ] && [ -x "${cepa_send_file%/*}/" ] \\', 'true \\',
     {'FILE in an unsearchable directory'}),
    # PR #122 review tail: the downgrade line follows a proven store only. This
    # mutant reports a downgraded send as delivered when it stored nothing, so
    # the two downgraded-store checks each have a kill no store mutant gives.
    ('nudge-downgrade-before-store', 'fail() { echo "Orca send failed: no message stored', 'fail() { [ -z "$cepa_send_downgraded" ] || { echo "Orca nudge not needed: $cepa_send_target is a mailbox Orca delivers; sent as no-nudge"; exit 0; }; echo "Orca send failed: no message stored',
     {'BOT chat row missing from the inbox', 'BOT read back skips a row for another address', 'BOT with no recipient and no row is not stored', 'BOTRUN row for another Run is not stored', 'BOTRUN row missing from the inbox', 'STORE downgraded send missing from the inbox', 'STORE downgraded send that stored nothing'}),
    ('nudge-downgrade-reroute-hidden', '  if [ "$cepa_send_to" != "$cepa_send_target" ] && [[ $cepa_send_to == term_* ]]; then', '  if false; then',
     {'STORE downgraded send rerouted to a term_ handle'}),
    ('file-symlink-allowed', '[ -f "$cepa_send_file" ] && [ ! -L "$cepa_send_file" ] && [ -O', '[ -f "$cepa_send_file" ] && [ -O',
     {'FILE a symlink', 'FILE a symlink keeps the link'}),
    ('file-any-name', '/cepa-send-[A-Za-z0-9._@-]{1,64}\\.txt$', '/[A-Za-z0-9._@-]{1,64}$',
     {'FILE another name', 'FILE another name keeps the file'}),
    ('file-dotdot-allowed', ' && $cepa_send_file != */../* ]]', ' ]]',
     {'FILE dot-dot part', 'FILE dot-dot part keeps the file'}),
    ('file-in-repo-allowed', '    || refuse "the message file is inside the repo"', '    || true',
     {'FILE in the main checkout from a worktree', 'FILE via a symlinked directory', 'FILE via a symlinked directory keeps the file', 'FILE inside the repo', 'FILE in the main checkout from a worktree keeps the file', 'FILE inside the repo keeps the file'}),
    ('file-physical-unchecked', ' && $cepa_send_phys != "$cepa_send_k"/* ]]', ' ]]', {'FILE in the main checkout from a worktree', 'FILE via a symlinked directory', 'FILE in the main checkout from a worktree keeps the file', 'FILE via a symlinked directory keeps the file'}),
    ('file-main-unchecked', 'for cepa_send_k in "$cepa_send_top" "$cepa_send_main"; do', 'for cepa_send_k in "$cepa_send_top"; do', {'FILE in the main checkout from a worktree', 'FILE in the main checkout from a worktree keeps the file'}),
    ('file-dot-allowed', ' && $cepa_send_file != */./* && ', ' && ', {'FILE dot part keeps the file', 'FILE dot part'}),
    ('file-unanchored', '=~ ^(/[A-Za-z0-9._@+-]+)*/cepa-send-', '=~ (/[A-Za-z0-9._@+-]+)*/cepa-send-', {'FILE space in the path', 'FILE relative path'}),
    ('file-read-unchecked', '[ "$cepa_send_read" = 0 ] || refuse "the message file could not be read"\n', '', {'FILE unreadable'}),
    ('file-single-line-body', "  [[ $cepa_send_msg != *$'\\n'* ]] || cepa_send_body=${cepa_send_msg#*$'\\n'}", "  cepa_send_body=${cepa_send_msg#*$'\\n'}", {'FILE subject only', 'FILE subject only, no newline'}),
    ('file-field-optional', '[[ $cepa_send_seen == *" file "* ]] || refuse "the file field is missing"\n', '',
     {'FILE field missing'}),
    ('heredoc-message-allowed', '[ -z "${cepa_send_rest//[[:space:]]/}" ] \\\n', 'true \\\n',
     {'FIELDS 1.43.0 block is refused', 'FIELDS message after a file field is refused'}),
    # FIELDS (punch-list L38, #19): the values are field lines on stdin.
    ('fields-args-allowed', '[ $# -eq 0 ] || refuse', 'true || refuse',
     {'FIELDS arguments are refused'}),
    ('fields-twice-allowed', '[[ $cepa_send_seen != *" $cepa_send_k "* ]] || refuse', 'true || refuse',
     {'FIELDS name given twice'}),
    ('fields-any-name', '    cli|target|type|nudge|outcome|task|session|on|file) ;;', '    cli|target|type|nudge|outcome|task|session|on|file|to) ;;',
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
    ('send-cli-bare-orca', '*) refuse "bare orca on Linux is the screen reader" ;;', '*) ;;',
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
     {'NUDGEFILE missing writes an alert', 'NUDGEFILE missing', 'NUDGEFILE missing names the session'}),
    ('nudge-wont-start-ignored', 'if [ "$cepa_send_nrc" -gt 3 ]; then', 'if false; then',
     {'NUDGEFILE would not start writes an alert', 'NUDGEFILE would not start'}),
    ('nudge-blank-line', '[ -z "$cepa_send_nout" ] || while', 'while',
     {'NUDGEFILE printed nothing, exit 0', 'NUDGEFILE printed nothing, exit 2', 'NUDGEFILE would not start'}),
    # PR #110 review fixes.
    ('nudge-silent-ok', 'if [ "$cepa_send_nrc" -le 3 ] && [ -z "$cepa_send_nout" ]; then', 'if false; then',
     {'NUDGEFILE printed nothing writes an alert', 'NUDGEFILE printed nothing, exit 0', 'NUDGEFILE printed nothing, exit 2'}),
    ('session-bare-refused', '^([a-z]+):(\\ (.*))?$', '^([a-z]+):\\ ((.*))$',
     {'SESSION bare field is no name'}),
    ('fields-from-env', 'unset cepa_send_f_cli', ': cepa_send_f_cli',
     {'SESSION from the environment is ignored'}),
    ('fields-target-late', '    target) cepa_send_target=$cepa_send_v ;;\n', '',
     # Every refusal before the target is copied (the heredoc and file
     # checks, L41) then names "the target session".
     {'FIELDS 1.43.0 block is refused', 'FIELDS message after a file field is refused', 'FIELDS name given twice',
      'FILE a dangling symlink', 'FILE a directory', 'FILE a symlink', 'FILE another name', 'FILE does not exist', 'FILE dot part',
      'FILE dot-dot part', 'FILE field missing', 'FILE in an unsearchable directory', 'FILE in the main checkout from a worktree', 'FILE inside the repo',
      'FILE relative path', 'FILE space in the path', 'FILE unreadable', 'FILE unremovable',
      'FILE via a symlinked directory', 'SENDREF target newline'}),
    ('subject-cr-kept', "  cepa_send_subject=${cepa_send_subject%$'\\r'}\n", '',
     {'FIELDS any order sends the same argv'}),
    # L72: Orca 1.4.246 answers a read without --full in its short shape.
    ('send-reply-short', '--body "$cepa_send_body" --retry-request "$cepa_send_req" --json --full ;;', '--body "$cepa_send_body" --retry-request "$cepa_send_req" --json ;;',
     {'CHATREPLY bot address as a recipient', 'CHATREPLY chat address with no id', 'CHATREPLY chat address with shell text', 'CHATREPLY reply stored for a chat is not claimed delivered', 'CHATSENDER a terminal handle wins over the chat id', 'CHATSENDER no structured session is no chat address', 'CHATSENDER reply Orca addressed to this chat is misaddressed', 'CHATSENDER reply to a question this chat sent is misaddressed', 'CHATSENDER session id with shell text is ignored', 'CHATSENDER structured session not 1 is no chat address', 'REPLY addressed to this session, question out of window', 'REPLY argv', 'REPLY handle not a term_ handle is ignored', 'REPLY names no recipient', 'REPLY no handle, question out of window', 'REPLY no-nudge stores only', 'REPLY not threaded on the question', 'REPLY question from another session', 'REPLY stored then nudged the asker', 'REPLY thread missing', 'REPLY thread not a message id', 'REPLY to a dispatch mailbox is not nudged', 'REPLY to a message this session sent', 'REPLY vsock retry', 'REPLYTHREAD another row of the thread quotes the question', 'REPLYTHREAD question is a root', 'REPLYTHREAD question on another thread', 'REPLYTHREAD question out of the window', 'REPLYTHREAD reply addressed to this session wins over the thread', "REPLYTHREAD reply to a reply counts on the question's root", 'REPLYTHREAD reply to its own reply is misaddressed'}),
    ('send-wdone-short', '--retry-request "$cepa_send_req" --json --full ;;\n  *)', '--retry-request "$cepa_send_req" --json ;;\n  *)', {'FOLLOWUP shape on a worker_done is not a follow-up', 'WDONE argv, no nudge', 'WDONE failed outcome', 'WDONE no lifecycle', 'WDONE other dispatch', 'WDONE other task', 'WDONE stored', 'WDONE vsock retry', 'WDONE wrong action'}),
    ('send-send-short', '--retry-request "$cepa_send_req" --json --full ;;\nesac', '--retry-request "$cepa_send_req" --json ;;\nesac', {'ALERT busy target skip writes none', 'ALERT nudge lost to a failed terminal send writes one file', 'ALERT nudge lost to a failed terminal show writes one file', 'ALERT nudge lost to a failed worktree ps writes one file', 'ALERT nudge lost to a send that is not ok writes one file', 'ALERT nudge lost to an Orca reply that is not ok writes one file', 'ALERT nudge skip writes none', 'ALERT stored send writes none', 'ALERT unproven send writes one file', 'BLOCK hostile message is sent as text', "BOT a chat id quoted in a title is not the bot's", 'BOT a chat with no closed field is not proven', "BOT a closed chat is not the bot's", 'BOT a name of 105 characters is accepted', "BOT another chat id is not the bot's", 'BOT argv and order, no nudge', 'BOT chat row missing from the inbox', 'BOT chats not JSON are unreadable', 'BOT chats not ok are unreadable', 'BOT chats of another bot are unreadable', 'BOT chats that fail are unreadable', 'BOT no-nudge prints no downgrade', "BOT send to a bot's chat counts", 'BOT stored for a Run with no bot request is not proven', 'BOT stored for a dispatch is not a bot', 'BOT stored for the bot address is not a chat', 'BOT to an earlier chat of the bot counts', 'BOT with no recipient and no row is not stored', 'BOT with no recipient is read back from its chat', 'BOTRUN a Home flag quoted as text is not proven', 'BOTRUN a Run with a terminal coordinator is not proven', 'BOTRUN a Run with no coordinator field is unreadable', 'BOTRUN a bot request on another msg id does not count', 'BOTRUN a closed Home chat is not proven', 'BOTRUN a null payload is not proven', "BOTRUN a payload given as an object, not Orca's string, is not proven", 'BOTRUN a payload with no botRequest is not proven', 'BOTRUN a run-show not JSON is unreadable', 'BOTRUN a run-show not ok is unreadable', 'BOTRUN a run-show of another Run is not proven', 'BOTRUN a run-show that fails is unreadable', 'BOTRUN argv and order, no nudge', 'BOTRUN botRequest in a payload that is not JSON is not proven', 'BOTRUN botRequest quoted as a payload value is not proven', 'BOTRUN botRequest quoted in the body is not proven', 'BOTRUN botRequest that is not an object is not proven', 'BOTRUN chats of another bot are unreadable', 'BOTRUN chats that fail are unreadable', 'BOTRUN no payload is not proven', 'BOTRUN only a chat that is not Home is not proven', 'BOTRUN row for another Run is not stored', 'BOTRUN row missing from the inbox', "BOTRUN send stored for the bot's Run counts", "BOTRUN with no recipient is read back from the bot's Run", 'CHAIN flag-shaped followUpOf is not a follow-up', 'CHAIN followUpOf as an address counts', 'CHAIN home record of another id fails', 'CHAIN hop of a bad shape fails', 'CHAIN hop record of another id fails', 'CHAIN hop with a flag-shaped id is never read', 'CHAIN hop with no followUpOf key fails', "CHAIN local dispatch walks this machine's records", 'CHAIN loop fails', 'CHAIN new dispatch equal to followUpOf is not a follow-up', 'CHAIN new dispatch equal to the target is not a follow-up', "CHAIN newest dispatch of the target's chain counts", 'CHAIN null followUpOf is not a follow-up', 'CHAIN of 8 hops counts', 'CHAIN of 9 hops fails', 'CHAIN reads the home record, then each hop on its server', 'CHAIN server id with shell text fails', "CHAIN stranger's dispatch fails", 'CHAIN unreadable hop fails', 'CHAIN with no worker-show reads fails', 'CHAIN with nudge says it is not needed', 'CHATREPLY a term_ send stored for a chat is not proven', 'FIELDS any order sends the same argv', 'FIELDS any order, CR and trailing spaces', 'FILE removed after a stored send', 'FILE session name in the file name sends', 'FOLLOWUP dispatch send carried as a follow-up dispatch counts', 'FOLLOWUP followUpOf as an address counts', 'FOLLOWUP makes no inbox call', 'FOLLOWUP new dispatch equal to the target fails', 'FOLLOWUP new dispatch of a bad shape fails', 'FOLLOWUP not ready fails', 'FOLLOWUP shape for a term_ target fails', 'FOLLOWUP that exited non-zero fails', 'FOLLOWUP with nudge says it is not needed', 'FRESH exit-0 reply with no message is not re-read', 'FRESH term_ send stays bounded at 15 s', 'GUARD every tool present sends', 'HOSTON argv carries --on', 'HOSTON no-nudge stores', 'HOSTON nudge is not needed, the host prompts its worker', "HOSTON row only in this machine's inbox does not count", 'HOSTON row stored for another handle is still a skip', 'NUDGEFILE missing', 'NUDGEFILE missing names the session', 'NUDGEFILE missing writes an alert', 'NUDGEFILE printed nothing writes an alert', 'NUDGEFILE printed nothing, exit 0', 'NUDGEFILE printed nothing, exit 2', 'NUDGEFILE would not start', 'NUDGEFILE would not start writes an alert', 'READBACK dispatch send rewritten to a follow-up', 'READBACK dispatch target does not take a term_ row', 'READBACK ok with no message id counts (L88 item 2)', 'SENDREF cli path equal to ORCA_CLI_COMMAND sends', 'SESSION nudge sent', 'SESSION nudge skip names it', 'STORE argv and order', 'STORE at the size cap', 'STORE bad recipient', 'STORE downgraded send missing from the inbox', 'STORE downgraded send rerouted to a term_ handle', 'STORE envelope id without result.message', 'STORE id in the inbox for another recipient', 'STORE id missing from the inbox', 'STORE inbox fails', 'STORE inbox in the 1.4.246 short shape', 'STORE inbox not JSON', 'STORE inbox not ok', 'STORE inbox vsock once', 'STORE inbox wrong shape', 'STORE no to_handle falls back to the target', 'STORE no-nudge stores only', 'STORE no-nudge to a dispatch address prints no downgrade', 'STORE nudge fail passes through', 'STORE nudge skip passes through', 'STORE nudge to a dispatch address is sent as no-nudge', 'STORE nudge to a run address is sent as no-nudge', 'STORE rerouted to a Run mailbox', 'STORE run address target', 'STORE send output in the 1.4.246 short shape', 'STORE send retry', 'STORE send vsock once', 'STORE stored for another handle', 'STORE stored then nudged', 'STORE warning beside a message counts', 'STORE warning-only result'}),
    ('send-inbox-short', '"${cepa_send_env_args[@]}"} --limit 200 --json --full \\\n  || fail', '"${cepa_send_env_args[@]}"} --limit 200 --json \\\n  || fail', {'ALERT busy target skip writes none', 'ALERT nudge lost to a failed terminal send writes one file', 'ALERT nudge lost to a failed terminal show writes one file', 'ALERT nudge lost to a failed worktree ps writes one file', 'ALERT nudge lost to a send that is not ok writes one file', 'ALERT nudge lost to an Orca reply that is not ok writes one file', 'ALERT nudge skip writes none', 'ALERT stored send writes none', 'BLOCK hostile message is sent as text', "BOT a chat id quoted in a title is not the bot's", 'BOT a chat with no closed field is not proven', "BOT a closed chat is not the bot's", 'BOT a name of 105 characters is accepted', "BOT another chat id is not the bot's", 'BOT argv and order, no nudge', 'BOT chat row missing from the inbox', 'BOT chats not JSON are unreadable', 'BOT chats not ok are unreadable', 'BOT chats of another bot are unreadable', 'BOT chats that fail are unreadable', 'BOT no-nudge prints no downgrade', "BOT read back from the bot's chat", 'BOT read back of a Run row with no bot request is not proven', "BOT send to a bot's chat counts", 'BOT stored for a Run with no bot request is not proven', 'BOT to an earlier chat of the bot counts', 'BOT with no recipient is read back from its chat', 'BOTRUN a Home flag quoted as text is not proven', 'BOTRUN a Run with a terminal coordinator is not proven', 'BOTRUN a Run with no coordinator field is unreadable', 'BOTRUN a bot request on another msg id does not count', 'BOTRUN a closed Home chat is not proven', 'BOTRUN a null payload is not proven', "BOTRUN a payload given as an object, not Orca's string, is not proven", 'BOTRUN a payload with no botRequest is not proven', 'BOTRUN a run-show not JSON is unreadable', 'BOTRUN a run-show not ok is unreadable', 'BOTRUN a run-show of another Run is not proven', 'BOTRUN a run-show that fails is unreadable', 'BOTRUN argv and order, no nudge', 'BOTRUN botRequest in a payload that is not JSON is not proven', 'BOTRUN botRequest quoted as a payload value is not proven', 'BOTRUN botRequest quoted in the body is not proven', 'BOTRUN botRequest that is not an object is not proven', 'BOTRUN chats of another bot are unreadable', 'BOTRUN chats that fail are unreadable', 'BOTRUN no payload is not proven', 'BOTRUN only a chat that is not Home is not proven', "BOTRUN read back from the bot's Run counts", 'BOTRUN row for another Run is not stored', 'BOTRUN row missing from the inbox', "BOTRUN send stored for the bot's Run counts", "BOTRUN with no recipient is read back from the bot's Run", 'CHATREPLY reply stored for a chat is not claimed delivered', 'CHATSENDER a terminal handle wins over the chat id', 'CHATSENDER no structured session is no chat address', 'CHATSENDER reply Orca addressed to this chat is misaddressed', 'CHATSENDER reply to a question this chat sent is misaddressed', 'CHATSENDER session id with shell text is ignored', 'CHATSENDER structured session not 1 is no chat address', 'FIELDS any order, CR and trailing spaces', 'FILE removed after a stored send', 'FILE session name in the file name sends', 'FRESH term_ send stays bounded at 15 s', 'GUARD every tool present sends', 'HOSTON no-nudge stores', 'HOSTON nudge is not needed, the host prompts its worker', "HOSTON re-reads the host's inbox", "HOSTON read-back takes the host's sender form", "HOSTON row only in this machine's inbox does not count", 'HOSTON row stored for another handle is still a skip', 'NUDGEFILE missing', 'NUDGEFILE missing names the session', 'NUDGEFILE missing writes an alert', 'NUDGEFILE printed nothing writes an alert', 'NUDGEFILE printed nothing, exit 0', 'NUDGEFILE printed nothing, exit 2', 'NUDGEFILE would not start', 'NUDGEFILE would not start writes an alert', 'READBACK dispatch send rewritten to a follow-up', 'READBACK empty stdout, row in the inbox, counts', 'READBACK empty stdout, then the nudge', 'READBACK from a chat counts its own row', 'READBACK ok with no message id counts (L88 item 2)', 'READBACK reply matched by thread', 'READBACK row from this sender counts', 'READBACK timeout, row in the inbox, counts', 'READBACK worker_done row and a completed dispatch count', 'REPLY addressed to this session, question out of window', 'REPLY argv', 'REPLY handle not a term_ handle is ignored', 'REPLY no handle, question out of window', 'REPLY no-nudge stores only', 'REPLY not threaded on the question', 'REPLY question from another session', 'REPLY stored then nudged the asker', 'REPLY to a dispatch mailbox is not nudged', 'REPLY to a message this session sent', 'REPLY vsock retry', 'REPLYTHREAD another row of the thread quotes the question', 'REPLYTHREAD question is a root', 'REPLYTHREAD question on another thread', 'REPLYTHREAD question out of the window', 'REPLYTHREAD reply addressed to this session wins over the thread', "REPLYTHREAD reply to a reply counts on the question's root", 'REPLYTHREAD reply to its own reply is misaddressed', 'SENDREF cli path equal to ORCA_CLI_COMMAND sends', 'SESSION nudge sent', 'SESSION nudge skip names it', 'STORE argv and order', 'STORE at the size cap', 'STORE downgraded send missing from the inbox', 'STORE downgraded send rerouted to a term_ handle', 'STORE id in the inbox for another recipient', 'STORE id missing from the inbox', 'STORE inbox vsock once', 'STORE no to_handle falls back to the target', 'STORE no-nudge stores only', 'STORE no-nudge to a dispatch address prints no downgrade', 'STORE nudge fail passes through', 'STORE nudge skip passes through', 'STORE nudge to a dispatch address is sent as no-nudge', 'STORE nudge to a run address is sent as no-nudge', 'STORE rerouted to a Run mailbox', 'STORE run address target', 'STORE send retry', 'STORE send vsock once', 'STORE stored for another handle', 'STORE stored then nudged', 'STORE warning beside a message counts', 'WDONE failed outcome', 'WDONE stored', 'WDONE vsock retry'}),
    ('send-inbox-shape-loose', '    if not isinstance(rows, list) or not all(isinstance(x, dict) and "to_handle" in x for x in rows):\n        sys.exit(2)\n', '',
     {'STORE inbox in the 1.4.246 short shape'}),
    # L84 read-back and L88 host target (`on:`).
    ('send-readback-off', 'cepa_send_back=$(cepa_send_readback) || cepa_send_back=', 'cepa_send_back=', {"BOT read back from the bot's chat", 'BOT read back of a Run row with no bot request is not proven', 'BOT with no recipient is read back from its chat', "BOTRUN read back from the bot's Run counts", "BOTRUN with no recipient is read back from the bot's Run", "HOSTON read-back takes the host's sender form", 'READBACK dispatch send rewritten to a follow-up', 'READBACK empty stdout, row in the inbox, counts', 'READBACK empty stdout, then the nudge', 'READBACK from a chat counts its own row', 'READBACK ok with no message id counts (L88 item 2)', 'READBACK reads the inbox before it reports', 'READBACK reply matched by thread', 'READBACK row from this sender counts', 'READBACK timeout, row in the inbox, counts', 'READBACK worker_done reads worker-show', 'READBACK worker_done row and a completed dispatch count', 'READBACK worker_done with an open dispatch is unproven'}),
    ('send-readback-ok-false', 'case "$cepa_send_why" in \'Orca did not return "ok": true\'*) fail "$cepa_send_why" ;; esac', ':', {'READBACK ok false makes no inbox call', 'READBACK ok false is a result, no read'}),
    ('send-readback-window', 't < int(t0) - 120:', 't < int(t0) - 1200:', {'READBACK row older than the window'}),
    ('send-readback-sender', 'if me and fh != me and not', 'if False and fh != me and not', {'HOSTON read-back sender form of another handle fails', "READBACK from a chat skips another sender's row", 'READBACK host sender form without on fails', 'READBACK row from another sender'}),
    ('send-readback-body', 'if not isinstance(x.get("body"), str) or x["body"].rstrip() != body:', 'if not isinstance(x.get("body"), str):', {'READBACK row with another body'}),
    ('send-readback-subject', 'elif x.get("type") != typ or x.get("subject") != subj:', 'elif x.get("type") != typ:', {'READBACK row with another subject'}),
    ('send-readback-type', 'elif x.get("type") != typ or x.get("subject") != subj:', 'elif x.get("subject") != subj:', {'READBACK row of another type'}),
    ('send-readback-thread', '        if x.get("thread_id") != target:\n', '        if False:\n', {"READBACK reply is not read back on the question's root", 'READBACK reply on another thread fails', 'READBACK reply to a reply with no question row fails'}),
    ('send-readback-payload', 'if not isinstance(p, dict) or p.get("dispatchId") != target[len("dispatch:"):] \\', 'if not isinstance(p, dict) \\', {'READBACK worker_done row of another dispatch fails'}),
    ('send-readback-wdone-state', 'sys.exit(0 if st == sys.argv[2] else 1)', 'sys.exit(0)', {'READBACK worker_done with an open dispatch is unproven'}),
    ('send-readback-date', '    if t is None or t < int(t0) - 120:', '    if t is not None and t < int(t0) - 120:', {'READBACK row with no date'}),
    ('send-on-dropped', '[ -z "$cepa_send_on" ] || cepa_send_on_args=(--on "$cepa_send_on")', ':', {'HOSTON argv carries --on'}),
    ('send-on-nudged', 'if [ -n "$cepa_send_on" ] && [ "$cepa_send_mode" = nudge ] && [ "$cepa_send_to" = "$cepa_send_target" ]; then', 'if false; then', {'HOSTON makes no nudge call', 'HOSTON nudge is not needed, the host prompts its worker'}),
    ('send-on-any-target', '[[ $cepa_send_target =~ ^term_[0-9a-f-]{36}$ && $cepa_send_type != reply ]]', '[[ 1 ]]', {'BOTREF on', 'HOSTON run target refused'}),
    # L89 a: an `on:` send is re-read (and read back) in the host's inbox.
    ('send-on-reread-local', '[ -z "$cepa_send_on" ] || cepa_send_env_args=(--environment "$cepa_send_on")', ':', {'HOSTON no-nudge stores', 'HOSTON nudge is not needed, the host prompts its worker', "HOSTON re-reads the host's inbox", "HOSTON read-back takes the host's sender form", "HOSTON row only in this machine's inbox does not count", 'HOSTON row stored for another handle is still a skip'}),
    ('send-readback-host-sender-any', 'not (on and isinstance(fh, str) and fh.startswith(me + " on "))', 'not (isinstance(fh, str) and fh.startswith(me + " on "))', {'READBACK host sender form without on fails'}),
    ('send-readback-host-sender-off', ' and not (on and isinstance(fh, str) and fh.startswith(me + " on "))', '', {"HOSTON read-back takes the host's sender form"}),
    ('send-readback-host-sender-prefix', 'fh.startswith(me + " on ")', '" on " in fh', {'HOSTON read-back sender form of another handle fails'}),
    # L89 b: a follow-up dispatch counts only in its whole measured shape.
    ('send-followup-off', 'return ("FOLLOWUP dispatch:" + nd) if fu == td else', 'return None if fu == td else', {'FOLLOWUP dispatch send carried as a follow-up dispatch counts', 'FOLLOWUP followUpOf as an address counts', 'FOLLOWUP with nudge says it is not needed'}),
    ('send-followup-of-any', 'return ("FOLLOWUP dispatch:" + nd) if fu == td else ("CHAIN dispatch:%s %s" % (nd, fu))', 'return "FOLLOWUP dispatch:" + nd', {'CHAIN followUpOf as an address counts', 'CHAIN home record of another id fails', 'CHAIN hop of a bad shape fails', 'CHAIN hop record of another id fails', 'CHAIN hop with a flag-shaped id is never read', 'CHAIN hop with no followUpOf key fails', "CHAIN local dispatch walks this machine's records", 'CHAIN loop fails', "CHAIN newest dispatch of the target's chain counts", 'CHAIN of 8 hops counts', 'CHAIN of 9 hops fails', 'CHAIN reads the home record, then each hop on its server', 'CHAIN server id with shell text fails', "CHAIN stranger's dispatch fails", 'CHAIN unreadable hop fails', 'CHAIN with no worker-show reads fails', 'CHAIN with nudge says it is not needed'}),
    ('send-followup-of-id-only', 'fu = fu[len("dispatch:"):] if isinstance(fu, str) and fu.startswith("dispatch:") else fu', 'fu = fu', {'CHAIN followUpOf as an address counts', 'FOLLOWUP followUpOf as an address counts'}),
    ('send-followup-state', 'and isinstance(r, dict) and r.get("state") == "ready":', 'and isinstance(r, dict):', {'FOLLOWUP not ready fails'}),
    ('send-followup-self', 'and nd not in (td, fu):', 'and nd != fu:', {'CHAIN new dispatch equal to the target is not a follow-up'}),
    ('send-followup-self-fu', 'and nd not in (td, fu):', 'and nd != td:', {'CHAIN new dispatch equal to followUpOf is not a follow-up'}),
    ('send-followup-shape', 're.fullmatch(r"ctx_[A-Za-z0-9_-]{1,64}", nd)', 'True', {'FOLLOWUP new dispatch of a bad shape fails'}),
    ('send-followup-message', 'if m is None and typ not in', 'if typ not in', {'FOLLOWUP beside a message is not a follow-up'}),
    ('send-followup-term', ' and target.startswith("dispatch:") \\', ' \\', {'FOLLOWUP shape for a term_ target fails'}),
    ('send-followup-nudge-line', 'of $cepa_send_target (punch-list L89)"\n    [ -z "$cepa_send_downgraded" ] \\', 'of $cepa_send_target (punch-list L89)"\n    true \\', {'FOLLOWUP with nudge says it is not needed'}),
    ('send-dispatch-unproven-off', '      if [[ $cepa_send_target == dispatch:* && $cepa_send_type != worker_done ]]; then\n        if [ "$cepa_send_rc"', '      if false; then\n        if [ "$cepa_send_rc"', {'CHAIN flag-shaped followUpOf is not a follow-up', 'CHAIN new dispatch equal to followUpOf is not a follow-up', 'CHAIN new dispatch equal to the target is not a follow-up', 'CHAIN null followUpOf is not a follow-up', 'FOLLOWUP beside a message is not a follow-up', 'FOLLOWUP new dispatch equal to the target fails', 'FOLLOWUP new dispatch of a bad shape fails', 'FOLLOWUP not ready fails', 'FOLLOWUP that exited non-zero fails', 'FRESH earlier follow-up that still owns the terminal fails', 'FRESH exit-0 reply with no message is not re-read', 'FRESH follow-up after a chain hop counts', "FRESH local target reads this machine's records", 'FRESH new owner record of another id fails', 'FRESH new owner that follows a flag-shaped id fails', 'FRESH new owner that follows another dispatch fails', 'FRESH new owner that follows nothing fails', "FRESH old owner outside the target's chain fails", 'FRESH owner before the send with no row fails', 'FRESH owner read failed before the send fails', 'FRESH owner row of a bad shape fails', 'FRESH owner row of another terminal fails', 'FRESH owner that did not change fails', "FRESH reads the terminal's owner before the send and after it", 'FRESH row that does not own the terminal fails', 'FRESH target record of another id fails', 'FRESH target with no terminal fails', 'FRESH timed-out dispatch send whose follow-up is found counts', 'FRESH two owner rows fail', 'FRESH unreadable home record fails', 'FRESH unreadable new owner fails', 'FRESH unreadable worker list fails', 'FRESH with no owner row fails', 'FRESH with nudge says it is not needed', 'FRESH worker list that is not ok fails', 'FRESH worker list with no row list fails', 'READBACK dispatch target does not take a term_ row'}),
    ('send-dispatch-unproven-wdone', ' && $cepa_send_type != worker_done ]]; then\n        if [ "$cepa_send_rc"', ' ]]; then\n        if [ "$cepa_send_rc"', {'FOLLOWUP shape on a worker_done is not a follow-up', 'FRESH timed-out worker_done is not re-read', 'READBACK worker_done row of another dispatch fails', 'READBACK worker_done row of another task fails', 'READBACK worker_done row with another outcome fails', 'WDONE empty stdout'}),
    # L89 b (orca-lab's re-measure of cepa 1.60.0): a followUpOf that names another
    # dispatch counts only when worker-show's followUpOf links reach the target.
    ('send-chain-off', 'cepa_send_chain "${cepa_send_got#* }" \\\n      || unproven "$cepa_send_chain_why; a follow-up dispatch may already exist, so do not resend"', ':', {'CHAIN home record of another id fails', 'CHAIN hop of a bad shape fails', 'CHAIN hop record of another id fails', 'CHAIN hop with a flag-shaped id is never read', 'CHAIN hop with no followUpOf key fails', 'CHAIN loop fails', 'CHAIN of 9 hops fails', 'CHAIN reads the home record, then each hop on its server', 'CHAIN server id with shell text fails', "CHAIN stranger's dispatch fails", 'CHAIN unreadable hop fails', 'CHAIN with no worker-show reads fails'}),
    ('send-chain-nudge-line', 'in its follow-up chain (punch-list L89 b)"\n    [ -z "$cepa_send_downgraded" ] \\', 'in its follow-up chain (punch-list L89 b)"\n    true \\', {'CHAIN with nudge says it is not needed'}),
    ('send-chain-local-only', "    'env '*) cepa_send_where_env=(--environment \"${nx#env }\") ;;", "    'env '*) ;;", {'CHAIN followUpOf as an address counts', 'CHAIN loop fails', "CHAIN newest dispatch of the target's chain counts", 'CHAIN of 8 hops counts', 'CHAIN of 9 hops fails', 'CHAIN reads the home record, then each hop on its server', "CHAIN stranger's dispatch fails", 'CHAIN with nudge says it is not needed', 'FRESH earlier follow-up that still owns the terminal fails', 'FRESH follow-up after a chain hop counts', 'FRESH new owner record of another id fails', 'FRESH new owner that follows a flag-shaped id fails', 'FRESH new owner that follows another dispatch fails', 'FRESH new owner that follows nothing fails', "FRESH old owner outside the target's chain fails", 'FRESH owner row of a bad shape fails', 'FRESH owner row of another terminal fails', 'FRESH owner that did not change fails', "FRESH reads the terminal's owner before the send and after it", 'FRESH row that does not own the terminal fails', 'FRESH timed-out dispatch send whose follow-up is found counts', 'FRESH two owner rows fail', 'FRESH unreadable new owner fails', 'FRESH unreadable worker list fails', 'FRESH with no owner row fails', 'FRESH with nudge says it is not needed', 'FRESH worker list that is not ok fails', 'FRESH worker list with no row list fails'}),
    ('send-chain-home-local', 'if "server" not in r:', 'if True:', {'CHAIN followUpOf as an address counts', 'CHAIN loop fails', "CHAIN newest dispatch of the target's chain counts", 'CHAIN of 8 hops counts', 'CHAIN of 9 hops fails', 'CHAIN reads the home record, then each hop on its server', "CHAIN stranger's dispatch fails", 'CHAIN with nudge says it is not needed', 'FRESH earlier follow-up that still owns the terminal fails', 'FRESH follow-up after a chain hop counts', 'FRESH new owner record of another id fails', 'FRESH new owner that follows a flag-shaped id fails', 'FRESH new owner that follows another dispatch fails', 'FRESH new owner that follows nothing fails', "FRESH old owner outside the target's chain fails", 'FRESH owner row of a bad shape fails', 'FRESH owner row of another terminal fails', 'FRESH owner that did not change fails', "FRESH reads the terminal's owner before the send and after it", 'FRESH row that does not own the terminal fails', 'FRESH timed-out dispatch send whose follow-up is found counts', 'FRESH two owner rows fail', 'FRESH unreadable new owner fails', 'FRESH unreadable worker list fails', 'FRESH with no owner row fails', 'FRESH with nudge says it is not needed', 'FRESH worker list that is not ok fails', 'FRESH worker list with no row list fails'}),
    ('send-chain-home-id', ' or r["dispatch"].get("id") != sys.argv[2]:', ':', {'CHAIN home record of another id fails'}),
    ('send-chain-server-shape', 'if not (isinstance(e, str) and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9 ._:%()@-]{0,99}", e)):', 'if not isinstance(e, str):', {'CHAIN server id with shell text fails'}),
    ('send-chain-hops-7', 'for hop in 1 2 3 4 5 6 7 8; do', 'for hop in 1 2 3 4 5 6 7; do', {'CHAIN of 8 hops counts'}),
    ('send-chain-hops-9', 'for hop in 1 2 3 4 5 6 7 8; do', 'for hop in 1 2 3 4 5 6 7 8 9; do', {'CHAIN of 9 hops fails'}),
    ('send-chain-loop-off', 'case "$seen" in *" $x "*)', 'case "$seen" in NEVER)', {'CHAIN loop fails'}),
    ('send-chain-end-ok', 'if [ "$nx" = END ]; then', 'if false; then', {"CHAIN stranger's dispatch fails", "FRESH old owner outside the target's chain fails"}),
    ('send-chain-hop-shape', 'elif isinstance(f, str) and re.fullmatch(r"ctx_[A-Za-z0-9_-]{1,64}", f):', 'elif isinstance(f, str):', {'CHAIN flag-shaped id reaches no argv', 'CHAIN hop with a flag-shaped id is never read'}),
    ('send-followup-fu-shape', 'if isinstance(fu, str) and re.fullmatch(r"ctx_[A-Za-z0-9_-]{1,64}", fu) \\', 'if isinstance(fu, str) \\', {'CHAIN flag-shaped followUpOf is not a follow-up', 'CHAIN flag-shaped followUpOf is not a follow-up makes no worker-show call'}),
    ('send-chain-do-not-resend', '|| unproven "$cepa_send_chain_why; a follow-up dispatch may already exist, so do not resend"', '|| unproven "$cepa_send_chain_why"', {'CHAIN home record of another id fails', 'CHAIN hop of a bad shape fails', 'CHAIN hop record of another id fails', 'CHAIN hop with a flag-shaped id is never read', 'CHAIN hop with no followUpOf key fails', 'CHAIN loop fails', 'CHAIN of 9 hops fails', 'CHAIN server id with shell text fails', "CHAIN stranger's dispatch fails", 'CHAIN unreadable hop fails', 'CHAIN with no worker-show reads fails'}),
    ('send-chain-hop-id', 'or x.get("id") != sys.argv[2] or "followUpOf" not in x:', 'or "followUpOf" not in x:', {'CHAIN hop record of another id fails'}),
    ('send-followup-any-type', 'if m is None and typ not in ("reply", "worker_done") and target.startswith', 'if m is None and target.startswith', {'FOLLOWUP shape on a worker_done is not a follow-up'}),
    ('send-on-any-value', '[[ $cepa_send_on =~ $cepa_send_onre ]] || refuse', ': || refuse', {'HOSTON empty server refused', 'HOSTON flag-shaped server refused', 'HOSTON shell text in the server refused'}),
    # PR #138 review: the read-back's recipient and clock.
    ('send-readback-recipient', '        elif to != target:\n            continue', '        elif False:\n            continue', {'READBACK row stored for another recipient fails', 'READBACK run target needs that run'}),
    ('send-readback-dispatch-any', 'if not (isinstance(to, str) and to.startswith("dispatch:")):', 'if False:', {'READBACK dispatch target does not take a term_ row'}),
    ('send-readback-noclock', '[ "$cepa_send_t0" != 0 ] || fail "$cepa_send_why"', ':', {'READBACK no clock makes no read-back', 'READBACK no clock makes no inbox call'}),
    # L93 1: a timed-out dispatch: send, its 60 s bound and THE FOLLOW-UP RE-READ.
    ('send-fresh-bound-15', '[[ $cepa_send_target != dispatch:* ]] || cepa_send_bound=60', ':', {'FRESH dispatch send is bounded at 60 s, its reads at 15'}),
    ('send-fresh-bound-kept', 'esac\ncepa_send_bound=15', 'esac\n:', {'FRESH dispatch send is bounded at 60 s, its reads at 15'}),
    ('send-fresh-off', 'if [ "$cepa_send_rc" != 0 ]; then\n          cepa_send_new=$(cepa_send_fresh) || :', 'if false; then\n          cepa_send_new=$(cepa_send_fresh) || :', {'FOLLOWUP that exited non-zero fails', 'FRESH earlier follow-up that still owns the terminal fails', 'FRESH follow-up after a chain hop counts', "FRESH local target reads this machine's records", 'FRESH new owner record of another id fails', 'FRESH new owner that follows a flag-shaped id fails', 'FRESH new owner that follows another dispatch fails', 'FRESH new owner that follows nothing fails', "FRESH old owner outside the target's chain fails", 'FRESH owner before the send with no row fails', 'FRESH owner read failed before the send fails', 'FRESH owner row of a bad shape fails', 'FRESH owner row of another terminal fails', 'FRESH owner that did not change fails', "FRESH reads the terminal's owner before the send and after it", 'FRESH row that does not own the terminal fails', 'FRESH target record of another id fails', 'FRESH target with no terminal fails', 'FRESH timed-out dispatch send whose follow-up is found counts', 'FRESH two owner rows fail', 'FRESH unreadable home record fails', 'FRESH unreadable new owner fails', 'FRESH unreadable worker list fails', 'FRESH with no owner row fails', 'FRESH with nudge says it is not needed', 'FRESH worker list that is not ok fails', 'FRESH worker list with no row list fails'}),
    ('send-fresh-any-rc', 'if [ "$cepa_send_rc" != 0 ]; then\n          cepa_send_new=$(cepa_send_fresh) || :', 'if true; then\n          cepa_send_new=$(cepa_send_fresh) || :', {'CHAIN flag-shaped followUpOf is not a follow-up', 'CHAIN new dispatch equal to followUpOf is not a follow-up', 'CHAIN new dispatch equal to the target is not a follow-up', 'CHAIN null followUpOf is not a follow-up', 'FOLLOWUP beside a message is not a follow-up', 'FOLLOWUP new dispatch equal to the target fails', 'FOLLOWUP new dispatch of a bad shape fails', 'FOLLOWUP not ready fails', 'FRESH exit-0 reply makes no worker-list call after the send', 'FRESH exit-0 reply with no message is not re-read', 'READBACK dispatch target does not take a term_ row'}),
    ('send-fresh-nudge-line', 'found by a re-read, though $cepa_send_why (punch-list L93)"\n            [ -z "$cepa_send_downgraded" ] \\', 'found by a re-read, though $cepa_send_why (punch-list L93)"\n            true \\', {'FRESH with nudge says it is not needed'}),
    ('send-fresh-do-not-resend', 'unproven "$cepa_send_why; a re-read proved no follow-up ($cepa_send_new), but one may exist, so do not resend"', 'unproven "$cepa_send_why"', {'FOLLOWUP that exited non-zero fails', 'FRESH earlier follow-up that still owns the terminal fails', 'FRESH new owner record of another id fails', 'FRESH new owner that follows a flag-shaped id fails', 'FRESH new owner that follows another dispatch fails', 'FRESH new owner that follows nothing fails', "FRESH old owner outside the target's chain fails", 'FRESH owner before the send with no row fails', 'FRESH owner read failed before the send fails', 'FRESH owner row of a bad shape fails', 'FRESH owner row of another terminal fails', 'FRESH owner that did not change fails', 'FRESH row that does not own the terminal fails', 'FRESH target record of another id fails', 'FRESH target with no terminal fails', 'FRESH two owner rows fail', 'FRESH unreadable home record fails', 'FRESH unreadable new owner fails', 'FRESH unreadable worker list fails', 'FRESH with no owner row fails', 'FRESH worker list that is not ok fails', 'FRESH worker list with no row list fails'}),
    ('send-fresh-no-pre', '  cepa_send_owner0=$(cepa_send_owner pre) || :', '  :', {'FRESH earlier follow-up that still owns the terminal fails', 'FRESH follow-up after a chain hop counts', "FRESH local target reads this machine's records", 'FRESH new owner record of another id fails', 'FRESH new owner that follows a flag-shaped id fails', 'FRESH new owner that follows another dispatch fails', 'FRESH new owner that follows nothing fails', "FRESH old owner outside the target's chain fails", 'FRESH owner row of a bad shape fails', 'FRESH owner row of another terminal fails', 'FRESH owner that did not change fails', "FRESH reads the terminal's owner before the send and after it", 'FRESH row that does not own the terminal fails', 'FRESH timed-out dispatch send whose follow-up is found counts', 'FRESH two owner rows fail', 'FRESH unreadable new owner fails', 'FRESH unreadable worker list fails', 'FRESH with no owner row fails', 'FRESH with nudge says it is not needed', 'FRESH worker list that is not ok fails', 'FRESH worker list with no row list fails'}),
    ('send-fresh-pre-any-type', 'if [[ $cepa_send_target == dispatch:* && $cepa_send_type != worker_done && $cepa_send_type != reply ]]; then\n  cepa_send_owner0', 'if [[ $cepa_send_target == dispatch:* ]]; then\n  cepa_send_owner0', {'FRESH worker_done reads no terminal owner before the send'}),
    # PR #144 review (P1): an owner that did not change is no follow-up.
    ('send-fresh-same-owner-ok', '  if [ "$nd" = "$o0" ]; then\n    echo "FAIL', '  if false; then\n    echo "FAIL', {'FRESH earlier follow-up that still owns the terminal fails', 'FRESH owner that did not change fails'}),
    ('send-fresh-follow-any', '  if [ "$fu" != "$o0" ]; then', '  if false; then', {'FRESH new owner that follows a flag-shaped id fails', 'FRESH new owner that follows another dispatch fails', 'FRESH new owner that follows nothing fails'}),
    ('send-fresh-chain-off', '  if [ "$o0" != "$td" ] && ! cepa_send_chain "$o0"; then', '  if false; then', {"FRESH old owner outside the target's chain fails"}),
    ('send-fresh-terminal-home', '  if [ ${#env[@]} -gt 0 ]; then\n    e=${env[1]}', '  if false; then\n    e=${env[1]}', {'FRESH earlier follow-up that still owns the terminal fails', 'FRESH follow-up after a chain hop counts', 'FRESH new owner record of another id fails', 'FRESH new owner that follows a flag-shaped id fails', 'FRESH new owner that follows another dispatch fails', 'FRESH new owner that follows nothing fails', "FRESH old owner outside the target's chain fails", 'FRESH owner row of a bad shape fails', 'FRESH owner row of another terminal fails', 'FRESH owner that did not change fails', "FRESH reads the terminal's owner before the send and after it", 'FRESH row that does not own the terminal fails', 'FRESH timed-out dispatch send whose follow-up is found counts', 'FRESH two owner rows fail', 'FRESH unreadable new owner fails', 'FRESH unreadable worker list fails', 'FRESH with no owner row fails', 'FRESH with nudge says it is not needed', 'FRESH worker list that is not ok fails', 'FRESH worker list with no row list fails'}),
    ('send-fresh-list-local', 'orchestration worker-list ${env[@]+"${env[@]}"} \\\n    --limit 100', 'orchestration worker-list \\\n    --limit 100', {"FRESH reads the terminal's owner before the send and after it"}),
    ('send-fresh-target-id', 'h = x.get("assigneeHandle") if isinstance(x, dict) and x.get("id") == td else None', 'h = x.get("assigneeHandle") if isinstance(x, dict) else None', {'FRESH target record of another id fails'}),
    ('send-fresh-handle-any', 'if not isinstance(h, str):\n    sys.exit(1)\nrows = b["result"]["workers"]', 'rows = b["result"]["workers"]', {'FRESH target with no terminal fails'}),
    ('send-fresh-rows-list', 'if not isinstance(rows, list):\n    sys.exit(1)\nhit = []', 'hit = []', {'FRESH worker list with no row list fails'}),
    ('send-fresh-terminal-any', 'if isinstance(r, dict) and r.get("terminalHandle") == h and isinstance(i, str) \\', 'if isinstance(r, dict) and isinstance(i, str) \\', {'FRESH follow-up after a chain hop counts', "FRESH local target reads this machine's records", 'FRESH new owner record of another id fails', 'FRESH new owner that follows a flag-shaped id fails', 'FRESH new owner that follows another dispatch fails', 'FRESH new owner that follows nothing fails', "FRESH old owner outside the target's chain fails", 'FRESH owner row of a bad shape fails', 'FRESH owner row of another terminal fails', 'FRESH owner that did not change fails', "FRESH reads the terminal's owner before the send and after it", 'FRESH row that does not own the terminal fails', 'FRESH timed-out dispatch send whose follow-up is found counts', 'FRESH two owner rows fail', 'FRESH unreadable new owner fails', 'FRESH unreadable worker list fails', 'FRESH with no owner row fails', 'FRESH with nudge says it is not needed', 'FRESH worker list that is not ok fails', 'FRESH worker list with no row list fails'}),
    ('send-fresh-owner-any', 'and r.get("ownerDispatchId") == i and re.fullmatch(r"ctx_[A-Za-z0-9_-]{1,64}", i):', 'and re.fullmatch(r"ctx_[A-Za-z0-9_-]{1,64}", i):', {'FRESH row that does not own the terminal fails'}),
    ('send-fresh-row-shape', 'and r.get("ownerDispatchId") == i and re.fullmatch(r"ctx_[A-Za-z0-9_-]{1,64}", i):', 'and r.get("ownerDispatchId") == i:', {'FRESH owner row of a bad shape fails'}),
    ('send-fresh-one-row', 'if len(hit) != 1:\n    sys.exit(2)', 'if not hit:\n    sys.exit(2)', {'FRESH two owner rows fail'}),
    ('send-fresh-new-on-home', 'orchestration worker-show --dispatch "$nd" \\\n    ${env[@]+"${env[@]}"} --json --full', 'orchestration worker-show --dispatch "$nd" \\\n    --json --full', {'FRESH follow-up after a chain hop counts', 'FRESH new owner that follows a flag-shaped id fails', 'FRESH new owner that follows another dispatch fails', 'FRESH new owner that follows nothing fails', "FRESH old owner outside the target's chain fails", "FRESH reads the terminal's owner before the send and after it", 'FRESH timed-out dispatch send whose follow-up is found counts', 'FRESH with nudge says it is not needed'}),
    ('send-fresh-new-id', 'if not isinstance(x, dict) or x.get("id") != sys.argv[2]:\n    sys.exit(1)\nf = x.get("followUpOf")', 'if not isinstance(x, dict):\n    sys.exit(1)\nf = x.get("followUpOf")', {'FRESH new owner record of another id fails'}),
    # L97: a reply threaded on the ROOT counts only on the question's own row.
    ('reply-root-unproven-dropped', '  4) unproven "the reply is threaded on', '  4) : "the reply is threaded on', {'REPLY not threaded on the question', 'REPLYTHREAD another row of the thread quotes the question', 'REPLYTHREAD another row of the thread quotes the question is not nudged', 'REPLYTHREAD question is a root', 'REPLYTHREAD question is a root is not nudged', 'REPLYTHREAD question on another thread', 'REPLYTHREAD question on another thread is not nudged', 'REPLYTHREAD question out of the window', 'REPLYTHREAD question out of the window is not nudged'}),
    ('reply-root-any-row', 'threaded = not root or any(isinstance(x, dict) and x.get("id") == q and x.get("thread_id") == root', 'threaded = not root or any(isinstance(x, dict) and x.get("thread_id") == root', {'REPLYTHREAD another row of the thread quotes the question', 'REPLYTHREAD another row of the thread quotes the question is not nudged'}),
    ('reply-root-shape-unchecked', '            if not (isinstance(th, str) and re.fullmatch(MIDRE, th)):\n                return "UNPROVEN the reply is not threaded on %s" % target', '            if not isinstance(th, str):\n                return "UNPROVEN the reply is not threaded on %s" % target', {'REPLY thread not a message id'}),
    # L98: a chat recipient counts.
    ('chat-recipient-refused', 'ADDR = r"(term_[0-9a-f-]{36}|run:[A-Za-z0-9_-]{1,64}|dispatch:[A-Za-z0-9_-]{1,64}|orca_session_id:[0-9a-f-]{36})"\nMIDRE = r"msg_[0-9a-f]{6,32}"\n\ndef verdict():', 'ADDR = r"(term_[0-9a-f-]{36}|run:[A-Za-z0-9_-]{1,64}|dispatch:[A-Za-z0-9_-]{1,64})"\nMIDRE = r"msg_[0-9a-f]{6,32}"\n\ndef verdict():', {"BOT a chat id quoted in a title is not the bot's", 'BOT a chat with no closed field is not proven', "BOT a closed chat is not the bot's", 'BOT a name of 105 characters is accepted', "BOT another chat id is not the bot's", 'BOT argv and order, no nudge', 'BOT chat row missing from the inbox', 'BOT chats not JSON are unreadable', 'BOT chats not ok are unreadable', 'BOT chats of another bot are unreadable', 'BOT chats that fail are unreadable', 'BOT no-nudge prints no downgrade', "BOT send to a bot's chat counts", 'BOT to an earlier chat of the bot counts', 'CHATREPLY reply stored for a chat is not claimed delivered', 'CHATSENDER reply Orca addressed to this chat is misaddressed'}),
    # L103 C1: a chat sender's own address.
    ('chat-me-ignored', '    && cepa_send_me=orca_session_id:$ORCA_AGENT_SESSION_ID', '    && :', {'CHATSENDER reply Orca addressed to this chat is misaddressed', 'CHATSENDER reply to a question this chat sent is misaddressed', "READBACK from a chat skips another sender's row"}),
    ('chat-me-unstructured', '  [ "${ORCA_STRUCTURED_SESSION:-}" = 1 ] && [[ ${ORCA_AGENT_SESSION_ID:-}', '  [[ ${ORCA_AGENT_SESSION_ID:-}', {'CHATSENDER no structured session is no chat address', 'CHATSENDER structured session not 1 is no chat address'}),
    ('chat-me-handle-loses', 'cepa_send_me=${ORCA_TERMINAL_HANDLE:-}\nif [ -z "$cepa_send_me" ]; then', 'cepa_send_me=${ORCA_TERMINAL_HANDLE:-}\nif [ "${ORCA_STRUCTURED_SESSION:-}" = 1 ]; then', {'CHATSENDER a terminal handle wins over the chat id'}),
    # L103 C1: a bot: target.
    ('bot-target-loose', 'coord:[A-Za-z0-9_-]{1,100}|bot:[A-Za-z0-9_][A-Za-z0-9._-]{0,104})$ ]]\n}', 'coord:[A-Za-z0-9_-]{1,100}|bot:.*)$ ]]\n}', {'BOTREF empty name', 'BOTREF name starts with a dash', 'BOTREF name too long', 'BOTREF name with a space', 'BOTREF name with shell text'}),
    ('bot-chats-skipped', 'if [[ $cepa_send_target == bot:* ]]; then\n  cepa_send_orca "$cepa_send_tmp/chats.json"', 'if false; then\n  cepa_send_orca "$cepa_send_tmp/chats.json"', {"BOT a chat id quoted in a title is not the bot's", 'BOT a chat with no closed field is not proven', "BOT a closed chat is not the bot's", "BOT another chat id is not the bot's", 'BOT argv and order, no nudge', 'BOT chats not JSON are unreadable', 'BOT chats not ok are unreadable', 'BOT chats of another bot are unreadable', 'BOT chats that fail are unreadable'}),
    ('bot-chats-closed-ignored', 'c.get("id") == sys.argv[3] and c.get("closed") is False for c in r["chats"])', 'c.get("id") == sys.argv[3] for c in r["chats"])', {'BOT a chat with no closed field is not proven', "BOT a closed chat is not the bot's"}),
    ('bot-chats-other-bot', 'if not isinstance(r, dict) or r.get("bot") != sys.argv[2] or not isinstance(r.get("chats"), list):\n        sys.exit(2)\n    hit = any(isinstance(c, dict) and c.get("id")', 'if not isinstance(r, dict) or not isinstance(r.get("chats"), list):\n        sys.exit(2)\n    hit = any(isinstance(c, dict) and c.get("id")', {'BOT chats of another bot are unreadable'}),
    ('bot-chats-parse-is-absence', 'c.get("id") == sys.argv[3] and c.get("closed") is False for c in r["chats"])\nexcept Exception:\n    sys.exit(2)', 'c.get("id") == sys.argv[3] and c.get("closed") is False for c in r["chats"])\nexcept Exception:\n    sys.exit(1)', {'BOT chats not JSON are unreadable'}),
    ('bot-recipient-any', '        if not (isinstance(to, str) and to.startswith(("orca_session_id:", "run:"))):\n            return "UNPROVEN the reply names no valid recipient"', '        if False:\n            return "UNPROVEN the reply names no valid recipient"', {'BOT stored for a dispatch is not a bot'}),
    # PR #149 review fixes.
    ('reply-mine-after-thread', 'sys.exit(1 if not found else 3 if mine else 4 if not threaded else 0)', 'sys.exit(1 if not found else 4 if not threaded else 3 if mine else 0)', {'REPLYTHREAD reply addressed to this session wins over the thread'}),
    ('chat-recipient-any-type', '    if to.startswith("orca_session_id:") and typ != "reply" and not target.startswith("bot:"):', '    if False:', {'CHATREPLY a term_ send stored for a chat is not proven'}),
    ('chat-reply-claimed', '  if [[ $cepa_send_to == orca_session_id:* ]]; then\n    echo "Orca nudge skipped: Orca stored it for', '  if false; then\n    echo "Orca nudge skipped: Orca stored it for', {'CHATREPLY reply stored for a chat is not claimed delivered'}),
    ('bot-no-recipient-unproven', '            return "FAIL the reply names no recipient for %s" % target', '            return "UNPROVEN the reply names no recipient for %s" % target', {'BOT with no recipient and no row is not stored', 'BOT with no recipient is read back from its chat', "BOTRUN with no recipient is read back from the bot's Run"}),
    ('bot-readback-any', '            if not (isinstance(to, str) and to.startswith(("orca_session_id:", "run:"))):\n                continue', '            pass', {'BOT read back skips a row for another address'}),
    # L104: a bot send stored for a Run counts only with all its proof.
    ('botrun-recipient-refused', 'to.startswith(("orca_session_id:", "run:"))):\n            return "UNPROVEN the reply names no valid recipient"', 'to.startswith("orca_session_id:")):\n            return "UNPROVEN the reply names no valid recipient"', {'BOT stored for a Run with no bot request is not proven', 'BOTRUN a Home flag quoted as text is not proven', 'BOTRUN a Run with a terminal coordinator is not proven', 'BOTRUN a Run with no coordinator field is unreadable', 'BOTRUN a bot request on another msg id does not count', 'BOTRUN a closed Home chat is not proven', 'BOTRUN a null payload is not proven', "BOTRUN a payload given as an object, not Orca's string, is not proven", 'BOTRUN a payload with no botRequest is not proven', 'BOTRUN a run-show not JSON is unreadable', 'BOTRUN a run-show not ok is unreadable', 'BOTRUN a run-show of another Run is not proven', 'BOTRUN a run-show that fails is unreadable', 'BOTRUN argv and order, no nudge', 'BOTRUN botRequest in a payload that is not JSON is not proven', 'BOTRUN botRequest quoted as a payload value is not proven', 'BOTRUN botRequest quoted in the body is not proven', 'BOTRUN botRequest that is not an object is not proven', 'BOTRUN chats of another bot are unreadable', 'BOTRUN chats that fail are unreadable', 'BOTRUN no payload is not proven', 'BOTRUN only a chat that is not Home is not proven', 'BOTRUN row for another Run is not stored', 'BOTRUN row missing from the inbox', "BOTRUN send stored for the bot's Run counts"}),
    ('botrun-readback-refused', 'to.startswith(("orca_session_id:", "run:"))):\n                continue', 'to.startswith("orca_session_id:")):\n                continue', {'BOT read back of a Run row with no bot request is not proven', "BOTRUN read back from the bot's Run counts", "BOTRUN with no recipient is read back from the bot's Run"}),
    ('botrun-botreq-skipped', '            and not any(botreq(x) for x in mine_rows):\n        sys.exit(5)', '            and False:\n        sys.exit(5)', {'BOT read back of a Run row with no bot request is not proven', 'BOT stored for a Run with no bot request is not proven', 'BOTRUN a bot request on another msg id does not count', 'BOTRUN a null payload is not proven', "BOTRUN a payload given as an object, not Orca's string, is not proven", 'BOTRUN a payload with no botRequest is not proven', 'BOTRUN botRequest in a payload that is not JSON is not proven', 'BOTRUN botRequest quoted as a payload value is not proven', 'BOTRUN botRequest quoted in the body is not proven', 'BOTRUN botRequest that is not an object is not proven', 'BOTRUN no payload is not proven'}),
    ('botrun-botreq-any-row', 'and not any(botreq(x) for x in mine_rows):', 'and not any(botreq(x) for x in rows):', {'BOTRUN a bot request on another msg id does not count'}),
    ('botrun-botreq-text', '        return isinstance(p, dict) and isinstance(p.get("botRequest"), dict)', '        return "botRequest" in str(x.get("payload")) + str(x.get("body"))', {'BOTRUN botRequest quoted as a payload value is not proven', 'BOTRUN botRequest that is not an object is not proven'}),
    ('botrun-botreq-any-value', 'isinstance(p, dict) and isinstance(p.get("botRequest"), dict)', 'isinstance(p, dict) and "botRequest" in p.values() or isinstance(p, dict) and "botRequest" in p', {'BOTRUN botRequest quoted as a payload value is not proven', 'BOTRUN botRequest that is not an object is not proven'}),
    ('botrun-botreq-exit-ignored', "  5) unproven \"$cepa_send_id is stored for $cepa_send_to without Orca's bot request, so it is not proven a send to $cepa_send_target\" ;;", '  5) ;;', {'BOT read back of a Run row with no bot request is not proven', 'BOT stored for a Run with no bot request is not proven', 'BOTRUN a bot request on another msg id does not count', 'BOTRUN a null payload is not proven', "BOTRUN a payload given as an object, not Orca's string, is not proven", 'BOTRUN a payload with no botRequest is not proven', 'BOTRUN botRequest in a payload that is not JSON is not proven', 'BOTRUN botRequest quoted as a payload value is not proven', 'BOTRUN botRequest quoted in the body is not proven', 'BOTRUN botRequest that is not an object is not proven', 'BOTRUN no payload is not proven'}),
    ('botrun-runshow-skipped', 'if [[ $cepa_send_target == bot:* && $cepa_send_to == run:* ]]; then', 'if false; then', {'BOTRUN a Home flag quoted as text is not proven', 'BOTRUN a Run with a terminal coordinator is not proven', 'BOTRUN a Run with no coordinator field is unreadable', 'BOTRUN a closed Home chat is not proven', 'BOTRUN a run-show not JSON is unreadable', 'BOTRUN a run-show not ok is unreadable', 'BOTRUN a run-show of another Run is not proven', 'BOTRUN a run-show that fails is unreadable', 'BOTRUN argv and order, no nudge', 'BOTRUN only a chat that is not Home is not proven', "BOTRUN read back from the bot's Run counts", "BOTRUN send stored for the bot's Run counts", "BOTRUN with no recipient is read back from the bot's Run"}),
    ('botrun-runshow-coord-ignored', 'ok = r.get("id") == sys.argv[2] and r["coordinator_handle"] is None', 'ok = r.get("id") == sys.argv[2]', {'BOTRUN a Run with a terminal coordinator is not proven'}),
    ('botrun-runshow-id-ignored', 'ok = r.get("id") == sys.argv[2] and r["coordinator_handle"] is None', 'ok = r["coordinator_handle"] is None', {'BOTRUN a run-show of another Run is not proven'}),
    ('botrun-runshow-field-optional', 'if not isinstance(r, dict) or "coordinator_handle" not in r:\n        sys.exit(2)\n    ok = r.get("id") == sys.argv[2] and r["coordinator_handle"] is None', 'if not isinstance(r, dict):\n        sys.exit(2)\n    ok = r.get("id") == sys.argv[2] and r.get("coordinator_handle") is None', {'BOTRUN a Run with no coordinator field is unreadable'}),
    # No mutant drops run-show's `|| unproven`: its parse reads a failed read's
    # output as unreadable, with the same reason, so that mutant stays green.
    ('botrun-home-ignored', 'c.get("home") is True and c.get("closed") is False', 'c.get("closed") is False', {'BOTRUN a Home flag quoted as text is not proven', 'BOTRUN only a chat that is not Home is not proven'}),
    ('botrun-home-truthy', 'c.get("home") is True and', 'c.get("home") and', {'BOTRUN a Home flag quoted as text is not proven'}),
    ('botrun-home-closed-ignored', 'c.get("home") is True and c.get("closed") is False', 'c.get("home") is True', {'BOTRUN a closed Home chat is not proven'}),
    ('botrun-home-other-bot', 'if not isinstance(r, dict) or r.get("bot") != sys.argv[2] or not isinstance(r.get("chats"), list):\n        sys.exit(2)\n    hit = any(isinstance(c, dict) and c.get("home")', 'if not isinstance(r, dict) or not isinstance(r.get("chats"), list):\n        sys.exit(2)\n    hit = any(isinstance(c, dict) and c.get("home")', {'BOTRUN chats of another bot are unreadable'}),
]
# orca-health.sh mutants (punch-list L34). Each runs only the health half,
# with the shipped nudge and send scripts as arguments 1 and 2.
HEALTH_MUTANTS = [
    ('health-stale-bound', 'HB_STALE, RUN_LONG, Q_WAIT, AWAIT = 30, 180, 10, 30', 'HB_STALE, RUN_LONG, Q_WAIT, AWAIT = 31, 180, 10, 30', {'HEALTH LIFE a terminal that is not an object is no life', 'HEALTH LIFE life after an ack alerts again', 'HEALTH LIFE output older than the heartbeat keeps the heartbeat', 'HEALTH LIFE no heartbeat since dispatch, silent', 'HEALTH LIFE a hung git ends the git reads', 'HEALTH LIFE a future commit is no life', 'HEALTH LIFE no handle on either side is no life', 'HEALTH LIFE commit before the dispatch is the base, not life', 'HEALTH LIFE null output is no life', 'HEALTH LIFE output stops counting at the long bound', 'HEALTH LIFE zero output time is no life', 'HEALTH LIFE text output time is no life', 'HEALTH LIFE output far in the future is no life', 'HEALTH new stale period alerts again', 'HEALTH stale with no heartbeat counts from the dispatch', 'HEALTH LIFE a branch not checked out at that path is no life', 'HEALTH stale at 30 minutes', 'HEALTH LIFE a commit time git cannot give is no life', 'HEALTH LIFE output at 30 minutes alerts', 'HEALTH LIFE float output time is no life', 'HEALTH LIFE true output time is no life', 'HEALTH LIFE a path outside this repo is no life', 'HEALTH LIFE a failing git is no life', 'HEALTH LIFE an output time too large for a float is no life', "HEALTH LIFE another terminal's output is no life"}),
    ('health-long-bound', 'HB_STALE, RUN_LONG, Q_WAIT, AWAIT = 30, 180, 10, 30', 'HB_STALE, RUN_LONG, Q_WAIT, AWAIT = 30, 181, 10, 30', {'HEALTH LIFE output stops counting at the long bound', 'HEALTH long at 180 minutes'}),
    ('health-question-bound', 'HB_STALE, RUN_LONG, Q_WAIT, AWAIT = 30, 180, 10, 30', 'HB_STALE, RUN_LONG, Q_WAIT, AWAIT = 30, 180, 11, 30', {'HEALTH question that threads on itself is unanswered', 'HEALTH worker question at 10 minutes', "HEALTH asker's own follow-up is not an answer"}),
    ('health-await-bound', 'HB_STALE, RUN_LONG, Q_WAIT, AWAIT = 30, 180, 10, 30', 'HB_STALE, RUN_LONG, Q_WAIT, AWAIT = 30, 180, 10, 31', {'HEALTH awaited reply at 30 minutes'}),
    ('health-input-ignored', 'if "input" not in cats and mins(last) >= HB_STALE and k not in acked:', 'if mins(last) >= HB_STALE and k not in acked:', {'HEALTH LIFE a worker with a pending ask reads no life', 'HEALTH pending ask is not stale'}),
    # L82: a stale candidate's terminal output and commit count as life.
    ('health-life-off', 'seen, out_txt, commit_txt = life(r.get("terminal"), handle, start)', 'seen = None',
     {'HEALTH LIFE fresh output beats an older commit', 'HEALTH LIFE an acked silence stays quiet', 'HEALTH LIFE life after an ack alerts again', 'HEALTH LIFE commit counts with no output time', 'HEALTH LIFE commit before the dispatch is the base, not life', 'HEALTH LIFE a path outside this repo is no life', 'HEALTH LIFE a future commit is no life', 'HEALTH LIFE output just past the clock is life', 'HEALTH LIFE output counts just before the long bound', 'HEALTH LIFE a branch not checked out at that path is no life', 'HEALTH LIFE commit read through a wsl$ path', "HEALTH LIFE commit on the worktree's branch is life", 'HEALTH LIFE no heartbeat since dispatch, silent', 'HEALTH LIFE a hung git ends the git reads', 'HEALTH LIFE output stops counting at the long bound', 'HEALTH LIFE a commit time git cannot give is no life', 'HEALTH LIFE recent output is life', 'HEALTH LIFE output at 29 minutes is life', 'HEALTH LIFE a failing git is no life', 'HEALTH LIFE commit read through a WSL path', 'HEALTH LIFE output at 30 minutes alerts', 'HEALTH LIFE output older than the heartbeat keeps the heartbeat'}),
    ('health-life-any-worker', '        if "input" not in cats and mins(last) >= HB_STALE:\n            seen, out_txt', '        if True:\n            seen, out_txt',
     {'HEALTH LIFE a worker with a pending ask reads no life (no git read)', 'HEALTH LIFE a fresh worker reads no life (no git read)'}),
    ('health-life-key-old', '            last = max(last, seen or 0)\n', '            pass\n',
     {'HEALTH LIFE fresh output beats an older commit', 'HEALTH LIFE output at 29 minutes is life', 'HEALTH LIFE an acked silence stays quiet', 'HEALTH LIFE commit read through a WSL path', 'HEALTH LIFE recent output is life', 'HEALTH LIFE commit read through a wsl$ path', 'HEALTH LIFE output at 30 minutes alerts', 'HEALTH LIFE output just past the clock is life', 'HEALTH LIFE life after an ack alerts again', "HEALTH LIFE commit on the worktree's branch is life", 'HEALTH LIFE no heartbeat since dispatch, silent', 'HEALTH LIFE output counts just before the long bound', 'HEALTH LIFE commit counts with no output time'}),
    ('health-life-other-handle', ' or term.get("handle") != handle:', ':',
     {"HEALTH LIFE another terminal's output is no life"}),
    ('health-life-no-handle-ok', ' or not isinstance(handle, str)', '',
     {'HEALTH LIFE no handle on either side is no life'}),
    ('health-life-type-loose', 'type(out) is int and 0 < out // 1000 <= limit', 'isinstance(out, (int, float)) and 0 < out // 1000 <= limit',
     {'HEALTH LIFE float output time is no life'}),
    ('health-life-zero-ok', 'and 0 < out // 1000 <= limit', 'and out // 1000 <= limit',
     {'HEALTH LIFE zero output time is no life'}),
    ('health-life-future-ok', 'and 0 < out // 1000 <= limit', 'and 0 < out // 1000',
     {'HEALTH LIFE output far in the future is no life', 'HEALTH LIFE an output time too large for a float is no life'}),
    ('health-life-no-ahead', 'limit, best = now + LIFE_AHEAD, None', 'limit, best = now, None',
     {'HEALTH LIFE output just past the clock is life'}),
    ('health-life-past-long', '        if mins(start) < RUN_LONG:\n', '        if True:\n',
     {'HEALTH LIFE output stops counting at the long bound'}),
    ('health-life-long-late', 'if mins(start) < RUN_LONG:', 'if mins(start) <= RUN_LONG:',
     {'HEALTH LIFE output stops counting at the long bound'}),
    ('health-life-any-path', 'worktree_refs().get(path) == ref:', 'True:',
     {'HEALTH LIFE a branch not checked out at that path is no life', 'HEALTH LIFE a path outside this repo is no life'}),
    ('health-life-no-wsl', '    path = m.group(1).replace("\\\\", "/") if m else path\n', '',
     {'HEALTH LIFE commit read through a wsl$ path', 'HEALTH LIFE commit read through a WSL path'}),
    ('health-life-no-wsl-dollar', '(?:\\.localhost|\\$)', '(?:\\.localhost)',
     {'HEALTH LIFE commit read through a wsl$ path'}),
    ('health-life-base-commit', '            if start <= int(t):\n', '            if True:\n',
     {'HEALTH LIFE commit before the dispatch is the base, not life'}),
    ('health-life-future-commit', ', t) and int(t) <= limit:', ', t):',
     {'HEALTH LIFE a future commit is no life'}),
    ('health-life-time-unchecked', 'if re.fullmatch(r"[0-9]{1,12}", t) and int(t)', 'if t and int(t)',
     {'HEALTH LIFE a commit time git cannot give is no life'}),
    ('health-life-commit-off', 'worktree_refs().get(path) == ref:', 'False:',
     {'HEALTH LIFE commit read through a WSL path', 'HEALTH LIFE commit read through a wsl$ path', "HEALTH LIFE commit on the worktree's branch is life", 'HEALTH LIFE commit counts with no output time', 'HEALTH LIFE commit before the dispatch is the base, not life'}),
    ('health-life-commit-wins', 'max(best or 0, int(t)), ago(int(t))', 'int(t), ago(int(t))',
     {'HEALTH LIFE fresh output beats an older commit'}),
    ('health-life-git-rc', 'return g.stdout if g.returncode == 0 else None', 'return g.stdout',
     {'HEALTH LIFE a failing git is no life'}),
    ('health-life-hang-continues', '        git_left[0] = 0\n        return None\n', '        return None\n',
     {'HEALTH LIFE a hung git costs one 3-second wait'}),
    ('health-exited-ignored', 'if verdict == "exited":', 'if False:', {'HEALTH exited worker'}),
    ('health-wait-ignored', '        if wait:\n', '        if False:\n', {'HEALTH waiting worker, no stale beside it'}),
    ('health-repo-unfiltered', 'mine = repo == "unknown" or f["repo"] in (repo, "unknown")', 'mine = True', {'HEALTH alert file of another repo is not'}),
    ('health-worktree-unfiltered', '        mine = f["worktree"] == wt\n', '        mine = True\n', {'HEALTH alert file of another worktree is not'}),
    ('health-unknown-repo-filtered', 'if mine and not main and repo != "unknown":', 'if mine and not main:', {'HEALTH unknown repo shows every file'}),
    ('health-shape-unchecked', 'shaped = lines[:1] == ["cepa-orca-alert 1"] and all(', 'shaped = True or all(', {'HEALTH alert file with a bad field', 'HEALTH alert file in an unknown shape'}),
    ('health-reason-unchecked', 'why = f["reason"] if any(r.fullmatch(f["reason"]) for r in REASONS) else "an unrecognised reason"', 'why = f["reason"]', {'HEALTH unknown reason is not shown'}),
    ('health-nudge-kind-unknown', 'send_(refused|failed|unproven)|nudge_skipped|outbox_', 'send_(refused|failed|unproven)|outbox_',
     {'HEALTH every nudge_skipped reason is shown', 'HEALTH nudge_skipped reads its reason (ps)', 'HEALTH nudge_skipped reads its reason (show)', 'HEALTH nudge_skipped reads its reason (send exit)', 'HEALTH nudge_skipped reads its reason (send not ok)'}),
    ('health-nudge-reasons-gone', '    r"(terminal show|worktree ps) failed or timed out", ', '    ',
     {'HEALTH every nudge_skipped reason is shown', 'HEALTH nudge_skipped reads its reason (ps)', 'HEALTH nudge_skipped reads its reason (show)'}),
    ('health-nudgefile-reasons-gone', '    r"orca-nudge\\.sh not found beside orca-send\\.sh", ', '    ',
     {'HEALTH every nudge_skipped reason is shown'}),
    ('health-reason-list-short', '    r"no request id could be made", ', '    ', {'HEALTH every orca-send.sh reason is shown'}),
    ('health-follow-up-answers', ' and x.get("from_handle") != sender.get(t):', ':', {"HEALTH asker's own follow-up is not an answer"}),
    ('health-acks-ignored', 'acked = set(listdir(acked_dir, "ack-dir"))', 'acked = set()', {'HEALTH failed and acked is not read again', 'HEALTH LIFE output stops counting at the long bound', 'HEALTH unreadable alert directory', 'HEALTH LIFE an acked silence stays quiet', 'HEALTH acked key is not reported', 'HEALTH acked file is not reported', 'HEALTH acked unbound is not reported', 'HEALTH acked unreadable is unknown, never ok'}),
    ('health-acks-shared', 'cepa_h_acked="$cepa_h_dir/acked/$cepa_h_wt"', 'cepa_h_acked="$cepa_h_dir/acked"', {'HEALTH failed and acked is not read again', 'HEALTH LIFE output stops counting at the long bound', 'HEALTH LIFE an acked silence stays quiet', 'HEALTH acked key is not reported', 'HEALTH acked unbound is not reported', "HEALTH another worktree's ack does not hide it", 'HEALTH acked unreadable is unknown, never ok', 'HEALTH ack marks keys for this worktree only'}),
    ('health-ack-missing-file-ok', '[[ $k == send-failed:* ]] && cepa_h_af=', '[[ $k == none ]] && cepa_h_af=', {'HEALTH ack of a missing alert file fails'}),
    ('health-ack-key-loose', 'send-failed:[0-9]{1,12}-[A-Za-z0-9]{1,20}\\.alert|', 'send-failed:[A-Za-z0-9_.-]{1,40}|', {'HEALTHREF ack temp file name'}),
    ('health-hidden-is-ok', 'if hidden and not seen:', 'if False:', {'HEALTH acked unreadable is unknown, never ok'}),
    ('health-run-id-unchecked', ' or r["id"] != sys.argv[2]:', ':', {'HEALTH run-show bad run id', 'HEALTH run-show names another Run'}),
    ('health-workers-shape-loose', 'r = d["result"]["workers"] if d.get("ok") is True else sys.exit(1)', 'r = d["result"].get("workers", []) if d.get("ok") is True else sys.exit(1)', {'HEALTH worker-list with no workers field'}),
    ('health-cap-ignored', 'if len(ids) > 20:', 'if False:', {'HEALTH more than 20 live rows across pages', 'HEALTH more than 20 live workers'}),
    # WORKER-LIST PAGES (punch-list L94).
    ('health-cursor-not-followed', '    [ -n "$cepa_h_cur" ] || break\n', '    break\n', {'HEALTH a cursor seen before is unreadable', 'HEALTH a later page that fails is unreadable', 'HEALTH a row live on page 1 and failed on page 2 alerts', 'HEALTH failed row on a later page alerts', 'HEALTH many finished rows over several pages are not capped', 'HEALTH more than 10 pages', 'HEALTH more than 20 live rows across pages'}),
    ('health-later-pages-dropped', 'for f in sys.argv[4:]:', 'for f in sys.argv[4:5]:', {'HEALTH a row live on page 1 and failed on page 2 alerts', 'HEALTH failed row on a later page alerts', 'HEALTH more than 20 live rows across pages'}),
    ('health-page-bound-gone', 'if [ "$cepa_h_pg" -ge 10 ]; then', 'if [ "$cepa_h_pg" -ge 99 ]; then', {'HEALTH more than 10 pages'}),
    ('health-page-bound-long', 'if [ "$cepa_h_pg" -ge 10 ]; then', 'if [ "$cepa_h_pg" -ge 11 ]; then', {'HEALTH more than 10 pages'}),
    ('health-dup-first-wins', 'if i not in byid or rank > byid[i][0]:', 'if i not in byid:', {'HEALTH a row live on page 1 and failed on page 2 alerts'}),
    ('health-cursor-dash-first', 're.fullmatch(r"[A-Za-z0-9_][A-Za-z0-9_=-]{0,4095}", c)', 're.fullmatch(r"[A-Za-z0-9_=-]{1,4096}", c)', {'HEALTH a cursor that starts with a dash is unreadable'}),
    ('health-cursor-loop-unchecked', '    [[ $cepa_h_seen != *" $cepa_h_cur "* ]] || { cepa_h_wlok=0; break; }\n', '', {'HEALTH a cursor seen before is unreadable'}),
    ('health-nopage-full-ok', '    sys.exit(0 if len(d["result"].get("workers") or []) < 100 else 1)', '    sys.exit(0)', {'HEALTH a full page with no page object is unreadable'}),
    ('health-limit-dropped', '--run "$cepa_h_run" --limit 100 --json --full)', '--run "$cepa_h_run" --json --full)', {'HEALTH failed and acked is not read again', 'HEALTH failed at start alerts', 'HEALTH host dispatch with no projection is skipped', 'HEALTH host dispatch with projection null is skipped', 'HEALTH many finished rows over several pages are not capped', 'HEALTH more than 10 pages', 'HEALTH quiet Run is ok', 'HEALTH server row with a projection is still read', "HEALTH this pane's Run held here is checked"}),
    ('health-page-bound-short', 'if [ "$cepa_h_pg" -ge 10 ]; then', 'if [ "$cepa_h_pg" -ge 9 ]; then', {'HEALTH 10 pages is read whole', 'HEALTH more than 10 pages'}),
    ('health-pages-alert-silent', '    if os.path.exists(os.path.join(tmp, "pages")):', '    if False:', {'HEALTH more than 10 pages'}),
    ('health-cursor-unchecked', 're.fullmatch(r"[A-Za-z0-9_][A-Za-z0-9_=-]{0,4095}", c)', 're.fullmatch(r".+", c)', {'HEALTH a cursor outside base64url is unreadable', 'HEALTH a cursor that starts with a dash is unreadable'}),
    ('health-hasmore-loose', 'if m is not True or not (', 'if not (', {'HEALTH hasMore that is not a boolean is unreadable'}),
    ('health-old-page-cap', '# L94: the cap counts live rows only; finished rows on more pages never do.\nif len(ids) > 20:', '# L94: the cap counts live rows only; finished rows on more pages never do.\nif len(ids) > 20 or len(sys.argv) > 5:', {'HEALTH 10 pages is read whole', 'HEALTH a cursor with dash, equals and underscore is followed', 'HEALTH a row live on page 1 and failed on page 2 alerts', 'HEALTH a row seen on two pages counts once', 'HEALTH failed row on a later page alerts', 'HEALTH many finished rows over several pages are not capped', 'HEALTH more than 10 pages'}),
    ('health-settled-read', '        if p["outcome"] != "in_progress":\n', '        if False:\n', {'HEALTH settled in worker-show is skipped'}),
    ('health-id-unchecked', 'if did != n[:-5] or not', 'if not', {'HEALTH worker-show names another dispatch'}),
    ('health-show-date-unchecked', ' or start is None:', ':', {'HEALTH worker-show with a bad date'}),
    ('health-hb-undated-ok', '        if hb is None and disp.get("lastHeartbeatAt") is not None:\n', '        if False:\n', {'HEALTH worker-show with a heartbeat time it cannot date'}),
    ('health-crash-exits-1', '    os._exit(3)', '    os._exit(1)', {'HEALTH a reader crash is an alert'}),
    ('health-alert-dir-silent', '    except OSError:\n        unreadable(what,', '    except OSError:\n        return []\n        unreadable(what,', {'HEALTH unreadable alert directory'}),
    ('health-run-fail-silent', 'if os.path.exists(os.path.join(tmp, "run.fail")):\n    unreadable("run-current" if os.path.exists(os.path.join(tmp, "run.current")) else "run-show")\n', '', {'HEALTH run-show bad run id', 'HEALTH run-show fails', 'HEALTH run-show names another Run', 'HEALTH run-show not ok', 'HEALTH run-show with no Run', 'HEALTH run-show with no run field', 'HEALTH run-current fails with no Run named', 'HEALTH run-current bad holder with no Run named', 'HEALTH run-current in the 1.4.246 short shape', 'HEALTH run-show in the 1.4.246 short shape'}),
    ('health-inbox-fail-silent', 'if not isinstance(rows, list):\n    unreadable("inbox")\n', 'if not isinstance(rows, list):\n    pass\n', {'HEALTH a timed-out call stops the rest', 'HEALTH inbox fails', 'HEALTH inbox with no messages field'}),
    ('health-no-wedge-stop', 'then cepa_h_wedged=1; return 1; fi', 'then return 1; fi', {'HEALTH no call after a timeout', 'HEALTH a timed-out call stops the rest'}),
    ('health-no-vsock-retry', '  for try in 1 2; do\n    t=$(date', '  for try in 1; do\n    t=$(date', {'HEALTH worker-list vsock once', 'HEALTH vsock retry runs worker-list twice'}),
    ('health-dir-relative', '[[ $cepa_h_dir == /* ]] || refuse "the alert directory is not an absolute path"\n', '', {'HEALTHREF relative alert directory'}),
    ('health-cli-any', '  orca-ide|orca-dev) ;;', '  orca-ide|orca-dev|bash) ;;', {'HEALTHREF cli not orca'}),
    # L46: with no Run named, only this pane's Run held here is checked.
    ('health-run-arg-unchecked', '[[ $2 =~ ^run_[A-Za-z0-9_]{1,64}$ ]] || refuse', 'true || refuse', {'HEALTHBLOCK passes the named Run as its own argument', 'HEALTHREF run with a dash', 'HEALTHREF run with shell text'}),
    ('health-want-gate-dropped', 'if [ -n "$cepa_h_want" ]; then', 'if true; then', {'HEALTH no Run named and none held here', 'HEALTH run-current bad holder with no Run named', 'HEALTH run-current fails with no Run named', "HEALTH this pane's Run held elsewhere is not checked", "HEALTH this pane's Run held here is checked", 'HEALTH run-current in the 1.4.246 short shape'}),
    ('health-adopts-any-holder', 'if h == sys.argv[2]:\n    print(i)', 'if True:\n    print(i)', {"HEALTH this pane's Run held elsewhere is not checked"}),
    ('health-never-adopts', 'if h == sys.argv[2]:\n    print(i)', 'if False:\n    print(i)', {"HEALTH this pane's Run held here is checked"}),
    ('health-current-label', 'unreadable("run-current" if os.path.exists(os.path.join(tmp, "run.current")) else "run-show")', 'unreadable("run-show")', {'HEALTH run-current bad holder with no Run named', 'HEALTH run-current fails with no Run named', 'HEALTH run-current in the 1.4.246 short shape'}),
    # L45: the unbound alert.
    ('health-unbound-silent', 'holder != me and k not in acked:', 'False and k not in acked:', {'HEALTH unbound Run is reported'}),
    ('health-unbound-holder-here', 'holder) and holder != me and k not in acked:', 'holder) and k not in acked:', {'HEALTH Run bound here is ok', "HEALTH this pane's Run held here is checked"}),
    ('health-unbound-holder-unchecked', 'isinstance(holder, str) and re.fullmatch(r"term_[0-9a-f-]{36}", holder) and', 'isinstance(holder, str) and', {'HEALTH unbound needs a valid holder'}),
    ('health-unbound-ack-ignored', 'holder != me and k not in acked:', 'holder != me:', {'HEALTH acked unbound is not reported'}),
    ('health-unbound-me-unchecked', 'if run and me:\n    # L45', 'if run:\n    # L45', {"HEALTH unbound needs this terminal's handle"}),
    ('health-unbound-key-refused', '|unbound:run_[A-Za-z0-9_-]{1,64}:[0-9]{1,12}', '', {'HEALTH unbound ack prints the key'}),
    # L72: Orca 1.4.246 answers a read without --full in its short shape.
    ('health-runshow-short', 'run-show --id "$cepa_h_want" --json --full;', 'run-show --id "$cepa_h_want" --json;', {'HEALTH 10 pages is read whole', 'HEALTH 20 live workers is not capped', 'HEALTH LIFE a branch not checked out at that path is no life', 'HEALTH LIFE a commit time git cannot give is no life', 'HEALTH LIFE a failing git is no life', 'HEALTH LIFE a fresh worker reads no life', 'HEALTH LIFE a future commit is no life', 'HEALTH LIFE a hung git ends the git reads', 'HEALTH LIFE a path outside this repo is no life', 'HEALTH LIFE a terminal that is not an object is no life', 'HEALTH LIFE a worker with a pending ask reads no life', 'HEALTH LIFE an acked silence stays quiet', 'HEALTH LIFE an output time too large for a float is no life', "HEALTH LIFE another terminal's output is no life", 'HEALTH LIFE commit before the dispatch is the base, not life', 'HEALTH LIFE commit counts with no output time', "HEALTH LIFE commit on the worktree's branch is life", 'HEALTH LIFE commit read through a WSL path', 'HEALTH LIFE commit read through a wsl$ path', 'HEALTH LIFE float output time is no life', 'HEALTH LIFE fresh output beats an older commit', 'HEALTH LIFE life after an ack alerts again', 'HEALTH LIFE no handle on either side is no life', 'HEALTH LIFE no heartbeat since dispatch, silent', 'HEALTH LIFE null output is no life', 'HEALTH LIFE output at 29 minutes is life', 'HEALTH LIFE output at 30 minutes alerts', 'HEALTH LIFE output counts just before the long bound', 'HEALTH LIFE output far in the future is no life', 'HEALTH LIFE output just past the clock is life', 'HEALTH LIFE output older than the heartbeat keeps the heartbeat', 'HEALTH LIFE output stops counting at the long bound', 'HEALTH LIFE recent output is life', 'HEALTH LIFE text output time is no life', 'HEALTH LIFE true output time is no life', 'HEALTH LIFE zero output time is no life', 'HEALTH Run bound here is ok', 'HEALTH a cursor outside base64url is unreadable', 'HEALTH a cursor seen before is unreadable', 'HEALTH a cursor that starts with a dash is unreadable', 'HEALTH a cursor with dash, equals and underscore is followed', 'HEALTH a full page with no page object is unreadable', 'HEALTH a later page that fails is unreadable', 'HEALTH a page with no hasMore is unreadable', 'HEALTH a reader crash is an alert', 'HEALTH a row live on page 1 and failed on page 2 alerts', 'HEALTH a row seen on two pages counts once', 'HEALTH a short page with no page object is the last', 'HEALTH a timed-out call stops the rest', 'HEALTH acked file is not reported', 'HEALTH acked key is not reported', 'HEALTH acked unbound is not reported', 'HEALTH acked unreadable is unknown, never ok', 'HEALTH alert file in an unknown shape', 'HEALTH alert file is reported', 'HEALTH alert file of another repo is not', 'HEALTH alert file of another worktree is not', 'HEALTH alert file with a bad field', 'HEALTH alert file with a bot target is reported', "HEALTH another worktree's ack does not hide it", 'HEALTH answered question', "HEALTH asker's own follow-up is not an answer", 'HEALTH awaited reply at 29 minutes', 'HEALTH awaited reply at 30 minutes', "HEALTH awaited reply needs this session's handle", 'HEALTH exited worker', 'HEALTH failed and acked is not read again', 'HEALTH failed at start alerts', 'HEALTH failed of another dispatch id in worker-show', 'HEALTH failed row on a later page alerts', 'HEALTH failed that sent its own worker_done is not an alert', 'HEALTH failed whose worker-show fails still alerts', 'HEALTH failed with a prose last failure shows none of it', 'HEALTH failed with a succeeded worker_done still alerts', 'HEALTH failed with an exited agent alerts', 'HEALTH failed with an odd stage', "HEALTH failed with another dispatch's worker_done still alerts", 'HEALTH failed with shell text in its last failure', 'HEALTH full inbox window is noted', 'HEALTH hasMore that is not a boolean is unreadable', 'HEALTH host dispatch row with a bad id is unreadable', 'HEALTH host dispatch row with no environment id is unreadable', 'HEALTH host dispatch with no projection is skipped', 'HEALTH host dispatch with projection null is skipped', 'HEALTH inbox fails', 'HEALTH inbox in the 1.4.246 short shape', 'HEALTH inbox row missing created_at', 'HEALTH inbox row that is not an object', 'HEALTH inbox with no messages field', 'HEALTH local server row with no projection is unreadable', 'HEALTH long at 180 minutes', 'HEALTH main checkout sees every worktree', 'HEALTH many finished rows over several pages are not capped', 'HEALTH more than 10 pages', 'HEALTH more than 20 live rows across pages', 'HEALTH more than 20 live workers', 'HEALTH new stale period alerts again', 'HEALTH no call after a timeout', 'HEALTH not long at 179 minutes', 'HEALTH not stale at 29 minutes', 'HEALTH nudge_skipped reads its reason (ps)', 'HEALTH nudge_skipped reads its reason (send exit)', 'HEALTH nudge_skipped reads its reason (send not ok)', 'HEALTH nudge_skipped reads its reason (show)', 'HEALTH other files are ignored', 'HEALTH pending ask is not stale', 'HEALTH question that threads on itself is unanswered', 'HEALTH quiet Run is ok', 'HEALTH refused send reads refused', 'HEALTH send_unproven reads its reason (chat inbox)', 'HEALTH send_unproven reads its reason (chats)', 'HEALTH send_unproven reads its reason (closed chat)', 'HEALTH send_unproven reads its reason (thread)', 'HEALTH server row with a projection is still read', 'HEALTH settled in worker-show is skipped', 'HEALTH stale at 30 minutes', 'HEALTH stale with no heartbeat counts from the dispatch', 'HEALTH unbound Run is reported', 'HEALTH unbound needs a valid holder', "HEALTH unbound needs this terminal's handle", 'HEALTH unknown reason is not shown', 'HEALTH unknown repo shows every file', 'HEALTH unreadable alert directory', 'HEALTH unverifiable is not an alert', 'HEALTH vsock retry runs worker-list twice', 'HEALTH waiting worker, no stale beside it', 'HEALTH worker question at 10 minutes', 'HEALTH worker question at 9 minutes', 'HEALTH worker-list in the 1.4.246 short shape', 'HEALTH worker-list last page is read', 'HEALTH worker-list not ok', 'HEALTH worker-list row with no projection', 'HEALTH worker-list vsock once', 'HEALTH worker-list with no workers field', 'HEALTH worker-show fails', 'HEALTH worker-show in the 1.4.246 short shape', 'HEALTH worker-show names another dispatch', 'HEALTH worker-show with a bad date', 'HEALTH worker-show with a heartbeat time it cannot date', 'HEALTH worker-show with no projection'}),
    ('health-runcur-short', 'orchestration run-current --json --full;', 'orchestration run-current --json;',
     {'HEALTH no Run named and none held here', "HEALTH this pane's Run held elsewhere is not checked", "HEALTH this pane's Run held here is checked"}),
    ('health-wlist-short', 'cepa_h_wl=(orchestration worker-list --run "$cepa_h_run" --limit 100 --json --full)', 'cepa_h_wl=(orchestration worker-list --run "$cepa_h_run" --limit 100 --json)', {'HEALTH 10 pages is read whole', 'HEALTH 20 live workers is not capped', 'HEALTH LIFE a branch not checked out at that path is no life', 'HEALTH LIFE a commit time git cannot give is no life', 'HEALTH LIFE a failing git is no life', 'HEALTH LIFE a fresh worker reads no life', 'HEALTH LIFE a future commit is no life', 'HEALTH LIFE a hung git ends the git reads', 'HEALTH LIFE a path outside this repo is no life', 'HEALTH LIFE a terminal that is not an object is no life', 'HEALTH LIFE a worker with a pending ask reads no life', 'HEALTH LIFE an acked silence stays quiet', 'HEALTH LIFE an output time too large for a float is no life', "HEALTH LIFE another terminal's output is no life", 'HEALTH LIFE commit before the dispatch is the base, not life', 'HEALTH LIFE commit counts with no output time', "HEALTH LIFE commit on the worktree's branch is life", 'HEALTH LIFE commit read through a WSL path', 'HEALTH LIFE commit read through a wsl$ path', 'HEALTH LIFE float output time is no life', 'HEALTH LIFE fresh output beats an older commit', 'HEALTH LIFE life after an ack alerts again', 'HEALTH LIFE no handle on either side is no life', 'HEALTH LIFE no heartbeat since dispatch, silent', 'HEALTH LIFE null output is no life', 'HEALTH LIFE output at 29 minutes is life', 'HEALTH LIFE output at 30 minutes alerts', 'HEALTH LIFE output counts just before the long bound', 'HEALTH LIFE output far in the future is no life', 'HEALTH LIFE output just past the clock is life', 'HEALTH LIFE output older than the heartbeat keeps the heartbeat', 'HEALTH LIFE output stops counting at the long bound', 'HEALTH LIFE recent output is life', 'HEALTH LIFE text output time is no life', 'HEALTH LIFE true output time is no life', 'HEALTH LIFE zero output time is no life', 'HEALTH Run bound here is ok', 'HEALTH a cursor with dash, equals and underscore is followed', 'HEALTH a page with no hasMore is unreadable', 'HEALTH a reader crash is an alert', 'HEALTH a row live on page 1 and failed on page 2 alerts', 'HEALTH a row seen on two pages counts once', 'HEALTH a short page with no page object is the last', 'HEALTH acked file is not reported', 'HEALTH acked key is not reported', 'HEALTH acked unbound is not reported', 'HEALTH alert file in an unknown shape', 'HEALTH alert file is reported', 'HEALTH alert file of another repo is not', 'HEALTH alert file of another worktree is not', 'HEALTH alert file with a bad field', 'HEALTH alert file with a bot target is reported', "HEALTH another worktree's ack does not hide it", 'HEALTH answered question', "HEALTH asker's own follow-up is not an answer", 'HEALTH awaited reply at 29 minutes', 'HEALTH awaited reply at 30 minutes', "HEALTH awaited reply needs this session's handle", 'HEALTH exited worker', 'HEALTH failed and acked is not read again', 'HEALTH failed at start alerts', 'HEALTH failed of another dispatch id in worker-show', 'HEALTH failed row on a later page alerts', 'HEALTH failed that sent its own worker_done is not an alert', 'HEALTH failed whose worker-show fails still alerts', 'HEALTH failed with a prose last failure shows none of it', 'HEALTH failed with a succeeded worker_done still alerts', 'HEALTH failed with an exited agent alerts', 'HEALTH failed with an odd stage', "HEALTH failed with another dispatch's worker_done still alerts", 'HEALTH failed with shell text in its last failure', 'HEALTH full inbox window is noted', 'HEALTH hasMore that is not a boolean is unreadable', 'HEALTH host dispatch with no projection is skipped', 'HEALTH host dispatch with projection null is skipped', 'HEALTH inbox fails', 'HEALTH inbox in the 1.4.246 short shape', 'HEALTH inbox row missing created_at', 'HEALTH inbox row that is not an object', 'HEALTH inbox with no messages field', 'HEALTH long at 180 minutes', 'HEALTH main checkout sees every worktree', 'HEALTH many finished rows over several pages are not capped', 'HEALTH more than 10 pages', 'HEALTH more than 20 live rows across pages', 'HEALTH more than 20 live workers', 'HEALTH new stale period alerts again', 'HEALTH not long at 179 minutes', 'HEALTH not stale at 29 minutes', 'HEALTH nudge_skipped reads its reason (ps)', 'HEALTH nudge_skipped reads its reason (send exit)', 'HEALTH nudge_skipped reads its reason (send not ok)', 'HEALTH nudge_skipped reads its reason (show)', 'HEALTH other files are ignored', 'HEALTH pending ask is not stale', 'HEALTH question that threads on itself is unanswered', 'HEALTH quiet Run is ok', 'HEALTH refused send reads refused', 'HEALTH send_unproven reads its reason (chat inbox)', 'HEALTH send_unproven reads its reason (chats)', 'HEALTH send_unproven reads its reason (closed chat)', 'HEALTH send_unproven reads its reason (thread)', 'HEALTH server row with a projection is still read', 'HEALTH settled in worker-show is skipped', 'HEALTH stale at 30 minutes', 'HEALTH stale with no heartbeat counts from the dispatch', "HEALTH this pane's Run held here is checked", 'HEALTH unbound Run is reported', 'HEALTH unbound needs a valid holder', "HEALTH unbound needs this terminal's handle", 'HEALTH unknown reason is not shown', 'HEALTH unknown repo shows every file', 'HEALTH unreadable alert directory', 'HEALTH unverifiable is not an alert', 'HEALTH waiting worker, no stale beside it', 'HEALTH worker question at 10 minutes', 'HEALTH worker question at 9 minutes', 'HEALTH worker-list last page is read', 'HEALTH worker-list vsock once', 'HEALTH worker-show fails', 'HEALTH worker-show in the 1.4.246 short shape', 'HEALTH worker-show names another dispatch', 'HEALTH worker-show with a bad date', 'HEALTH worker-show with a heartbeat time it cannot date', 'HEALTH worker-show with no projection'}),
    ('health-wshow-short', 'worker-show --dispatch "$d" --json --full \\', 'worker-show --dispatch "$d" --json \\', {'HEALTH 10 pages is read whole', 'HEALTH 20 live workers is not capped', 'HEALTH LIFE a branch not checked out at that path is no life', 'HEALTH LIFE a commit time git cannot give is no life', 'HEALTH LIFE a failing git is no life', 'HEALTH LIFE a fresh worker reads no life', 'HEALTH LIFE a future commit is no life', 'HEALTH LIFE a hung git ends the git reads', 'HEALTH LIFE a path outside this repo is no life', 'HEALTH LIFE a terminal that is not an object is no life', 'HEALTH LIFE a worker with a pending ask reads no life', 'HEALTH LIFE an acked silence stays quiet', 'HEALTH LIFE an output time too large for a float is no life', "HEALTH LIFE another terminal's output is no life", 'HEALTH LIFE commit before the dispatch is the base, not life', 'HEALTH LIFE commit counts with no output time', "HEALTH LIFE commit on the worktree's branch is life", 'HEALTH LIFE commit read through a WSL path', 'HEALTH LIFE commit read through a wsl$ path', 'HEALTH LIFE float output time is no life', 'HEALTH LIFE fresh output beats an older commit', 'HEALTH LIFE life after an ack alerts again', 'HEALTH LIFE no handle on either side is no life', 'HEALTH LIFE no heartbeat since dispatch, silent', 'HEALTH LIFE null output is no life', 'HEALTH LIFE output at 29 minutes is life', 'HEALTH LIFE output at 30 minutes alerts', 'HEALTH LIFE output counts just before the long bound', 'HEALTH LIFE output far in the future is no life', 'HEALTH LIFE output just past the clock is life', 'HEALTH LIFE output older than the heartbeat keeps the heartbeat', 'HEALTH LIFE output stops counting at the long bound', 'HEALTH LIFE recent output is life', 'HEALTH LIFE text output time is no life', 'HEALTH LIFE true output time is no life', 'HEALTH LIFE zero output time is no life', 'HEALTH Run bound here is ok', 'HEALTH a cursor with dash, equals and underscore is followed', 'HEALTH a reader crash is an alert', 'HEALTH a row live on page 1 and failed on page 2 alerts', 'HEALTH a row seen on two pages counts once', 'HEALTH a short page with no page object is the last', 'HEALTH acked file is not reported', 'HEALTH acked key is not reported', 'HEALTH acked unbound is not reported', 'HEALTH alert file in an unknown shape', 'HEALTH alert file is reported', 'HEALTH alert file of another repo is not', 'HEALTH alert file of another worktree is not', 'HEALTH alert file with a bad field', 'HEALTH alert file with a bot target is reported', "HEALTH another worktree's ack does not hide it", 'HEALTH answered question', "HEALTH asker's own follow-up is not an answer", 'HEALTH awaited reply at 29 minutes', 'HEALTH awaited reply at 30 minutes', "HEALTH awaited reply needs this session's handle", 'HEALTH exited worker', 'HEALTH failed and acked is not read again', 'HEALTH failed at start alerts', 'HEALTH failed of another dispatch id in worker-show', 'HEALTH failed row on a later page alerts', 'HEALTH failed that sent its own worker_done is not an alert', 'HEALTH failed whose worker-show fails still alerts', 'HEALTH failed with a prose last failure shows none of it', 'HEALTH failed with a succeeded worker_done still alerts', 'HEALTH failed with an exited agent alerts', 'HEALTH failed with an odd stage', "HEALTH failed with another dispatch's worker_done still alerts", 'HEALTH failed with shell text in its last failure', 'HEALTH full inbox window is noted', 'HEALTH host dispatch with no projection is skipped', 'HEALTH host dispatch with projection null is skipped', 'HEALTH inbox fails', 'HEALTH inbox in the 1.4.246 short shape', 'HEALTH inbox row missing created_at', 'HEALTH inbox row that is not an object', 'HEALTH inbox with no messages field', 'HEALTH long at 180 minutes', 'HEALTH main checkout sees every worktree', 'HEALTH many finished rows over several pages are not capped', 'HEALTH more than 10 pages', 'HEALTH more than 20 live rows across pages', 'HEALTH more than 20 live workers', 'HEALTH new stale period alerts again', 'HEALTH not long at 179 minutes', 'HEALTH not stale at 29 minutes', 'HEALTH nudge_skipped reads its reason (ps)', 'HEALTH nudge_skipped reads its reason (send exit)', 'HEALTH nudge_skipped reads its reason (send not ok)', 'HEALTH nudge_skipped reads its reason (show)', 'HEALTH other files are ignored', 'HEALTH pending ask is not stale', 'HEALTH question that threads on itself is unanswered', 'HEALTH quiet Run is ok', 'HEALTH refused send reads refused', 'HEALTH send_unproven reads its reason (chat inbox)', 'HEALTH send_unproven reads its reason (chats)', 'HEALTH send_unproven reads its reason (closed chat)', 'HEALTH send_unproven reads its reason (thread)', 'HEALTH server row with a projection is still read', 'HEALTH settled in worker-show is skipped', 'HEALTH stale at 30 minutes', 'HEALTH stale with no heartbeat counts from the dispatch', "HEALTH this pane's Run held here is checked", 'HEALTH unbound Run is reported', 'HEALTH unbound needs a valid holder', "HEALTH unbound needs this terminal's handle", 'HEALTH unknown reason is not shown', 'HEALTH unknown repo shows every file', 'HEALTH unreadable alert directory', 'HEALTH unverifiable is not an alert', 'HEALTH waiting worker, no stale beside it', 'HEALTH worker question at 10 minutes', 'HEALTH worker question at 9 minutes', 'HEALTH worker-list last page is read', 'HEALTH worker-list vsock once'}),
    ('health-inbox-short', 'orchestration inbox --limit 200 --json --full ||', 'orchestration inbox --limit 200 --json ||', {'HEALTH answered question', "HEALTH asker's own follow-up is not an answer", 'HEALTH awaited reply at 29 minutes', 'HEALTH awaited reply at 30 minutes', "HEALTH awaited reply needs this session's handle", 'HEALTH failed and acked is not read again', 'HEALTH failed at start alerts', 'HEALTH failed that sent its own worker_done is not an alert', 'HEALTH failed with a succeeded worker_done still alerts', "HEALTH failed with another dispatch's worker_done still alerts", 'HEALTH full inbox window is noted', 'HEALTH host dispatch with no projection is skipped', 'HEALTH host dispatch with projection null is skipped', 'HEALTH many finished rows over several pages are not capped', 'HEALTH more than 10 pages', 'HEALTH no Run named and none held here', 'HEALTH question that threads on itself is unanswered', 'HEALTH quiet Run is ok', 'HEALTH server row with a projection is still read', "HEALTH this pane's Run held elsewhere is not checked", "HEALTH this pane's Run held here is checked", 'HEALTH worker question at 10 minutes', 'HEALTH worker question at 9 minutes'}),
    ('health-inbox-shape-loose', 'if any(not isinstance(x, dict)\n       or not all(k in x for k in ("id", "type", "from_handle", "to_handle", "thread_id", "created_at"))\n       for x in rows):', 'if False:',
     {'HEALTH inbox in the 1.4.246 short shape', 'HEALTH inbox row missing created_at', 'HEALTH inbox row that is not an object'}),
    # L60: a dispatch that failed with no worker_done.
    ('health-failed-off', '    elif o == "failed":', '    elif False:', {'HEALTH a row live on page 1 and failed on page 2 alerts', 'HEALTH failed at start alerts', 'HEALTH failed of another dispatch id in worker-show', 'HEALTH failed row on a later page alerts', 'HEALTH failed whose worker-show fails still alerts', 'HEALTH failed with a prose last failure shows none of it', 'HEALTH failed with a succeeded worker_done still alerts', 'HEALTH failed with an exited agent alerts', 'HEALTH failed with an odd stage', "HEALTH failed with another dispatch's worker_done still alerts", 'HEALTH failed with shell text in its last failure'}),
    ('health-failed-reported', 'if k in acked or did in reported:', 'if k in acked:', {'HEALTH failed that sent its own worker_done is not an alert'}),
    ('health-failed-acked-read', '[ ! -e "$cepa_h_acked/failed:$cepa_h_fd" ] || continue', ':', {'HEALTH failed and acked is not read again'}),
    ('health-failed-lf-any', 're.fullmatch(r"[a-z_]{1,40}", lf) or lf in LAST_FAILURES', 're.fullmatch(r"[^\\n]{1,120}", lf)', {'HEALTH failed with a prose last failure shows none of it', 'HEALTH failed with shell text in its last failure'}),
    ('health-failed-stage-any', 'det if isinstance(det, str) and re.fullmatch(r"[a-z_]{1,40}", det) else "unknown"', 'det if isinstance(det, str) else "unknown"', {'HEALTH failed with an odd stage'}),
    ('health-failed-id-any', '        if not isinstance(disp, dict) or disp.get("id") != did:', '        if not isinstance(disp, dict):', {'HEALTH failed of another dispatch id in worker-show'}),
    ('health-failed-ack-key', '|(exited|failed|long|question|awaited):', '|(exited|long|question|awaited):', {'HEALTH failed is ackable'}),
    ('health-failed-reported-any-outcome', ' and pl.get("outcome") == "failed":', ':', {'HEALTH failed with a succeeded worker_done still alerts'}),
    # L89 g: a host dispatch (a server object, no projection) is skipped.
    ('health-host-row-read', 'if isinstance(sv, dict) and isinstance(sv.get("environmentId"), str) and sv["environmentId"] != "local" \\', 'if False \\', {'HEALTH host dispatch with no projection is skipped', 'HEALTH host dispatch with projection null is skipped'}),
    ('health-host-row-any-id', '            and isinstance(w.get("dispatchId"), str) and re.fullmatch(r"ctx_[0-9a-f]{6,32}", w["dispatchId"]):', '            :', {'HEALTH host dispatch row with a bad id is unreadable'}),
    ('health-host-row-no-server', 'if isinstance(sv, dict) and isinstance(sv.get("environmentId"), str) and sv["environmentId"] != "local" \\', 'if True \\', {'HEALTH host dispatch row with no environment id is unreadable', 'HEALTH local server row with no projection is unreadable', 'HEALTH worker-list in the 1.4.246 short shape', 'HEALTH worker-list row with no projection'}),
    ('health-host-row-any-server', 'isinstance(sv.get("environmentId"), str) and sv["environmentId"] != "local"', 'sv.get("environmentId") != "local"', {'HEALTH host dispatch row with no environment id is unreadable'}),
    ('health-host-row-local', ' and sv["environmentId"] != "local" \\', ' \\', {'HEALTH local server row with no projection is unreadable'}),
    ('health-host-row-projection-unchecked', '            and w.get("projection") is None \\\n', '', {'HEALTH server row with a projection is still read'}),
    # L97, L98, L103 C1: the new reasons and address forms are shown.
    ('health-bot-target-unknown', 'r"|bot:[A-Za-z0-9_][A-Za-z0-9._-]{0,104}|orca_session_id:[0-9a-f-]{36})")', 'r"|orca_session_id:[0-9a-f-]{36})")', {'HEALTH alert file with a bot target is reported'}),
    ('health-chat-address-unknown', 'r"|bot:[A-Za-z0-9_][A-Za-z0-9._-]{0,104}|orca_session_id:[0-9a-f-]{36})")', 'r"|bot:[A-Za-z0-9_][A-Za-z0-9._-]{0,104})")', {'HEALTH send_unproven reads its reason (chat inbox)'}),
    ('health-thread-reason-unknown', 'r", and the re-read does not show " + MID + r" in that thread"', 'r", and the re-read shows nothing"', {'HEALTH send_unproven reads its reason (thread)'}),
    ('health-bot-chat-reason-unknown', '{36}, which is not an open chat of bot:', '{36}, which is not a chat of bot:', {'HEALTH send_unproven reads its reason (closed chat)'}),
    ('health-bot-chats-reason-unknown', '{0,104} could not be read, so " + MID + r" is unconfirmed",', '{0,104} was not read",', {'HEALTH send_unproven reads its reason (chats)'}),
]
# REBIND (punch-list L45): mutants of orca-rebind.sh, run by the health legs.
REBIND_MUTANTS = [
    ('rebind-no-live-check', 'case "$cepa_rb_live" in\n  gone) ;;', 'case gone in\n  gone) ;;', {'REBIND short terminal list asks', 'REBIND omitted id with shell text asks as partial', 'REBIND live holder on this server wins over an omitted host', 'REBIND terminal list not ok asks', 'REBIND list with no host scope asks', 'REBIND holder moved to a live terminal between reads asks', 'REBIND six omitted hosts ask as partial', 'REBIND truncated terminal list asks', 'REBIND live holder is never taken', 'REBIND confirm does not lift the live check', 'REBIND omitted host holds the holder'}),
    ('rebind-truncated-ignored', ' or r.get("truncated") is not False', '', {'REBIND WSL host list partial asks', "REBIND host's own list truncated asks", 'REBIND truncated terminal list asks'}),
    ('rebind-total-ignored', ' or r.get("totalCount") != len(t)', '', {'REBIND short terminal list asks'}),
    ('rebind-run-unchecked', '[ -z "$cepa_rb_want" ] || [[ $cepa_rb_want =~ ^run_[A-Za-z0-9_]{1,64}$ ]] \\', '[ -z "$cepa_rb_want" ] || true \\', {'REBINDREF run with a dash', 'REBINDREF run with a flag', 'REBINDREF run with shell text', 'RULE2BLOCK shell text in the run line runs nothing'}),
    ('rebind-me-unchecked', '[[ $cepa_rb_me =~ ^term_[0-9a-f-]{36}$ ]] || refuse', 'true || refuse', {'REBINDREF bad terminal handle', 'REBINDREF no terminal handle'}),
    ('rebind-run-use-retried', 'cepa_rb_orca "$cepa_rb_tmp/use.json" 0', 'cepa_rb_orca "$cepa_rb_tmp/use.json" 1', {'REBIND run-use is not retried on vsock'}),
    ('rebind-no-vsock-retry', '  for try in 1 2; do\n    timeout', '  for try in 1; do\n    timeout', {'REBIND run-current vsock once'}),
    ('rebind-extra-field', 'case "$cepa_rb_k" in cli|run|confirm) ;;', 'case "$cepa_rb_k" in cli|run|confirm|from) ;;', {'REBINDREF unknown field'}),
    ('rebind-show-id-unchecked', '[ "$cepa_rb_s_id" = "$cepa_rb_run" ] || failed "run-show did not return $cepa_rb_run"\n', '', {'REBIND run-show of another Run fails'}),
    ('rebind-handle-unchecked', 'elif not (isinstance(h, str) and re.fullmatch(r"term_[0-9a-f-]{36}", h)):\n    sys.exit(1)\n', '', {'REBIND run-current bad shape fails', 'REBIND run-show empty holder fails', 'REBIND run-show dash holder fails'}),
    ('rebind-rest-ignored', '[ -z "${cepa_rb_rest//[[:space:]]/}" ] || refuse', 'true || refuse', {'REBINDREF line after fields'}),
    ('rebind-host-scope-ignored', 'print("omitted " + " ".join(om) if om else "gone")', 'print("gone")', {'REBIND environment id starting with a dash asks', 'REBIND environment list fails asks, naming the host', 'REBIND host list that leaves out hosts of its own asks', 'REBIND host list with no hostIds asks', "REBIND host's own list truncated asks", "REBIND offline host's own list fails asks, naming it", 'REBIND omitted WSL host is read once', 'REBIND omitted host holds the holder', 'REBIND omitted host read on its server, holder absent', 'REBIND omitted host with no environment asks, naming it', 'REBIND two omitted hosts each read'}),
    ('rebind-dashed-id-refused', 'if not (isinstance(i, str) and re.fullmatch(r"run_[A-Za-z0-9_-]{1,64}", i)):', 'if not (isinstance(i, str) and re.fullmatch(r"run_[A-Za-z0-9_]{1,64}", i)):', {'REBIND no run field reports a dashed Run id'}),
    ('rebind-show-bound-here-ignored', 'if [ "$cepa_rb_old" = "$cepa_rb_me" ]; then', 'if false; then', {'REBIND holder moved here between reads is ok', 'REBIND run-show names this terminal'}),
    # L46 (#113 findings 11, 12).
    ('rebind-no-generation-check', 'if [ "$cepa_rb_gen_after" = "$cepa_rb_gen_want" ]; then', 'if true; then', {'REBIND generation unchanged fails', 'REBIND confirmed null holder still null one generation up fails', 'REBIND run-show re-read names another terminal fails', 'REBIND run-use is not retried on vsock', 'REBIND confirmed null holder that run-use left null fails', 'REBIND run-show re-read of another Run fails', 'REBIND confirmed null holder generation rose by two fails', 'REBIND generation rose by two fails'}),
    ('rebind-confirm-unchecked', '[ -z "$cepa_rb_confirm" ] || [ "$cepa_rb_confirm" = "$cepa_rb_want" ] \\', '[ -z "$cepa_rb_confirm" ] || true \\', {'REBINDREF confirm of another Run', 'REBINDREF confirm without run'}),
    # PR #116 review.
    ('rebind-no-recheck', 'if [ "$cepa_rb_recheck" != "$cepa_rb_shown" ]; then', 'if false; then', {'REBIND confirmed null holder whose generation moved asks', 'REBIND confirmed null holder that moved before run-use asks', 'REBIND Run moved before run-use asks'}),
    ('rebind-stale-holder', '[ "$cepa_rb_s_id" = "$cepa_rb_run" ] || failed "run-show did not return $cepa_rb_run"\n',
     '[ "$cepa_rb_s_id" = "$cepa_rb_run" ] || failed "run-show did not return $cepa_rb_run"\n[ -z "$cepa_rb_cur_h" ] || cepa_rb_old=$cepa_rb_cur_h\n', {'REBIND confirmed null holder while run-current reports another Run re-binds', 'REBIND confirmed named Run re-binds', 'REBIND holder moved to a live terminal between reads asks', 'REBIND run-current holder and a null run-show disagree asks', 'REBIND run-show names this terminal', 'REBIND holder moved here between reads is ok'}),
    ('rebind-gen-floor-dropped', 'not 0 <= g < 10 ** 9', 'not g < 10 ** 9', {'REBIND negative generation fails'}),
    ('rebind-cli-path-unchecked', '/*) [ "$cepa_rb_cli" = "${ORCA_CLI_COMMAND:-}" ] || refuse "a cli path must equal ORCA_CLI_COMMAND" ;;', '/*) ;;', {'REBINDREF cli path other than ORCA_CLI_COMMAND', 'REBINDREF cli path with no ORCA_CLI_COMMAND'}),
    ('rebind-cli-relative-allowed', '  */*) refuse "a cli path must be absolute and equal ORCA_CLI_COMMAND" ;;\n', '', {'REBINDREF relative cli path'}),
    ('rebind-held-message-dropped', 'if [ "$cepa_rb_a_id" = "$cepa_rb_run" ] && [ "$cepa_rb_a_h" = "$cepa_rb_me" ]; then', 'if false; then', {'REBIND confirmed null holder generation rose by two fails', 'REBIND generation rose by two fails', 'REBIND generation unchanged fails'}),
    ('rebind-show-gen-unchecked', 'if type(g) is not int or not 0 <= g < 10 ** 9:\n    sys.exit(1)\n', '', {'REBIND huge generation fails', 'REBIND negative generation fails', 'REBIND run-show boolean generation fails'}),
    # L46 (operator's choice in #116): a Run held elsewhere needs a run: line.
    ('rebind-runcurrent-fail-ignored', '--json --full || failed "run-current failed"', '--json --full || true', {'REBIND run-current fails'}),
    ('rebind-norun-takes', 'if [ -z "$cepa_rb_want" ]; then', 'if false; then', {'REBIND no run field reports a dashed Run id', "RULE2BLOCK without a run line never takes run-current's Run", 'REBIND no run field and a null-holder current Run asks', "REBIND no run field never takes run-current's Run", 'REBIND no run field and current Run bound here', 'REBIND no run field and no current Run', 'REBIND empty run field is no Run'}),
    ('rebind-norun-bound-here-ignored', '  if [ "$cepa_rb_cur_h" = "$cepa_rb_me" ]; then', '  if false; then', {'REBIND no run field and current Run bound here'}),
    ('rebind-no-agree-check', 'if [ "$cepa_rb_cur_id" != "$cepa_rb_run" ] && [ "$cepa_rb_confirm" != "$cepa_rb_run" ]; then', 'if false; then', {'REBIND bound here with another run field asks', 'REBIND gone named Run while run-current reports another asks', 'REBIND named Run that run-current does not report asks', 'REBIND named Run with no current Run asks', 'REBIND run-show error before the ownership ask still asks', 'REBIND run_not_found with ok true is not retired', 'RULE2BLOCK with a run line asks when run-current does not agree'}),
    ('rebind-confirm-ignored', ' && [ "$cepa_rb_confirm" != "$cepa_rb_run" ]; then', '; then', {'REBIND confirmed null holder while run-current reports another Run re-binds', 'RULE2BLOCK with run and confirm lines re-binds', 'REBIND confirmed named Run re-binds', 'REBIND confirm does not lift the live check', 'REBIND confirmed null holder re-binds', 'REBIND confirmed null holder still null one generation up fails', 'REBIND confirmed null holder whose generation moved asks', 'REBIND confirmed null holder that moved before run-use asks', 'REBIND confirmed null holder that run-use left null fails', 'REBIND confirmed null holder generation rose by two fails'}),
    # L72: Orca 1.4.246 answers a read without --full in its short shape.
    ('rebind-runcur-short', 'orchestration run-current --json --full ||', 'orchestration run-current --json ||', {'REBIND failed recheck fails', 'REBIND WSL host holds the holder', 'REBIND no run field reports a dashed Run id', 'REBIND WSL host id of a bad shape asks', 'REBIND confirmed null holder that moved before run-use asks', 'REBIND no run field and current Run bound here', 'REBIND six WSL hosts ask', 'REBIND six omitted hosts ask as partial', 'REBIND generation unchanged fails', 'REBIND run-show with no holder key fails', 'REBIND environment id starting with a dash asks', 'REBIND run_not_found with ok true is not retired', 'REBIND omitted host with no environment asks, naming it', 'REBIND truncated terminal list asks', 'REBIND run-show fails', 'RULE2BLOCK with a run line asks when run-current does not agree', 'REBIND WSL host list fails asks', 'REBIND run-show re-read of another Run fails', 'REBIND environment list fails asks, naming the host', 'REBIND confirmed named Run re-binds', 'REBIND short terminal list asks', "RULE2BLOCK without a run line never takes run-current's Run", 'REBIND two omitted hosts each read', 'REBIND run-show of another Run fails', 'REBIND negative generation fails', 'REBIND run-current in the 1.4.246 short shape fails', "REBIND no run field never takes run-current's Run", 'REBIND dead holder is re-bound', 'REBIND confirmed null holder re-binds', 'REBIND confirmed null holder whose generation moved asks', 'REBIND failed run-show re-read fails', 'REBIND run-show without a generation fails', 'REBIND run-current bad shape fails', 'REBIND confirmed null holder that run-use left null fails', 'REBIND generation rose by two fails', "REBIND offline host's own list fails asks, naming it", 'REBIND confirmed null holder still null one generation up fails', 'REBIND omitted id with shell text asks as partial', 'REBIND named Run with no current Run asks', 'REBIND terminal list fails asks', 'REBIND run-show boolean generation fails', 'REBIND run-show with removedWork re-binds', 'REBIND run-current fails', 'REBIND terminal list not ok asks', 'REBIND omitted host read on its server, holder absent', 'REBIND run-show error before the ownership ask still asks', 'REBIND host list that leaves out hosts of its own asks', 'REBIND run-show names this terminal', 'REBIND holder moved to a live terminal between reads asks', 'REBIND gone named Run while run-current reports another asks', 'REBIND environment list fails asks', 'REBIND huge generation fails', 'REBIND retired Run that run-current does not report says so', 'REBIND WSL host read on its server, holder absent', 'REBIND list with no host scope asks', 'REBIND holder moved here between reads is ok', "REBIND host's own list truncated asks", 'REBIND confirmed null holder while run-current reports another Run re-binds', 'REBIND omitted WSL host is read once', 'REBIND run-current vsock once', 'REBIND null holder in the measured shape without confirm asks', 'REBIND confirmed null holder in the measured shape re-binds', 'REBIND bound here with another run field asks', 'REBIND empty run field is no Run', 'REBIND run-show in the 1.4.246 short shape fails', 'REBIND run-show empty holder fails', 'REBIND confirmed null holder generation rose by two fails', 'REBIND Run moved before run-use asks', 'RULE2BLOCK with run and confirm lines re-binds', 'REBIND environment list not ok asks', 'REBIND confirm does not lift the live check', 'REBIND live holder on this server wins over an omitted host', 'REBIND CR and trailing spaces are dropped', 'RULE2BLOCK with a run line re-binds the named Run', 'REBIND null holder without confirm asks', 'REBIND run-show dash holder fails', 'REBIND run-current holder and a null run-show disagree asks', 'REBIND run-use is not retried on vsock', 'REBIND run-show error other than run_not_found fails', 'REBIND confirmed retired Run says so', 'REBIND cli path equal to ORCA_CLI_COMMAND re-binds', 'REBIND host list with no hostIds asks', 'REBIND retired Run says so', 'REBIND run-show re-read bad shape fails', 'REBIND WSL host list partial asks', 'REBIND failed run-use that took effect counts', 'REBIND no run field and a null-holder current Run asks', 'REBIND run-show re-read names another terminal fails', 'REBIND live holder is never taken', 'REBIND no run field and no current Run', 'REBIND omitted host holds the holder', 'REBIND named Run that run-current does not report asks'}),
    ('rebind-runshow-short', 'run-show --id "$cepa_rb_run" --json --full \\\n  || { ! cepa_rb_gone_run', 'run-show --id "$cepa_rb_run" --json \\\n  || { ! cepa_rb_gone_run', {'RULE2BLOCK with run and confirm lines re-binds', 'REBIND environment list not ok asks', 'REBIND confirm does not lift the live check', 'REBIND failed recheck fails', 'REBIND live holder on this server wins over an omitted host', 'REBIND WSL host holds the holder', 'REBIND CR and trailing spaces are dropped', 'REBIND holder moved to a live terminal between reads asks', 'REBIND negative generation fails', 'REBIND null holder without confirm asks', 'REBIND WSL host id of a bad shape asks', 'REBIND confirmed null holder that moved before run-use asks', 'REBIND run-show dash holder fails', 'REBIND run-current holder and a null run-show disagree asks', 'REBIND run-use is not retried on vsock', 'RULE2BLOCK with a run line re-binds the named Run', 'REBIND run-show error other than run_not_found fails', 'REBIND six WSL hosts ask', 'REBIND confirmed retired Run says so', 'REBIND six omitted hosts ask as partial', 'REBIND environment list fails asks', 'REBIND cli path equal to ORCA_CLI_COMMAND re-binds', 'REBIND dead holder is re-bound', 'REBIND generation unchanged fails', 'REBIND host list with no hostIds asks', 'REBIND retired Run says so', 'REBIND confirmed null holder re-binds', 'REBIND huge generation fails', 'REBIND confirmed null holder whose generation moved asks', 'REBIND failed run-show re-read fails', 'REBIND run-show with no holder key fails', 'REBIND run-show without a generation fails', 'REBIND confirmed null holder that run-use left null fails', 'REBIND environment id starting with a dash asks', 'REBIND WSL host read on its server, holder absent', 'REBIND list with no host scope asks', 'REBIND generation rose by two fails', 'REBIND holder moved here between reads is ok', "REBIND host's own list truncated asks", 'REBIND confirmed null holder while run-current reports another Run re-binds', "REBIND offline host's own list fails asks, naming it", 'REBIND run-show re-read bad shape fails', 'REBIND omitted host with no environment asks, naming it', 'REBIND confirmed null holder still null one generation up fails', 'REBIND omitted WSL host is read once', 'REBIND run-current vsock once', 'REBIND run-show fails', 'REBIND truncated terminal list asks', 'REBIND WSL host list fails asks', 'REBIND omitted id with shell text asks as partial', 'REBIND null holder in the measured shape without confirm asks', 'REBIND WSL host list partial asks', 'REBIND failed run-use that took effect counts', 'REBIND confirmed null holder in the measured shape re-binds', 'REBIND run-show re-read of another Run fails', 'REBIND terminal list fails asks', 'REBIND run-show boolean generation fails', 'REBIND environment list fails asks, naming the host', 'REBIND confirmed named Run re-binds', 'REBIND run-show re-read names another terminal fails', 'REBIND short terminal list asks', 'REBIND live holder is never taken', 'REBIND omitted host holds the holder', 'REBIND run-show in the 1.4.246 short shape fails', 'REBIND run-show with removedWork re-binds', 'REBIND terminal list not ok asks', 'REBIND run-show empty holder fails', 'REBIND omitted host read on its server, holder absent', 'REBIND host list that leaves out hosts of its own asks', 'REBIND run-show names this terminal', 'REBIND run-show of another Run fails', 'REBIND confirmed null holder generation rose by two fails', 'REBIND two omitted hosts each read', 'REBIND Run moved before run-use asks'}),
    ('rebind-recheck-short', 'run-show --id "$cepa_rb_run" --json --full \\\n  || failed "run-show for $cepa_rb_run failed on the recheck', 'run-show --id "$cepa_rb_run" --json \\\n  || failed "run-show for $cepa_rb_run failed on the recheck', {'RULE2BLOCK with run and confirm lines re-binds', 'REBIND failed recheck fails', 'REBIND CR and trailing spaces are dropped', 'RULE2BLOCK with a run line re-binds the named Run', 'REBIND confirmed null holder that moved before run-use asks', 'REBIND run-use is not retried on vsock', 'REBIND cli path equal to ORCA_CLI_COMMAND re-binds', 'REBIND dead holder is re-bound', 'REBIND generation unchanged fails', 'REBIND confirmed null holder re-binds', 'REBIND confirmed null holder whose generation moved asks', 'REBIND failed run-show re-read fails', 'REBIND confirmed null holder that run-use left null fails', 'REBIND WSL host read on its server, holder absent', 'REBIND generation rose by two fails', 'REBIND confirmed null holder while run-current reports another Run re-binds', 'REBIND run-show re-read bad shape fails', 'REBIND confirmed null holder still null one generation up fails', 'REBIND omitted WSL host is read once', 'REBIND run-current vsock once', 'REBIND failed run-use that took effect counts', 'REBIND confirmed null holder in the measured shape re-binds', 'REBIND run-show re-read of another Run fails', 'REBIND confirmed named Run re-binds', 'REBIND run-show re-read names another terminal fails', 'REBIND run-show with removedWork re-binds', 'REBIND omitted host read on its server, holder absent', 'REBIND confirmed null holder generation rose by two fails', 'REBIND two omitted hosts each read', 'REBIND Run moved before run-use asks'}),
    ('rebind-after-short', 'after-show.json" 1 orchestration run-show --id "$cepa_rb_run" --json --full', 'after-show.json" 1 orchestration run-show --id "$cepa_rb_run" --json', {'RULE2BLOCK with run and confirm lines re-binds', 'REBIND CR and trailing spaces are dropped', 'RULE2BLOCK with a run line re-binds the named Run', 'REBIND run-use is not retried on vsock', 'REBIND cli path equal to ORCA_CLI_COMMAND re-binds', 'REBIND dead holder is re-bound', 'REBIND generation unchanged fails', 'REBIND confirmed null holder re-binds', 'REBIND failed run-show re-read fails', 'REBIND confirmed null holder that run-use left null fails', 'REBIND WSL host read on its server, holder absent', 'REBIND generation rose by two fails', 'REBIND confirmed null holder while run-current reports another Run re-binds', 'REBIND run-show re-read bad shape fails', 'REBIND confirmed null holder still null one generation up fails', 'REBIND omitted WSL host is read once', 'REBIND run-current vsock once', 'REBIND failed run-use that took effect counts', 'REBIND confirmed null holder in the measured shape re-binds', 'REBIND run-show re-read of another Run fails', 'REBIND confirmed named Run re-binds', 'REBIND run-show re-read names another terminal fails', 'REBIND run-show with removedWork re-binds', 'REBIND omitted host read on its server, holder absent', 'REBIND confirmed null holder generation rose by two fails', 'REBIND two omitted hosts each read'}),
    # L85: a host Orca left out of terminal list is read on its own server.
    ('rebind-host-read-off', 'if [[ $cepa_rb_live == omitted\\ * ]]; then', 'if false; then', {'REBIND environment id starting with a dash asks', 'REBIND environment list fails asks, naming the host', 'REBIND host list that leaves out hosts of its own asks', 'REBIND host list with no hostIds asks', "REBIND host's own list truncated asks", "REBIND offline host's own list fails asks, naming it", 'REBIND omitted WSL host is read once', 'REBIND omitted host holds the holder', 'REBIND omitted host read on its server, holder absent', 'REBIND omitted host with no environment asks, naming it', 'REBIND two omitted hosts each read'}),
    ('rebind-host-live-ignored', '      live) cepa_rb_live=live; break ;;', '      live) ;;', {'REBIND omitted host holds the holder'}),
    ('rebind-host-map-by-name', '(e.get("runtimeId") == want or e.get("id") == want)', '(e.get("name") == want)', {'REBIND host list that leaves out hosts of its own asks', 'REBIND host list with no hostIds asks', "REBIND host's own list truncated asks", "REBIND offline host's own list fails asks, naming it", 'REBIND omitted WSL host is read once', 'REBIND omitted host holds the holder', 'REBIND omitted host read on its server, holder absent', 'REBIND two omitted hosts each read'}),
    ('rebind-host-scope', 'if sys.argv[3] == "host":', 'if False:', {'REBIND host list with no hostIds asks'}),
    ('rebind-host-id-any', 'all(isinstance(x, str) and re.fullmatch(r"[A-Za-z0-9:%._-]{1,100}", x) for x in om)', 'all(isinstance(x, str) for x in om)', {'REBIND omitted id with shell text asks as partial'}),
    ('rebind-host-own-scope', 'if not isinstance(hs, dict) or not hs.get("hostIds") or hs.get("omittedHostIds") != []:', 'if not isinstance(hs, dict):', {'REBIND host list that leaves out hosts of its own asks', 'REBIND host list with no hostIds asks'}),
    ('rebind-env-dash', 'if len(hit) != 1 or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._:-]{0,99}", hit[0]):', 'if len(hit) != 1 or not re.fullmatch(r"[A-Za-z0-9._:-]{1,100}", hit[0]):', {'REBIND environment id starting with a dash asks'}),
    # L92: a Run Orca deleted reads run_not_found, and is retired.
    ('rebind-retired-pre-ask-off', '    || ! cepa_rb_gone_run "$cepa_rb_tmp/show.json" || retired\n', '    || :\n', {'REBIND retired Run that run-current does not report says so'}),
    ('rebind-retired-pre-ask-any-cur', '  if [ -z "$cepa_rb_cur_id" ]; then\n    cepa_rb_orca "$cepa_rb_tmp/show.json"', '  if true; then\n    cepa_rb_orca "$cepa_rb_tmp/show.json"', {'REBIND bound here with another run field asks', 'REBIND gone named Run while run-current reports another asks', 'REBIND named Run that run-current does not report asks'}),
    ('rebind-retired-main-off', '|| { ! cepa_rb_gone_run "$cepa_rb_tmp/show.json" || retired; failed', '|| { failed', {'REBIND confirmed retired Run says so', 'REBIND retired Run says so'}),
    ('rebind-gone-any-code', 'e.get("code") == "run_not_found"', 'True', {'REBIND run-show error before the ownership ask still asks', 'REBIND run-show error other than run_not_found fails'}),
    ('rebind-gone-ok-any', 'if isinstance(d, dict) and d.get("ok") is False else None', 'if isinstance(d, dict) else None', {'REBIND run_not_found with ok true is not retired'}),
    # L89 d: each WSL host is read on its own server.
    ('rebind-wsl-off', 'for cepa_rb_env in $cepa_rb_wsl; do', 'for cepa_rb_env in ; do', {'REBIND WSL host holds the holder', 'REBIND WSL host list fails asks', 'REBIND WSL host list partial asks', 'REBIND WSL host read on its server, holder absent'}),
    ('rebind-wsl-live-ignored', '    live) ask "$cepa_rb_run is held by $cepa_rb_old, which is still open on the Orca WSL host', '    xlive) ask "$cepa_rb_run is held by $cepa_rb_old, which is still open on the Orca WSL host', {'REBIND WSL host holds the holder'}),
    ('rebind-wsl-kind-any', 'od.get("kind") == "wsl"', 'True', {'REBIND cli path equal to ORCA_CLI_COMMAND re-binds', 'REBIND omitted WSL host is read once', 'RULE2BLOCK with a run line re-binds the named Run', 'REBIND failed recheck fails', 'REBIND CR and trailing spaces are dropped', 'REBIND WSL host list partial asks', 'REBIND confirmed named Run re-binds', 'REBIND Run moved before run-use asks', 'REBIND failed run-show re-read fails', 'REBIND generation unchanged fails', 'REBIND run-show re-read bad shape fails', 'REBIND run-show with removedWork re-binds', 'REBIND WSL host holds the holder', 'REBIND dead holder is re-bound', 'REBIND run-show re-read names another terminal fails', 'REBIND run-use is not retried on vsock', 'REBIND failed run-use that took effect counts', 'REBIND run-current vsock once', 'REBIND generation rose by two fails', 'REBIND run-show re-read of another Run fails', 'REBIND WSL host read on its server, holder absent', 'REBIND WSL host list fails asks', 'RULE2BLOCK with run and confirm lines re-binds'}),
    ('rebind-wsl-envs-fail-open', 'environment list --json \\\n  || ask "environment list failed', 'environment list --json \\\n  || : "environment list failed', {'REBIND environment list fails asks'}),
    ('rebind-wsl-read-twice', '[[ $cepa_rb_envs_read != *" $cepa_rb_env "* ]] || continue', ':', {'REBIND omitted WSL host is read once'}),
    ('rebind-wsl-cap', 'if len(out) > 5:\n    sys.exit(1)\nprint(" ".join(out))', 'print(" ".join(out))', {'REBIND six WSL hosts ask'}),
    ('rebind-wsl-id-any', 'if not (isinstance(i, str) and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._:-]{0,99}", i)):', 'if not isinstance(i, str):', {'REBIND WSL host id of a bad shape asks'}),
    # L99 / L103 C3: a null holder is holder unknown, never free.
    ('rebind-null-holder-refused', 'if h is None:\n    h = "-"\nelif not', 'if False:\n    h = "-"\nelif not', {'REBIND confirmed null holder while run-current reports another Run re-binds', 'REBIND confirmed null holder still null one generation up fails', 'REBIND confirmed null holder re-binds', 'REBIND null holder without confirm asks', 'REBIND confirmed null holder whose generation moved asks', 'REBIND confirmed null holder that moved before run-use asks', 'REBIND run-current holder and a null run-show disagree asks', 'REBIND null holder in the measured shape without confirm asks', 'REBIND confirmed null holder that run-use left null fails', 'REBIND no run field and a null-holder current Run asks', 'REBIND confirmed null holder in the measured shape re-binds', 'REBIND confirmed null holder generation rose by two fails'}),
    ('rebind-null-confirm-ignored', 'if [ "$cepa_rb_old" = - ] && [ "$cepa_rb_run" != "$cepa_rb_confirm" ]; then', 'if false; then', {'REBIND null holder without confirm asks', 'REBIND null holder in the measured shape without confirm asks'}),
    ('rebind-null-live-check-on', 'if [ "$cepa_rb_old" != - ]; then  # the liveness', 'if true; then  # the liveness', {'REBIND confirmed null holder while run-current reports another Run re-binds', 'REBIND confirmed null holder still null one generation up fails', 'REBIND confirmed null holder re-binds', 'REBIND confirmed null holder whose generation moved asks', 'REBIND confirmed null holder that moved before run-use asks', 'REBIND confirmed null holder that run-use left null fails', 'REBIND confirmed null holder in the measured shape re-binds', 'REBIND confirmed null holder generation rose by two fails'}),
    ('rebind-norun-null-ask-dropped', '  [ "$cepa_rb_cur_h" != - ] || ask', '  true || ask', {'REBIND no run field and a null-holder current Run asks'}),
    ('rebind-done-null-label', '[ "$cepa_rb_old" != - ] || cepa_rb_old="no recorded holder"', ':', {'REBIND confirmed null holder while run-current reports another Run re-binds', 'REBIND confirmed null holder in the measured shape re-binds', 'REBIND confirmed null holder re-binds'}),
    # PR #148 review.
    ('rebind-null-falsy', 'if h is None:\n    h = "-"\nelif not', 'if not h:\n    h = "-"\nelif not', {'REBIND run-show empty holder fails'}),
    ('rebind-null-disagree-off', '[ "$cepa_rb_cur_id" = "$cepa_rb_run" ] && [ "$cepa_rb_cur_h" != - ]; then', 'false; then', {'REBIND run-current holder and a null run-show disagree asks'}),
    ('rebind-null-unmoved-off', 'if [ "$cepa_rb_old" = - ] && [ "$cepa_rb_gen_after" = "$cepa_rb_shown" ]; then', 'if false; then', {'REBIND confirmed null holder that run-use left null fails'}),
]
# RULE2BLOCK, HEALTHBLOCK (punch-list L46): mutants of SKILL.md's rule 2 and
# rule 8 blocks, run by the health legs against the shipped scripts. Rule 6's
# rename block is check-orca-detection-controls.sh's.
SKILLH_MUTANTS = [
    ('rule2-unquoted-delimiter', 'orca-rebind.sh" <<\'CEPA_FIELDS\' || true', 'orca-rebind.sh" <<CEPA_FIELDS || true',
     {'RULE2BLOCK heredoc holds the cli, run and confirm field lines', 'RULE2BLOCK shell text in the run line runs nothing'}),
    ('rule2-no-script-check', 'if [ -z "${CEPA_ROOT:-}" ] || [ ! -f "$CEPA_ROOT/scripts/orca-rebind.sh" ]; then',
     'if [ -z "${CEPA_ROOT:-}" ]; then', {'RULE2BLOCK with the script absent is skipped'}),
    ('rule2-no-confirm-line', "     confirm: <the same id, only after the operator's answer below; else leave this line out>\n", '', {'RULE2BLOCK heredoc holds the cli, run and confirm field lines', 'RULE2BLOCK shell text in the run line runs nothing', 'RULE2BLOCK with a run line asks when run-current does not agree', 'RULE2BLOCK with a run line re-binds the named Run', 'RULE2BLOCK with run and confirm lines re-binds', "RULE2BLOCK without a run line never takes run-current's Run"}),
    ('rule2-no-or-true', 'orca-rebind.sh" <<\'CEPA_FIELDS\' || true', 'orca-rebind.sh" <<\'CEPA_FIELDS\'', {'RULE2BLOCK shell text in the run line runs nothing', 'RULE2BLOCK with a run line asks when run-current does not agree', "RULE2BLOCK without a run line never takes run-current's Run"}),
    ('health-no-or-true', '"${cepa_health_argv[@]}" || true', '"${cepa_health_argv[@]}"', {'HEALTHBLOCK a cli line with spaces stays one argument', 'HEALTHBLOCK ack form passes each key as one argument', 'HEALTHBLOCK cli with a command substitution runs nothing', 'HEALTHBLOCK passes the named Run as its own argument'}),
    ('health-no-script-check', 'if [ -z "${CEPA_ROOT:-}" ] || [ ! -f "$CEPA_ROOT/scripts/orca-health.sh" ]; then',
     'if [ -z "${CEPA_ROOT:-}" ]; then', {'HEALTHBLOCK with the script absent is skipped'}),
    ('health-block-unquoted-heredoc', "cepa_health_args=$(cat <<'CEPA_ARGS'", 'cepa_health_args=$(cat <<CEPA_ARGS', {'HEALTHBLOCK ack form passes each key as one argument', 'HEALTHBLOCK cli with a command substitution runs nothing', 'HEALTHBLOCK passes the named Run as its own argument'}),
    ('health-block-argv-unquoted', '"${cepa_health_argv[@]}"', '${cepa_health_argv[@]}', {'HEALTHBLOCK a cli line with spaces stays one argument', 'HEALTHBLOCK ack form passes each key as one argument', 'HEALTHBLOCK passes the named Run as its own argument'}),
]
# BLOCK (punch-list L41): mutants of SKILL.md's rule 1 block, run by the
# send legs against the shipped scripts.
SKILL_MUTANTS = [
    ("block-message-in-heredoc", "     file: <file>\n     CEPA_FIELDS\n",
     "     file: <file>\n\n     <subject, one line>\n     <body>\n     CEPA_FIELDS\n",
     {"BLOCK heredoc holds only field lines", "BLOCK hostile message is sent as text"}),
    ("block-no-file-field", "     session: <session>\n     file: <file>\n", "     session: <session>\n",
     {"BLOCK heredoc holds only field lines", "BLOCK hostile message is sent as text"}),
    ("block-unquoted-delimiter", "orca-send.sh\" <<'CEPA_FIELDS' || true", "orca-send.sh\" <<CEPA_FIELDS || true",
     {'BLOCK hostile message is sent as text', 'BLOCK heredoc holds only field lines'}),
]
SEND = "plugins/cepa/scripts/orca-send.sh"
HEALTH = "plugins/cepa/scripts/orca-health.sh"
REBIND = "plugins/cepa/scripts/orca-rebind.sh"
SKILL = "plugins/cepa/skills/autonomy/SKILL.md"
WORKFLOW = ".github/workflows/residual-integrity.yml"
src = open(SCRIPT, encoding="utf-8").read()
send_src = open(SEND, encoding="utf-8").read()
health_src = open(HEALTH, encoding="utf-8").read()
skill_src = open(SKILL, encoding="utf-8").read()
rebind_src = open(REBIND, encoding="utf-8").read()

# Every mutant, in one list: (part, mutant). A shard runs every Nth one.
ALL = ([("nudge", m) for m in MUTANTS] + [("send", m) for m in SEND_MUTANTS]
       + [("health", m) for m in HEALTH_MUTANTS] + [("skill", m) for m in SKILL_MUTANTS]
       + [("rebind", m) for m in REBIND_MUTANTS] + [("skillh", m) for m in SKILLH_MUTANTS])
spec = os.environ.get("CEPA_NUDGE_CONTROLS_SHARD", "1/1")
sm = re.fullmatch(r"([1-9][0-9]?)/([1-9][0-9]?)", spec)
if not sm or int(sm.group(1)) > int(sm.group(2)):
    print("MISS --shard is %r, want I/N with 1 <= I <= N" % spec)
    raise SystemExit(1)
SHARD, NSHARDS = int(sm.group(1)), int(sm.group(2))

def shard_of(i, n):
    return i % n + 1

passed = failed = 0
TMP = tempfile.mkdtemp(prefix="cepa-nudge-ctl-")

def ok(msg):
    global passed; passed += 1; print("PASS", msg)

def miss(msg):
    global failed; failed += 1; print("MISS", msg)

# Names must be unique: each result line, and each mutant's temp path, is
# keyed by name. Shard membership comes from the list index, not the name.
names = [m[0] for _, m in ALL]
dup = sorted({n for n in names if names.count(n) > 1})
if dup:
    miss("mutant names are not unique: %r" % dup[:3])
else:
    ok("the %d mutant names are unique" % len(names))

def shard_split(n):
    """The mutant names each of shards 1..n runs, as a list of n lists."""
    return [[name for i, name in enumerate(names) if shard_of(i, n) == s] for s in range(1, n + 1)]

def wf_problems(wf):
    """What is wrong with how the workflow text runs the shards; [] if sound.
    Each `--shard I/N` run line must be the plain step form, in its own job,
    with `if: always()` on the step, no job-level `if:`, and no
    continue-on-error, and the lines must be 1/N..N/N, each once. Any other
    non-comment line that names the controls script is a problem, so a block
    scalar (`run: |`) or a quoted form fails closed instead of being skipped."""
    probs, specs = [], []
    body = wf.split("\njobs:\n", 1)[-1]
    for job in re.split(r"(?m)^  (?=[A-Za-z0-9_-]+:[ \t]*$)", body)[1:]:
        jname, lines = job.split(":", 1)[0], job.splitlines()
        hits = []
        for k, line in enumerate(lines):
            if "check-orca-nudge-controls.sh" not in line or line.lstrip().startswith("#"):
                continue
            m = re.fullmatch(r"        run: bash scripts/check-orca-nudge-controls\.sh --shard (\S+)", line)
            if not m:
                probs.append("%s: unrecognized line %r" % (jname, line.strip()))
                continue
            hits.append(m.group(1))
            step = k
            while step > 0 and not lines[step].startswith("      - "):
                step -= 1
            if "        if: always()" not in lines[step:k]:
                probs.append("%s: the --shard %s step has no `if: always()`" % (jname, m.group(1)))
        if not hits:
            continue
        specs += hits
        if len(hits) > 1:
            probs.append("%s: runs %d shards in one job" % (jname, len(hits)))
        if any(re.match(r"    if:", l) for l in lines):
            probs.append("%s: job-level `if:`" % jname)
        if any(re.match(r"\s+continue-on-error:", l) for l in lines):
            probs.append("%s: continue-on-error" % jname)
    want = ["%d/%d" % (i, len(specs)) for i in range(1, len(specs) + 1)]
    if not specs or sorted(specs) != sorted(want):
        probs.append("shards %r, want each of %r once" % (specs, want))
    return probs, len(specs)

# Without this, a deleted, disabled or merged CI job silently drops 1/N of the
# mutants while every remaining job stays green.
wf = open(WORKFLOW, encoding="utf-8").read()
probs, want_n = wf_problems(wf)
if probs:
    miss("%s: %s" % (WORKFLOW, "; ".join(probs)))
else:
    ok("%s runs shards 1/%d to %d/%d, one per job, each once" % (WORKFLOW, want_n, want_n, want_n))
# The shards of that N and of this run's N each partition the mutants, and no
# shard is empty: an empty shard passes on its baseline alone.
for n in sorted({want_n or 1, NSHARDS}):
    parts = shard_split(n)
    if sorted(sum(parts, [])) == sorted(names) and all(parts):
        ok("shards 1/%d to %d/%d partition the %d mutants, none empty" % (n, n, n, len(names)))
    else:
        miss("shards of N=%d: sizes %r, %d of %d names covered"
             % (n, [len(x) for x in parts], len(set(sum(parts, []))), len(names)))
# Planted workflow edits, checked in process: each must make wf_problems red.
J2, J3 = "\n  orca-nudge-2:\n", "\n  orca-nudge-32:\n"
R3 = "        run: bash scripts/check-orca-nudge-controls.sh --shard 32/32\n"
WF_PLANTS = [
    ("two shards in one job", J2, "\n"),
    ("job-level if: false", J3, J3 + "    if: false\n"),
    ("continue-on-error on a job", J3, J3 + "    continue-on-error: true\n"),
    ("shard 32 job deleted", wf[wf.find(J3):] if J3 in wf else J3, "\n"),
    ("shard 32 run line commented out", R3, "        # run: bash scripts/check-orca-nudge-controls.sh --shard 32/32\n"),
    ("shard 32 run line in a block scalar", R3,
     "        run: |\n          bash scripts/check-orca-nudge-controls.sh --shard 32/32\n"),
    ("shard 32 run line with || true", R3, R3[:-1] + " || true\n"),
    ("a quoted mention beside the shard 32 run line", R3,
     R3 + "      - run: echo bash scripts/check-orca-nudge-controls.sh --shard 32/32\n"),
    ("shard 2 step without if: always()",
     "        if: always()\n        run: bash scripts/check-orca-nudge-controls.sh --shard 2/32\n",
     "        run: bash scripts/check-orca-nudge-controls.sh --shard 2/32\n"),
]
for label, old, new in WF_PLANTS:
    if wf.count(old) != 1:
        miss("workflow plant %r: anchor found %d times, want 1" % (label, wf.count(old)))
    elif wf_problems(wf.replace(old, new))[0]:
        ok("workflow plant goes red: %s" % label)
    else:
        miss("workflow plant stays green: %s" % label)

def check(args, legs="all"):
    r = subprocess.run(["bash", CHECK] + args, capture_output=True, text=True, timeout=300,
                       env=dict(os.environ, CEPA_NUDGE_CHECK_LEGS=legs))
    lines = r.stdout.splitlines()
    return (r.returncode, {l[5:].split(":", 1)[0] for l in lines if l.startswith("MISS ")},
            {l[5:] for l in lines if l.startswith("PASS ")})

def run(script, legs="all"):
    return check([script], legs)[:2]

# Every shard runs the unmutated copy first: a red mutant proves nothing in a
# job whose own baseline is not clean.
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

def run_mutant(part, m):
    try:
        return run_part(part, m)
    except (subprocess.SubprocessError, OSError) as e:
        return -1, {"exception %s" % type(e).__name__}

def run_part(part, m):
    # Each part writes under its own directory, so names only need to be
    # unique within a part for the paths to be distinct.
    name, old, new, want = m
    base = os.path.join(TMP, part)
    os.makedirs(base, exist_ok=True)
    if part == "nudge":
        if src.count(old) != 1:
            return None, src.count(old)
        path = os.path.join(base, name + ".sh")
        open(path, "w", encoding="utf-8").write(src.replace(old, new))
        return run(path, "nudge")
    if part == "send":
        # The send legs run the shipped nudge beside orca-send.sh.
        if send_src.count(old) != 1:
            return None, send_src.count(old)
        d = os.path.join(base, name)
        os.mkdir(d)
        open(os.path.join(d, "orca-send.sh"), "w", encoding="utf-8").write(send_src.replace(old, new))
        shutil.copy(SCRIPT, d)
        return check([SCRIPT, os.path.join(d, "orca-send.sh")], "send")[:2]
    if part == "skill":
        # The send legs read the rule 1 block from argument 4.
        if skill_src.count(old) != 1:
            return None, skill_src.count(old)
        path = os.path.join(base, name + ".md")
        open(path, "w", encoding="utf-8").write(skill_src.replace(old, new))
        return check([SCRIPT, SEND, HEALTH, path], "send")[:2]
    if part == "skillh":
        # The health legs read the rule 2 and 8 blocks from argument 4.
        if skill_src.count(old) != 1:
            return None, skill_src.count(old)
        path = os.path.join(base, name + ".md")
        open(path, "w", encoding="utf-8").write(skill_src.replace(old, new))
        return check([SCRIPT, SEND, HEALTH, path], "health")[:2]
    if part == "rebind":
        # The health legs run orca-rebind.sh from argument 5.
        if rebind_src.count(old) != 1:
            return None, rebind_src.count(old)
        path = os.path.join(base, name + ".sh")
        open(path, "w", encoding="utf-8").write(rebind_src.replace(old, new))
        return check([SCRIPT, SEND, HEALTH, SKILL, path], "health")[:2]
    if health_src.count(old) != 1:
        return None, health_src.count(old)
    path = os.path.join(base, name + ".sh")
    open(path, "w", encoding="utf-8").write(health_src.replace(old, new))
    return check([SCRIPT, SEND, path], "health")[:2]

# Each check run makes its own temp dir, so the runs share nothing. One pool
# for all three parts, so no part waits on another part's slowest mutant.
mine = [pm for i, pm in enumerate(ALL) if shard_of(i, NSHARDS) == SHARD]
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    results = list(pool.map(lambda pm: run_mutant(*pm), mine))
for (part, (name, old, new, want)), (rc, got) in zip(mine, results):
    if rc is None:
        miss("%s: anchor found %d times, want 1" % (name, got)); continue
    if rc == 1 and got == want:
        ok("%s goes red on %s" % (name, ", ".join(sorted(want))))
    else:
        miss("%s: rc=%s, MISS set %r" % (name, rc, sorted(got)))

shutil.rmtree(TMP, ignore_errors=True)
print("-- shard %d/%d: %d of %d mutants; %d/%d controls passed --"
      % (SHARD, NSHARDS, len(mine), len(ALL), passed, passed + failed))
raise SystemExit(1 if failed else 0)
PY
