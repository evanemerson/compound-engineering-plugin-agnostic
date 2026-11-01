#!/usr/bin/env bash
# Controls for scripts/check-orca-lane.sh. Each mutant is one substitution in
# a temp copy of plugins/cepa/scripts/orca-lane.sh (or, for SKILL_MUTANTS, of
# the autonomy skill whose rule 2 lane block the BLOCK leg runs). It must turn
# the check red with EXACTLY the MISS cases named beside it, so each mutant
# shows which case catches it and that no other case does.
# The unmutated copy must run with no MISS line, or every red below proves
# nothing. A mutant whose anchor text is not found exactly once is a MISS,
# never a skip: the shipped script changed shape and the mutant needs
# re-reading.
#
# Every leg of the check (FIELDS, SCOPE, READS, CREATE, NAME, RM, BLOCK) has
# at least one mutant here that only its own cases kill; the last control
# asserts that, so a new leg that also kills an old leg's only mutant shows.
#
# STATED LIMITS: a mutant is one substitution; two compensating edits are not
# modeled. The controls prove each named case can fail, not that the case
# list is complete.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

python3 - <<'PY'
import concurrent.futures, os, re, shutil, subprocess, sys, tempfile

SCRIPT = "plugins/cepa/scripts/orca-lane.sh"
SKILL = "plugins/cepa/skills/autonomy/SKILL.md"
CHECK = "scripts/check-orca-lane.sh"

# (name, old, new, exact MISS case set)
MUTANTS = [
    # FIELDS
    ("cli-any-chars", "''|-*|*[!A-Za-z0-9._/-]*) refuse \"the cli is not a plain command name\" ;;",
     "''|-*) refuse \"the cli is not a plain command name\" ;;", {"FIELDS cli with shell text"}),
    ("name-takes-lane", '[[ $cepa_ln_seen != *" lane "* ]] || refuse "name takes no lane field"', ':',
     {"FIELDS name with lane"}),
    ("rm-takes-base", '[[ $cepa_ln_seen != *" base "* ]] || refuse "rm takes no base field" ;;', ';;',
     {"FIELDS rm with base"}),
    ("lane-loose", "cepa_ln_wt_re='^[A-Za-z0-9_]+(-[A-Za-z0-9_]+)*$'", "cepa_ln_wt_re='^[A-Za-z0-9_-]+$'",
     {"FIELDS lane double dash", "FIELDS lane leading dash"}),
    ("linked-caller", '[ "$cepa_ln_gd" = "$cepa_ln_cd" ] || refuse', 'true || refuse',
     {"FIELDS linked worktree caller"}),
    ("extra-line", '[ -z "${cepa_ln_rest//[[:space:]]/}" ] || refuse', 'true || refuse',
     {"FIELDS line after fields"}),
    # SCOPE
    ("distro-any", "if not distro or m.group(1) != distro:", "if not distro:",
     {"SCOPE another distro's path is UNKNOWN"}),
    ("list-unscoped", 'worktree list --repo "id:$cepa_ln_rid" --limit 500 --json', 'worktree list --limit 500 --json',
     None),
    # READS
    ("truncated-ok", 'if not isinstance(rows, list) or r.get("truncated") is not False:',
     'if not isinstance(rows, list):', None),
    ("omitted-ok", 'if hs.get("omittedHostIds") != []:', 'if False:', None),
    ("ps-failure-ok", '"kept $cepa_ln_lane — worktree ps failed, so a live agent cannot be ruled out"',
     'true', None),
    # CREATE
    ("setup-run", "--no-parent --setup inherit --json", "--no-parent --setup run --json", {"CREATE exact create argv"}),
    ("basename-unchecked", '[ "${c_path##*/}" = "$cepa_ln_lane" ] \\', 'true \\', None),
    ("branch-unchecked", '[ "$cepa_ln_br" = "$cepa_ln_park" ] \\', 'true \\', None),
    ("ahead-unchecked", '[ "$cepa_ln_ahead" = 0 ] \\', 'true \\', None),
    ("park-exists-ok", '! git show-ref --verify -q "refs/heads/$cepa_ln_park" \\', 'true \\', None),
    ("show-unchecked", '[ "$cepa_ln_shown" = "$cepa_ln_lane fixed" ] \\', 'true \\', None),
    # NAME
    ("name-renames-main", '[ -n "$w_id" ] && [ "$w_main" = 0 ] || continue\n    if [ "$w_mode" = fixed ]',
     '[ -n "$w_id" ] || continue\n    if [ "$w_mode" = fixed ]', None),
    ("name-unverified", '[ "$cepa_ln_hit" = "fixed $d_base" ] \\', 'true \\', None),
    # RM
    ("rm-dirty-ok", '[ -z "$cepa_ln_st" ] || kept', 'true || kept', None),
    ("rm-reflog-ok", '[ -z "$cepa_ln_lost" ] || kept', 'true || kept', None),
    ("rm-agent-ok", '[ "$cepa_ln_agents" = 0 ] || kept', 'true || kept', None),
    ("rm-force", '--worktree "id:$r_id" --run-hooks --json', '--worktree "id:$r_id" --run-hooks --force --json', None),
    ("rm-unproved", '[ "$w_id" != "$r_id" ] || failed', 'true || failed', None),
    ("rm-hook-ignored", "  removed|unknown) ;;", "  removed|unknown|worktree_archive_hook_failed*) ;;", None),
]
SKILL_MUTANTS = [
    ("block-unquoted", "orca-lane.sh\" <<'CEPA_FIELDS' || true", "orca-lane.sh\" <<CEPA_FIELDS || true", None),
]
LEGS = ["FIELDS", "SCOPE", "READS", "CREATE", "NAME", "RM", "BLOCK"]

# Calibrated sets for the mutants written None above (kept apart so each
# mutant line stays readable). Measured by running this file, then read.
EXPECT = {
    "list-unscoped": {"SCOPE list is scoped by repo id"},
    "truncated-ok": {"READS listpartial is UNKNOWN for name", "READS listpartial is UNKNOWN for rm",
                     "READS listpartial is UNKNOWN for create", "READS pspartial keeps the lane"},
    "omitted-ok": {"READS listomitted is UNKNOWN for name", "READS listomitted is UNKNOWN for rm",
                   "READS listomitted is UNKNOWN for create"},
    "ps-failure-ok": {"READS psfail keeps the lane"},
    "basename-unchecked": {"CREATE suffixed path kept"},
    "branch-unchecked": {"CREATE suffixed branch kept"},
    "ahead-unchecked": {"CREATE park branch with a commit kept", "CREATE park branch with a commit not deleted"},
    "park-exists-ok": {"CREATE park branch exists"},
    "show-unchecked": {"CREATE stale show"},
    "name-renames-main": {"NAME renames automatic non-main lanes only", "NAME set by full id only",
                          "NAME second run is a no-op", "BLOCK runs name", "SCOPE name never renames another repo's lane"},
    "name-unverified": {"NAME set that does not stick"},
    "rm-dirty-ok": {"RM untracked file", "RM tracked change"},
    "rm-reflog-ok": {"RM reflog-only commit"},
    "rm-agent-ok": {"RM live agent"},
    "rm-force": {"RM exact rm argv (no --force, no waiver)"},
    "rm-unproved": {"RM reply says removed but lane stays"},
    "rm-hook-ignored": {"RM archive hook fails"},
    # Unquoted, the heredoc no longer matches the fill, so <cli> stays and
    # every BLOCK case that fills it goes red.
    "block-unquoted": {"BLOCK shell text in the lane runs nothing", "BLOCK runs name",
                       "BLOCK quoted heredoc holds cli, action, lane, base"},
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
    return r.returncode, names


tmp = tempfile.mkdtemp(prefix="cepa-lane-controls-")
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
