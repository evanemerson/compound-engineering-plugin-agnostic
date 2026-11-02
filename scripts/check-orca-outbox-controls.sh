#!/usr/bin/env bash
# Controls for scripts/check-orca-outbox.sh. Each mutant is one substitution
# in a temp copy of plugins/cepa/scripts/orca-send.sh (SEND), orca-health.sh
# (HEALTH), orca-outbox.sh (OUTBOX) or the autonomy skill whose rule 8 drain
# block the BLOCK leg runs (SKILL). It must turn the check red with EXACTLY
# the MISS cases named beside it, so each mutant shows which case catches it
# and that no other case does. The unmutated copies must run with no MISS
# line, or every red below proves nothing. A mutant whose anchor text is not
# found exactly once is a MISS, never a skip: the shipped file changed shape
# and the mutant needs re-reading.
#
# Every leg of the check (TARGET, WRITE, RESOLVE, PRUNE, HEALTH, DRAIN,
# BLOCK) has at least one mutant here that only its own cases kill; the last
# controls assert that, so a new leg that also kills an old leg's only mutant
# shows.
#
# Also: every reason the new code adds to orca-health.sh's REASONS has a
# mutant that removes it, killed by a case that shows that reason (plan
# review #23).
#
# STATED LIMITS: a mutant is one substitution; two compensating edits are not
# modeled. The controls prove each named case can fail, not that the case
# list is complete. The `-O` owner checks have no mutant (one user only).
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

python3 - <<'PY'
import concurrent.futures, os, re, shutil, subprocess, sys, tempfile

FILES = {"SEND": "plugins/cepa/scripts/orca-send.sh", "HEALTH": "plugins/cepa/scripts/orca-health.sh",
         "OUTBOX": "plugins/cepa/scripts/orca-outbox.sh", "SKILL": "plugins/cepa/skills/autonomy/SKILL.md"}
ORDER = ["SEND", "HEALTH", "OUTBOX", "SKILL"]
CHECK = "scripts/check-orca-outbox.sh"
LEGS = ["TARGET", "WRITE", "RESOLVE", "PRUNE", "HEALTH", "DRAIN", "BLOCK"]

SENDS = ["RESOLVE one live coord@main is sent to and moved to delivered",
         "RESOLVE objective with nothing after the name matches",
         "RESOLVE one handle in two Runs is one handle", "RESOLVE a match on a later page is found"]
# (file, name, old, new, exact MISS case set)
MUTANTS = [
    # TARGET
    ("SEND", "slug-unchecked", ' && [ "$(cepa_send_slug "$cepa_send_coord")" = "$cepa_send_coord" ]; then', '; then',
     {"TARGET leading dash is refused and kept in _invalid", "TARGET double dash is refused and kept in _invalid"}),
    ("SEND", "escalation-coord-ok", '[[ $cepa_send_target != coord:* ]] || refuse "an escalation',
     '[[ $cepa_send_target != nothing* ]] || refuse "an escalation',
     {"TARGET escalation refuses a coord address and keeps it as refused"}),
    ("SEND", "outbox-for-every-target", 'if [[ ${cepa_send_f_target-} == coord:* ]]; then',
     'if [[ ${cepa_send_f_target-} == * ]]; then', {"TARGET a term_ target writes no outbox copy"}),
    # WRITE
    ("SEND", "file-mode-644", '&& chmod 600 "$tmp" 2>/dev/null', '&& chmod 644 "$tmp" 2>/dev/null',
     {"WRITE file 600, directories 700"}),
    ("SEND", "header-extra-line", '"type=$typ" "session=$sess" "---"', '"type=$typ" "session=$sess" "x=1" "---"',
     {"WRITE header is exact and the message is verbatim"}),
    ("SEND", "symlink-root-ok", '[ -d "$root" ] && [ ! -L "$root" ] && [ -O "$root" ]', '[ -d "$root" ] && [ -O "$root" ]',
     {"WRITE a symlinked outbox root is refused"}),
    ("SEND", "relative-root-ok", '[[ $root == /* ]] || refuse "the outbox directory is not an absolute path"',
     '[[ $root == * ]] || refuse "the outbox directory is not an absolute path"',
     {"WRITE a relative outbox root is refused"}),
    ("SEND", "refused-not-moved", '"${cepa_send_obox%/*}/refused/$n" 2>/dev/null; then',
     '"${cepa_send_obox%/*}/$n" 2>/dev/null; then', None),
    # RESOLVE
    ("SEND", "objective-unanchored", 'r" coord@main(?:$|[ :])"', 'r" coord@main"',
     {"RESOLVE an objective that runs on past coord@main never matches"}),
    ("SEND", "objective-search", "if isinstance(o, str) and obj.match(o)", "if isinstance(o, str) and obj.search(o)",
     {"RESOLVE an objective that only contains the name never matches"}),
    ("SEND", "connected-ignored", 'if not t or t.get("connected") is not True:', 'if not t:',
     {"RESOLVE a terminal that is not connected is not live"}),
    ("SEND", "pty-absent-ok", 'rows[0].get("hasLivePty") is not True:', 'rows[0].get("hasLivePty") is False:',
     {"RESOLVE an open tab with no live pty is not live"}),
    ("SEND", "linked-worktree-ok", 'if w and w.get("isMainWorktree") is True and slug(base) == repo:',
     'if w and slug(base) == repo:', {"RESOLVE a live coord@main in a linked worktree is a mismatch"}),
    ("SEND", "basename-ignored", 'if w and w.get("isMainWorktree") is True and slug(base) == repo:',
     'if w and w.get("isMainWorktree") is True:',
     {"RESOLVE a live coord@main in another repo's main checkout is a mismatch"}),
    ("SEND", "ambiguous-at-three", "    if len(live) > 1:", "    if len(live) > 2:",
     {"RESOLVE two live coord@main handles are ambiguous"}),
    ("SEND", "cursor-dropped", '        --cursor "$cepa_send_cur" --json', '        --json',
     {"RESOLVE a match on a later page is found", "RESOLVE pagination follows nextCursor"}),
    ("SEND", "cursor-any-text", r're.fullmatch(r"[A-Za-z0-9_=-]{1,512}", c)', r're.fullmatch(r".{1,512}", c)',
     {"RESOLVE a bad cursor is unreadable"}),
    ("SEND", "truncation-ignored", 'if tl["truncated"] is not False or ps["truncated"] is not False:',
     'if ps["truncated"] is not False:', {"RESOLVE a truncated terminal list is unreadable"}),
    ("SEND", "delivered-unnamed", '"${cepa_send_obox%/*}/delivered/${cepa_send_n%.md}.to-$cepa_send_target.md" 2>/dev/null; then',
     '"${cepa_send_obox%/*}/delivered/$cepa_send_n" 2>/dev/null; then', set(SENDS)),
    ("SEND", "failed-send-refused",
     'fail() { echo "Orca send failed: no message stored — $1"; cepa_send_obox_note pending;',
     'fail() { echo "Orca send failed: no message stored — $1"; cepa_send_obox_note refused;',
     {"RESOLVE a failed send stays pending"}),
    # PRUNE
    ("SEND", "prune-at-70-days", "time.time() - 7 * 86400", "time.time() - 70 * 86400",
     {"PRUNE files older than 7 days go in every status", "PRUNE a pending or refused file leaves an alert, a delivered one none"}),
    ("SEND", "prune-pending-silent", '      *) cepa_send_alert_for outbox_pruned', '      *) : outbox_pruned',
     {"PRUNE a pending or refused file leaves an alert, a delivered one none"}),
    # HEALTH
    ("HEALTH", "key-oldest", "            newest = max(newest, n)", "            newest = min(newest or n, n)", None),
    ("HEALTH", "worktree-scope-off", '                ours = h["worktree"] == wt', '                ours = True',
     {"HEALTH a linked worktree sees only its own files"}),
    ("HEALTH", "class-key-lost", '        key = "outbox:%s:%s:%s" % (orepo, cls, n)', '        key = "send-failed:" + n', None),
    ("HEALTH", "class-ack-unchecked", '[[ $k =~ ^outbox:[^:]+:(ambiguous|mismatch|unreadable|pruned):(.+)$ ]] && cepa_h_af=',
     '[[ $k =~ ^nothing(.)(.)$ ]] && cepa_h_af=', {"HEALTH an outbox class ack needs its alert file"}),
    ("HEALTH", "mode-unchecked", "stat.S_IMODE(st.st_mode) != 0o600", "False", None),
    ("HEALTH", "unknown-shown-to-lanes", '    see_unknown = main and (', '    see_unknown = (',
     {"HEALTH a receiver's linked worktree gets no unknown-shape alert or inbound note"}),
    ("HEALTH", "key-any-repo", "outbox:[A-Za-z0-9_-]{1,100}:([0-9]{8}", "outbox:.{1,100}:([0-9]{8}",
     {"HEALTH a bad outbox key is refused"}),
    # DRAIN
    ("OUTBOX", "newest-first", "shown.sort(key=lambda x: x[0])", "shown.sort(key=lambda x: x[0], reverse=True)",
     {"DRAIN shows pending and gone-handle files oldest first, nothing else"}),
    ("OUTBOX", "own-handle-shown", "    if to == me or to in live:", "    if to in live:", None),
    ("OUTBOX", "fixed-nonce", "    nonce = secrets.token_hex(8)", '    nonce = "0" * 16',
     {"DRAIN each body sits between markers with its own nonce"}),
    ("OUTBOX", "control-chars-raw", "(ord(c) >= 32 and ord(c) != 127)", "(ord(c) >= 0)",
     {"DRAIN control characters print as ?"}),
    ("OUTBOX", "ack-keeps-name", "    dst=$cepa_ob_dir/delivered/${n%%.*}.drained.md", "    dst=$cepa_ob_dir/delivered/$n", None),
    ("OUTBOX", "linked-worktree-drains", '[ "$cepa_ob_gitdir" = "$cepa_ob_common" ] || refuse', 'true || refuse',
     {"DRAIN refuses a linked worktree"}),
    ("OUTBOX", "fail-open-liveness", "        return set()   # unknown: every delivered file is shown",
     "        return {'" + "term_" + "b" * 8 + "-0000-0000-0000-" + "b" * 12 + "', '" + "term_" + "c" * 8 + "-0000-0000-0000-" + "c" * 12 + "'}",
     {"DRAIN a failed terminal read shows every recent delivered file"}),
    # BLOCK
    ("SKILL", "drain-args-joined", 'bash "$CEPA_ROOT/scripts/orca-outbox.sh" "${cepa_outbox_argv[@]}" || true',
     'bash "$CEPA_ROOT/scripts/orca-outbox.sh" "${cepa_outbox_argv[*]}" || true',
     {"BLOCK show runs the script", "BLOCK the ack form passes each name as one argument",
      "BLOCK a cli with a command substitution runs nothing"}),
]
# REASONS added by L61: each removal must show as `an unrecognised reason`.
REASON_MUTANTS = [
    ("HEALTH", "reason-ambiguous-gone",
     '    r"more than one live coord@main claims [A-Za-z0-9_-]{1,100}: term_[0-9a-f-]{36}( term_[0-9a-f-]{36}){1,9}",\n',
     "", {"HEALTH resolver alert files become outbox class keys"}),
    ("HEALTH", "reason-mismatch-gone", '    r"a live session claims coord@main of [A-Za-z0-9_-]{1,100} outside its main checkout: "\n    r"term_[0-9a-f-]{36}( term_[0-9a-f-]{36}){0,9}",\n',
     "", {"HEALTH resolver alert files become outbox class keys"}),
    ("HEALTH", "reason-unreadable-gone", '    r"the (Run list|terminal list) could not be read", ', "    ",
     {"HEALTH resolver alert files become outbox class keys"}),
]
# Exact sets that are long to restate; each is what the named mutant must
# break and nothing more (read from a run, then checked by hand).
EXPECT = {
    "refused-not-moved": {"TARGET escalation refuses a coord address and keeps it as refused",
                          "TARGET reply refuses a coord address and keeps it as refused",
                          "TARGET worker_done refuses a coord address and keeps it as refused",
                          "WRITE a refusal after the write moves it to refused"},
    "key-oldest": {"HEALTH the sender sees one count alert keyed by the newest file",
                   "HEALTH an acked count alert holds",
                   "HEALTH a new file alerts again under a new key"},
    "class-key-lost": {"HEALTH resolver alert files become outbox class keys"},
    "mode-unchecked": {"HEALTH unknown-shape files alert in the receiving main checkout",
                       "HEALTH the receiving main checkout gets the inbound note"},
    "own-handle-shown": {"DRAIN shows pending and gone-handle files oldest first, nothing else",
                         "DRAIN never shows refused, live, own, old, drained or unknown-shape files",
                         "DRAIN each body sits between markers with its own nonce",
                         "DRAIN a failed terminal read shows every recent delivered file"},
    "ack-keeps-name": {"DRAIN ack moves pending and delivered files to drained"},
}

passed = failed = 0


def ok(m):
    global passed
    passed += 1


def miss(m):
    global failed
    failed += 1
    print("MISS " + m)


def run_check(paths):
    r = subprocess.run(["bash", CHECK] + [paths[k] for k in ORDER], capture_output=True, text=True, timeout=900)
    names = set()
    for l in r.stdout.splitlines():
        if l.startswith("MISS "):
            names.add(l[5:].split(": ", 1)[0])
    if not re.search(r"^-- \d+/\d+ checks passed --$", r.stdout, re.M) or "Traceback" in r.stderr:
        names.add("CRASHED")
    return r.returncode, names


tmp = tempfile.mkdtemp(prefix="cepa-outbox-controls-")
rc, names = run_check(FILES)
(ok if rc == 0 and not names else miss)("unmutated copies pass the check" + ("" if not names else ": %s" % sorted(names)))


def one(m):
    kind, name, old, new, want = m
    want = want if want is not None else EXPECT.get(name)
    text = open(FILES[kind]).read()
    if text.count(old) != 1:
        return name, None, "anchor found %d times" % text.count(old), want
    d = os.path.join(tmp, name)
    os.makedirs(d)
    p = os.path.join(d, os.path.basename(FILES[kind]))
    open(p, "w").write(text.replace(old, new))
    paths = dict(FILES)
    paths[kind] = p
    rc, got = run_check(paths)
    return name, got, None if rc else "check stayed green", want


results = {}
with concurrent.futures.ThreadPoolExecutor(max_workers=min(8, os.cpu_count() or 4)) as ex:
    for name, got, why, want in ex.map(one, MUTANTS + REASON_MUTANTS):
        results[name] = got
        if why:
            miss("%s: %s" % (name, why))
        elif got != want:
            miss("%s: MISS set %s, want %s" % (name, sorted(got), sorted(want or [])))
        else:
            ok(name)

for leg in LEGS:
    own = [n for n, got in results.items() if got and all(c.startswith(leg + " ") for c in got)]
    (ok if own else miss)("leg %s has a mutant only its cases kill" % leg)

shutil.rmtree(tmp, ignore_errors=True)
print("-- %d/%d controls passed --" % (passed, passed + failed))
sys.exit(1 if failed else 0)
PY
