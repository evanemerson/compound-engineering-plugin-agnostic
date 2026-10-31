#!/usr/bin/env bash
# Controls for scripts/check-orca-detection.sh. Each mutant is one substitution
# in a temp copy of the shipped skill file (section 12) or of one command file,
# and must turn the check red ON THE CASE NAMED BESIDE IT — a mutant that only
# breaks something else proves nothing about the case meant to catch it. The
# unmutated copies must run with no MISS line, or every red below proves
# nothing. A mutant whose anchor text is gone is a MISS, never a skip: the
# shipped text changed shape and these mutants need re-reading.
#
# What each mutant reverts is in its name; the MUTANTS table pairs it with the
# case that must catch it. Every leg and every CITES check family has at least
# one mutant here that names it; FIXTURES cases that share one code path (the
# several malformed-JSON answers) share one mutant.
#
# Mutants run four at a time, each against its own copies. Each run of the
# check takes a few seconds because its hang cases use the shorter test bound
# (see BOUNDS and TITLE-BOUNDS in the check's header); the whole set took
# about two minutes locally on 2026-10-30. On
# 2026-10-30 the hang cases waited out the shipped 12 s per mutant, and the
# controls overran the residual-integrity job's 10-minute bound (run
# 41072902545).
#
# STATED LIMITS: a mutant is one substitution; two compensating edits are not
# modeled. The controls prove each named case can fail, not that the case list
# is complete.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

python3 - <<'PY'
import concurrent.futures, os, shutil, subprocess, sys, tempfile

HOME = "plugins/cepa/skills/autonomy/SKILL.md"
SITES = "plugins/cepa/commands"
CHECK = "scripts/check-orca-detection.sh"
TO = 'timeout -k "$cepa_orca_kill" "$cepa_orca_wait" '
PROBE = '  ' + TO + '"$cepa_orca_cli" status --json </dev/null >"$cepa_orca_tmp" 2>"$cepa_orca_err" && return 0'
# (name, file, old, new, killer) — file is "skill" or a command file name.
MUTANTS = [
    ("linux-bare", "skill", "    cepa_orca_cli=orca-ide\n", "    cepa_orca_cli=orca\n", "unset-no-cli"),
    ("no-cli-check", "skill", '  if ! command -v "$cepa_orca_cli" >/dev/null 2>&1; then',
     "  if false; then", "unset-no-cli"),
    ("unbounded", "skill", TO + '"$cepa_orca_cli" status', '"$cepa_orca_cli" status',
     "status-hangs-ignoring-TERM"),
    ("no-kill", "skill", TO, 'timeout "$cepa_orca_wait" ', "status-hangs-ignoring-TERM"),
    ("longer-timeout", "skill", "  cepa_orca_wait=10 cepa_orca_kill=2\n", "  cepa_orca_wait=20 cepa_orca_kill=2\n",
     "BOUNDS"),
    ("bounds-from-env", "skill", "  cepa_orca_wait=10 cepa_orca_kill=2\n",
     "  cepa_orca_wait=${CEPA_ORCA_WAIT:-10} cepa_orca_kill=2\n", "BOUNDS"),
    ("env-longer-wait", "skill", "  cepa_orca_wait=3 cepa_orca_kill=0.5\n", "  cepa_orca_wait=5 cepa_orca_kill=0.5\n",
     "BOUNDS"),
    ("bounds-hoisted", "skill",
     '  cepa_orca_wait=10 cepa_orca_kill=2\n  if ! command -v "$cepa_orca_cli" >/dev/null 2>&1; then\n'
     '    cepa_orca_why="$cepa_orca_cli not on PATH"\n  fi\nfi\n',
     '  if ! command -v "$cepa_orca_cli" >/dev/null 2>&1; then\n'
     '    cepa_orca_why="$cepa_orca_cli not on PATH"\n  fi\nfi\ncepa_orca_wait=10 cepa_orca_kill=2\n',
     "env-stale-hangs"),
    ("env-no-kill", "skill", "  cepa_orca_wait=3 cepa_orca_kill=0.5\n  case", "  cepa_orca_wait=3 cepa_orca_kill=0\n  case",
     "BOUNDS"),
    ("pipe-probe", "skill", PROBE,
     '  ' + TO + '"$cepa_orca_cli" status --json </dev/null 2>"$cepa_orca_err" | cat >"$cepa_orca_tmp" && return 0',
     "bg-child-holds-stdout"),
    ("no-stdin-redirect", "skill", "status --json </dev/null >", "status --json >", "stdin-reader"),
    ("no-json-flag", "skill", "status --json </dev/null", "status </dev/null", "status-ok"),
    ("exit-ignored", "skill", '>"$cepa_orca_tmp" 2>"$cepa_orca_err" && return 0', '>"$cepa_orca_tmp" 2>"$cepa_orca_err"; [ -s "$cepa_orca_tmp" ] && return 0',
     "status-nonzero-exit"),
    ("truthy-ok", "skill", '.get("ok") is True else 1)\' "$cepa_orca_tmp"', '.get("ok") else 1)\' "$cepa_orca_tmp"',
     "status-ok-string"),
    ("no-timeout-check", "skill", "elif ! command -v timeout >/dev/null 2>&1; then", "elif false; then",
     "no-timeout-tool"),
    ("no-python-check", "skill", "elif ! command -v python3 >/dev/null 2>&1; then", "elif false; then",
     "no-python3"),
    ("no-dev-branch", "skill", '  if [ -n "${ORCA_DEV_REPO_ROOT:-}" ]; then', "  if false; then", "dev-checkout"),
    ("non-linux-fallback", "skill", "  else\n    cepa_orca_cli=orca\n  fi", "  else\n    cepa_orca_cli=orca-ide\n  fi",
     "non-linux-uses-orca"),
    ("env-no-probe", "skill", '    cepa_orca_why="ORCA_CLI_COMMAND=$cepa_orca_cli is not on PATH"\n  fi\n',
     '    cepa_orca_why="ORCA_CLI_COMMAND=$cepa_orca_cli is not on PATH"\n  fi\n'
     '  [ -n "$cepa_orca_why" ] || { echo "ORCA: present cli=$cepa_orca_cli via=ORCA_CLI_COMMAND"; exit 0; }\n',
     "env-stale-fails"),
    ("env-via-status", "skill", "  cepa_orca_via=ORCA_CLI_COMMAND\n", "  cepa_orca_via=status\n", "env-set-probes-ok"),
    ("env-empty-is-set", "skill", 'if [ -n "${ORCA_CLI_COMMAND:-}" ]; then', 'if [ -n "${ORCA_CLI_COMMAND+x}" ]; then',
     "env-empty-probes"),
    ("env-no-charset", "skill", "    -*|*[!A-Za-z0-9._/-]*) cepa_orca_why=", "    -*) cepa_orca_why=", "env-inject"),
    ("env-dash-allowed", "skill", "    -*|*[!A-Za-z0-9._/-]*) cepa_orca_why=", "    *[!A-Za-z0-9._/-]*) cepa_orca_why=",
     "env-dash"),
    ("env-bare-orca", "skill", 'orca) [ "$cepa_orca_os" != Linux ] || cepa_orca_why=', "orca) true || cepa_orca_why=",
     "env-bare-orca-linux"),
    ("env-any-name", "skill", '*) cepa_orca_why="ORCA_CLI_COMMAND does not name an Orca CLI" ;;', "*) ;;",
     "env-not-orca"),
    ("env-no-path-check", "skill", 'if [ -z "$cepa_orca_why" ] && ! command -v "$cepa_orca_cli"',
     'if false && ! command -v "$cepa_orca_cli"', "env-not-on-path"),
    ("env-basename-only", "skill", '    case "${cepa_orca_cli##*/}" in', '    case "$cepa_orca_cli" in', "env-abs-path"),
    # RETRY (L28): once, only on the WSL interop error, inside the bounds.
    ("retry-none", "skill", "! cepa_orca_probe && ! { cepa_orca_vsock && cepa_orca_probe; }",
     "! cepa_orca_probe", "retry-vsock-once"),
    ("retry-any-error", "skill",
     '  [[ $cepa_orca_e == *UtilAcceptVsock* && $cepa_orca_e == *"accept4 failed 110"* ]]\n', "  true\n",
     "retry-other-error"),
    ("retry-vsock-text-only", "skill", ' && $cepa_orca_e == *"accept4 failed 110"*', "",
     "retry-vsock-text-only"),
    ("retry-accept-text-only", "skill", "$cepa_orca_e == *UtilAcceptVsock* && ", "", "retry-accept-text-only"),
    ("retry-twice", "skill", "{ cepa_orca_vsock && cepa_orca_probe; }",
     "{ cepa_orca_vsock && cepa_orca_probe; } && ! { cepa_orca_vsock && cepa_orca_probe; }",
     "retry-vsock-twice"),
    ("retry-unbounded", "skill", "{ cepa_orca_vsock && cepa_orca_probe; }",
     '{ cepa_orca_vsock && "$cepa_orca_cli" status --json </dev/null >"$cepa_orca_tmp" 2>/dev/null; }',
     "env-retry-vsock-then-hangs"),
    ("retry-after-timeout", "skill", '  [ "$cepa_orca_rc" != 124 ] && [ "$cepa_orca_rc" != 137 ] || return 1\n', "",
     "env-retry-not-after-timeout"),
    ("retry-nul-warning", "skill", '{ cepa_orca_e=$(<"$cepa_orca_err"); } 2>/dev/null', 'cepa_orca_e=$(<"$cepa_orca_err")',
     "retry-nul-in-stderr"),
    ("mktemp-err-unchecked", "skill", ' || ! cepa_orca_err=$(mktemp 2>/dev/null); then', '; then cepa_orca_err=$(mktemp 2>/dev/null) || true\nelif false; then',
     "mktemp-err-file-fails"),
    ("mktemp-msg", "skill", 'echo "ORCA: absent (mktemp failed)"', 'echo "ORCA: absent (x)"', "mktemp-fails"),
    ("err-file-not-removed", "skill", '[ -z "$cepa_orca_err" ] || rm -f "$cepa_orca_err"\n', "", "status-ok"),
    ("second-block", "skill", "`ORCA: absent (<what failed>)`:\n", "`ORCA: absent (<what failed>)`:\n\n```bash\ntrue\n```\n",
     "BLOCK"),
    ("prose-drops-do-not-paste", "skill", "`Sent to coord@main via Orca — do not paste.`",
     "`Sent to coord@main via Orca.`", "section 12 prose names `Sent to coord@main via Orca — do not paste.`"),
    ("prose-drops-do-not-paste-wt", "skill", "`Sent to coord@<wt> via Orca — do\n   not paste.`",
     "`Sent to coord@<wt> via Orca.`", "section 12 prose names `Sent to coord@<wt> via Orca — do not paste.`"),
    ("invalid-env-probes", "skill", 'if [ -n "$cepa_orca_why" ]; then\n  echo "ORCA: absent ($cepa_orca_why)"',
     'orca-ide status </dev/null >/dev/null 2>&1 || true\nif [ -n "$cepa_orca_why" ]; then\n  echo "ORCA: absent ($cepa_orca_why)"',
     "env-inject"),
    ("prose-drops-ask", "skill", "with Orca's\n   `ask`**", "with Orca's\n   ask**", "section 12 prose names Orca's `ask`"),
    # 12b rule 6: the tab-title block.
    ("title-second-block", "skill", "     [ -z \"$cepa_title_tmp\" ] || rm -f \"$cepa_title_tmp\"\n     ```\n",
     "     [ -z \"$cepa_title_tmp\" ] || rm -f \"$cepa_title_tmp\"\n     ```\n\n     ```bash\n     true\n     ```\n",
     "TITLE-BLOCK"),
    ("title-longer-bound", "skill", "timeout -k 0.5 3 <cli> terminal rename", "timeout -k 0.5 30 <cli> terminal rename",
     "TITLE-BOUNDS"),
    ("title-unbounded", "skill", "elif ! timeout -k 0.5 3 <cli> terminal rename", "elif ! <cli> terminal rename",
     "TITLE-BOUNDS"),
    # Keeps the bounded call and adds an unbounded one, so only the hang case sees it.
    ("title-second-unbounded-call", "skill", '--json </dev/null >"$cepa_title_tmp" 2>/dev/null; then',
     '--json </dev/null >"$cepa_title_tmp" 2>/dev/null && <cli> terminal rename </dev/null >/dev/null; then',
     "title-rename-hangs"),
    ("title-show-toplevel", "skill", "git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)",
     "git rev-parse --path-format=absolute --show-toplevel 2>/dev/null)/.git", "title-self-linked-worktree"),
    ("title-no-git-suffix-check", "skill", "         *) cepa_title_why=\"git rev-parse --git-common-dir gave no",
     "         *) cepa_title_repo=x; [ -n \"\" ] && cepa_title_why=\"git rev-parse --git-common-dir gave no",
     "title-not-a-repo"),
    ("title-split-arg", "skill", '--title "$cepa_title_repo · $cepa_title_name"',
     '--title $cepa_title_repo · $cepa_title_name', "title-self-linked-worktree"),
    ("title-ascii-dot", "skill", '--title "$cepa_title_repo · $cepa_title_name"',
     '--title "$cepa_title_repo - $cepa_title_name"', "title-self-linked-worktree"),
    ("title-self-ignored", "skill", '  if [ "$cepa_title_term" = self ]; then', "  if false; then",
     "title-self-linked-worktree"),
    ("title-no-handle-msg", "skill", '[ -n "$cepa_title_term" ] || cepa_title_why=', 'true || cepa_title_why=',
     "title-self-no-handle"),
    ("title-no-handle-charset", "skill", "''|-*|*[!A-Za-z0-9_:.-]*) cepa_title_why=", "''|-*) cepa_title_why=",
     "title-worker-inject-handle"),
    ("title-dash-handle", "skill", "''|-*|*[!A-Za-z0-9_:.-]*) cepa_title_why=", "''|*[!A-Za-z0-9_:.-]*) cepa_title_why=",
     "title-self-dash-handle"),
    ("title-no-name-charset", "skill",
     'case "$cepa_title_name" in\n         \'\'|-*|*[!A-Za-z0-9._@-]*) cepa_title_why=',
     'case "$cepa_title_name" in\n         \'\'|-*) cepa_title_why=', "title-name-inject"),
    ("title-no-repo-charset", "skill",
     'case "$cepa_title_repo" in\n         \'\'|-*|*[!A-Za-z0-9._@-]*) cepa_title_why=',
     'case "$cepa_title_repo" in\n         \'\'|-*) cepa_title_why=', "title-repo-space"),
    ("title-name-unquoted-heredoc", "skill", "cat <<'CEPA_NAME'", "cat <<CEPA_NAME", "title-name-subst"),
    ("title-fatal-failure", "skill", '  echo "ORCA title: failed (<cli> terminal rename failed or timed out)"',
     '  echo "ORCA title: failed (<cli> terminal rename failed or timed out)"; exit 1', "title-rename-fails"),
    ("title-exit-only", "skill", "\"$cepa_title_tmp\" >/dev/null 2>&1; then\n       echo \"ORCA title: set",
     "\"$cepa_title_tmp\" >/dev/null 2>&1 || true; then\n       echo \"ORCA title: set", "title-rename-not-ok"),
    ("title-no-devnull-stdin", "skill", '--json </dev/null >"$cepa_title_tmp"', '--json >"$cepa_title_tmp"',
     "title-stdin-reader"),
    ("title-stderr-leaks", "skill", '--json </dev/null >"$cepa_title_tmp" 2>/dev/null;',
     '--json </dev/null >"$cepa_title_tmp";', "title-self-linked-worktree"),
    ("title-no-json-flag", "skill", '$cepa_title_name" --json </dev/null', '$cepa_title_name" </dev/null',
     "title-self-linked-worktree"),
    ("title-truthy-ok", "skill", '.get("ok") is True else 1)\' "$cepa_title_tmp"',
     '.get("ok") else 1)\' "$cepa_title_tmp"', "title-rename-not-ok"),
    ("title-no-rm", "skill", '     [ -z "$cepa_title_tmp" ] || rm -f "$cepa_title_tmp"\n', "     true\n",
     "title-self-linked-worktree"),
    ("title-mktemp-msg", "skill", 'echo "ORCA title: skipped (mktemp failed)"', 'echo "ORCA title: skipped (x)"',
     "title-mktemp-fails"),
    ("title-handle-empty-allowed", "skill", "''|-*|*[!A-Za-z0-9_:.-]*) cepa_title_why=",
     "-*|*[!A-Za-z0-9_:.-]*) cepa_title_why=", "title-worker-empty-handle"),
    ("title-name-dash-allowed", "skill",
     'case "$cepa_title_name" in\n         \'\'|-*|*[!A-Za-z0-9._@-]*) cepa_title_why=',
     'case "$cepa_title_name" in\n         \'\'|*[!A-Za-z0-9._@-]*) cepa_title_why=', "title-name-dash"),
    ("title-name-empty-allowed", "skill",
     'case "$cepa_title_name" in\n         \'\'|-*|*[!A-Za-z0-9._@-]*) cepa_title_why=',
     'case "$cepa_title_name" in\n         -*|*[!A-Za-z0-9._@-]*) cepa_title_why=', "title-name-empty"),
    ("title-repo-dash-allowed", "skill",
     'case "$cepa_title_repo" in\n         \'\'|-*|*[!A-Za-z0-9._@-]*) cepa_title_why=',
     'case "$cepa_title_repo" in\n         \'\'|*[!A-Za-z0-9._@-]*) cepa_title_why=', "title-repo-dash"),
    ("title-placeholder-is-self", "skill", "     <handle-or-self>\n     CEPA_TERM", "     self\n     CEPA_TERM",
     "title-placeholder-left"),
    ("prose-drops-title-format", "skill", "as `<repo> · <role>@<wt>`.**", "as repo and name.**",
     "section 12 prose names `<repo> · <role>@<wt>`"),
    ("handoff-no-rename-grant", "handoff.md", ", Bash(orca-ide terminal rename:*)", "",
     "handoff.md grants Bash(orca-ide terminal rename:*)"),
    ("task-no-cite", "task.md", "apply `cepa:autonomy` §12 —", "apply the adapter —",
     "task.md carries the §12 citation sentence"),
    ("lfg-no-rule3", "lfg.md", "autonomy §12b rule 3", "autonomy rule 3", "lfg.md cites §12b rule 3"),
    ("handoff-no-rule1", "handoff.md", "§12b rule 1", "§12b", "handoff.md cites §12b rule 1"),
    ("handoff-no-ask-grant", "handoff.md", ", Bash(orca-ide orchestration ask:*)", "",
     "handoff.md grants Bash(orca-ide orchestration ask:*)"),
]
passed = failed = 0
TMP = tempfile.mkdtemp(prefix="cepa-orca-ctl-")

def ok(msg):
    global passed; passed += 1; print("PASS", msg)

def miss(msg):
    global failed; failed += 1; print("MISS", msg)

def run(skill, sites):
    try:
        r = subprocess.run(["bash", CHECK, skill], env=dict(os.environ, CEPA_ORCA_SITES=sites),
                           capture_output=True, text=True, timeout=600)
    except subprocess.TimeoutExpired:
        return None, []
    return r.returncode, [l[5:] for l in r.stdout.splitlines() if l.startswith("MISS ")]

def copy_tree(name):
    d = os.path.join(TMP, name)
    shutil.copytree(SITES, os.path.join(d, "commands"))
    shutil.copy(HOME, os.path.join(d, "SKILL.md"))
    return os.path.join(d, "SKILL.md"), os.path.join(d, "commands")

skill, sites = copy_tree("clean")
rc, misses = run(skill, sites)
if rc == 0 and not misses:
    ok("unmutated copies run with no MISS")
else:
    miss("unmutated copies: rc=%s, first MISS %r" % (rc, misses[:1]))
def control(mutant):
    # Returns (passed, message). Each mutant has its own copies, and the check
    # makes its own temp dir, so mutants run side by side.
    name, target, old, new, killer = mutant
    try:
        return mutate(name, target, old, new, killer)
    except Exception as e:  # a crashed control is a MISS, never a lost line
        return False, "%s: control crashed: %r" % (name, e)

def mutate(name, target, old, new, killer):
    skill, sites = copy_tree(name)
    path = skill if target == "skill" else os.path.join(sites, target)
    text = open(path).read()
    n = text.count(old)
    if n != 1:
        return False, "%s: anchor occurs %d times in %s, want 1" % (name, n, target)
    open(path, "w").write(text.replace(old, new, 1))
    rc, misses = run(skill, sites)
    if rc is None:
        return False, "%s: check still running after 600s" % name
    hit = [m for m in misses if m.startswith(killer + ":") or m == "CITES: " + killer]
    if rc != 0 and hit:
        return True, "%s killed by %s" % (name, killer)
    return False, "%s: not killed by %s (rc=%s, MISS lines: %r)" % (name, killer, rc, misses[:2])

# Four at a time: the check's slowest case waits about 2.3 s, and its time
# bounds leave room for a loaded runner.
try:
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for good, msg in pool.map(control, MUTANTS):
            (ok if good else miss)(msg)
finally:
    shutil.rmtree(TMP, ignore_errors=True)
print("-- %d/%d controls passed, %d failed --" % (passed, passed + failed, failed))
sys.exit(1 if failed else 0)
PY
