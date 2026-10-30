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
# case that must catch it. Every FIXTURES case and every CITES check family has
# at least one mutant here that names it.
#
# STATED LIMITS: a mutant is one substitution; two compensating edits are not
# modeled. The controls prove each named case can fail, not that the case list
# is complete.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

python3 - <<'PY'
import os, shutil, subprocess, sys, tempfile

HOME = "plugins/cepa/skills/autonomy/SKILL.md"
SITES = "plugins/cepa/commands"
CHECK = "scripts/check-orca-detection.sh"
PROBE = 'elif ! timeout -k 2 10 "$cepa_orca_cli" status --json </dev/null >"$cepa_orca_tmp" 2>/dev/null; then'
# (name, file, old, new, killer) — file is "skill" or a command file name.
MUTANTS = [
    ("linux-bare", "skill", "    cepa_orca_cli=orca-ide\n", "    cepa_orca_cli=orca\n", "unset-no-cli"),
    ("no-cli-check", "skill", '  if ! command -v "$cepa_orca_cli" >/dev/null 2>&1; then',
     "  if false; then", "unset-no-cli"),
    ("unbounded", "skill", 'timeout -k 2 10 "$cepa_orca_cli" status', '"$cepa_orca_cli" status',
     "status-hangs-ignoring-TERM"),
    ("no-kill", "skill", "timeout -k 2 10 ", "timeout 10 ", "status-hangs-ignoring-TERM"),
    ("longer-timeout", "skill", "timeout -k 2 10 ", "timeout -k 2 20 ", "status-hangs-ignoring-TERM"),
    ("pipe-probe", "skill", PROBE,
     'elif ! timeout -k 2 10 "$cepa_orca_cli" status --json </dev/null 2>/dev/null | cat >"$cepa_orca_tmp"; then',
     "bg-child-holds-stdout"),
    ("no-stdin-redirect", "skill", "status --json </dev/null >", "status --json >", "stdin-reader"),
    ("no-json-flag", "skill", "status --json </dev/null", "status </dev/null", "status-ok"),
    ("exit-ignored", "skill", '>"$cepa_orca_tmp" 2>/dev/null; then', '>"$cepa_orca_tmp" 2>/dev/null; [ ! -s "$cepa_orca_tmp" ]; then',
     "status-nonzero-exit"),
    ("truthy-ok", "skill", '.get("ok") is True else', '.get("ok") else', "status-ok-string"),
    ("no-timeout-check", "skill", "  elif ! command -v timeout >/dev/null 2>&1; then", "  elif false; then",
     "no-timeout-tool"),
    ("no-python-check", "skill", "  elif ! command -v python3 >/dev/null 2>&1; then", "  elif false; then",
     "no-python3"),
    ("no-dev-branch", "skill", '  if [ -n "${ORCA_DEV_REPO_ROOT:-}" ]; then', "  if false; then", "dev-checkout"),
    ("non-linux-fallback", "skill", "  else\n    cepa_orca_cli=orca\n  fi", "  else\n    cepa_orca_cli=orca-ide\n  fi",
     "non-linux-uses-orca"),
    ("env-probes", "skill", '    echo "ORCA: present cli=$cepa_orca_cli via=ORCA_CLI_COMMAND"',
     '    "$cepa_orca_cli" status --json >/dev/null 2>&1 || true\n'
     '    echo "ORCA: present cli=$cepa_orca_cli via=ORCA_CLI_COMMAND"', "env-set-no-probe"),
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
    ("second-block", "skill", "`ORCA: absent (<what failed>)`:\n", "`ORCA: absent (<what failed>)`:\n\n```bash\ntrue\n```\n",
     "BLOCK"),
    ("prose-drops-ask", "skill", "with Orca's\n   `ask`**", "with Orca's\n   ask**", "section 12 prose names Orca's `ask`"),
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
for name, target, old, new, killer in MUTANTS:
    skill, sites = copy_tree(name)
    path = skill if target == "skill" else os.path.join(sites, target)
    text = open(path).read()
    n = text.count(old)
    if n < 1:
        miss("%s: anchor not found in %s" % (name, target)); continue
    if n > 1 and name not in ("no-kill", "longer-timeout"):
        miss("%s: anchor occurs %d times in %s, want 1" % (name, n, target)); continue
    open(path, "w").write(text.replace(old, new, 1))
    rc, misses = run(skill, sites)
    if rc is None:
        miss("%s: check still running after 600s" % name); continue
    hit = [m for m in misses if m.startswith(killer) or m.startswith("CITES: " + killer)]
    if rc != 0 and hit:
        ok("%s killed by %s" % (name, killer))
    else:
        miss("%s: not killed by %s (rc=%s, MISS lines: %r)" % (name, killer, rc, misses[:2]))
shutil.rmtree(TMP, ignore_errors=True)
print("-- %d/%d controls passed, %d failed --" % (passed, passed + failed, failed))
sys.exit(1 if failed else 0)
PY
