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

command -v gh     >/dev/null 2>&1 || { printf 'FATAL: gh not on PATH\n'     >&2; exit 2; }
command -v git    >/dev/null 2>&1 || { printf 'FATAL: git not on PATH\n'    >&2; exit 2; }
# base64 belongs here for the same reason gh and git do. It was omitted, and the
# decode below used to swallow its failure -- so on a host whose base64 wants -D
# rather than -d, EVERY entry silently degraded to the no-entries fallback and
# the script still exited 0 reporting the full release count.
command -v base64 >/dev/null 2>&1 || { printf 'FATAL: base64 not on PATH\n' >&2; exit 2; }

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
# $OUT.new is in the CALLER's directory, not $WORK, so the tmpdir cleanup does
# not cover it: a SIGTERM between the cp and the mv below would otherwise strand
# CHANGELOG.md.new in the repo, where `git reset --hard` will not remove it.
trap 'rm -rf "$WORK"; rm -f "$OUT.new"' EXIT
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
# Bounded explicitly, not left to the caller's job timeout. `mutation-sweep.yml`
# already wraps its three gh calls in `timeout 120` for this reason: a job-level
# bound kills the WHOLE job, so one hung call consumes every retry attempt as
# well as itself. -k grace matches the pattern used in run-mutation-sweep.sh.
if ! timeout -k 5 60 gh api "repos/$REPO/releases" --paginate \
       --jq '.[] | select(.draft == false)
             | [.tag_name, .created_at, (.name // ""), .html_url, ((.body // "") | @base64)]
             | @tsv' > "$FEED" 2>"$WORK/gh.err"; then
  printf 'FATAL: could not read releases for %s: %s\n' \
    "$REPO" "$(head -1 "$WORK/gh.err")" >&2
  exit 1
fi

# `|| true` then validate: grep -c exits 1 on no matches (printing 0, which is
# the answer we want) but exits 2 on an unreadable file printing NOTHING, and an
# empty $count made the numeric test below error out -- which an `if` reads as
# false, falling straight through the one guard standing between a bad token and
# an emptied changelog.
count=$(grep -c . "$FEED") || true
case "$count" in
  ''|*[!0-9]*)
    printf 'FATAL: could not count releases in the API response (got %s).\n' "${count:-<empty>}" >&2
    printf '       Refusing to overwrite %s.\n' "$OUT" >&2
    exit 1 ;;
esac

# A generator that asserts nothing is not a pass. Zero releases is far likelier
# to be a bad token, a rename, or an API blip than a genuinely empty history --
# and writing that result would replace a good file with a plausible-looking
# empty one.
if [ "$count" -eq 0 ]; then
  printf 'FATAL: the API returned no published releases for %s.\n' "$REPO" >&2
  printf '       Refusing to overwrite %s with an empty history.\n' "$OUT" >&2
  exit 1
fi

# Every row must carry exactly 5 fields. A short row means the API response
# shape changed under us, and the emit loop would render the shift as plausible
# markdown rather than failing -- see the field-splitting note in emit().
if ! awk -F'\t' 'NF != 5 { exit 1 }' "$FEED"; then
  printf 'FATAL: a release row does not have 5 tab-separated fields.\n' >&2
  printf '       Refusing to overwrite %s from a malformed response.\n' "$OUT" >&2
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
# Sorted through a FILE, not a process substitution: `mapfile < <(sort ...)`
# leaves $? at 0 no matter how sort exits, so a sort that died mid-stream handed
# the loop a truncated list and nothing noticed. LC_ALL=C pins collation, so
# byte-identical output is a property of the script rather than a coincidence of
# whichever locale the runner happens to have.
if ! LC_ALL=C sort -t"$(printf '\t')" -k1,1V "$FEED" > "$WORK/sorted.tsv"; then
  printf 'FATAL: could not sort the release feed.\n' >&2
  printf '       Refusing to overwrite %s.\n' "$OUT" >&2
  exit 1
fi
mapfile -t ROWS < "$WORK/sorted.tsv"

emit() {  # emit <tsv-row> <predecessor-tag-or-empty>
  local row="$1" prev="$2"
  local tag created name url b64 body date_only lead bullets

  # `cut -f`, NOT `IFS=$'\t' read`. Tab is an IFS *whitespace* character, so read
  # collapses runs of tabs into one delimiter and an empty field simply vanishes,
  # shifting every later field left. A release with a blank title therefore put
  # html_url into $name, the base64 body into $url, and nothing into $b64 -- and
  # the result was not an error but plausible markdown: a heading whose link was
  # a base64 blob, every bullet gone, and the italic lead suppressed because
  # $lead now equalled $name. Committed to main unattended. cut treats each
  # delimiter separately and preserves empty fields.
  tag=$(printf '%s' "$row"     | cut -f1)
  created=$(printf '%s' "$row" | cut -f2)
  name=$(printf '%s' "$row"    | cut -f3)
  url=$(printf '%s' "$row"     | cut -f4)
  b64=$(printf '%s' "$row"     | cut -f5)
  [ -z "$tag" ] && return 0

  # Belt and braces on the same defect: if a field ever shifts again, $url stops
  # looking like a URL. Fail rather than render it.
  case "$url" in
    https://*) ;;
    *) printf 'FATAL: release %s has a malformed html_url (%.60s) -- fields are misaligned.\n' \
         "$tag" "$url" >&2
       exit 1 ;;
  esac

  # A decode failure is fatal, not an empty body. Swallowing it degraded every
  # entry to the no-entries fallback while the script exited 0 reporting the full
  # count -- the file lost 100% of its content and still cleared every guard.
  # An empty $b64 decodes to an empty string with exit 0, so a genuinely
  # bodyless release still takes the fallback path below.
  if ! body=$(printf '%s' "$b64" | base64 -d 2>"$WORK/b64.err"); then
    printf 'FATAL: could not decode the release body for %s: %s\n' \
      "$tag" "$(head -1 "$WORK/b64.err")" >&2
    exit 1
  fi
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

  # Two distinct causes, two distinct strings. One shared fallback meant a
  # bodyless release and a body whose section headings did not match were
  # indistinguishable in the output, so nobody could tell a correct entry from a
  # parser that had stopped matching.
  if [ -n "$bullets" ]; then
    printf '%s\n\n' "$bullets" >> "$TMP"
  elif [ -z "$body" ]; then
    printf '_This release has no body; see the release page._\n\n' >> "$TMP"
  else
    printf '_Release body has no parseable change list; see the release page._\n\n' >> "$TMP"
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
  # emit's appends can fail (a full disk mid-loop) and its return value used to
  # be discarded, so the loop reported success having written one line of many.
  if ! emit "${ROWS[$i]}" "$prevtag"; then
    printf 'FATAL: failed while writing the entry for row %s.\n' "$i" >&2
    printf '       Refusing to overwrite %s.\n' "$OUT" >&2
    exit 1
  fi
  i=$((i - 1))
done

# Reconcile OUTPUT against INPUT. This replaces a line-count floor that could not
# do the job it existed for: the header emits exactly 12 lines against a `-le 12`
# threshold (zero margin, and its own comment said "~11"), while a single
# surviving release cleared it at 16 -- so 27 of 28 releases could vanish and
# still pass. Worse, in a script whose header argues that restated counts are the
# failure class it exists to eliminate, that 12 was a restated count.
emitted=$(grep -c '^## \[' "$TMP") || true
if [ "$emitted" != "$count" ]; then
  printf 'FATAL: read %s releases but emitted %s entries.\n' "$count" "${emitted:-<none>}" >&2
  printf '       Refusing to overwrite %s with a truncated history.\n' "$OUT" >&2
  exit 1
fi
lines=$(wc -l < "$TMP")

# Atomic: a failure above must not leave a half-written changelog on disk.
# Copy to a SIBLING of $OUT, then rename. $WORK is a different filesystem
# (mktemp -d lands in /tmp) so a direct mv from there would degrade to a
# non-atomic copy; $OUT.new is beside $OUT, so this rename is atomic. Do not
# "simplify" it to a single mv from $WORK -- that is the weaker form this two
# step exists to avoid. $OUT.new is cleaned up by the EXIT trap.
if ! cp "$TMP" "$OUT.new" || ! mv -f "$OUT.new" "$OUT"; then
  rm -f "$OUT.new"
  printf 'FATAL: could not move the generated file into place at %s\n' "$OUT" >&2
  exit 1
fi

printf 'wrote %s - %s releases, %s lines\n' "$OUT" "$count" "$lines"
