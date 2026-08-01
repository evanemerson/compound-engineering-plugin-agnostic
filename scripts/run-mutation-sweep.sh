#!/usr/bin/env bash
# Mutation sweep for the model-pin control suite.
#
#   scripts/check-model-pins.sh          enforces the rule
#   scripts/check-model-pins-controls.sh proves the checker still catches what
#                                        its record says it catches
#   THIS                                 sabotages the checker and confirms the
#                                        CONTROLS notice
#
# A sabotage nobody catches is a hole in the controls.
#
# `cepa:autonomy` §9f owns the policy: the cadence and why this is never a PR
# gate, the outcome vocabulary, the re-anchoring rule, and what a green sweep
# does NOT prove. Read it there rather than here — the operator-facing summary
# printed by every run is below, in the report header.
#
# HOW IT REACHES THE MUTATED CHECKER. The repo is copied INCLUDING .git to a
# temp dir, mutants are applied to the copy's checker, and the control harness
# runs with cwd inside the copy. `CEPA_PIN_CHECKER` is deliberately NOT used:
# that hook is hard-refused whenever CI is set, and the alternative was to
# widen a guard whose stated job is keeping CI from validating a checker nobody
# reviewed. The copy is cheap here (the tree plus history is ~11 MB) and it
# touches no existing guard. Consequence, stated rather than hidden: the
# mutated checker is also CONTENT in the fixture the harness builds, so a
# mutant that perturbs citation-shaped text reddens the baseline gate for a
# reason unrelated to the behaviour under test. Author around it.
#
# `.git` is copied because the harness resolves its root with `git rev-parse`
# and builds its fixture from `git ls-files` — a bare file copy is not a work
# tree and it exits 2. `git worktree add` was rejected: it checks out HEAD, so
# it would test the COMMITTED checker while the operator is mid-edit on the
# checker, which is the exact moment this sweep matters.
#
# CONFINEMENT. The working tree is never written. The copy lives under TMPDIR,
# never inside the repo — inside, it would trip this script's own quiescence
# check, and the ignore rule added to quiet that would also hide a genuinely
# mutated checker in a diff.
#
# Usage:
#   scripts/run-mutation-sweep.sh                 run every mutant
#   scripts/run-mutation-sweep.sh --mutants a,b   run a subset (PARTIAL)
#   scripts/run-mutation-sweep.sh --list          list the registry, run nothing
#   scripts/run-mutation-sweep.sh --selftest      exercise the classifier
#   scripts/run-mutation-sweep.sh --allow-dirty   permit a dirty tree under CI
set -uo pipefail

SS=$'\302\247'   # built, never written literally: see registry.sh's header

MUTANTS=''
LIST_ONLY=0
SELFTEST=0
ALLOW_DIRTY=0
KEEP=0

while [ $# -gt 0 ]; do
  case "$1" in
    # A bare trailing `--mutants` would shift past the end, leave the filter
    # empty and silently run everything — an argument error that WIDENS a run.
    --mutants) shift; [ $# -gt 0 ] || { printf -- '--mutants needs a value\n' >&2; exit 2; }; MUTANTS="$1" ;;
    --mutants=*) MUTANTS="${1#--mutants=}" ;;
    --list) LIST_ONLY=1 ;;
    --selftest) SELFTEST=1 ;;
    --allow-dirty) ALLOW_DIRTY=1 ;;
    --keep) KEEP=1 ;;
    -h|--help) sed -n '1,50p' "$0"; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  printf 'FATAL: not inside a git work tree\n' >&2; exit 2; }
REGISTRY="$REPO_ROOT/scripts/mutants/registry.sh"
CONTROLS_REL='scripts/check-model-pins-controls.sh'
[ -r "$REGISTRY" ] || { printf 'FATAL: no readable registry at %s\n' "$REGISTRY" >&2; exit 2; }

# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------
# Sourcing the registry runs this branch's shell code, in this process, BEFORE
# any validation below — the checks that follow read the arrays a well-behaved
# registry declares; they cannot constrain arbitrary top-level statements.
# The containment is the ephemeral runner and nothing else: the workflow's
# GITHUB_TOKEN carries `issues: write`, and token scope bounds what `gh` can do,
# not what a shell process can. So a hostile registry has the runner's full
# access, including the checked-out tree this script otherwise never writes.
# Locally there is no containment at all. Read the registry diff before running
# this, and never `workflow_dispatch` it against an unreviewed ref. Accepted as
# the cost of a reviewable, `reg`-shaped registry.
# shellcheck source=scripts/mutants/registry.sh
. "$REGISTRY"

if [ "${#MUT_IDS[@]}" -eq 0 ]; then
  printf 'FATAL: the registry defines no mutants — a sweep that asserts nothing is not a pass\n' >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Authoring-error checks. These run before anything expensive, because every
# one of them is a mistake in the registry rather than a finding about the
# control suite, and reporting them as findings is how a suite starts lying.
# ---------------------------------------------------------------------------
reg_errors=''
seen_ids=' '
i=0
while [ "$i" -lt "${#MUT_IDS[@]}" ]; do
  id="${MUT_IDS[$i]}"; t="${MUT_TARGET[$i]}"

  case "$seen_ids" in *" $id "*) reg_errors="${reg_errors}duplicate id '${id}'"$'\n' ;; esac
  seen_ids="${seen_ids}${id} "

  # A target must be repo-relative and must still resolve inside the copy. An
  # absolute path, a `..` component or a symlink is an authoring error, not a
  # finding: without this an interrupted run could leave a weakened checker
  # somewhere whose diff looks like a one-line edit.
  case "$t" in
    /*)   reg_errors="${reg_errors}${id}: target is absolute"$'\n' ;;
    *../*|*/..|..) reg_errors="${reg_errors}${id}: target has a .. component"$'\n' ;;
  esac
  [ -f "$REPO_ROOT/$t" ] || reg_errors="${reg_errors}${id}: target '${t}' is not a regular file"$'\n'
  [ -L "$REPO_ROOT/$t" ] && reg_errors="${reg_errors}${id}: target '${t}' is a symlink"$'\n'

  [ -n "${MUT_OLD[$i]}" ] || reg_errors="${reg_errors}${id}: empty 'old' would match everywhere"$'\n'
  [ "${MUT_OLD[$i]}" = "${MUT_NEW[$i]}" ] && reg_errors="${reg_errors}${id}: 'new' is identical to 'old'"$'\n'
  [ -n "${MUT_WHY[$i]}" ] || reg_errors="${reg_errors}${id}: empty 'why'"$'\n'

  # A declared survivor must cite a location that actually records a stated
  # limit. Nothing machine-checks that the limit is the RIGHT one — relabelling
  # a real gap as expected is still a one-word diff — but a declaration cannot
  # point at prose that no longer says so.
  if [ -n "${MUT_LIMIT[$i]}" ]; then
    lf="${MUT_LIMIT[$i]%%:*}"; ll="${MUT_LIMIT[$i]##*:}"
    case "${MUT_LIMIT[$i]}" in
      *:*) ;;
      *) reg_errors="${reg_errors}${id}: survivor reference '${MUT_LIMIT[$i]}' is not <file>:<line>"$'\n' ;;
    esac
    case "$ll" in
      ''|*[!0-9]*) reg_errors="${reg_errors}${id}: survivor reference has no line number"$'\n' ;;
      *)
        if ! sed -n "${ll}p" "$REPO_ROOT/$lf" 2>/dev/null | grep -q 'STATED LIMIT'; then
          reg_errors="${reg_errors}${id}: ${lf}:${ll} does not carry the words STATED LIMIT"$'\n'
        fi ;;
    esac
  fi
  i=$((i + 1))
done

if [ -n "$reg_errors" ]; then
  printf 'FATAL: the mutant registry has authoring errors:\n' >&2
  printf '%s' "$reg_errors" | sed 's/^/  /' >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------
selected() {
  [ -z "$MUTANTS" ] && return 0
  case ",$MUTANTS," in *",$1,"*) return 0 ;; esac
  return 1
}

if [ -n "$MUTANTS" ]; then
  unknown=''
  for want in ${MUTANTS//,/ }; do
    case "$seen_ids" in *" $want "*) ;; *) unknown="${unknown}${want} " ;; esac
  done
  [ -z "$unknown" ] || { printf 'FATAL: no such mutant: %s\n' "$unknown" >&2; exit 2; }
fi

if [ "$LIST_ONLY" -eq 1 ]; then
  i=0
  while [ "$i" -lt "${#MUT_IDS[@]}" ]; do
    if [ -n "${MUT_LIMIT[$i]}" ]; then
      printf '%-22s %-30s SURVIVOR (%s)\n' "${MUT_IDS[$i]}" "${MUT_TARGET[$i]}" "${MUT_LIMIT[$i]}"
    else
      printf '%-22s %-30s\n' "${MUT_IDS[$i]}" "${MUT_TARGET[$i]}"
    fi
    printf '    %s\n' "${MUT_WHY[$i]}"
    i=$((i + 1))
  done
  printf -- '-- %d mutants registered --\n' "${#MUT_IDS[@]}"
  exit 0
fi

# ---------------------------------------------------------------------------
# String substitution primitives
# ---------------------------------------------------------------------------
# Declarative, literal, and counted. `old` must occur EXACTLY once: zero means
# the mutant needs re-anchoring to the construct it targeted, and more than one
# means it would apply somewhere its `why` does not describe.
read_file() {  # read_file <path>  (preserves trailing newlines)
  local c
  # `&&`, not `;`. With `;` the substitution takes printf's status, which never
  # fails, so this returned SUCCESS with an empty body on an unreadable file —
  # making the caller's guard dead code and reporting an environment failure as
  # ANCHOR-MISSING, whose message tells the operator to edit a correct registry.
  c=$(cat -- "$1" && printf X) || return 1
  printf '%s' "${c%X}"
}

count_occurrences() {  # count_occurrences <haystack-var-name> <needle>
  local hay="${!1}" needle="$2" n=0
  while [ -n "$needle" ] && [ "${hay#*"$needle"}" != "$hay" ]; do
    n=$((n + 1)); hay="${hay#*"$needle"}"
  done
  printf '%s' "$n"
}

# ---------------------------------------------------------------------------
# The classifier
# ---------------------------------------------------------------------------
# THE SWEEP'S CREDIBILITY RESTS ENTIRELY HERE, so it is a pure function of the
# harness transcript and it is exercised by --selftest on every branch rather
# than on the one branch a given run happens to reach.
#
# Classification NEVER reads exit status. Baseline-abort, no-controls-ran and a
# genuine kill all exit 1. The signal is the harness's per-case PASS/FAIL lines
# and its `-- N/M controls passed --` trailer.
#
#   CAUGHT              at least one control went red
#   SURVIVED            the suite passed intact
#   BASELINE-DIRTY      the harness aborted at its baseline gate; no control ran
#   HARNESS-ERROR       the harness died for a reason that is not about the
#                       mutant — an environment failure, not a finding
#
# A missing trailer is never a CAUGHT.
CLASS=''; CLASS_DETAIL=''
classify_transcript() {  # classify_transcript <transcript>
  local out="$1" trailer failed
  CLASS=''; CLASS_DETAIL=''

  # A control that could not be SET UP is checked FIRST, before the trailer —
  # the harness still prints its trailer after a setup error, so a
  # trailer-branch-first classifier read "the fixture copy failed" as "a
  # control went red", i.e. as a kill. Reproduced: simulating one ENOSPC copy
  # flipped a genuinely-surviving mutant to CAUGHT/exit 0. With 21 undeclared
  # survivors on the books, two environmentally-failing controls would have
  # turned the whole recorded backlog green in one run.
  if printf '%s\n' "$out" | grep -q '^ERROR '; then
    CLASS='HARNESS-ERROR'
    CLASS_DETAIL="a control could not be set up, so it never ran — not a kill: $(printf '%s\n' "$out" | grep -E '^-- [0-9]+ setup errors --$' | tail -1)"
    return
  fi

  # Machine tokens, not prose. These used to grep the harness's English FATAL
  # sentences, duplicated verbatim with no marker at either end — so an
  # ordinary copy edit there would have reported a re-anchorable mutant as a
  # broken environment and stopped the run.
  if printf '%s\n' "$out" | grep -q '^BASELINE-ABORT dirty$'; then
    CLASS='BASELINE-DIRTY'
    CLASS_DETAIL='the mutated checker does not report 0 MISS / 0 WARN on the clean tree, so the harness aborted before running any control'
    return
  fi
  if printf '%s\n' "$out" | grep -q '^BASELINE-ABORT zero-coverage$'; then
    CLASS='BASELINE-DIRTY'
    CLASS_DETAIL='the mutated checker reported zero coverage in at least one counter, so the harness aborted before running any control'
    return
  fi

  trailer=$(printf '%s\n' "$out" | grep -oE -- '^-- [0-9]+/[0-9]+ controls passed --$' | tail -1)
  if [ -z "$trailer" ]; then
    CLASS='HARNESS-ERROR'
    CLASS_DETAIL=$(printf '%s\n' "$out" | grep -m1 -E '^(FATAL|WARN)' || printf 'no trailer, no BASELINE-ABORT token, no FATAL line (empty or truncated transcript)')
    return
  fi

  failed=$(printf '%s\n' "$out" | grep -cE '^FAIL  ')
  if [ "$failed" -gt 0 ]; then
    CLASS='CAUGHT'
    CLASS_DETAIL="$failed control(s) went red: $(printf '%s\n' "$out" | grep -E '^FAIL  ' | awk '{print $2}' | tr '\n' ' ')"
    return
  fi
  CLASS='SURVIVED'
  CLASS_DETAIL="${trailer#-- }"
}

# The reported outcome folds the transcript classification together with what
# the registry DECLARED. A survivor that gets caught is a failure in the other
# direction: the stated limit was closed and the declaration is now false.
OUTCOME=''; OUTCOME_OK=0
resolve_outcome() {  # resolve_outcome <class> <is_declared_survivor 0|1>
  case "$1:$2" in
    CAUGHT:0)          OUTCOME='CAUGHT';               OUTCOME_OK=1 ;;
    CAUGHT:1)          OUTCOME='CAUGHT-DECLARED';      OUTCOME_OK=0 ;;
    SURVIVED:1)        OUTCOME='SURVIVED-DECLARED';    OUTCOME_OK=1 ;;
    SURVIVED:0)        OUTCOME='SURVIVED-UNDECLARED';  OUTCOME_OK=0 ;;
    BASELINE-DIRTY:*)  OUTCOME='BASELINE-DIRTY';       OUTCOME_OK=0 ;;
    HARNESS-ERROR:*)   OUTCOME='HARNESS-ERROR';        OUTCOME_OK=0 ;;
    *)                 OUTCOME='UNKNOWN';              OUTCOME_OK=0 ;;
  esac
}

# ---------------------------------------------------------------------------
# --selftest
# ---------------------------------------------------------------------------
if [ "$SELFTEST" -eq 1 ]; then
  st_pass=0; st_fail=0
  st() {  # st <name> <expected-outcome> <expected-ok> <declared 0|1> <transcript>
    classify_transcript "$5"
    resolve_outcome "$CLASS" "$4"
    if [ "$OUTCOME" = "$2" ] && [ "$OUTCOME_OK" -eq "$3" ]; then
      printf 'PASS  %s\n' "$1"; st_pass=$((st_pass + 1))
    else
      printf 'FAIL  %s\n        expected %s/ok=%s, got %s/ok=%s (%s)\n' \
        "$1" "$2" "$3" "$OUTCOME" "$OUTCOME_OK" "$CLASS_DETAIL"
      st_fail=$((st_fail + 1))
    fi
  }

  GREEN='baseline: 0 MISS, 0 WARN, exit 0; 96 tracked files; coverage counters non-zero

PASS  1    line-initial unqualified citation
PASS  L1   agent frontmatter names an unsanctioned tier

-- 57/57 controls passed --'

  RED='baseline: 0 MISS, 0 WARN, exit 0; 96 tracked files; coverage counters non-zero

PASS  1    line-initial unqualified citation
FAIL  L1   agent frontmatter names an unsanctioned tier
        expected 1 MISS / 0 WARN, got 0 MISS / 0 WARN

-- 56/57 controls passed --
FAIL: the checker no longer behaves the way its record claims. Failed: L1 '

  BASE='== control suite for /tmp/x/scripts/check-model-pins.sh ==
BASELINE-ABORT dirty
FATAL: baseline is not clean — every case expectation is a delta from it,
       so a dirty baseline makes the whole suite meaningless.
       got: 3 MISS, 0 WARN, exit 1'

  ZEROCOV='== control suite for /tmp/x/scripts/check-model-pins.sh ==
BASELINE-ABORT zero-coverage
FATAL: baseline reports zero coverage in: citations
       A clean run over nothing is not a clean run.'

  # A setup failure PLUS a trailer. This is the shape that reproduced as a
  # false CAUGHT: the harness still prints its trailer after a control fails to
  # copy its fixture or plant its defect.
  SETUPERR='baseline: 0 MISS, 0 WARN, exit 0; 96 tracked files; coverage counters non-zero

PASS  1    line-initial unqualified citation
ERROR L3e  a correctly ordered pair is silent
        setup failed, so this control never ran: could not copy fixture

-- 1 setup errors --

-- 56/57 controls passed --'

  # A setup error alongside a genuine kill still is not a kill: the run is not
  # evidence about the mutant in either direction.
  SETUPERR_MIXED='PASS  1    line-initial unqualified citation
FAIL  L1   agent frontmatter names an unsanctioned tier
ERROR 17   root present, no file of a scannable extension
        setup failed, so this control never ran: plant step failed or landed as a no-op

-- 1 setup errors --

-- 55/57 controls passed --'

  EMPTY=''

  BROKEN='== control suite for /tmp/x/scripts/check-model-pins.sh ==
FATAL: fixture is incomplete — 90 of 96 tracked files materialized'

  NOCASES='baseline: 0 MISS, 0 WARN, exit 0; 96 tracked files; coverage counters non-zero

FATAL: no controls ran (--only matched nothing?) — a suite that asserts nothing is not a pass'

  st 'a red control on an ordinary mutant is CAUGHT'      CAUGHT              1 0 "$RED"
  st 'a green suite on an ordinary mutant is a real gap'  SURVIVED-UNDECLARED 0 0 "$GREEN"
  st 'a green suite on a declared survivor is expected'   SURVIVED-DECLARED   1 1 "$GREEN"
  st 'a declared survivor that gets caught is a failure'  CAUGHT-DECLARED     0 1 "$RED"
  st 'a dirty baseline is never a CAUGHT'                 BASELINE-DIRTY      0 0 "$BASE"
  st 'a dirty baseline is never a CAUGHT (survivor)'      BASELINE-DIRTY      0 1 "$BASE"
  st 'zero-coverage baseline aborts the same way'         BASELINE-DIRTY      0 0 "$ZEROCOV"
  st 'a fixture failure is not a finding'                 HARNESS-ERROR       0 0 "$BROKEN"
  st 'no controls ran is not a finding'                   HARNESS-ERROR       0 0 "$NOCASES"
  st 'a setup error is never a CAUGHT, trailer or not'    HARNESS-ERROR       0 0 "$SETUPERR"
  st 'a setup error outranks a real FAIL in the same run' HARNESS-ERROR       0 0 "$SETUPERR_MIXED"
  st 'a setup error on a declared survivor still errors'  HARNESS-ERROR       0 1 "$SETUPERR"
  st 'an empty transcript is not a finding'               HARNESS-ERROR       0 0 "$EMPTY"

  # ANCHOR-MISSING is decided before the harness runs, so it is exercised
  # against the substitution primitives rather than a transcript.
  st_tmp=$(mktemp) || exit 2
  printf 'alpha\nbeta\nalpha\n' > "$st_tmp"
  st_body=$(read_file "$st_tmp")
  rm -f "$st_tmp"

  # read_file must REPORT a failure. It used to return success with an empty
  # body on an unreadable path, which made its caller's guard dead code and
  # turned an environment failure into an ANCHOR-MISSING finding.
  if read_file /nonexistent/definitely-not-here >/dev/null 2>&1; then
    printf 'FAIL  read_file reports success on an unreadable path\n'
    st_fail=$((st_fail + 1))
  else
    printf 'PASS  read_file reports failure on an unreadable path\n'
    st_pass=$((st_pass + 1))
  fi
  for probe in 'zeta 0' 'beta 1' 'alpha 2'; do
    set -- $probe
    got=$(count_occurrences st_body "$1")
    if [ "$got" -eq "$2" ]; then
      printf 'PASS  anchor count for %s is %s\n' "$1" "$2"; st_pass=$((st_pass + 1))
    else
      printf 'FAIL  anchor count for %s: expected %s, got %s\n' "$1" "$2" "$got"
      st_fail=$((st_fail + 1))
    fi
  done

  printf -- '\n-- %d/%d classifier selftests passed --\n' "$st_pass" "$((st_pass + st_fail))"
  [ "$st_fail" -eq 0 ] || exit 1
  exit 0
fi

# ---------------------------------------------------------------------------
# Quiescence (two states, not one)
# ---------------------------------------------------------------------------
# The person who needs this sweep is mid-edit on the checker BY CONSTRUCTION,
# so a blanket dirty-tree refusal would brand every useful local run invalid
# and train the operator to read past the banner. What actually corrupted a run
# was writes landing DURING it — a mid-run change is re-checked at exit and is
# fatal; a tree that was merely dirty at the start is not.
# `git status --porcelain` emits a status code and a path, NEVER content — so
# for a file that was ALREADY modified at start, further edits leave the line
# byte-identical and the end-of-run comparison sees nothing. That is exactly
# the mid-edit-on-the-checker case this gate was built for. So hash the
# registered targets too: they are the only files whose mid-run drift changes
# what the results mean.
target_digest() {
  local seen=' ' t
  local i=0
  while [ "$i" -lt "${#MUT_TARGET[@]}" ]; do
    t="${MUT_TARGET[$i]}"
    case "$seen" in *" $t "*) ;; *)
      seen="${seen}${t} "
      printf '%s ' "$t"
      git -C "$REPO_ROOT" hash-object -- "$t" 2>/dev/null || printf 'UNREADABLE'
      printf '\n' ;;
    esac
    i=$((i + 1))
  done
}

# A failing `git status` prints nothing and exits non-zero — read as an empty
# status, that asserted "clean tree — gate result" about a tree nobody
# inspected (dubious ownership, a held index.lock, a corrupt index all land
# here). Quiescence that cannot be READ is not quiescence.
START_STATUS=$(git -C "$REPO_ROOT" status --porcelain) || {
  printf 'FATAL: could not read the tree status, so quiescence is unverifiable and no\n' >&2
  printf '       result from this run could be called a gate result.\n' >&2
  exit 2
}
START_DIGEST=$(target_digest)
HEAD_SHA=$(git -C "$REPO_ROOT" rev-parse --short HEAD) || {
  printf 'FATAL: could not resolve HEAD\n' >&2; exit 2; }
DIRTY=0; [ -n "$START_STATUS" ] && DIRTY=1

if [ "$DIRTY" -eq 1 ] && [ -n "${CI:-}" ] && [ "$ALLOW_DIRTY" -eq 0 ]; then
  printf 'FATAL: the tree is dirty under CI. A CI checkout is clean by construction, so this\n' >&2
  printf '       is a broken job, not a local run. Pass --allow-dirty to override.\n' >&2
  printf '%s\n' "$START_STATUS" | sed 's/^/  /' >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# The copy
# ---------------------------------------------------------------------------
WORK=$(mktemp -d "${TMPDIR:-/tmp}/cepa-mutation-sweep.XXXXXX") || exit 2
cleanup() {
  [ "$KEEP" -eq 1 ] && { printf 'work tree kept at %s\n' "$WORK"; return; }
  chmod -R u+rwX "$WORK" 2>/dev/null
  rm -rf "$WORK" 2>/dev/null || printf 'WARN: work tree leaked at %s\n' "$WORK" >&2
}
trap cleanup EXIT INT TERM

WORK_REAL=$(readlink -f "$WORK") || exit 2
ROOT_REAL=$(readlink -f "$REPO_ROOT") || exit 2
case "$WORK_REAL/" in
  "$ROOT_REAL"/*)
    printf 'FATAL: TMPDIR resolves inside the repo (%s) — the copy would trip this run own\n' "$WORK_REAL" >&2
    printf '       quiescence check, and the ignore rule that quiets that would also hide a\n' >&2
    printf '       genuinely mutated checker. Set TMPDIR outside the repo.\n' >&2
    exit 2 ;;
esac

# Every nested `mktemp` — including the control harness's own fixture root,
# created 63 times — lands inside $WORK, so the single outer cleanup covers it
# and a leak is reported rather than stranded in the operator's /tmp with
# mode-000 directories the harness plants for cases 33/34.
export TMPDIR="$WORK"

COPY="$WORK/repo"
mkdir -p "$COPY"
# `.git` PLUS TRACKED CONTENT ONLY — deliberately not `cp -a "$REPO_ROOT/."`.
# A whole-directory copy also took untracked, gitignored files out of the repo:
# `.env.local` (mode 0600, holds MCP_ACCESS_KEY), `cepa.local.md`, and `docs/`.
# They would sit in TMPDIR for the length of the run, indefinitely under
# `--keep`, and a failed cleanup reports only `WARN: work tree leaked` inside an
# otherwise green report. The harness needs none of it: it resolves its root
# with `git rev-parse` and builds its fixture from `git ls-files`, so `.git`
# plus tracked working-tree content is exactly sufficient — the same reasoning
# the sibling harness states for its own `git ls-files` fixture.
cp -a "$REPO_ROOT/.git" "$COPY/.git" || {
  printf 'FATAL: could not copy .git\n' >&2; exit 2; }
( cd "$REPO_ROOT" && git ls-files -z | tar --null -cf - -T - ) \
  | ( cd "$COPY" && tar -xf - ) || {
  printf 'FATAL: could not materialize tracked content in the copy\n' >&2; exit 2; }

# A `.git` FILE (a linked worktree or submodule) points back at the ORIGINAL
# gitdir, so the harness inside the copy would resolve its root — and build its
# fixture — from the real repo while reading a mutated checker from the copy.
# Every result would be about a tree nobody mutated.
COPY_ROOT=$(git -C "$COPY" rev-parse --show-toplevel 2>/dev/null) || {
  printf 'FATAL: the copy is not a git work tree\n' >&2; exit 2; }
if [ "$(readlink -f "$COPY_ROOT")" != "$(readlink -f "$COPY")" ]; then
  printf 'FATAL: the copy resolves its git root to %s, not to itself. Running here would\n' "$COPY_ROOT" >&2
  printf '       measure the real repo. Run the sweep from a normal clone, not a linked\n' >&2
  printf '       worktree.\n' >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Report header
# ---------------------------------------------------------------------------
printf '== model-pin mutation sweep ==\n'
if [ "$DIRTY" -eq 1 ]; then
  printf 'LOCAL (dirty at %s) — not a gate result\n' "$HEAD_SHA"
else
  printf 'clean tree at %s — gate result\n' "$HEAD_SHA"
fi
printf 'harness: %s (run once per mutant, in a copy under %s)\n' "$CONTROLS_REL" "${TMPDIR:-/tmp}"
printf '\n'
printf 'A green sweep means every ENUMERATED mutant was killed. That is not coverage of\n'
printf 'the checker: the enumeration is hand-authored, and a mutant killed by a control\n'
printf 'that is itself wrong still reports CAUGHT. See autonomy %s9f.\n' "$SS"
printf '\n'
printf 'declared survivors (expected to survive, each against a recorded stated limit):\n'
survivor_n=0
i=0
while [ "$i" -lt "${#MUT_IDS[@]}" ]; do
  if [ -n "${MUT_LIMIT[$i]}" ]; then
    printf '  %-20s %s\n' "${MUT_IDS[$i]}" "${MUT_LIMIT[$i]}"
    survivor_n=$((survivor_n + 1))
  fi
  i=$((i + 1))
done
[ "$survivor_n" -eq 0 ] && printf '  (none)\n'
printf '\n'

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
ran=0; ok=0; bad=0
BAD_LINES=''

record() {  # record <id> <outcome> <ok> <detail> <why>
  printf '%-16s %-20s %s\n' "$2" "$1" "$4"
  if [ "$3" -eq 1 ]; then
    ok=$((ok + 1))
  else
    # The reason is printed AT THE FAILURE SITE, not left in a registry entry
    # the reader has to go find — the same rule the control harness applies to
    # its own `why` field, which this file had validated as non-empty and then
    # never shown to anyone.
    [ -n "${5:-}" ] && printf '                 %s\n' "$5"
    BAD_LINES="${BAD_LINES}  ${2} ${1} — ${4}"$'\n'
    [ -n "${5:-}" ] && BAD_LINES="${BAD_LINES}      ${5}"$'\n'
    bad=$((bad + 1))
  fi
}

i=0
while [ "$i" -lt "${#MUT_IDS[@]}" ]; do
  id="${MUT_IDS[$i]}"
  if ! selected "$id"; then i=$((i + 1)); continue; fi
  ran=$((ran + 1))

  target="$COPY/${MUT_TARGET[$i]}"
  declared=0; [ -n "${MUT_LIMIT[$i]}" ] && declared=1

  body=$(read_file "$target") || {
    printf 'FATAL: could not read %s in the copy — an environment failure, never a\n' "${MUT_TARGET[$i]}" >&2
    printf '       finding about mutant %s. Stopping.\n' "$id" >&2
    exit 2
  }

  n=$(count_occurrences body "${MUT_OLD[$i]}")
  if [ "$n" -ne 1 ]; then
    record "$id" 'ANCHOR-MISSING' 0 \
      "'old' occurs ${n} times in ${MUT_TARGET[$i]} (want exactly 1) — re-anchor this mutant to the construct it targets; deleting it is never the fix" \
      "${MUT_WHY[$i]}"
    i=$((i + 1)); continue
  fi

  # Written to a sibling and moved into place. `>` truncates on open, so a
  # write that failed partway (ENOSPC) left a TRUNCATED checker and the old
  # code recorded-and-continued without restoring — every later mutant then ran
  # against a corrupted file and was reported as ANCHOR-MISSING or
  # BASELINE-DIRTY, both of which tell the operator to re-anchor a registry
  # that is correct. Fatal here, matching the restore path below and the
  # HARNESS-ERROR contract in autonomy 9f.
  if ! printf '%s' "${body/"${MUT_OLD[$i]}"/"${MUT_NEW[$i]}"}" > "$target.mut" \
     || ! mv -f "$target.mut" "$target"; then
    rm -f "$target.mut"
    printf 'FATAL: could not write the mutated %s. Stopping rather than continuing\n' "${MUT_TARGET[$i]}" >&2
    printf '       against a target whose contents are now unknown.\n' >&2
    exit 2
  fi

  # Bounded per mutant. The harness bounds each CHECKER invocation at 120s
  # across ~59 controls, so one pathological mutant's worst case is ~2 hours —
  # the whole CI budget, spent before any other mutant runs.
  out=$( cd "$COPY" && timeout -k 30 900 bash "$CONTROLS_REL" 2>&1 )

  # Restore before classifying, so an error in classification cannot leave the
  # next mutant running against two mutations at once.
  if ! printf '%s' "$body" > "$target.mut" || ! mv -f "$target.mut" "$target" \
     || [ "$(read_file "$target")" != "$body" ]; then
    rm -f "$target.mut"
    printf 'FATAL: could not restore %s in the copy — every later result would be about\n' "${MUT_TARGET[$i]}" >&2
    printf '       two mutations at once. Stopping.\n' >&2
    exit 2
  fi

  classify_transcript "$out"
  if [ "$CLASS" = 'HARNESS-ERROR' ]; then
    printf 'FATAL: the control harness failed for a reason that is not about mutant %s:\n' "$id" >&2
    printf '       %s\n' "$CLASS_DETAIL" >&2
    printf '       The environment is broken; continuing would produce garbage.\n\n' >&2
    printf '%s\n' "$out" | sed 's/^/  | /' >&2
    exit 2
  fi
  resolve_outcome "$CLASS" "$declared"
  record "$id" "$OUTCOME" "$OUTCOME_OK" "$CLASS_DETAIL" "${MUT_WHY[$i]}"
  i=$((i + 1))
done

# ---------------------------------------------------------------------------
# Verdict
# ---------------------------------------------------------------------------
printf '\n'

# A run that asserted nothing is not a pass — the same rule the control suite
# applies to itself and the checker applies to its own coverage counters.
if [ "$ran" -eq 0 ]; then
  printf 'FATAL: no mutants ran — a sweep that asserts nothing is not a pass\n'
  exit 1
fi

# A filtered run must never read as a complete one.
if [ -n "$MUTANTS" ]; then
  printf -- '** PARTIAL RUN — only %s ran; %d of %d mutants were not exercised **\n\n' \
    "$MUTANTS" "$(( ${#MUT_IDS[@]} - ran ))" "${#MUT_IDS[@]}"
fi

END_STATUS=$(git -C "$REPO_ROOT" status --porcelain) || END_STATUS='<unreadable>'
END_DIGEST=$(target_digest)
if [ "$END_STATUS" != "$START_STATUS" ] || [ "$END_DIGEST" != "$START_DIGEST" ]; then
  printf 'INVALID — tree changed mid-run. Every result above is about a snapshot that no\n'
  printf 'longer describes the tree. Re-run on a quiescent tree.\n'
  exit 1
fi

printf -- '-- %d/%d mutants accounted for --\n' "$ok" "$ran"
if [ "$bad" -gt 0 ]; then
  printf '\nFAIL: the control suite does not catch what this sweep says it should.\n'
  printf '%s' "$BAD_LINES"
  # No line of this footer may BEGIN with an outcome token. The report lines
  # above are the machine-readable half of this output — the CI failure issue
  # greps for `^<OUTCOME> ` to name the failing mutants — and prose starting
  # with a bare token lands in that list as a mutant nobody registered.
  # Observed on the first full run: a footer sentence opening with
  # SURVIVED-UNDECLARED reported as a 64th result.
  printf '\nAn undeclared survivor is a real gap in the controls: add a control, or\n'
  printf 'declare it against a stated limit that actually exists. A dirty baseline means\n'
  printf 'the mutant is loud on the clean tree and needs re-anchoring to the silent form\n'
  printf 'of the same construct. A gap found here becomes a residual, not an edit to the\n'
  printf 'checker in the same change — a detection change and the thing it detects must\n'
  printf 'not hide each other.\n'
  exit 1
fi
exit 0
