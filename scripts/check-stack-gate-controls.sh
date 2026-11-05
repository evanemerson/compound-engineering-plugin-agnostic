#!/usr/bin/env bash
# Controls for scripts/check-stack-gate.sh. Each mutant is one substitution in
# a temp copy of plugins/cepa/scripts/stack-gate.sh. It must turn the check
# red with EXACTLY the MISS cases named beside it (or, for a mutant marked
# None, with at least one MISS and the check's summary line — a crashed check
# counts as a failed control, never a kill), so each mutant shows which case
# catches it
# and that no other case does. The unmutated copy must run with no MISS line,
# or every red below proves nothing. A mutant whose anchor text is not found
# exactly once is a MISS, never a skip: the shipped script changed shape and
# the mutant needs re-reading.
#
# Every leg of the check (USAGE, CONFIG, COUNT, MEM, RUN, LOCK, LIST,
# COUNTMODE, BUILD) has at least one mutant here whose exact case set lies inside
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
    ("conf-sourced", 'cepa_sg_read_conf || cepa_sg_refuse "cannot read the config',
     '. "$cepa_sg_conf" 2>/dev/null; cepa_sg_read_conf || cepa_sg_refuse "cannot read the config',
     {"CONFIG shell text never runs"}),
    ("conf-unreadable-ok", 'is not a readable file"\n    return 1', 'is not a readable file"\n    return 0',
     {"BUILD unreadable config refuses", "CONFIG unreadable file refuses", "COUNTMODE unreadable config is unknown"}),
    ("unknown-key-silent",
     '*) echo "STACK gate: WARN — $cepa_sg_conf line $n: unknown key $key; ignored" >&2; continue ;;',
     "*) continue ;;", {"CONFIG unknown key warns"}),
    ("max-ignored", "max_running) cepa_sg_max=$val ;;", "max_running) ;;", None),
    # COUNT
    ("self-counted", 'grep -cvxF -- "$cepa_sg_proj"', "grep -c .", {"COUNT own running stack not counted"}),
    ("stopped-counted", "--filter status=running --filter status=paused --filter status=restarting \\", "-a \\",
     {"COUNT stopped stacks not counted", "COUNTMODE one line", "COUNT paused and restarting stacks count"}),
    ("paused-not-counted", "--filter status=running --filter status=paused --filter status=restarting \\",
     "--filter status=running \\", {"COUNT paused and restarting stacks count"}),
    ("ids-truncated", "docker ps --no-trunc \\", "docker ps \\", None),
    ("any-project-counted", "[[ $p == *-wt-* ]] || continue", "true || continue",
     {"COUNT non-wt projects not counted", "COUNTMODE one line"}),
    ("docker-failure-ok", '    rm -f "$err"\n    return 1\n  fi', '    rm -f "$err"\n    return 0\n  fi', None),
    # MEM
    ("mem-strict", '[ "$cepa_sg_mem" -lt "$cepa_sg_min" ]', '[ "$cepa_sg_mem" -le "$cepa_sg_min" ]',
     {"MEM exactly the minimum passes"}),
    ("mem-unchecked", 'if [ "$cepa_sg_mem" -lt "$cepa_sg_min" ]; then', "if false; then",
     {"MEM below minimum refuses", "CONFIG minimum memory is read"}),
    ("meminfo-failure-ok", 'cepa_sg_refuse "cannot read MemAvailable from', 'true "cannot read MemAvailable from',
     {"MEM missing file refuses", "MEM no MemAvailable line refuses"}),
    # RUN
    ("exit-0", 'command "$@" {cepa_sg_fd}<&-\nexit $?', 'command "$@" {cepa_sg_fd}<&-\nexit 0',
     {"RUN exit code comes through"}),
    ("argv-split", 'command "$@" {cepa_sg_fd}<&-', 'command $@ {cepa_sg_fd}<&-', None),
    # LOCK
    ("no-lock", 'flock -w "$cepa_sg_wait" "$cepa_sg_fd"\n', "true\n",
     {"LOCK two starts on one count", "LOCK held lock refuses after the wait",
      "LOCK nested gate for another project waits"}),
    ("lock-inherited", 'command "$@" {cepa_sg_fd}<&-', 'command "$@" ', {"LOCK not held by a process the command leaves"}),
    ("nested-not-exported", 'CEPA_STACK_GATE_HELD="$cepa_sg_proj" command "$@"', 'command "$@"',
     {"LOCK nested gate for the same project runs"}),
    ("nested-any-project", 'if [ "${CEPA_STACK_GATE_HELD:-}" = "$cepa_sg_proj" ]; then',
     'if [ -n "${CEPA_STACK_GATE_HELD:-}" ]; then', {"LOCK nested gate for another project waits"}),
    ("wait-silent", 'echo "STACK gate: waiting up to ${cepa_sg_wait}s', 'true "STACK gate: waiting up to ${cepa_sg_wait}s',
     {"LOCK a waiting start says so"}),
    ("home-unchecked", 'if [ -z "${HOME:-}" ]; then', 'if false; then', {"USAGE HOME unset"}),
    ("wait-ignored", 'flock -w "$cepa_sg_wait"', "flock -w 600",
     {"LOCK held lock refuses after the wait", "LOCK nested gate for another project waits"}),
    # LIST
    ("shortest-idle-first", "-k1,1n -k2,2nr", "-k1,1n -k2,2n", {LIST}),
    ("unknown-idle-last", "-k1,1n -k2,2nr", "-k1,1nr -k2,2nr", {"LIST unreadable start time sorts first"}),
    ("inspect-failure-silent", 'note=" (docker inspect failed: idle times unknown)"', 'note=""',
     {"LIST inspect failure is said"}),
    ("oldest-container", '[ "$t" -gt "${newest[$p]}" ]', '[ "$t" -lt "${newest[$p]}" ]', {LIST}),
    ("repo-from-project", 'repo="${w%/.claude/worktrees/*}"; repo="${repo##*/}"', 'repo="${proj%%-wt-*}"', {LIST}),
    ("label-uncleaned", "printf '%s' \"${v//[!A-Za-z0-9._\\/-]/?}\"", "printf '%s' \"$v\"",
     {"LIST hostile label prints as ?"}),
    # COUNTMODE
    ("count-creates-dir", 'then shift; cepa_sg_count_mode "$@"; fi',
     'then shift; mkdir -p "$cepa_sg_dir"; cepa_sg_count_mode "$@"; fi', {"COUNTMODE creates nothing"}),
    ("count-locks", 'then shift; cepa_sg_count_mode "$@"; fi',
     'then shift; flock "$cepa_sg_dir" true 2>/dev/null; cepa_sg_count_mode "$@"; fi', {"COUNTMODE takes no lock"}),
    ("count-unknown-exit0", 'if ! cepa_sg_read_running; then\n    echo "STACK count: running=unknown limit=$cepa_sg_max — $cepa_sg_err"\n    exit 1',
     'if ! cepa_sg_read_running; then\n    echo "STACK count: running=unknown limit=$cepa_sg_max — $cepa_sg_err"\n    exit 0',
     {"COUNTMODE docker failure is unknown"}),
    # BUILD (L70 item 1)
    ("build-never-skips", 'elif why=$(cepa_sg_images_exist "$@"); then',
     'elif why=$(cepa_sg_images_exist "$@"; false); then',
     {"BUILD a failed build is built again, a success clears it", "BUILD a missing pull-only image does not build",
      "BUILD a project with nothing to build skips, no lock", "BUILD skip when every image exists, no lock"}),
    ("build-checks-first-only", '--format \'{{.Id}}\' -- "${imgs[@]}"', '--format \'{{.Id}}\' -- "${imgs[0]}"',
     {"BUILD a missing image builds", "BUILD a missing pull-only image does not build",
      "BUILD a service\'s image key is the name read"}),
    ("build-no-services-skips", 'if not c["services"]:\n    sys.exit(1)\n', "", {"BUILD an empty image list builds"}),
    ("build-nothing-builds", '''so there is nothing to build"
    return 0''', '''so there is nothing to build"
    return 1''', {"BUILD a project with nothing to build skips, no lock"}),
    ("build-skip-on-unreadable", '''    echo "the image list cannot be read (compose config or python3 failed)"
    return 1''', '''    echo "the image list cannot be read (compose config or python3 failed)"
    return 0''', {"BUILD an unreadable image list builds", "BUILD a read that fails after its output builds",
                   "BUILD no python3 builds", "BUILD output that is not JSON builds", "BUILD no project name builds",
                   "BUILD no services key builds", "BUILD a service that is not a mapping builds",
                   "BUILD an empty image list builds"}),
    # L75: only services with a `build:` section, by their real names.
    ("build-lists-pull-only", 'if "build" in body.keys():', 'if True:',
     {"BUILD a failed build is built again, a success clears it", "BUILD a missing pull-only image does not build", "BUILD a waiter skips once the same project was built",
      "BUILD a project with nothing to build skips, no lock", "BUILD skip when every image exists, no lock"}),
    ("build-env-resolved", 'config --no-env-resolution --format json 2>', 'config --format json 2>',
     {"BUILD a failed build is built again, a success clears it", "BUILD a missing pull-only image does not build",
      "BUILD a name that is not a plain reference builds", "BUILD a project with nothing to build skips, no lock",
      "BUILD a waiter skips once the same project was built", "BUILD skip when every image exists, no lock"}),
    ("build-only-fixed-images", 'if "build" in body.keys():', 'if "build" in body.keys() and body.get("image"):',
     {"BUILD a default name with pull-only images present builds", "BUILD a killed build leaves its marker",
      "BUILD a missing image builds", "BUILD a missing pull-only image does not build",
      "BUILD a waiter skips once the same project was built", "BUILD a waiting build says so, default 3600 s",
      "BUILD build lock and start lock are separate", "BUILD exit code comes through",
      "BUILD held build lock refuses after the wait", "BUILD lock outlives a gate killed mid-build",
      "BUILD skip when every image exists, no lock", "BUILD two builds run one at a time",
      "BUILD unreadable config refuses"}),
    ("build-no-pipefail", 'set -o pipefail\n', 'true\n', {"BUILD a read that fails after its output builds"}),
    ("build-image-key-ignored", 'print(body.get("image") or name + "-" + service)', 'print(name + "-" + service)',
     {"BUILD a missing pull-only image does not build", "BUILD a name that is not a plain reference builds",
      "BUILD a service's image key is the name read"}),
    ("build-default-name-wrong", 'name + "-" + service', 'name + "_" + service',
     {"BUILD a failed build is built again, a success clears it", "BUILD a missing pull-only image does not build", "BUILD a waiter skips once the same project was built", "BUILD skip when every image exists, no lock"}),
    ("build-non-mapping-passes", '"build" in body.keys()', '"build" in body',
     {"BUILD a service that is not a mapping builds"}),
    ("build-probe-no-project", '    COMPOSE_PROJECT_NAME="$cepa_sg_proj" timeout --foreground -k 2 60 "$@" config', '    COMPOSE_PROJECT_NAME= timeout --foreground -k 2 60 "$@" config',
     {"BUILD a failed build is built again, a success clears it", "BUILD a missing pull-only image does not build",
      "BUILD a waiter skips once the same project was built", "BUILD skip when every image exists, no lock"}),
    ("rebuild-skips", 'if [ "$cepa_sg_mode" = --rebuild ]; then', 'if false; then',
     {"BUILD --rebuild always builds", "BUILD a failed build is built again, a success clears it"}),
    ("build-exit-0", '  exit "$brc"\n}', '  exit 0\n}',
     {"BUILD exit code comes through", "BUILD a failed build is built again, a success clears it"}),
    ("build-no-lock", 'flock -w "$cepa_sg_bwait" "$cepa_sg_bfd"\n', "true\n",
     {"BUILD a waiter skips once the same project was built", "BUILD held build lock refuses after the wait", "BUILD lock outlives a gate killed mid-build", "BUILD two builds run one at a time"}),
    ("build-wait-silent", 'echo "STACK build: waiting up to', 'true "STACK build: waiting up to',
     {"BUILD a waiting build says so, default 3600 s"}),
    ("build-wait-600", "cepa_sg_bwait=3600", "cepa_sg_bwait=600",
     {"BUILD a waiting build says so, default 3600 s"}),
    ("build-on-start-lock", 'exec {cepa_sg_bfd}>>"$cepa_sg_block"', 'exec {cepa_sg_bfd}<"$cepa_sg_dir"',
     {"BUILD build lock and start lock are separate", "BUILD held build lock refuses after the wait"}),
    ("build-lock-not-inherited", 'command "$@" build\n', 'command "$@" build {cepa_sg_bfd}>&-\n',
     {"BUILD lock outlives a gate killed mid-build"}),
    ("build-marker-ignored", 'elif [ -e "$cepa_sg_bmark" ]; then', 'elif false; then',
     {"BUILD a failed build is built again, a success clears it"}),
    ("build-marker-after", ': >"$cepa_sg_bmark" 2>/dev/null ||', 'true ||',
     {"BUILD a killed build leaves its marker", "BUILD a failed build is built again, a success clears it"}),
    ("build-waiter-no-recheck", 'if [ "$waited" = yes ] && [ "$cepa_sg_mode" = --build ]', 'if false',
     {"BUILD a waiter skips once the same project was built"}),
    ("build-plain-ref-skipped", 'echo "an image name is not a plain reference"\n      return 1',
     'echo "an image name is not a plain reference"\n      continue',
     {"BUILD a name that is not a plain reference builds"}),
    ("build-conf-ignored", 'cepa_sg_read_conf || cepa_sg_build_refuse', 'true || cepa_sg_build_refuse',
     {"BUILD held build lock refuses after the wait", "BUILD lock outlives a gate killed mid-build", "BUILD unreadable config refuses"}),
    ("build-under-gate-ok", 'if [ -n "${CEPA_STACK_GATE_HELD:-}" ]; then\n    cepa_sg_build_refuse',
     'if false; then\n    cepa_sg_build_refuse', {"BUILD inside a gated command refuses"}),
    ("build-wait-key-ignored", "      build_wait_seconds) cepa_sg_bwait=$val ;;\n", "",
     {"BUILD held build lock refuses after the wait", "BUILD lock outlives a gate killed mid-build"}),
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
    # A check that crashed (no summary line) proves nothing about the mutant.
    if not re.search(r"^check-stack-gate: \d+ passed, \d+ failed$", r.stdout, re.M):
        cases = {"CRASH"}
        out = r.stdout + r.stderr
        return 99, cases, out
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
    if cases == {"CRASH"}:
        print(f"MISS control {name}: the check crashed instead of reporting: {out[-300:]!r}")
        failed += 1
    elif rc == 0 or not cases:
        print(f"MISS control {name}: mutant stayed green")
        failed += 1
    elif want is not None and cases != want:
        print(f"MISS control {name}: killed {sorted(cases)}, want {sorted(want)}")
        failed += 1
    else:
        passed += 1

LEGS = ["USAGE", "CONFIG", "COUNT", "MEM", "RUN", "LOCK", "LIST", "COUNTMODE", "BUILD"]
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
