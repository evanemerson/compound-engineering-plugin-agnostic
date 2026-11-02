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
#   stack-gate.sh --count
#     Read-only, for the coordinator health check (`stacks:over:<n>`): takes
#     no lock, creates nothing, runs nothing. Prints exactly one line:
#       STACK count: running=<n> limit=<limit>
#     and exits 0, or, when Docker cannot be read:
#       STACK count: running=unknown limit=<limit> — <why>
#     and exits 1. The caller raises its alert when <n> > <limit>.
#
# The gate passes when BOTH hold:
#   - the distinct compose projects whose name contains `-wt-` and that have
#     at least one running container, not counting <project> itself (a start
#     of a stack that already runs adds no stack), are fewer than the limit.
#     Stopped stacks never count (`docker ps` without `-a`, status=running).
#   - MemAvailable in /proc/meminfo is at least the minimum. (The check sets
#     CEPA_STACK_GATE_MEMINFO to read a fixture file instead; nothing else
#     should set it.)
# Docker or meminfo that cannot be read refuses: the gate fails closed.
#
# Output: one line on stdout before anything the command prints:
#   STACK gate: ok — <counts>
#   STACK gate: refused — <reason>; running -wt- stacks, longest idle first:
#     <project> (repo <r>, lane <l>, idle <d>); …
# A refused line lists every running `-wt-` stack, so coord@main can ask the
# operator which to stop (3 longest-idle as options). Idle time is the time
# since the newest container of that stack started — Docker records no later
# use. Repo and lane come from the stack's compose working directory
# (`<repo>/.claude/worktrees/<lane>` or `workspaces/<repo>/<lane>`), else the
# project name before `-wt-`. Every listed value is reduced to
# [A-Za-z0-9._/-]; any other character prints as `?`.
# Config WARN lines go to stderr.
#
# Exit: 3 refused (the command was not run), 2 usage, otherwise the start
# command's own exit code. --count: 0, or 1 when unreadable.
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
# The lock is flock(1) on the config directory itself, created if absent.
#
# Requires: bash, docker, flock, timeout, date (GNU). No jq.
set -u

cepa_sg_dir="$HOME/.config/cepa"
cepa_sg_conf="$cepa_sg_dir/stack-gate.conf"
cepa_sg_max=6
cepa_sg_min=2048
cepa_sg_wait=600
cepa_sg_meminfo=${CEPA_STACK_GATE_MEMINFO:-/proc/meminfo}

cepa_sg_usage() {
  echo "STACK gate: usage — $1" >&2
  echo "usage: stack-gate.sh <project> -- <start command…> | stack-gate.sh --count" >&2
  exit 2
}

cepa_sg_clean() { # reduce a docker-supplied value to printable plain text
  local v="$1"
  printf '%s' "${v//[!A-Za-z0-9._\/-]/?}"
}

cepa_sg_read_conf() {
  [ -f "$cepa_sg_conf" ] || return 0
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
      max_running|min_available_mib|lock_wait_seconds) ;;
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
    esac
  done <"$cepa_sg_conf"
}

# Fills cepa_sg_rows with "project<TAB>working_dir<TAB>container id" lines of
# RUNNING containers in `-wt-` compose projects. Returns 1 when docker fails.
cepa_sg_read_running() {
  local out
  out=$(timeout -k 2 30 docker ps --no-trunc --filter status=running \
    --filter label=com.docker.compose.project \
    --format '{{.Label "com.docker.compose.project"}}	{{.Label "com.docker.compose.project.working_dir"}}	{{.ID}}' 2>&1) || {
    cepa_sg_err="docker ps failed: $(cepa_sg_clean "${out%%$'\n'*}")"
    return 1
  }
  cepa_sg_rows=""
  local p w i
  while IFS=$'\t' read -r p w i; do
    [[ $p == *-wt-* ]] || continue
    cepa_sg_rows+="$p"$'\t'"$w"$'\t'"$i"$'\n'
  done <<<"$out"
  return 0
}

# Distinct project names in cepa_sg_rows, one per line, sorted.
cepa_sg_projects() {
  local p w i
  while IFS=$'\t' read -r p w i; do
    [ -n "$p" ] && echo "$p"
  done <<<"$cepa_sg_rows" | sort -u
}

cepa_sg_count_mode() {
  [ $# -eq 0 ] || cepa_sg_usage "--count takes no arguments"
  cepa_sg_read_conf
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
  if [ "$s" -ge 86400 ]; then echo "$((s / 86400))d$((s % 86400 / 3600))h"
  elif [ "$s" -ge 3600 ]; then echo "$((s / 3600))h$((s % 3600 / 60))m"
  else echo "$((s / 60))m"; fi
}

# The running `-wt-` stacks, longest idle first, as one `; `-joined string.
cepa_sg_listing() {
  local now ids line id started t p w i repo lane out="" proj
  now=$(date +%s)
  declare -A newest=() wd=()
  ids=$(while IFS=$'\t' read -r p w i; do [ -n "$i" ] && echo "$i"; done <<<"$cepa_sg_rows")
  declare -A start_of=()
  if [ -n "$ids" ]; then
    # shellcheck disable=SC2086  # ids are docker's hex container ids
    while read -r id started; do
      t=$(date -d "$started" +%s 2>/dev/null) || continue
      start_of[$id]=$t
    done < <(timeout -k 2 30 docker inspect --format '{{.Id}} {{.State.StartedAt}}' $ids 2>/dev/null)
  fi
  while IFS=$'\t' read -r p w i; do
    [ -n "$p" ] || continue
    wd[$p]="$w"
    t="${start_of[$i]:-}"
    [ -n "$t" ] || continue
    if [ -z "${newest[$p]:-}" ] || [ "$t" -gt "${newest[$p]}" ]; then newest[$p]=$t; fi
  done <<<"$cepa_sg_rows"
  while IFS=$'\t' read -r line proj; do
    [ -n "$proj" ] || continue
    w="${wd[$proj]}"
    if [[ $w == */.claude/worktrees/* ]]; then
      repo="${w%/.claude/worktrees/*}"; repo="${repo##*/}"; lane="${w##*/}"
    elif [[ $w =~ /workspaces/([^/]+)/([^/]+)$ ]]; then
      repo="${BASH_REMATCH[1]}"; lane="${BASH_REMATCH[2]}"
    else
      repo="${proj%%-wt-*}"; lane="${w##*/}"; [ -n "$lane" ] || lane=unknown
    fi
    if [ "$line" = -1 ]; then line="idle unknown"; else line="idle $(cepa_sg_dur "$line")"; fi
    out+="${out:+; }$(cepa_sg_clean "$proj") (repo $(cepa_sg_clean "$repo"), lane $(cepa_sg_clean "$lane"), $line)"
  done < <(for proj in $(cepa_sg_projects); do
             if [ -n "${newest[$proj]:-}" ]; then echo "$((now - newest[$proj]))	$proj"
             else echo "-1	$proj"; fi
           done | sort -t $'\t' -k1,1nr)
  printf '%s' "${out:-none}"
}

cepa_sg_refuse() {
  echo "STACK gate: refused — $1"
  exit 3
}

# --- arguments ---
[ $# -ge 1 ] || cepa_sg_usage "no arguments"
if [ "$1" = --count ]; then shift; cepa_sg_count_mode "$@"; fi
cepa_sg_proj="$1"; shift
[[ $cepa_sg_proj =~ ^[a-z0-9][a-z0-9_-]{0,63}$ ]] || cepa_sg_usage "project is not a compose project name"
[[ $cepa_sg_proj == *-wt-* ]] || cepa_sg_usage "project $cepa_sg_proj has no -wt- (the gate is for worktree stacks)"
[ "${1:-}" = -- ] || cepa_sg_usage "expected -- after the project"
shift
[ $# -ge 1 ] || cepa_sg_usage "no start command after --"

cepa_sg_read_conf

# --- lock: flock on the config directory, held until the command returns ---
mkdir -p "$cepa_sg_dir" 2>/dev/null || cepa_sg_refuse "cannot create $cepa_sg_dir for the lock"
exec {cepa_sg_fd}<"$cepa_sg_dir" || cepa_sg_refuse "cannot open $cepa_sg_dir for the lock"
flock -w "$cepa_sg_wait" "$cepa_sg_fd" ||
  cepa_sg_refuse "lock busy — another start held $cepa_sg_dir for ${cepa_sg_wait}s"

# --- count, under the lock ---
cepa_sg_read_running || cepa_sg_refuse "cannot count running stacks — $cepa_sg_err"
cepa_sg_others=$(cepa_sg_projects | grep -cvxF -- "$cepa_sg_proj")
cepa_sg_self=no
cepa_sg_projects | grep -qxF -- "$cepa_sg_proj" && cepa_sg_self=yes

cepa_sg_mem=$(awk '$1 == "MemAvailable:" && $3 == "kB" { print int($2 / 1024); f = 1 } END { if (!f) exit 1 }' \
  "$cepa_sg_meminfo" 2>/dev/null) && [[ $cepa_sg_mem =~ ^[0-9]+$ ]] ||
  cepa_sg_refuse "cannot read MemAvailable from $cepa_sg_meminfo; running -wt- stacks, longest idle first: $(cepa_sg_listing)"

if [ "$cepa_sg_others" -ge "$cepa_sg_max" ]; then
  cepa_sg_refuse "$cepa_sg_others running -wt- stacks other than $cepa_sg_proj, limit $cepa_sg_max; running -wt- stacks, longest idle first: $(cepa_sg_listing)"
fi
if [ "$cepa_sg_mem" -lt "$cepa_sg_min" ]; then
  cepa_sg_refuse "${cepa_sg_mem} MiB available, minimum $cepa_sg_min MiB; running -wt- stacks, longest idle first: $(cepa_sg_listing)"
fi

echo "STACK gate: ok — $cepa_sg_proj: $cepa_sg_others other running -wt- stacks, limit $cepa_sg_max; ${cepa_sg_mem} MiB available, minimum $cepa_sg_min MiB$([ "$cepa_sg_self" = yes ] && echo "; already running")"
"$@" {cepa_sg_fd}<&-
exit $?
