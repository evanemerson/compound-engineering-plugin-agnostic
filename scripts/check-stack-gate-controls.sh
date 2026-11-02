#!/usr/bin/env bash
# Controls for scripts/check-stack-gate.sh. Each mutant is one substitution in
# a temp copy of plugins/cepa/scripts/stack-gate.sh. It must turn the check
# red with EXACTLY the MISS cases named beside it (or, for a mutant marked
# None, with at least one MISS), so each mutant shows which case catches it
# and that no other case does. The unmutated copy must run with no MISS line,
# or every red below proves nothing. A mutant whose anchor text is not found
# exactly once is a MISS, never a skip: the shipped script changed shape and
# the mutant needs re-reading.
#
# Every leg of the check (USAGE, CONFIG, COUNT, MEM, RUN, LOCK, LIST,
# COUNTMODE) has at least one mutant here whose exact case set lies inside
# that leg alone; the last control asserts that, so a new leg that also kills
# an old leg's only mutant shows.
#
# STATED LIMITS: a mutant is one substitution; two compensating edits are not
# modeled. The controls prove each named case can fail, not that the case
# list is complete. The LOCK cases use real time (sleeps under 10 s); the
# runs go 3 at a time to keep that timing slack on a loaded runner.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

python3 - <<'PY'
import concurrent.futures, os, re, shutil, subprocess, sys, tempfile

SCRIPT = "plugins/cepa/scripts/stack-gate.sh"
CHECK = "scripts/check-stack-gate.sh"
LIST = "LIST every stack, longest idle first, repo and lane"

# (name, old, new, exact MISS case set, or None for "any MISS")
MUTANTS = [
    # USAGE
    ("wt-not-required", '[[ $cepa_sg_proj == *-wt-* ]] || cepa_sg_usage', 'true || cepa_sg_usage',
     {"USAGE project without -wt-"}),
    ("project-any-text", "^[a-z0-9][a-z0-9_-]{0,63}$", "^.+$", {"USAGE project with shell text"}),
    ("no-dashdash-check", '[ "${1:-}" = -- ] || cepa_sg_usage', 'true || cepa_sg_usage', {"USAGE no --"}),
    ("count-takes-args", '[ $# -eq 0 ] || cepa_sg_usage "--count', 'true || cepa_sg_usage "--count',
     {"USAGE --count with argument"}),
    # CONFIG
    ("octal", "val=$((10#$val))", "val=$((val))", {"CONFIG leading zero is decimal"}),
    ("digits-unbounded", "^[0-9]{1,6}$ ]]; then", "^[0-9]+$ ]]; then",
     {"CONFIG seven digits warns, default kept"}),
    ("conf-sourced", "cepa_sg_read_conf\n\n# --- lock",
     '. "$cepa_sg_conf" 2>/dev/null; cepa_sg_read_conf\n\n# --- lock', {"CONFIG shell text never runs"}),
    ("unknown-key-silent",
     '*) echo "STACK gate: WARN — $cepa_sg_conf line $n: unknown key $key; ignored" >&2; continue ;;',
     "*) continue ;;", {"CONFIG unknown key warns"}),
    ("max-ignored", "max_running) cepa_sg_max=$val ;;", "max_running) ;;", None),
    # COUNT
    ("self-counted", 'grep -cvxF -- "$cepa_sg_proj"', "grep -c .", {"COUNT own running stack not counted"}),
    ("stopped-counted", "--filter status=running \\", "-a \\",
     {"COUNT stopped stacks not counted", "COUNTMODE one line"}),
    ("any-project-counted", "[[ $p == *-wt-* ]] || continue", "true || continue",
     {"COUNT non-wt projects not counted", "COUNTMODE one line"}),
    ("docker-failure-ok", '    return 1\n  }\n  cepa_sg_rows=""', '    return 0\n  }\n  cepa_sg_rows=""',
     {"COUNT docker failure refuses", "COUNTMODE docker failure is unknown"}),
    # MEM
    ("mem-strict", '[ "$cepa_sg_mem" -lt "$cepa_sg_min" ]', '[ "$cepa_sg_mem" -le "$cepa_sg_min" ]',
     {"MEM exactly the minimum passes"}),
    ("mem-unchecked", 'if [ "$cepa_sg_mem" -lt "$cepa_sg_min" ]; then', "if false; then",
     {"MEM below minimum refuses", "CONFIG minimum memory is read"}),
    ("meminfo-failure-ok", 'cepa_sg_refuse "cannot read MemAvailable from', 'true "cannot read MemAvailable from',
     {"MEM missing file refuses", "MEM no MemAvailable line refuses"}),
    # RUN
    ("exit-0", '"$@" {cepa_sg_fd}<&-\nexit $?', '"$@" {cepa_sg_fd}<&-\nexit 0', {"RUN exit code comes through"}),
    ("argv-split", '"$@" {cepa_sg_fd}<&-', '$@ {cepa_sg_fd}<&-', None),
    # LOCK
    ("no-lock", 'flock -w "$cepa_sg_wait" "$cepa_sg_fd" ||', "true ||",
     {"LOCK two starts on one count", "LOCK held lock refuses after the wait"}),
    ("lock-inherited", '"$@" {cepa_sg_fd}<&-', '"$@"', {"LOCK not held by a process the command leaves"}),
    ("wait-ignored", 'flock -w "$cepa_sg_wait"', "flock -w 600", {"LOCK held lock refuses after the wait"}),
    # LIST
    ("shortest-idle-first", "sort -t $'\\t' -k1,1nr", "sort -t $'\\t' -k1,1n", {LIST}),
    ("oldest-container", '[ "$t" -gt "${newest[$p]}" ]', '[ "$t" -lt "${newest[$p]}" ]', {LIST}),
    ("repo-from-project", 'repo="${w%/.claude/worktrees/*}"; repo="${repo##*/}"', 'repo="${proj%%-wt-*}"', {LIST}),
    ("label-uncleaned", "printf '%s' \"${v//[!A-Za-z0-9._\\/-]/?}\"", "printf '%s' \"$v\"",
     {"LIST hostile label prints as ?"}),
    # COUNTMODE
    ("count-creates-dir", 'then shift; cepa_sg_count_mode "$@"; fi',
     'then shift; mkdir -p "$cepa_sg_dir"; cepa_sg_count_mode "$@"; fi', {"COUNTMODE creates nothing"}),
    ("count-locks", 'then shift; cepa_sg_count_mode "$@"; fi',
     'then shift; flock "$cepa_sg_dir" true 2>/dev/null; cepa_sg_count_mode "$@"; fi', {"COUNTMODE takes no lock"}),
    ("count-unknown-exit0", '— $cepa_sg_err"\n    exit 1', '— $cepa_sg_err"\n    exit 0',
     {"COUNTMODE docker failure is unknown"}),
]

src = open(SCRIPT).read()
passed = failed = 0


def run(text):
    d = tempfile.mkdtemp(prefix="cepa-sg-mut-")
    p = os.path.join(d, "stack-gate.sh")
    with open(p, "w") as f:
        f.write(text)
    try:
        r = subprocess.run(["bash", CHECK, p], capture_output=True, text=True, timeout=600)
    finally:
        shutil.rmtree(d, ignore_errors=True)
    cases = set()
    for line in r.stdout.splitlines():
        if line.startswith("MISS "):
            cases.add(line[5:].split(": ", 1)[0])
    return r.returncode, cases, r.stdout


rc, cases, out = run(src)
if rc != 0 or cases:
    print(f"MISS control unmutated copy is red: {sorted(cases)}\n{out}")
    sys.exit(1)
passed += 1

jobs = {}
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as ex:
    for name, old, new, want in MUTANTS:
        if src.count(old) != 1:
            print(f"MISS control {name}: anchor found {src.count(old)} times, want 1")
            failed += 1
            continue
        jobs[name] = (want, ex.submit(run, src.replace(old, new)))
    results = {n: (w, f.result()) for n, (w, f) in jobs.items()}

for name, (want, (rc, cases, out)) in results.items():
    if rc == 0 or not cases:
        print(f"MISS control {name}: mutant stayed green")
        failed += 1
    elif want is not None and cases != want:
        print(f"MISS control {name}: killed {sorted(cases)}, want {sorted(want)}")
        failed += 1
    else:
        passed += 1

LEGS = ["USAGE", "CONFIG", "COUNT", "MEM", "RUN", "LOCK", "LIST", "COUNTMODE"]
for leg in LEGS:
    own = [n for n, (w, _) in results.items()
           if w and all(c.split(" ", 1)[0] == leg for c in w) and results[n][1][1] == w]
    if not own:
        print(f"MISS control leg {leg}: no mutant is killed by this leg's cases alone")
        failed += 1
    else:
        passed += 1

print(f"check-stack-gate-controls: {passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
PY
