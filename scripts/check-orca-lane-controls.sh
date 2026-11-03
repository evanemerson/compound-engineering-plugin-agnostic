#!/usr/bin/env bash
# Controls for scripts/check-orca-lane.sh. Each mutant is one substitution in
# a temp copy of plugins/cepa/scripts/orca-lane.sh (or, for SKILL_MUTANTS, of
# the autonomy skill whose rule 2 lane block the BLOCK leg runs; for
# HELPER_MUTANTS, of orca-lane-reflog.sh, which rm calls). It must turn
# the check red with EXACTLY the MISS cases named beside it, so each mutant
# shows which case catches it and that no other case does.
# The unmutated copy must run with no MISS line, or every red below proves
# nothing. A mutant whose anchor text is not found exactly once is a MISS,
# never a skip: the shipped script changed shape and the mutant needs
# re-reading.
#
# Every leg of the check (FIELDS, SCOPE, READS, CREATE, NAME, RM, HOOKS, BLOCK) has
# at least one mutant here that only its own cases kill; the last control
# asserts that, so a new leg that also kills an old leg's only mutant shows.
# It reads each mutant's calibrated MISS set, not its run: every shard proves
# its own mutants hit exactly that set, so all shards together prove the
# ownership the sets show.
#
# `--shard I/N` runs only mutants I, I+N, I+2N, ... of the one list that holds
# every script, skill and helper mutant in order (no argument means 1/1, every
# mutant). Each shard still runs the unmutated copy and the partition control
# first. CI runs shards 1/N to N/N as N parallel jobs, the same pattern as
# check-orca-nudge-controls.sh (punch-list L42). Controls here fail unless
# residual-integrity.yml runs each shard exactly once, one per job, never
# disabled, and unless every shard of that N is non-empty; planted workflow
# edits prove that check can fail. So a dropped job cannot silently drop
# mutants. Cost history: 4m52s of the one hosted job's 10-minute bound on main
# (run 41585965432); 12m06s with PR #133's HOOKS mutants (run 41588799781,
# cancelled at the bound) — about 10.7s of hosted wall time per check run,
# 4 at a time. The PR #133 body has the per-shard times.
#
# STATED LIMITS: a mutant is one substitution; two compensating edits are not
# modeled. The controls prove each named case can fail, not that the case
# list is complete.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }
shard=1/1
if [[ $# -eq 2 && $1 == --shard ]]; then
  shard=$2
elif [[ $# -ne 0 ]]; then
  echo "MISS usage: $0 [--shard I/N]"; exit 1
fi

CEPA_LANE_CONTROLS_SHARD=$shard python3 - <<'PY'
import concurrent.futures, os, re, shutil, subprocess, sys, tempfile

SCRIPT = "plugins/cepa/scripts/orca-lane.sh"
SKILL = "plugins/cepa/skills/autonomy/SKILL.md"
HELPER = "plugins/cepa/scripts/orca-lane-reflog.sh"
CHECK = "scripts/check-orca-lane.sh"
WORKFLOW = ".github/workflows/residual-integrity.yml"

# (name, old, new, exact MISS case set)
MUTANTS = [
    # FIELDS
    ("cli-any-chars", "''|-*|*[!A-Za-z0-9._/-]*) refuse \"the cli is not a plain command name\" ;;",
     "''|-*) refuse \"the cli is not a plain command name\" ;;", {"FIELDS cli with shell text"}),
    ("name-takes-lane", '[[ $cepa_ln_seen != *" lane "* ]] || refuse "name takes no lane field"', ':',
     {"FIELDS name with lane"}),
    ("rm-takes-base", '[[ $cepa_ln_seen != *" base "* ]] || refuse "rm takes no base field"', ':',
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
    ("rm-reflog-ok", '    1) kept "kept $cepa_ln_lane — HEAD reflog holds a commit that is on no origin ref and not landed',
     '    1) true "kept $cepa_ln_lane — HEAD reflog holds a commit that is on no origin ref and not landed', None),
    ("rm-reflog-unknown-ok", '    *) kept "kept $cepa_ln_lane — HEAD reflog holds a commit no origin ref has, and whether',
     '    *) true "kept $cepa_ln_lane — HEAD reflog holds a commit no origin ref has, and whether', None),
    ("rm-yaml-dirty-ok", '[ -z "$cepa_ln_oy" ] || kept', 'true || kept', None),
    ("rm-yaml-unequal-ok", '[ -n "$cepa_ln_yw" ] && [ "$cepa_ln_yw" = "$cepa_ln_yo" ] \\', 'true \\', None),
    ("rm-landed-line-unchecked", '[ "$cepa_ln_rrc" != 0 ] || [[ $cepa_ln_rlast == "landed: "* ]] || cepa_ln_rrc=99', 'true', None),
    ("confirm-unchecked", '[ "$cepa_ln_f_confirm" = "$cepa_ln_lane" ] || refuse', 'true || refuse', None),
    ("rm-confirm-optional", '[[ $cepa_ln_seen == *" confirm "* ]] || refuse "rm needs a confirm field', 'true || refuse "rm needs a confirm field', None),
    ("name-skip-exit0", '[ "$cepa_ln_skip" = 0 ] || {', 'true || {', None),
    ("resume-any-branch", 'elif [ "$cepa_ln_br" != "$cepa_ln_park" ] && {', 'elif false && {', None),
    ("resume-never", 'elif ! git show-ref --verify -q "refs/heads/$cepa_ln_park"; then cepa_ln_why=',
     'elif true; then cepa_ln_why=', None),
    ("create-no-base-fetch", '  cepa_ln_fetch=\n  timeout -k 2 60 git fetch -q origin "+refs/heads/',
     '  cepa_ln_fetch=\n  true timeout -k 2 60 git fetch -q origin "+refs/heads/', None),
    ("create-no-step0-fetch", 'if [ "$cepa_ln_action" = create ]; then\n  timeout -k 2 60 git fetch',
     'if [ "$cepa_ln_action" = create ]; then\n  true timeout -k 2 60 git fetch', None),
    ("rm-agent-ok", '[ "$cepa_ln_agents" = 0 ] || kept', 'true || kept', None),
    ("rm-force", '--worktree "id:$r_id" --run-hooks --json', '--worktree "id:$r_id" --run-hooks --force --json', None),
    ("rm-unproved", '[ "$w_id" != "$r_id" ] || failed', 'true || failed', None),
    ("rm-hook-ignored", "  removed|unknown) ;;", "  removed|unknown|worktree_archive_hook_failed*) ;;", None),
    ("count-ok", 'if r.get("totalCount") != len(rows) or len(rows) >= LIMIT:', 'if len(rows) >= LIMIT:', None),
    ("rm-git-proof-skipped", '  failed "removal not proved — $r_path is still in git worktree list"',
     '  true "removal not proved — $r_path is still in git worktree list"', None),
    ("rm-not-in-git-ok", '  kept "kept $cepa_ln_lane — $r_path is not in this repo\'s git worktree list"',
     '  true "kept $cepa_ln_lane — $r_path is not in this repo\'s git worktree list"', None),
    ("rm-sidebar-ok", '[ "$w_mode" != fixed ] || [ "$w_name" = "$cepa_ln_lane" ] \\', 'true \\', None),
    ("rm-other-shows-ok", '  elif [ "$w_name" = "$cepa_ln_lane" ]; then', '  elif false; then', None),
    ("rm-no-fetch", 'timeout -k 2 60 git fetch -q --prune origin', 'true timeout -k 2 60 git fetch -q --prune origin', None),
    ("name-dup-ok", 'if grep -qxF -- "$w_base" <<<', 'if false && grep -qxF -- "$w_base" <<<', None),
    ("create-displayname-ok", '[ "$w_base" = "$cepa_ln_lane" ] || [ "$w_name" = "$cepa_ln_lane" ] || continue',
     '[ "$w_base" = "$cepa_ln_lane" ] || continue', None),
    # HOOKS (L76)
    ("hook-unset-implicit-off", 'eff = pol or ("local-only" if loc else "shared-only")', 'eff = pol or "shared-only"', None),
    ("hook-run-both-ok", 'if eff == "run-both" and loc:', 'if False:', None),
    ("hook-local-compare-off", 'elif eff == "local-only" and loc != y:', 'elif False:', None),
    ("hook-unknown-policy-ok", 'if pol is not None and pol not in ("local-only", "run-both", "shared-only"):', 'if False:', None),
    ("hook-yaml-block-ok", 'elif v[0] in "|>[{&*!@`%":', 'elif False:', None),
    ("hook-yaml-dup-ok", "            if found is not None:\n                sys.exit(1)", "            if False:\n                sys.exit(1)", None),
    ("create-hook-unchecked", "|| kept \"not created — Orca's saved hook settings shadow orca.yaml:",
     "|| true \"not created — Orca's saved hook settings shadow orca.yaml:", None),
    ("rm-hook-unchecked", "|| kept \"kept $cepa_ln_lane — Orca's saved hook settings shadow orca.yaml:",
     "|| true \"kept $cepa_ln_lane — Orca's saved hook settings shadow orca.yaml:", None),
    ("hook-toplevel-any", '                if not re.match(r"[A-Za-z_][A-Za-z0-9_-]*\\s*:(\\s|$)", s):',
     '                if False:', None),
    ("hook-indented-doc-ok", "            if not top:\n                sys.exit(1)", "            if False:\n                sys.exit(1)", None),
    ("hook-null-ok", 'if re.fullmatch(r"(?i)~|null', 'if False and re.fullmatch(r"(?i)~|null', None),
    ("hook-python-strip", "loc = loc.strip(JS_WS)", "loc = loc.strip()", None),
    ("post-park-hook-unchecked", '  [ "$cepa_ln_hook" = ok ] \\\n    || failed "the lane is created and parked',
     '  true \\\n    || failed "the lane is created and parked', None),
    ("ls-remote-ignored", '[ "$cepa_ln_lrc" != 2 ] || kept', 'true || kept', None),
    ("hook-output-relayed", 'print(code, x if type(x) is int else "?")',
     'print(code, x if type(x) is int else "?", (data.get("output") or "")[:80])', None),
]
SKILL_MUTANTS = [
    ("block-unquoted", "orca-lane.sh\" <<'CEPA_FIELDS' || true", "orca-lane.sh\" <<CEPA_FIELDS || true", None),
]
HELPER_MUTANTS = [
    ("helper-ancestor-unchecked", 'if git -C "$lp" merge-base --is-ancestor "$s" "${nh#*:}" 2>/dev/null; then ok[$s]=1',
     'if true; then ok[$s]=1', None),
    ("helper-base-unchecked", '$st == MERGED && $bb == "$dflt" &&', '$st == MERGED &&', None),
    ("helper-fork-ok", '$h =~ ^[0-9a-f]{40}$ && $x == false ]]', '$h =~ ^[0-9a-f]{40}$ ]]', None),
    ("helper-merge-guard-off", '  [ -z "$m" ]\n}', '  true\n}', None),
    ("helper-no-amend-rule", 'if [ -n "$a" ] && {', 'if false && {', None),
    ("helper-no-default-patch", 'patch_in "refs/remotes/origin/$dflt" "$s" || {', 'false || {', None),
    ("helper-gh-failure-ok", '    || { echo "unknown — gh pr list failed for branch $b"; exit 3; }', '    || true', None),
]
LEGS = ["FIELDS", "SCOPE", "READS", "CREATE", "NAME", "RM", "HOOKS", "BLOCK"]

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
    "rm-agent-ok": {"RM live agent"},
    "rm-force": {"RM exact rm argv (no --force, no waiver)"},
    "rm-unproved": {"RM reply says removed but lane stays"},
    "rm-hook-ignored": {"RM archive hook fails"},
    # Unquoted, the heredoc no longer matches the fill, so <cli> stays and
    # every BLOCK case that fills it goes red.
    "count-ok": {"READS listcount is UNKNOWN for create", "READS listcount is UNKNOWN for name",
                 "READS listcount is UNKNOWN for rm"},
    "rm-reflog-unknown-ok": {"RM gh fails", "RM helper exits 0 without a landed line"},
    "rm-yaml-dirty-ok": {"RM main orca.yaml uncommitted"},
    "confirm-unchecked": {"FIELDS rm confirm differs"},
    "rm-confirm-optional": {"FIELDS rm without confirm"},
    "name-skip-exit0": {"NAME a skip ends with an Ending line", "NAME renames automatic non-main lanes only",
                        "NAME second run is a no-op", "NAME skips a name another lane shows"},
    "resume-any-branch": {"CREATE does not resume a lane on another branch", "CREATE refused resume deletes nothing"},
    # The refusal then names another reason, so the on-another-branch case
    # reads red too.
    "resume-never": {"CREATE does not resume a lane on another branch", "HOOKS a resume onto a shadow fails",
                     "CREATE resume parks detached and deletes the park branch",
                     "CREATE resumes a lane detached at its park tip", "CREATE resumes a lane left on its park branch"},
    "create-no-base-fetch": {"CREATE re-fetches a stale origin/base"},
    "rm-reflog-ok": {"RM reflog-only commit", "RM unpushed commit the PR head lacks", "RM branch with no merged PR",
                     "RM PR into another base", "RM fork PR", "RM merge commit whose parent landed"},
    "rm-yaml-unequal-ok": {"RM main orca.yaml unpushed", "RM main orca.yaml edited under skip-worktree"},
    "rm-landed-line-unchecked": {"RM helper exits 0 without a landed line"},
    # The amend case then counts its old commit under rule 1, not rule 3.
    "helper-ancestor-unchecked": {"RM unpushed commit the PR head lacks", "RM amended-away commit"},
    "helper-base-unchecked": {"RM PR into another base"},
    "helper-fork-ok": {"RM fork PR"},
    "helper-merge-guard-off": {"RM merge commit whose parent landed"},
    "helper-no-amend-rule": {"RM amended-away commit"},
    "helper-no-default-patch": {"RM detached commit landed as an equal patch"},
    "helper-gh-failure-ok": {"RM gh fails"},
    "rm-git-proof-skipped": {"RM Orca drops the row but git keeps the worktree"},
    "rm-not-in-git-ok": {"RM row not in git worktree list"},
    "rm-sidebar-ok": {"RM fixed sidebar name differs"},
    "rm-other-shows-ok": {"RM another lane shows the name"},
    "rm-no-fetch": {"RM stale origin ref does not vouch"},
    "name-dup-ok": {"NAME skips a name another lane shows"},
    "create-displayname-ok": {"CREATE name taken as a display name only"},
    "hook-output-relayed": {"RM archive hook fails"},
    "hook-unset-implicit-off": {"HOOKS unset with a local script refuses", "HOOKS rm unset with a local archive refuses",
                                "HOOKS a local script Python would strip but JS keeps refuses"},
    "hook-run-both-ok": {"HOOKS run-both with a local script refuses"},
    # An unset policy with a local script is local-only, so its cases go red too.
    "hook-local-compare-off": {"HOOKS local-only differing refuses", "HOOKS local-only empty refuses",
                               "HOOKS a local script Python would strip but JS keeps refuses",
                               "HOOKS a resume onto a shadow fails",
                               "HOOKS checks origin's current orca.yaml, not a stale local ref",
                               "HOOKS unset with a local script refuses", "HOOKS rm local-only empty archive refuses",
                               "HOOKS rm unset with a local archive refuses"},
    "hook-unknown-policy-ok": {"HOOKS unknown policy refuses", "HOOKS rm unknown shape refuses"},
    # A block scalar is also caught by the continuation-line check; only a
    # flow value reaches this guard alone.
    "hook-yaml-block-ok": {"HOOKS orca.yaml flow value"},
    "hook-yaml-dup-ok": {"HOOKS orca.yaml duplicate key"},
    "create-hook-unchecked": {"HOOKS local-only differing refuses", "HOOKS local-only empty refuses",
                              "HOOKS a local script Python would strip but JS keeps refuses",
                              "HOOKS checks origin's current orca.yaml, not a stale local ref",
                              "HOOKS unset with a local script refuses", "HOOKS run-both with a local script refuses"},
    # The reader-shape cases push their orca.yaml from another clone, so
    # without step 0 the pre-create check reads the stale plain one and the
    # post-park check then fails them (exit 3) instead of refusing.
    "create-no-step0-fetch": {"HOOKS checks origin's current orca.yaml, not a stale local ref",
                              "HOOKS a base origin lacks refuses", "HOOKS a failed fetch refuses",
                              "HOOKS orca.yaml BOM refuses", "HOOKS orca.yaml indented document refuses",
                              "HOOKS orca.yaml null value refuses", "HOOKS orca.yaml quoted top-level key refuses"},
    "hook-toplevel-any": {"HOOKS orca.yaml BOM refuses", "HOOKS orca.yaml quoted top-level key refuses"},
    "hook-indented-doc-ok": {"HOOKS orca.yaml indented document refuses"},
    "hook-null-ok": {"HOOKS orca.yaml null value refuses"},
    "hook-python-strip": {"HOOKS a local script Python would strip but JS keeps refuses"},
    "post-park-hook-unchecked": {"HOOKS a resume onto a shadow fails"},
    "ls-remote-ignored": {"HOOKS a base origin lacks refuses"},
    "rm-hook-unchecked": {"HOOKS rm local-only empty archive refuses", "HOOKS rm unset with a local archive refuses"},
    "block-unquoted": {"BLOCK shell text in the lane runs nothing", "BLOCK runs name",
                       "BLOCK quoted heredoc holds cli, action, lane, base, confirm"},
}

passed = failed = 0


def ok(m):
    global passed
    passed += 1


def miss(m):
    global failed
    failed += 1
    print("MISS " + m)


def run_check(script, skill, helper=HELPER):
    r = subprocess.run(["bash", CHECK, script, skill, helper], capture_output=True, text=True, timeout=600)
    names = set()
    for l in r.stdout.splitlines():
        if l.startswith("MISS "):
            names.add(l[5:].split(": ", 1)[0].split(" | ", 1)[0])
    # A check that crashed prints no summary: its partial MISS set proves
    # nothing, so it is a case of its own (PR #118 review).
    if not re.search(r"^-- \d+/\d+ checks passed --$", r.stdout, re.M) or "Traceback" in r.stderr:
        names.add("CRASHED")
    return r.returncode, names


jobs = [("script", m) for m in MUTANTS] + [("skill", m) for m in SKILL_MUTANTS] + \
       [("helper", m) for m in HELPER_MUTANTS]
spec = os.environ.get("CEPA_LANE_CONTROLS_SHARD", "1/1")
sm = re.fullmatch(r"([1-9][0-9]?)/([1-9][0-9]?)", spec)
if not sm or int(sm.group(1)) > int(sm.group(2)):
    print("MISS --shard is %r, want I/N with 1 <= I <= N" % spec)
    sys.exit(1)
SHARD, NSHARDS = int(sm.group(1)), int(sm.group(2))


def shard_of(i, n):
    return i % n + 1


# Names must be unique: each result, and each mutant's temp dir, is keyed by
# name. Shard membership comes from the list index, not the name.
mnames = [m[0] for _, m in jobs]
dup = sorted({n for n in mnames if mnames.count(n) > 1})
(ok if not dup else miss)("mutant names are unique" + ("" if not dup else ": %r" % dup[:3]))


def shard_split(n):
    """The mutant names each of shards 1..n runs, as a list of n lists."""
    return [[x for i, x in enumerate(mnames) if shard_of(i, n) == s] for s in range(1, n + 1)]


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
            if "check-orca-lane-controls.sh" not in line or line.lstrip().startswith("#"):
                continue
            m = re.fullmatch(r"        run: bash scripts/check-orca-lane-controls\.sh --shard (\S+)", line)
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
(ok if not probs else miss)("%s runs shards 1/%d to %d/%d, one per job, each once%s"
                            % (WORKFLOW, want_n, want_n, want_n, "" if not probs else ": " + "; ".join(probs)))
# The shards of that N and of this run's N each partition the mutants, and no
# shard is empty: an empty shard passes on its baseline alone.
for n in sorted({want_n or 1, NSHARDS}):
    parts = shard_split(n)
    (ok if sorted(sum(parts, [])) == sorted(mnames) and all(parts) else miss)(
        "shards of N=%d partition the %d mutants, none empty: sizes %r" % (n, len(mnames), [len(x) for x in parts]))
# Planted workflow edits, checked in process: each must make wf_problems red.
J2, J4 = "\n  orca-lane-2:\n", "\n  orca-lane-4:\n"
R4 = "        run: bash scripts/check-orca-lane-controls.sh --shard 4/4\n"
WF_PLANTS = [
    ("two shards in one job", J2, "\n"),
    ("job-level if: false", J4, J4 + "    if: false\n"),
    ("continue-on-error on a job", J4, J4 + "    continue-on-error: true\n"),
    # From the shard 4 job header to the next job header, so the job goes
    # and every other job stays.
    ("shard 4 job deleted", (lambda a: wf[a:a + len(J4) + re.search(
        r"(?m)^  (?=[A-Za-z0-9_-]+:[ \t]*$)|\Z", wf[a + len(J4):]).start()] if a >= 0 else J4)(wf.find(J4)), "\n"),
    ("shard 4 run line commented out", R4, "        # run: bash scripts/check-orca-lane-controls.sh --shard 4/4\n"),
    ("shard 4 run line in a block scalar", R4,
     "        run: |\n          bash scripts/check-orca-lane-controls.sh --shard 4/4\n"),
    ("shard 4 run line with || true", R4, R4[:-1] + " || true\n"),
    ("a quoted mention beside the shard 4 run line", R4,
     R4 + "      - run: echo bash scripts/check-orca-lane-controls.sh --shard 4/4\n"),
    ("shard 2 step without if: always()",
     "        if: always()\n        run: bash scripts/check-orca-lane-controls.sh --shard 2/4\n",
     "        run: bash scripts/check-orca-lane-controls.sh --shard 2/4\n"),
]
for label, old, new in WF_PLANTS:
    if wf.count(old) != 1:
        miss("workflow plant %r: anchor found %d times, want 1" % (label, wf.count(old)))
    else:
        (ok if wf_problems(wf.replace(old, new))[0] else miss)("workflow plant goes red: %s" % label)

# Every shard runs the unmutated copy first: a red mutant proves nothing in a
# job whose own baseline is not clean.
tmp = tempfile.mkdtemp(prefix="cepa-lane-controls-")
rc, names = run_check(SCRIPT, SKILL)
(ok if rc == 0 and not names else miss)("unmutated copy passes the check" + ("" if not names else ": %s" % sorted(names)))


def one(kind, m):
    name, old, new, want = m
    want = want if want is not None else EXPECT.get(name)
    src = {"script": SCRIPT, "skill": SKILL, "helper": HELPER}[kind]
    text = open(src).read()
    if text.count(old) != 1:
        return name, None, "anchor found %d times" % text.count(old), want
    d = os.path.join(tmp, name)
    os.makedirs(d)
    p = os.path.join(d, os.path.basename(src))
    open(p, "w").write(text.replace(old, new))
    rc, got = {"script": lambda: run_check(p, SKILL), "skill": lambda: run_check(SCRIPT, p),
               "helper": lambda: run_check(SCRIPT, SKILL, p)}[kind]()
    return name, got, None if rc else "check stayed green", want


mine = [j for i, j in enumerate(jobs) if shard_of(i, NSHARDS) == SHARD]
with concurrent.futures.ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as ex:
    for name, got, why, want in ex.map(lambda j: one(*j), mine):
        if why:
            miss("%s: %s" % (name, why))
        elif got != want:
            miss("%s: MISS set %s, want %s" % (name, sorted(got), sorted(want or [])))
        else:
            ok(name)

# Each leg has a mutant that only its own cases kill. Every shard reads the
# calibrated sets of all mutants, so it runs the same in every shard; the run
# above proves this shard's mutants hit exactly their sets.
wants = {m[0]: (m[3] if m[3] is not None else EXPECT.get(m[0])) for _, m in jobs}
for leg in LEGS:
    own = [n for n, want in wants.items() if want and all(c.startswith(leg + " ") for c in want)]
    (ok if own else miss)("leg %s has a mutant only its cases kill" % leg)

shutil.rmtree(tmp, ignore_errors=True)
print("-- shard %d/%d: %d of %d mutants; %d/%d controls passed --"
      % (SHARD, NSHARDS, len(mine), len(jobs), passed, passed + failed))
sys.exit(1 if failed else 0)
PY
