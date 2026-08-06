#!/usr/bin/env bash
# Generate CHANGELOG.md from this repo's GitHub Releases.
#
#   scripts/generate-changelog.sh [output-path]     default: CHANGELOG.md
#
# The file is DERIVED, never authored. That is the whole point: a hand-written
# changelog is a restatement surface (CLAUDE.md's hardcoded-counts and
# model-pin-restatement rules) and a shared append sink (its sharded-sinks
# rule). This script restates nothing — the releases are generated from merged
# PRs, and this file is generated from the releases — and it appends nothing:
# every run rewrites the file whole, at a single serialized trunk point, which
# is the form that rule explicitly permits.
#
# Idempotent by construction: the same releases produce a byte-identical file,
# so a caller can diff the result and skip an empty commit.
#
# Exit codes:
#   0  wrote the file
#   1  refused to write — see the message; any previous file is left intact
#   2  usage or environment error

set -uo pipefail

OUT="${1:-CHANGELOG.md}"

command -v gh  >/dev/null 2>&1 || { printf 'FATAL: gh not on PATH\n'  >&2; exit 2; }
command -v git >/dev/null 2>&1 || { printf 'FATAL: git not on PATH\n' >&2; exit 2; }

# GITHUB_REPOSITORY is set in Actions. Locally, resolve it from the remote so
# the script needs no arguments and no configuration.
REPO="${GITHUB_REPOSITORY:-}"
if [ -z "$REPO" ]; then
  url=$(git config --get remote.origin.url 2>/dev/null) || url=''
  # Handles git@github.com:owner/repo.git and https://github.com/owner/repo[.git]
  REPO=$(printf '%s' "$url" | sed -E 's#^.*[:/]([^/:]+/[^/]+)$#\1#; s#\.git$##')
fi
case "$REPO" in
  */*) ;;
  *) printf 'FATAL: could not determine owner/repo (got %s)\n' "${REPO:-<empty>}" >&2; exit 2 ;;
esac

WORK=$(mktemp -d "${TMPDIR:-/tmp}/cepa-changelog.XXXXXX") || exit 2
trap 'rm -rf "$WORK"' EXIT
TMP="$WORK/CHANGELOG.md"
FEED="$WORK/releases.tsv"

# ONE call, not one per release, and gh's BUILT-IN jq rather than the external
# binary: jq is not installed on every machine that will run this (it was not on
# the author's), and a release tool that only works where an optional dependency
# happens to exist is a tool that fails the first time it is needed.
#
# The body is base64-encoded into the TSV because release bodies are multi-line
# and TSV is not. Decoding happens per row, below.
#
# --paginate matters: a repo past 30 releases would otherwise silently lose its
# oldest, and a changelog that stops at the page boundary is worse than none --
# it reads as complete.
if ! gh api "repos/$REPO/releases" --paginate \
       --jq '.[] | select(.draft == false)
             | [.tag_name, .created_at, (.name // ""), .html_url, ((.body // "") | @base64)]
             | @tsv' > "$FEED" 2>"$WORK/gh.err"; then
  printf 'FATAL: could not read releases for %s: %s\n' \
    "$REPO" "$(head -1 "$WORK/gh.err")" >&2
  exit 1
fi

count=$(grep -c . "$FEED")
# A generator that asserts nothing is not a pass. Zero releases is far likelier
# to be a bad token, a rename, or an API blip than a genuinely empty history --
# and writing that result would replace a good file with a plausible-looking
# empty one.
if [ "$count" -eq 0 ]; then
  printf 'FATAL: the API returned no published releases for %s.\n' "$REPO" >&2
  printf '       Refusing to overwrite %s with an empty history.\n' "$OUT" >&2
  exit 1
fi

{
  printf '# Changelog\n\n'
  printf '<!--\n'
  printf '  GENERATED FILE - do not edit by hand.\n'
  printf '  Produced by scripts/generate-changelog.sh from this repository'"'"'s GitHub\n'
  printf '  Releases, which are themselves generated from merged PR titles. Every run\n'
  printf '  rewrites this file in full, so hand edits are lost at the next release.\n'
  printf '  To change an entry, edit the release (or the PR title) it came from.\n'
  printf -- '-->\n\n'
  printf 'Every version below is a tag you can check out: `git checkout vX.Y.Z`.\n\n'
} > "$TMP"

# Explicit version sort, ascending here so each entry knows its predecessor for
# the compare link; the emit loop below walks the list in reverse. NOT the API's
# order: that matches version order today only because the backfilled tag dates
# were repaired by hand, and a file whose ordering depends on a one-time repair
# reorders itself the next time someone tags out of band.
mapfile -t ROWS < <(sort -t"$(printf '\t')" -k1,1V "$FEED")

emit() {  # emit <tsv-row> <predecessor-tag-or-empty>
  local row="$1" prev="$2"
  local tag created name url b64 body date_only lead bullets
  IFS=$'\t' read -r tag created name url b64 <<< "$row"
  [ -z "$tag" ] && return 0

  body=$(printf '%s' "$b64" | base64 -d 2>/dev/null) || body=''
  date_only="${created%%T*}"

  printf '## [%s](%s) - %s\n\n' "$tag" "$url" "$date_only" >> "$TMP"

  # The release title carries framing the bullets alone do not, most visibly on
  # multi-PR releases like v1.6.0. Strip the leading "vX.Y.Z - " so it does not
  # simply repeat the heading. Parameter expansion, not sed: these titles carry
  # regex metacharacters (dots, parens, slashes, +) in almost every release.
  lead="$name"
  lead="${lead#"$tag"}"
  lead="${lead# — }"
  lead="${lead# - }"
  if [ -n "$lead" ] && [ "$lead" != "$name" ]; then
    printf '_%s_\n\n' "$lead" >> "$TMP"
  fi

  # Bullets come from the body, but ONLY from its "What's Changed" section.
  # "New Contributors" uses the same `* ` syntax, and merging the two lists
  # would present a contributor line as a change. Any `## ` heading closes the
  # section, so a future section added by GitHub cannot leak in either.
  bullets=$(printf '%s\n' "$body" \
    | awk '/^## /   { inchanges = (index($0, "Changed") > 0) ? 1 : 0; next }
           inchanges && /^\* / { print }' \
    | sed -E "s#https://github.com/${REPO}/pull/([0-9]+)#\#\1#g")

  if [ -n "$bullets" ]; then
    printf '%s\n\n' "$bullets" >> "$TMP"
  else
    printf '_No PR-derived entries; see the release page._\n\n' >> "$TMP"
  fi

  if [ -n "$prev" ]; then
    printf '[Compare %s...%s](https://github.com/%s/compare/%s...%s)\n\n' \
      "$prev" "$tag" "$REPO" "$prev" "$tag" >> "$TMP"
  fi
}

i=$(( ${#ROWS[@]} - 1 ))
while [ "$i" -ge 0 ]; do
  if [ "$i" -gt 0 ]; then
    prevtag=$(printf '%s' "${ROWS[$((i - 1))]}" | cut -f1)
  else
    prevtag=''
  fi
  emit "${ROWS[$i]}" "$prevtag"
  i=$((i - 1))
done

# Sanity floor: the header alone is ~11 lines, so anything at or under that
# means the emit loop wrote nothing and the guards above missed it.
lines=$(wc -l < "$TMP")
if [ "$lines" -le 12 ]; then
  printf 'FATAL: generated changelog has only %s lines - the release loop produced nothing.\n' "$lines" >&2
  printf '       Refusing to overwrite %s.\n' "$OUT" >&2
  exit 1
fi

# Atomic: a failure above must not leave a half-written changelog on disk.
# cat-into-place rather than mv, because $WORK and $OUT are often on different
# filesystems (mktemp -d lands in /tmp) and mv would fall back to a non-atomic
# copy anyway — this way the truncate-and-write is at least a single open.
if ! cp "$TMP" "$OUT.new" || ! mv -f "$OUT.new" "$OUT"; then
  rm -f "$OUT.new"
  printf 'FATAL: could not move the generated file into place at %s\n' "$OUT" >&2
  exit 1
fi

printf 'wrote %s - %s releases, %s lines\n' "$OUT" "$count" "$lines"
