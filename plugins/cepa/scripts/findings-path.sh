#!/usr/bin/env bash
# findings-path.sh — reserve a fresh findings-file path in todos/ and print it.
#
# WHY (punch-list L54). Findings files were named by second alone
# (`todos/review-YYYY-MM-DD-HHMMSS.md`), and the writer typed the stamp
# itself. PR #108 (8d71f58) wrote `todos/review-2026-10-31-213000.md` over PR
# #107's file (cd40fdb), two hours later — the stamp was typed, not read from a
# clock: 29 of 101 stamps in this repo's todos/ end in `000`
# (`ls todos/review-*.md | grep -cE -- '-[0-9]{3}000\.md$'`, 2026-11-01).
# This is the shared-sink class (repo CLAUDE.md, "Shared sinks are sharded or
# serialized; composed paths are slugged"). This script closes it three ways:
#
#   1. the stamp comes from `date`, never from the writer;
#   2. the name carries a per-run component, slug(<scope>), where slug is
#      `cepa:autonomy` §5's slug(x) (defined there — this file implements it,
#      it does not redefine it) and <scope> is the current branch, or the short
#      SHA on a detached HEAD, or --scope;
#   3. the file is CREATED EXCLUSIVELY (bash noclobber, which opens with
#      O_EXCL). If the name exists, it tries `-2`, `-3`, … and never truncates
#      an existing file. The printed path is an empty file this run owns.
#
# Name:  <dir>/<kind>-YYYY-MM-DD-HHMMSS-<slug>[-N].md
# Every reader that globs `review-*.md` or `review-weekly-*.md` matches both
# this name and the old `<kind>-YYYY-MM-DD-HHMMSS.md` one, and the stamp still
# leads, so a sort by name is still a sort by time.
#
# Usage:
#   bash findings-path.sh [--kind review|review-weekly] [--scope <value>] [--dir <dir>]
#     --kind   review (default) or review-weekly
#     --scope  the per-run value to slug; default: the current branch, or the
#              short SHA on a detached HEAD. A weekly run passes its trunk.
#     --dir    default: <repo toplevel>/todos (created if missing)
#
# Output: one line, the absolute path of the reserved (empty) file.
# Exit:   0 reserved   2 usage, or the path could not be made   (stderr says why)
set -u

kind=review; scope=''; dir=''
while [ $# -gt 0 ]; do
  case "$1" in
    --kind)  shift; [ $# -gt 0 ] || { echo 'findings-path: --kind needs a value' >&2; exit 2; }; kind="$1" ;;
    --scope) shift; [ $# -gt 0 ] || { echo 'findings-path: --scope needs a value' >&2; exit 2; }; scope="$1" ;;
    --dir)   shift; [ $# -gt 0 ] || { echo 'findings-path: --dir needs a value' >&2; exit 2; }; dir="$1" ;;
    -h|--help) sed -n '2,37p' "$0"; exit 0 ;;
    *) echo "findings-path: unknown argument (see --help)" >&2; exit 2 ;;
  esac
  shift
done
case "$kind" in review|review-weekly) ;; *) echo 'findings-path: --kind must be review or review-weekly' >&2; exit 2 ;; esac

short_sha() { git rev-parse --short HEAD 2>/dev/null; }

# cepa:autonomy §5 slug(x). Bytes, not characters (LC_ALL=C), so a multi-byte
# character becomes a run of `-` that the collapse then folds to one.
slug() {
  local s
  s=$(printf '%s' "$1" | LC_ALL=C sed -e 's/[^A-Za-z0-9_-]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//')
  case "$s" in ''|.*) s=$(short_sha) ;; esac
  printf '%s' "$s"
}

# A detached HEAD gives an empty branch; slug() then falls back to the short
# SHA, as §5 says. That fallback is the only one (path-detached pins it).
[ -n "$scope" ] || scope=$(git branch --show-current 2>/dev/null) || scope=''
s=$(slug "$scope")
[ -n "$s" ] || { echo 'findings-path: no per-run component — no branch, no --scope, and no commit to take a short SHA from' >&2; exit 2; }

if [ -z "$dir" ]; then
  top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo 'findings-path: not in a git work tree and no --dir given' >&2; exit 2; }
  dir="$top/todos"
fi
mkdir -p -- "$dir" || { echo 'findings-path: cannot create the todos directory' >&2; exit 2; }
dir=$(cd -- "$dir" && pwd) || exit 2

stamp=$(date +%Y-%m-%d-%H%M%S) || exit 2
[[ "$stamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}$ ]] || { echo 'findings-path: date returned a malformed stamp' >&2; exit 2; }

base="$dir/$kind-$stamp-$s"
path="$base.md"; n=1
while :; do
  if ( set -C; : > "$path" ) 2>/dev/null; then
    printf '%s\n' "$path"; exit 0
  fi
  # Not created. If nothing is there, the failure was not a collision
  # (permissions, a dangling symlink): say so, never loop or fall through.
  [ -e "$path" ] || [ -L "$path" ] || { echo "findings-path: cannot create ${path##*/}" >&2; exit 2; }
  [ -L "$path" ] && [ ! -e "$path" ] && { echo "findings-path: ${path##*/} is a dangling symlink" >&2; exit 2; }
  n=$((n + 1))
  [ "$n" -le 99 ] || { echo "findings-path: 99 names taken for ${base##*/}" >&2; exit 2; }
  path="$base-$n.md"
done
