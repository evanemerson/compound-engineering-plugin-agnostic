#!/usr/bin/env bash
# Controls for scripts/check-orca-attention.sh. Each mutant is one
# substitution in a temp copy of plugins/cepa/scripts/orca-attention.sh (or,
# for SKILL_MUTANTS, of the autonomy skill whose rule 7 attention block the
# BLOCK leg runs). It must turn the check red with EXACTLY the MISS cases
# named beside it, so each mutant shows which case catches it and that no
# other case does. The unmutated copy must run with no MISS line, or every
# red below proves nothing. A mutant whose anchor text is not found exactly
# once is a MISS, never a skip: the shipped script changed shape and the
# mutant needs re-reading.
#
# Every leg of the check (FIELDS, SCOPE, MARK, CLEAR, BLOCK) has at least one
# mutant here that only its own cases kill; the last control asserts that, so
# a new leg that also kills an old leg's only mutant shows.
#
# STATED LIMITS: the `-O` ownership check and the `cd` to the top level have
# no mutant (the check's header says why neither can be pinned). A mutant is
# one substitution; two compensating edits are not
# modeled. The controls prove each named case can fail, not that the case
# list is complete.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

python3 - <<'PY'
import concurrent.futures, os, re, shutil, subprocess, sys, tempfile

SCRIPT = "plugins/cepa/scripts/orca-attention.sh"
SKILL = "plugins/cepa/skills/autonomy/SKILL.md"
CHECK = "scripts/check-orca-attention.sh"

# (name, old, new, exact MISS case set; None = the EXPECT entry below)
MUTANTS = [
    # FIELDS
    ("cli-any-chars", "''|-*|*[!A-Za-z0-9._/-]*) refuse \"the cli is not a plain command name\" ;;",
     "''|-*) refuse \"the cli is not a plain command name\" ;;", None),
    ("clear-takes-file", '[[ $cepa_at_seen != *" file "* ]] || refuse "clear takes no file field"', 'true', None),
    ("multi-line-ok", "[[ $cepa_at_q != *$'\\n'* ]] || refuse", "true || refuse", None),
    ("cntrl-ok", "[[ $cepa_at_q != *[[:cntrl:]]* ]] || refuse", "true || refuse", None),
    ("long-ok", '[ "${#cepa_at_q}" -le 200 ] || refuse', 'true || refuse', None),
    ("in-repo-ok", '      || refuse "the question file is inside the repo"', '      || true', None),
    ("symlink-ok", '[ -f "$cepa_at_file" ] && [ ! -L "$cepa_at_file" ] && [ -O "$cepa_at_file" ]',
     '[ -f "$cepa_at_file" ] && [ -O "$cepa_at_file" ]', None),
    ("extra-line", '[ -z "${cepa_at_rest//[[:space:]]/}" ] || refuse', 'true || refuse', None),
    # SCOPE
    ("distro-any", "if not distro or m.group(1) != distro:", "if not distro:", None),
    ("path-unchecked", '    if (p.rstrip("/") or "/") != top:', '    if False:', None),
    ("id-unchecked", 'if i != rid + "::" + p:\n    sys.exit(1)', 'if False:\n    sys.exit(1)', None),
    ("set-active", 'worktree set --worktree "id:$cepa_at_id" --unread', 'worktree set --worktree active --unread', None),
    # MARK
    ("mark-unproved", '[ "$cepa_at_u" = 1 ] && [ "$cepa_at_c" = "$cepa_at_want" ] \\', 'true \\', None),
    ("prefix-doubled", 'cepa_at_q=${cepa_at_q#NEEDS YOU:}', ':', None),
    ("show-id-unchecked", '    if i != sys.argv[3]:\n        sys.exit(1)', '    if False:\n        sys.exit(1)', None),
    ("no-retry", '[ "$try" = 1 ] || return 1\n    { e=', 'return 1\n    { e=', None),
    # CLEAR
    ("clear-any-comment", '  "NEEDS YOU: "*) ;;', '  *) ;;', None),
    ("clear-unproved", '[ "$cepa_at_u" = 0 ] && [ "$cepa_at_c" = " " ] \\', 'true \\', None),
    ("cli-abs-any", '/*) [ "$cepa_at_cli" = "${ORCA_CLI_COMMAND:-}" ] || refuse "a cli path must equal ORCA_CLI_COMMAND" ;;',
     '/*) ;;', None),
    ("bare-orca-ok", '  orca) [ "$(uname -s 2>/dev/null)" != Linux ] || refuse "bare orca on Linux is the screen reader" ;;',
     '  orca) ;;', None),
    ("dot-segment-ok", '&& $cepa_at_file != */./* && $cepa_at_file != */../* ]]', ']]', None),
    ("phys-unchecked", '[[ $cepa_at_file != "$cepa_at_k"/* && $cepa_at_phys != "$cepa_at_k"/* ]]',
     '[[ $cepa_at_file != "$cepa_at_k"/* ]]', None),
    ("distro-unset-ok", "if not distro or m.group(1) != distro:", "if distro and m.group(1) != distro:", None),
    ("no-timeout", 'timeout -k 2 15 "$cepa_at_cli" "$@"', '"$cepa_at_cli" "$@"', None),
    ("retry-all", '[[ $e == *UtilAcceptVsock* && $e == *"accept4 failed 110"* ]] || return 1', ':', None),
    ("show-shape-ok", 'if type(u) is not bool or not isinstance(c, str):', 'if not isinstance(c, str):', None),
    ("mark-unread-unproved", '[ "$cepa_at_u" = 1 ] && [ "$cepa_at_c" = "$cepa_at_want" ]', '[ "$cepa_at_c" = "$cepa_at_want" ]', None),
    ("clear-unread-unproved", '[ "$cepa_at_u" = 0 ] && [ "$cepa_at_c" = " " ]', '[ "$cepa_at_c" = " " ]', None),
    ("prefix-loose", '  "NEEDS YOU: "*) ;;', '  "NEEDS YOU"*) ;;', None),
    ("dot-unsaid", '[ "$cepa_at_u" = 0 ] || cepa_at_dot=', 'true || cepa_at_dot=', None),
    ("clear-empty-comment", '"id:$cepa_at_id" --read --comment " " --json', '"id:$cepa_at_id" --read --comment "" --json', None),
]
SKILL_MUTANTS = [
    ("block-unquoted", "orca-attention.sh\" <<'CEPA_FIELDS' || true", "orca-attention.sh\" <<CEPA_FIELDS || true", None),
]
LEGS = ["FIELDS", "SCOPE", "MARK", "CLEAR", "BLOCK"]

# Calibrated sets for the mutants written None above. Measured by running
# this file, then read.
EXPECT = {
    "cli-any-chars": {"FIELDS cli with shell text"},
    "clear-takes-file": {"FIELDS clear with file"},
    "multi-line-ok": {"FIELDS question two lines"},
    "cntrl-ok": {"FIELDS question control character"},
    "long-ok": {"FIELDS question too long"},
    "in-repo-ok": {"FIELDS file inside the main checkout", "FIELDS file inside this checkout",
                   "FIELDS file through a symlinked directory into the checkout"},
    "symlink-ok": {"FIELDS file symlink"},
    "extra-line": {"FIELDS line after fields"},
    "distro-any": {"SCOPE another distro's path"},
    "path-unchecked": {"SCOPE another worktree's row"},
    "id-unchecked": {"SCOPE id not repoId::path"},
    # `active` is not an id the stub knows, so every mark that should
    # succeed or reach the re-read fails at the set.
    "set-active": {"BLOCK clears", "BLOCK marks from a file", "MARK 200 characters pass",
                   "MARK interop error is retried", "MARK prefix not doubled", "MARK re-read fails",
                   "MARK re-read of an unknown shape", "MARK re-read of another id", "MARK set does not stick",
                   "MARK set stores the comment only", "MARK shell text is stored as text",
                   "SCOPE linked worktree sets its own id", "SCOPE main checkout sets its own id"},
    "mark-unproved": {"MARK set does not stick", "MARK set stores the comment only"},
    # Without the strip, "NEEDS YOU:   " is not empty, so the empty case
    # goes red too.
    "prefix-doubled": {"FIELDS question empty", "MARK prefix not doubled"},
    "show-id-unchecked": {"MARK re-read of another id"},
    "no-retry": {"MARK interop error is retried"},
    "clear-any-comment": {"CLEAR a NEEDS YOUR note is not a flag", "CLEAR leaves another comment alone",
                          "CLEAR says the dot is still set", "FIELDS absolute cli equal to ORCA_CLI_COMMAND passes"},
    "clear-unproved": {"CLEAR set clears the comment only", "CLEAR set does not stick"},
    "cli-abs-any": {"FIELDS absolute cli not ORCA_CLI_COMMAND"},
    "bare-orca-ok": {"FIELDS bare orca on Linux"},
    "dot-segment-ok": {"FIELDS file with a dot segment"},
    "phys-unchecked": {"FIELDS file through a symlinked directory into the checkout"},
    "distro-unset-ok": {"SCOPE WSL_DISTRO_NAME unset"},
    "no-timeout": {"MARK a hung call is bounded"},
    "retry-all": {"MARK other errors are not retried"},
    "show-shape-ok": {"MARK re-read of an unknown shape"},
    "mark-unread-unproved": {"MARK set stores the comment only"},
    "clear-unread-unproved": {"CLEAR set clears the comment only"},
    "prefix-loose": {"CLEAR a NEEDS YOUR note is not a flag"},
    "dot-unsaid": {"CLEAR says the dot is still set"},
    # Orca ignores an empty --comment (measured L57), so the flag stays.
    "clear-empty-comment": {"BLOCK clears", "CLEAR clears a NEEDS YOU flag"},
    # Unquoted, the heredoc no longer matches the fill, so <cli> stays and
    # every BLOCK case that fills it goes red.
    "block-unquoted": {"BLOCK clears", "BLOCK marks from a file", "BLOCK quoted heredoc holds cli, action, file",
                       "BLOCK shell text in the file field runs nothing"},
}

passed = failed = 0


def ok(m):
    global passed
    passed += 1


def miss(m):
    global failed
    failed += 1
    print("MISS " + m)


def run_check(script, skill):
    r = subprocess.run(["bash", CHECK, script, skill], capture_output=True, text=True, timeout=600)
    names = set()
    for l in r.stdout.splitlines():
        if l.startswith("MISS "):
            names.add(l[5:].split(": ", 1)[0].split(" | ", 1)[0])
    # A check that crashed prints no summary: its partial MISS set proves
    # nothing, so it is a case of its own (PR #118 review).
    if not re.search(r"^-- \d+/\d+ checks passed --$", r.stdout, re.M) or "Traceback" in r.stderr:
        names.add("CRASHED")
    return r.returncode, names


tmp = tempfile.mkdtemp(prefix="cepa-at-controls-")
rc, names = run_check(SCRIPT, SKILL)
(ok if rc == 0 and not names else miss)("unmutated copy passes the check" + ("" if not names else ": %s" % sorted(names)))


def one(kind, m):
    name, old, new, want = m
    want = want if want is not None else EXPECT.get(name)
    src = SCRIPT if kind == "script" else SKILL
    text = open(src).read()
    if text.count(old) != 1:
        return name, None, "anchor found %d times" % text.count(old), want
    d = os.path.join(tmp, name)
    os.makedirs(d)
    p = os.path.join(d, os.path.basename(src))
    open(p, "w").write(text.replace(old, new))
    rc, got = run_check(p, SKILL) if kind == "script" else run_check(SCRIPT, p)
    return name, got, None if rc else "check stayed green", want


jobs = [("script", m) for m in MUTANTS] + [("skill", m) for m in SKILL_MUTANTS]
results = {}
with concurrent.futures.ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as ex:
    for name, got, why, want in ex.map(lambda j: one(*j), jobs):
        results[name] = got
        if why:
            miss("%s: %s" % (name, why))
        elif got != want:
            miss("%s: MISS set %s, want %s" % (name, sorted(got), sorted(want or [])))
        else:
            ok(name)

# Each leg has a mutant that only its own cases kill.
for leg in LEGS:
    own = [n for n, got in results.items() if got and all(c.startswith(leg + " ") for c in got)]
    (ok if own else miss)("leg %s has a mutant only its cases kill" % leg)

shutil.rmtree(tmp, ignore_errors=True)
print("-- %d/%d controls passed --" % (passed, passed + failed))
sys.exit(1 if failed else 0)
PY
