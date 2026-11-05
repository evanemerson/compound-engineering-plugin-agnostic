#!/usr/bin/env bash
# cepa stack gate — the one check before a worktree's Docker stack starts
# (punch-list L66; design "Piece 3" items 4-5, Builder-check answer 6,
# plan-review decisions #14 and #19). It counts the RUNNING worktree stacks on
# this machine and the free memory, and starts the caller's stack only when
# both are inside the limits. The lane & stack skill owns WHEN a repo calls
# it (every target that runs `compose up`, `restart` or `start` in a lane,
# and setup before it writes anything); this script owns HOW.
#
# Why: dpc-pro's `worktree-init` counted stacks with `docker ps -a` and only
# at create, so stopped stacks filled the limit and a later `compose up` or
# `compose run` started a stack past it. And a count taken before the start,
# by a script that then exits, lets two starts pass on the same count.
#
# Usage:
#   stack-gate.sh <project> -- <start command…>
#     <project>  the caller's compose project name. It must contain `-wt-`
#                (the worktree naming rule) and be a valid compose name:
#                [a-z0-9] then [a-z0-9_-], at most 64 characters.
#     The start command runs as given (argv, never through a shell), only
#     when the gate passes, while the gate still holds its lock. The lock is
#     released when the command returns; the command does not inherit the
#     lock's file descriptor, so a process it leaves running never holds it.
#     The lock is held for the command's WHOLE run, so the command must be
#     the start ONLY and return once the stack is started: `compose up -d
#     --no-build`, `start`, `restart`. Never a build, a foreground
#     `compose up`, or a long one-off `compose run`: every other lane's start
#     waits behind it and is refused after lock_wait_seconds as "lock busy",
#     while capacity is free. A cold build takes 5-8 minutes per lane, so at
#     fleet launch a third lane would wait past the 600 s default (L68).
#     Build first, OUTSIDE the gate, with `--build` below (the build lock,
#     not this one; no container started), and pass `--no-build`, because a
#     plain `compose up -d` builds any image that is missing. The gate does
#     not inspect the command; the caller (the lane-stack skill's `make up`
#     and setup) owns this. What still runs under the lock: `--no-build`
#     still pulls a missing pull-only image and waits on `depends_on` health
#     conditions, and a gated setup init runs its migrations here.
#     A gate killed by SIGTERM or SIGKILL leaves its
#     command running without the lock (Ctrl-C reaches both); the next start
#     may then count before that stack is up. Stated, not handled.
#     A start that waits prints one `waiting` line on stderr first.
#     Nesting: the command runs with CEPA_STACK_GATE_HELD=<project>; a gate
#     for the same project inside it runs at once (no lock, no count), so a
#     gated setup can call a start-only target that is gated too. A gate for
#     a different project inside it waits like any other start. `--build`
#     inside it refuses, so a gated setup never calls `make up` (it builds):
#     it starts with `compose up -d --no-build`.
#     The lock follows $HOME: a start under another HOME (sudo, another WSL
#     distro on the same Docker) takes a different lock. Stated, not handled.
#   stack-gate.sh --build <project> -- <compose command…>
#   stack-gate.sh --rebuild <project> -- <compose command…>
#     One image build at a time on this machine (punch-list L70 item 1). The
#     compose command is given WITHOUT a verb (`docker compose -f dev.yml`);
#     the gate adds `config --no-env-resolution --format json` and `build`,
#     and runs both with
#     COMPOSE_PROJECT_NAME=<project>. <project> is checked as above.
#     --build first lists the images the project BUILDS and checks them with
#     `docker image inspect`. When every name is a plain image reference and
#     every image exists, it prints `STACK build: skipped — …`, exits 0, and
#     takes no lock. A project with services and no `build:` section has
#     nothing to build, so it skips the same way. A failed read, or a project
#     with no services, builds. --rebuild always builds: the skip keeps an
#     old image after a Dockerfile, requirements or build-arg change.
#     The list holds only services that have a `build:` section (L75): a
#     missing pull-only image is not a reason to build, and `up -d
#     --no-build` pulls it. `config --images` cannot give this list: it
#     prints every service, and `config --images <service>` adds the
#     service's dependencies (measured, Compose 5.5.1). So python3 reads
#     `config --format json`, as other cepa scripts read JSON; no jq. A
#     service's image is its `image:`, else Compose's default
#     `<name>-<service>`, written here: if Compose changes that default, the
#     name is not found and --build builds. No python3 also builds.
#     --no-env-resolution because setup reads this before it writes `.env`,
#     and a missing `env_file` fails the read; a Compose without the flag
#     fails the read too, and builds. The JSON still holds `environment:`
#     values, so it goes down a pipe and is never stored or printed.
#     A build runs `<compose…> build` under the BUILD lock,
#     ~/.config/cepa/build.lock (flock), never the start lock above, so a
#     start that does not build never waits on a build, and a build never
#     waits on a start. Builds from every lane and every repo under this
#     HOME queue on it. A build that waits prints one `waiting` line on
#     stderr first, and once it holds the lock --build checks the images
#     again (skipped when the build it waited for made them). flock does
#     not wake waiters in order: a lane can lose the race to a later one,
#     so `lock busy` is retryable, and the wait limit below is a sizing,
#     not a promise.
#     The build INHERITS the lock's descriptor, unlike a start: the lock
#     lasts as long as the build, so a gate killed mid-build (SIGTERM,
#     SIGKILL, a tool timeout) never lets a second build start beside it.
#     The cost: a process the build leaves running holds the lock too.
#     The build has no time limit of its own; a hung build holds the lock
#     until it is stopped. Stated, not handled.
#     Before each build the gate writes ~/.config/cepa/build-failed.<project>
#     and removes it only when the build exits 0. While it exists, --build
#     never skips, so a failed, partial or killed build is built again.
#     Inside a gated command (CEPA_STACK_GATE_HELD set) it refuses: a build
#     there would hold the start lock for the whole build.
#     It reads no stack count and no MemAvailable: the bound is one build at
#     a time, not a memory check.
#   stack-gate.sh --count
#     Read-only, for the coordinator health check (`stacks:over:<n>`): takes
#     no lock, creates nothing, runs nothing. Prints exactly one line:
#       STACK count: running=<n> limit=<limit>
#     and exits 0, or, when Docker cannot be read:
#       STACK count: running=unknown limit=<limit> — <why>
#     and exits 1. The caller raises its alert when <n> > <limit> (the gate
#     admits up to <limit>, so <n> = <limit> is normal), and treats exit 1 as
#     its own unreadable alert, never as zero. A config that exists but cannot
#     be read is also exit 1.
#
# The gate passes when BOTH hold:
#   - the distinct compose projects whose name contains `-wt-` and that have
#     at least one running, paused or restarting container, not counting
#     <project> itself (a start of a stack that already runs adds no stack),
#     are fewer than the limit. Stopped (exited or created) stacks never count
#     (`docker ps` without `-a`). A restart of a running stack while the
#     others already fill the limit, or while memory is low, still refuses:
#     the gate fails closed rather than judge which start adds load.
#   - MemAvailable in /proc/meminfo is at least the minimum. (The check sets
#     CEPA_STACK_GATE_MEMINFO to read a fixture file instead; nothing else
#     should set it.)
# Docker, meminfo or an existing config that cannot be read refuses: the gate
# fails closed. A failed `flock` refuses as "lock busy" on its timeout (rc 1)
# and as "cannot lock" on any other code.
#
# Output: one line on stdout before anything the command prints:
#   STACK gate: ok — <counts>
#   STACK gate: refused — <reason>; running -wt- stacks, unknown idle then
#     longest idle first: <project> (repo <r>, lane <l>, idle <d>); …
# A refused line lists every running `-wt-` stack, so coord@main can ask the
# operator which to stop (3 longest-idle as options). Idle time is the time
# since the newest container of that stack started — Docker records no later
# use. A stack whose start time cannot be read prints `idle unknown` and
# sorts FIRST, so it is never hidden below the three options; a failed
# `docker inspect` adds one note saying so. Repo and lane come from the stack's compose working directory
# (`<repo>/.claude/worktrees/<lane>` or `workspaces/<repo>/<lane>`), else the
# project name before `-wt-`. Every listed value is reduced to
# [A-Za-z0-9._/-]; any other character prints as `?`.
# Config WARN lines go to stderr.
#
# Exit: 3 refused (the command was not run), 2 usage, otherwise the start
# command's own exit code. --count: 0, or 1 when unreadable. --build and
# --rebuild: 0 skipped, 3 refused (lock busy, cannot lock, inside a gate),
# 2 usage, otherwise the build's own exit code. The command can
# itself exit 2 or 3 (`make` exits 2 on any error; a nested gate exits 3), so
# the `STACK gate:` line, not the exit code, says whether the gate refused.
#
# Config: ~/.config/cepa/stack-gate.conf, `key=value` lines, READ — never
# sourced or evaluated (review #19: every Docker repo's make runs the gate, so
# a sourced file would run in every repo). Blank lines and `#` lines are
# skipped. A value must match ^[0-9]{1,6}$ and is read as decimal (`010` is
# ten). A bad or empty value, or an unknown key, prints a WARN and the
# default stands. A missing file means all defaults, without a WARN.
#   max_running=6          running `-wt-` stacks allowed at once
#   min_available_mib=2048 free memory (MemAvailable) a start needs
#   lock_wait_seconds=600  how long a start waits for another start's lock;
#                          at the end it refuses ("lock busy")
#   build_wait_seconds=3600 how long a build waits for the build lock. A cold
#                          build takes 5-8 min; when 6 lanes build at once
#                          the last waits for 5, about 40 min at 8 min each,
#                          so 60 min leaves half again as slack. At the end
#                          it refuses ("lock busy").
# The start lock is flock(1) on the config directory itself, created if
# absent; the build lock is the file build.lock inside it.
#
# Requires: bash, docker, flock, timeout, date (GNU). No jq. python3 for the
# --build skip only: without it --build always builds.
set -u

if [ -z "${HOME:-}" ]; then
  echo "STACK gate: usage — HOME is not set" >&2
  exit 2
fi
cepa_sg_dir="$HOME/.config/cepa"
cepa_sg_conf="$cepa_sg_dir/stack-gate.conf"
cepa_sg_max=6
cepa_sg_min=2048
cepa_sg_wait=600
cepa_sg_bwait=3600
cepa_sg_block="$cepa_sg_dir/build.lock"
cepa_sg_meminfo=${CEPA_STACK_GATE_MEMINFO:-/proc/meminfo}

cepa_sg_usage() {
  echo "STACK gate: usage — $1" >&2
  echo "usage: stack-gate.sh [--build|--rebuild] <project> -- <command…> | stack-gate.sh --count" >&2
  exit 2
}

cepa_sg_clean() { # reduce a docker-supplied value to printable plain text
  local v="$1"
  printf '%s' "${v//[!A-Za-z0-9._\/-]/?}"
}

cepa_sg_read_conf() { # returns 1 when the file exists but cannot be read
  [ -e "$cepa_sg_conf" ] || return 0
  if [ ! -f "$cepa_sg_conf" ] || [ ! -r "$cepa_sg_conf" ]; then
    cepa_sg_err="$cepa_sg_conf exists but is not a readable file"
    return 1
  fi
  local line key val n=0
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    line="${line%$'\r'}"
    [[ $line =~ ^[[:space:]]*(#|$) ]] && continue
    if [[ ! $line =~ ^[[:space:]]*([a-z_]+)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
      echo "STACK gate: WARN — $cepa_sg_conf line $n is not key=value; ignored" >&2
      continue
    fi
    key="${BASH_REMATCH[1]}"
    val="${BASH_REMATCH[2]}"
    val="${val%"${val##*[![:space:]]}"}"
    case "$key" in
      max_running|min_available_mib|lock_wait_seconds|build_wait_seconds) ;;
      *) echo "STACK gate: WARN — $cepa_sg_conf line $n: unknown key $key; ignored" >&2; continue ;;
    esac
    if [[ ! $val =~ ^[0-9]{1,6}$ ]]; then
      echo "STACK gate: WARN — $cepa_sg_conf line $n: $key is not 1-6 digits; default kept" >&2
      continue
    fi
    val=$((10#$val))
    case "$key" in
      max_running) cepa_sg_max=$val ;;
      min_available_mib) cepa_sg_min=$val ;;
      lock_wait_seconds) cepa_sg_wait=$val ;;
      build_wait_seconds) cepa_sg_bwait=$val ;;
    esac
  done <"$cepa_sg_conf"
}

# Fills cepa_sg_rows with "container id<TAB>project<TAB>working_dir" lines of
# running, paused or restarting containers in `-wt-` compose projects.
# Returns 1 when docker fails. Each field carries a prefix in the template so
# an empty label never collapses the tab-separated fields; a row whose id is
# not 64 hex characters (a label holding a newline or tab) is dropped.
cepa_sg_read_running() {
  local out err rc
  err=$(mktemp) || { cepa_sg_err="mktemp failed"; return 1; }
  out=$(timeout --foreground -k 2 30 docker ps --no-trunc \
    --filter status=running --filter status=paused --filter status=restarting \
    --filter label=com.docker.compose.project \
    --format 'i:{{.ID}}	p:{{.Label "com.docker.compose.project"}}	w:{{.Label "com.docker.compose.project.working_dir"}}' 2>"$err")
  rc=$?
  if [ "$rc" != 0 ]; then
    if [ "$rc" = 124 ] || [ "$rc" = 137 ]; then
      cepa_sg_err="docker ps timed out after 30s"
    else
      local first
      first=$(head -n 1 "$err")
      cepa_sg_err="docker ps failed (rc $rc): $(cepa_sg_clean "$first")"
    fi
    rm -f "$err"
    return 1
  fi
  rm -f "$err"
  cepa_sg_rows=""
  local i p w
  while IFS=$'\t' read -r i p w; do
    [[ $i =~ ^i:[0-9a-f]{64}$ && $p == p:* && $w == w:* ]] || continue
    i="${i#i:}"; p="${p#p:}"; w="${w#w:}"
    [[ $p == *-wt-* ]] || continue
    cepa_sg_rows+="$i"$'\t'"$p"$'\t'"$w"$'\n'
  done <<<"$out"
  return 0
}

# Distinct project names in cepa_sg_rows, one per line, sorted.
cepa_sg_projects() {
  local i p w
  while IFS=$'\t' read -r i p w; do
    [ -n "$p" ] && printf '%s\n' "$p"
  done <<<"$cepa_sg_rows" | sort -u
}

cepa_sg_count_mode() {
  [ $# -eq 0 ] || cepa_sg_usage "--count takes no arguments"
  if ! cepa_sg_read_conf; then
    echo "STACK count: running=unknown limit=$cepa_sg_max — $cepa_sg_err"
    exit 1
  fi
  if ! cepa_sg_read_running; then
    echo "STACK count: running=unknown limit=$cepa_sg_max — $cepa_sg_err"
    exit 1
  fi
  local n
  n=$(cepa_sg_projects | grep -c .)
  echo "STACK count: running=$n limit=$cepa_sg_max"
  exit 0
}

cepa_sg_dur() { # seconds -> 3d4h, 2h5m, 7m
  local s=$1
  [ "$s" -ge 0 ] || s=0
  if [ "$s" -ge 86400 ]; then echo "$((s / 86400))d$((s % 86400 / 3600))h"
  elif [ "$s" -ge 3600 ]; then echo "$((s / 3600))h$((s % 3600 / 60))m"
  else echo "$((s / 60))m"; fi
}

# The running `-wt-` stacks as one `; `-joined string: stacks whose idle time
# cannot be read come FIRST (marked `idle unknown`, so the operator sees them
# among the first options), then longest idle first.
cepa_sg_listing() {
  local now id started t i p w repo lane out="" proj idle note="" nt
  local -a ids=()
  local -A newest=() wd=() start_of=()
  now=$(date +%s)
  while IFS=$'\t' read -r i p w; do [ -n "$i" ] && ids+=("$i"); done <<<"$cepa_sg_rows"
  if [ "${#ids[@]}" -gt 0 ]; then
    local ins
    if ins=$(timeout --foreground -k 2 30 docker inspect --format '{{.Id}} {{.State.StartedAt}}' -- "${ids[@]}" 2>/dev/null); then
      while read -r id started; do
        [[ $id =~ ^[0-9a-f]{64}$ ]] || continue
        t=$(date -d "$started" +%s 2>/dev/null) || continue
        start_of[$id]=$t
      done <<<"$ins"
    else
      note=" (docker inspect failed: idle times unknown)"
    fi
  fi
  while IFS=$'\t' read -r i p w; do
    [ -n "$p" ] || continue
    wd[$p]="$w"
    t="${start_of[$i]:-}"
    [ -n "$t" ] || continue
    if [ -z "${newest[$p]:-}" ] || [ "$t" -gt "${newest[$p]}" ]; then newest[$p]=$t; fi
  done <<<"$cepa_sg_rows"
  while IFS=$'\t' read -r idle proj; do
    [ -n "$proj" ] || continue
    w="${wd[$proj]:-}"
    if [[ $w == */.claude/worktrees/* ]]; then
      repo="${w%/.claude/worktrees/*}"; repo="${repo##*/}"; lane="${w##*/}"
    elif [[ $w =~ /workspaces/([^/]+)/([^/]+)$ ]]; then
      repo="${BASH_REMATCH[1]}"; lane="${BASH_REMATCH[2]}"
    else
      repo="${proj%%-wt-*}"; lane="${w##*/}"
    fi
    [ -n "$lane" ] || lane=unknown
    if [ "$idle" = unknown ]; then idle="idle unknown"; else idle="idle $(cepa_sg_dur "$idle")"; fi
    out+="${out:+; }$(cepa_sg_clean "$proj") (repo $(cepa_sg_clean "$repo"), lane $(cepa_sg_clean "$lane"), $idle)"
  done < <(cepa_sg_projects | while IFS= read -r proj; do
             nt="${newest[$proj]:-}"
             if [ -n "$nt" ]; then printf '1\t%s\t%s\n' "$((now - nt))" "$proj"
             else printf '0\tunknown\t%s\n' "$proj"; fi
           done | sort -t $'\t' -k1,1n -k2,2nr | cut -f2-)
  printf '%s%s' "${out:-none}" "$note"
}

cepa_sg_refuse() {
  echo "STACK gate: refused — $1"
  exit 3
}

# stdin: `compose config --format json`. stdout: one image name per service
# that has a `build:` section, nothing when none has. No services, or any
# other shape, exits non-zero: unknown, so the caller builds. `.keys()` so a
# service that is not a mapping raises.
cepa_sg_built_py='
import json, sys
c = json.load(sys.stdin)
name = c["name"]
if not c["services"]:
    sys.exit(1)
for service, body in c["services"].items():
    if "build" in body.keys():
        print(body.get("image") or name + "-" + service)
'

# --build: prints why, and returns 0 only when the list of images the project
# builds is readable, all plain references, and every image exists, or when
# the project builds nothing.
cepa_sg_images_exist() {
  local out img
  local -a imgs=()
  # pipefail: a compose that prints its JSON and then fails is a failed read.
  if ! out=$(set -o pipefail
    COMPOSE_PROJECT_NAME="$cepa_sg_proj" timeout --foreground -k 2 60 "$@" config --no-env-resolution --format json 2>/dev/null |
      python3 -I -c "$cepa_sg_built_py" 2>/dev/null); then
    echo "the image list cannot be read (compose config or python3 failed)"
    return 1
  fi
  while IFS= read -r img; do
    [ -n "$img" ] || continue
    if [[ ! $img =~ ^[A-Za-z0-9][A-Za-z0-9._/:@-]*$ ]]; then
      echo "an image name is not a plain reference"
      return 1
    fi
    imgs+=("$img")
  done <<<"$out"
  if [ "${#imgs[@]}" -eq 0 ]; then
    echo "no service has a build: section, so there is nothing to build"
    return 0
  fi
  if ! timeout --foreground -k 2 60 docker image inspect --format '{{.Id}}' -- "${imgs[@]}" >/dev/null 2>&1; then
    echo "at least one of its ${#imgs[@]} built images is missing, or docker image inspect failed"
    return 1
  fi
  echo "all ${#imgs[@]} built images exist (--rebuild builds anyway)"
}

cepa_sg_build_refuse() {
  echo "STACK build: refused — $1"
  exit 3
}

# --build / --rebuild: one build at a time, on the build lock (L70 item 1).
cepa_sg_build_mode() {
  local why brc waited=no cepa_sg_bmark="$cepa_sg_dir/build-failed.$cepa_sg_proj"
  if [ -n "${CEPA_STACK_GATE_HELD:-}" ]; then
    cepa_sg_build_refuse "inside a gated command (the start lock for $(cepa_sg_clean "$CEPA_STACK_GATE_HELD") is held); build before the gate, never under it"
  fi
  if [ "$cepa_sg_mode" = --rebuild ]; then
    why="rebuild asked"
  elif [ -e "$cepa_sg_bmark" ]; then
    why="the last build of this project failed or was stopped ($cepa_sg_bmark)"
  elif why=$(cepa_sg_images_exist "$@"); then
    echo "STACK build: skipped — $cepa_sg_proj: $why"
    exit 0
  fi
  cepa_sg_read_conf || cepa_sg_build_refuse "cannot read the config — $cepa_sg_err"
  mkdir -p -m 700 "$cepa_sg_dir" 2>/dev/null || cepa_sg_build_refuse "cannot create $cepa_sg_dir for the build lock"
  exec {cepa_sg_bfd}>>"$cepa_sg_block" || cepa_sg_build_refuse "cannot open $cepa_sg_block for the build lock"
  if flock -n "$cepa_sg_bfd"; then
    brc=0
  else
    echo "STACK build: waiting up to ${cepa_sg_bwait}s for another build's lock on $cepa_sg_block" >&2
    flock -w "$cepa_sg_bwait" "$cepa_sg_bfd"
    brc=$?
    waited=yes
  fi
  case "$brc" in
    0) ;;
    1) cepa_sg_build_refuse "lock busy — another build held $cepa_sg_block for ${cepa_sg_bwait}s" ;;
    *) cepa_sg_build_refuse "cannot lock $cepa_sg_block — flock exited $brc" ;;
  esac
  # A build that waited re-checks: the build it waited for may have been
  # this project's own (setup and a `make up` of one lane).
  if [ "$waited" = yes ] && [ "$cepa_sg_mode" = --build ] && [ ! -e "$cepa_sg_bmark" ] &&
    why=$(cepa_sg_images_exist "$@"); then
    echo "STACK build: skipped — $cepa_sg_proj: $why (built while this one waited)"
    exit 0
  fi
  # The marker is written BEFORE the build and removed only when it exits 0,
  # so a failed, partial or killed build never lets the next --build skip.
  : >"$cepa_sg_bmark" 2>/dev/null || cepa_sg_build_refuse "cannot write $cepa_sg_bmark"
  echo "STACK build: building — $cepa_sg_proj: $why"
  # The build INHERITS the lock's descriptor, so the lock lives as long as
  # the build: a gate killed mid-build (SIGTERM, SIGKILL) frees nothing
  # while its build still runs.
  COMPOSE_PROJECT_NAME="$cepa_sg_proj" command "$@" build
  brc=$?
  [ "$brc" != 0 ] || rm -f "$cepa_sg_bmark"
  exit "$brc"
}

# --- arguments ---
[ $# -ge 1 ] || cepa_sg_usage "no arguments"
if [ "$1" = --count ]; then shift; cepa_sg_count_mode "$@"; fi
cepa_sg_mode=start
case "$1" in --build|--rebuild) cepa_sg_mode="$1"; shift ;; esac
cepa_sg_proj="${1:-}"; [ $# -ge 1 ] && shift
[[ $cepa_sg_proj =~ ^[a-z0-9][a-z0-9_-]{0,63}$ ]] || cepa_sg_usage "project is not a compose project name"
[[ $cepa_sg_proj == *-wt-* ]] || cepa_sg_usage "project $cepa_sg_proj has no -wt- (the gate is for worktree stacks)"
[ "${1:-}" = -- ] || cepa_sg_usage "expected -- after the project"
shift
[ $# -ge 1 ] || cepa_sg_usage "no start command after --"
[ "$cepa_sg_mode" = start ] || cepa_sg_build_mode "$@"

# A gated target that calls another gated start-only target for the SAME
# project (setup runs `stack-gate.sh p -- make start`, and that is gated
# too; never `make up`, whose --build refuses in here) would wait on
# the lock its own parent holds and be refused as "lock busy". The outer gate
# exports CEPA_STACK_GATE_HELD=<project> to its command; an inner gate for
# that project runs its command without taking the lock or counting again.
# Any other project nested inside a gate still waits (and is refused).
if [ "${CEPA_STACK_GATE_HELD:-}" = "$cepa_sg_proj" ]; then
  echo "STACK gate: ok — $cepa_sg_proj: nested inside a gate that holds the lock for it"
  command "$@"
  exit $?
fi

cepa_sg_read_conf || cepa_sg_refuse "cannot read the config — $cepa_sg_err"
[ "$cepa_sg_meminfo" = /proc/meminfo ] ||
  echo "STACK gate: WARN — reading memory from $cepa_sg_meminfo (CEPA_STACK_GATE_MEMINFO is set)" >&2

# --- lock: flock on the config directory, held until the command returns ---
mkdir -p -m 700 "$cepa_sg_dir" 2>/dev/null || cepa_sg_refuse "cannot create $cepa_sg_dir for the lock"
exec {cepa_sg_fd}<"$cepa_sg_dir" || cepa_sg_refuse "cannot open $cepa_sg_dir for the lock"
if flock -n "$cepa_sg_fd"; then
  cepa_sg_lrc=0
else
  echo "STACK gate: waiting up to ${cepa_sg_wait}s for another start's lock on $cepa_sg_dir" >&2
  flock -w "$cepa_sg_wait" "$cepa_sg_fd"
  cepa_sg_lrc=$?
fi
case "$cepa_sg_lrc" in
  0) ;;
  1) cepa_sg_refuse "lock busy — another start held $cepa_sg_dir for ${cepa_sg_wait}s" ;;
  *) cepa_sg_refuse "cannot lock $cepa_sg_dir — flock exited $cepa_sg_lrc" ;;
esac

# --- count, under the lock ---
cepa_sg_read_running || cepa_sg_refuse "cannot count running stacks — $cepa_sg_err"
cepa_sg_others=$(cepa_sg_projects | grep -cvxF -- "$cepa_sg_proj")
cepa_sg_self=no
cepa_sg_projects | grep -qxF -- "$cepa_sg_proj" && cepa_sg_self=yes

cepa_sg_mem=$(awk '$1 == "MemAvailable:" && $3 == "kB" { print int($2 / 1024); f = 1 } END { if (!f) exit 1 }' \
  "$cepa_sg_meminfo" 2>/dev/null) && [[ $cepa_sg_mem =~ ^[0-9]+$ ]] ||
  cepa_sg_refuse "cannot read MemAvailable from $cepa_sg_meminfo; running -wt- stacks, unknown idle then longest idle first: $(cepa_sg_listing)"

if [ "$cepa_sg_others" -ge "$cepa_sg_max" ]; then
  cepa_sg_refuse "$cepa_sg_others running -wt- stacks other than $cepa_sg_proj, limit $cepa_sg_max; running -wt- stacks, unknown idle then longest idle first: $(cepa_sg_listing)"
fi
if [ "$cepa_sg_mem" -lt "$cepa_sg_min" ]; then
  cepa_sg_refuse "${cepa_sg_mem} MiB available, minimum $cepa_sg_min MiB; running -wt- stacks, unknown idle then longest idle first: $(cepa_sg_listing)"
fi

echo "STACK gate: ok — $cepa_sg_proj: $cepa_sg_others other running -wt- stacks, limit $cepa_sg_max; ${cepa_sg_mem} MiB available, minimum $cepa_sg_min MiB$([ "$cepa_sg_self" = yes ] && echo "; already running")"
CEPA_STACK_GATE_HELD="$cepa_sg_proj" command "$@" {cepa_sg_fd}<&-
exit $?
