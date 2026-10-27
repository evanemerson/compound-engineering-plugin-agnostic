#!/usr/bin/env bash
# cepa write-back-gap check — read-only. Reports when a PR body cites a
# `todos/*.md` findings file that still holds `status: deferred` findings at
# the PR's tree. Never modifies anything. Run from the repo root.
#
# WHY IT EXISTS. Nothing in the ordinary branch/PR/merge path writes a
# decided or fixed finding's status back to its findings file, and
# `/cepa:sweep` writes back only for items it consumed itself. Option (b) of
# the 2026-09-25 write-back-gap decision in `memory/tasks.d/2026-09-25-main.md`,
# chosen when its second instance appeared (punch-list L18 in
# `memory/tasks.d/2026-10-02-punch-list.md`). The instance this check is built
# to catch: PR #17 cited `todos/review-2026-07-12-115234.md` by path and said
# its "4 policy decisions" were resolved; all four findings stayed `deferred`
# for ~10 weeks, until PR #79 (`86332d8`) closed three of them.
#
# MATCHING IS AT FILE LEVEL. #17 never named a finding number, so a check that
# needs `finding #3` in the body would miss the instance it exists for. A body
# that cites a file is reported with EVERY deferred finding in that file; the
# body's finding numbers, if any, are not read (STATED LIMITS).
#
# WARN VS MISS — the semantics, and why:
#   WARN (never fails): a cited file holds deferred findings. A deferred
#     finding can be open on purpose — #17's file still holds ### 2, whose
#     decision waits on a verification that has no record. Only a human can
#     tell "open on purpose" from "decided, never written back", so the check
#     names each file and each deferred `### N` and leaves the call to the
#     reader. A failing check here would be red on every later PR that cites
#     the file, and the ways to turn it green would be to stop citing the
#     file or to write a false status — both worse than the gap.
#   WARN (never fails): a cited path that is not a file at the checked tree.
#     The citation could not be checked, so it must not read as clean; but a
#     body may name a file that a later commit deleted, which is not a gap.
#   MISS (exit 1): the probe did not reach its target — the body could not be
#     fetched, the ref does not resolve, a cited file could not be read, or a
#     cited file has `### N` finding headings but the status pattern matched
#     ZERO rows (or its body could not be extracted). Each of these would
#     otherwise read as "0 deferred", the false clean that CONCEPTS.md
#     `### Absence measurement` describes.
#   In CI each WARN is also emitted as a `::warning` annotation, so a green
#   job still shows it on the PR and the commit.
#
# THE STATUS PATTERN IS NOT RESTATED HERE. This script SOURCES
# plugins/cepa/scripts/check-findings-file.sh — the one executable copy of the
# `cepa:file-todos` field-spelling pattern — and composes its FIELD_PRE and
# FIELD_POST fragments, and reads each file through its `_cff_body` (the body
# after frontmatter, fenced regions removed). A row is deferred when its value
# word — the `[a-z_-]+` value class that `check-findings-file.sh --rows`
# prints — is `deferred`, matched case-blind. The findings file's own
# `summary: deferred:` counter is never read: #17's file declared
# `deferred: 0` over a body with four deferred rows.
#
# A finding is the section under a `### N` (or `### N-M`) heading, to the next
# `#`, `##` or `###` heading. A deferred row outside every such section is
# reported as a row "outside any ### N heading", never dropped.
#
# THE BODY IS UNTRUSTED. It is written to a temp file by `gh api --jq` and read
# only by grep. No body text is ever printed: every output line interpolates a
# cited path that passed the citation pattern below (letters, digits, `.`,
# `_`, `-` only), `### N` ids, SHAs, PR numbers and counts.
#
# Usage:
#   check-writeback-gap.sh --pr N [--ref REF]     PR N's body, at REF (default HEAD)
#   check-writeback-gap.sh --commit SHA           each merged PR whose merge commit
#                                                 is SHA, at SHA (a push to main)
#   check-writeback-gap.sh --body-file F --ref REF   a body on disk (the controls)
#   check-writeback-gap.sh --replay               every merged PR in the repo, each
#                                                 at its own merge commit
# Exit: 0 no MISS (WARN allowed), 1 any MISS, 2 usage.
#
# STATED LIMITS — none of these can read as a pass:
#   * Citation forms read: `todos/X.md`, `./todos/X.md`, `/todos/X.md`, and a
#     GitHub URL ending `/blob/<ref>/todos/X.md`, anywhere in the body (link,
#     bare text, code span). A deeper path (`plugins/x/todos/X.md`, a
#     subdirectory of todos/) is not a citation of this repo's findings store
#     and is ignored. A file named only by its stamp (`review-2026-07-12-…`
#     with no `todos/`) is not seen.
#   * Finding numbers in the body are not read. A PR that fixed ### 3 and
#     cites the file is reported with every deferred finding in it.
#   * `--commit` finds PRs through GitHub's commit→PR association, matched on
#     merge_commit_sha. A direct push has none and reports INFO, not a pass
#     over anything. The pull_request run checks the same body before merge.
#   * A body edited AFTER merge is not re-checked by the push run; `--replay`
#     reads every body as it stands now.

set -uo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"
CFF="${CEPA_FINDINGS_CHECKER:-$ROOT/plugins/cepa/scripts/check-findings-file.sh}"
if [ ! -f "$CFF" ]; then
  printf 'MISS writeback-gap: the findings checker is missing (%s) — without its status pattern no file can be read\n' "${CFF//[[:cntrl:]]/?}"
  exit 1
fi
# shellcheck source=/dev/null
. "$CFF"

MISSES=0; WARNS=0; CITES=0; PRS=0
FLAGGED=''
WORK="$(mktemp -d -t cepa-writeback-gap.XXXXXX)" || { echo "MISS writeback-gap: mktemp failed"; exit 1; }
trap 'rm -rf "$WORK"' EXIT

_flat() { printf '%s' "${1//[[:cntrl:]]/?}"; }
miss() { printf 'MISS writeback-gap: %s\n' "$(_flat "$1")"; MISSES=$((MISSES + 1)); }
info() { printf 'INFO writeback-gap: %s\n' "$(_flat "$1")"; }
warn() {
  local m; m="$(_flat "$1")"
  printf 'WARN writeback-gap: %s\n' "$m"
  WARNS=$((WARNS + 1))
  # A workflow command is parsed from stdout. The message holds only
  # pattern-checked paths, ids, SHAs and counts, so it cannot carry `::`
  # or a newline of its own.
  [ "${GITHUB_ACTIONS:-}" != true ] || printf '::warning title=Write-back gap::%s\n' "$m"
}

# The citation pattern. A token is read with a wide class, then ACCEPTED only
# in the forms STATED LIMITS lists; the captured path is `todos/<name>.md`.
CITE_TOKEN='[A-Za-z0-9._/:%~+-]*todos/[A-Za-z0-9_-][A-Za-z0-9._-]*\.md'
CITE_ACCEPT='^((\./|/)?|.*/blob/[^/]+/)(todos/[A-Za-z0-9_-][A-Za-z0-9._-]*\.md)$'

# cites <bodyfile> — the cited todos/ paths, one per line, sorted and unique.
cites() {
  local t
  { grep -oE "$CITE_TOKEN" "$1"; [ $? -le 1 ]; } | while IFS= read -r t; do
    if [[ "$t" =~ $CITE_ACCEPT ]]; then printf '%s\n' "${BASH_REMATCH[3]}"; fi  # GUARD:accept
  done | sort -u
}

# scan <file> — prints `H <headings>`, `R <status rows>`, then `D <id>` per
# deferred row (`-` when the row is outside every `### N` section). rc 2 when
# a pattern errored.
scan() {
  local f="$1" body tagged lines rc n
  body="$(_cff_body "$f")" || return 2
  tagged="$(awk '
    BEGIN { id = "-"; n = 0 }
    /^#(#|##)?[[:space:]]/ {
      id = "-"
      if (match($0, /^###[[:space:]]+[0-9]+([[:space:]]*-[[:space:]]*[0-9]+)?/)) {
        id = substr($0, 1, RLENGTH); sub(/^###[[:space:]]+/, "", id); gsub(/[[:space:]]/, "", id); n++
      }
      next
    }
    { print id "\t" $0 }
    END { print "#H\t" n }' <<<"$body")" || return 2
  printf 'H %s\n' "$(awk -F'\t' '$1 == "#H" { print $2 }' <<<"$tagged")"
  lines="$(awk -F'\t' '$1 != "#H" { sub(/^[^\t]*\t/, ""); print }' <<<"$tagged")"
  n="$(grep -ciE "${FIELD_PRE}status${FIELD_POST}[a-z_-]+" <<<"$lines")"; rc=$?
  [ "$rc" -le 1 ] || return 2
  printf 'R %s\n' "$n"
  grep -niE "${FIELD_PRE}status${FIELD_POST}deferred([^a-z_-]|$)" <<<"$lines" | cut -d: -f1 > "$WORK/hits"  # GUARD:deferred
  [ "${PIPESTATUS[0]}" -le 1 ] || return 2
  awk -F'\t' 'NR == FNR { want[$1] = 1; next } $1 != "#H" { i++; if (i in want) print "D " $1 }' \
    "$WORK/hits" <(printf '%s\n' "$tagged") || return 2
}

# check_body <bodyfile> <ref> <label> — one body against one tree.
check_body() {
  local body="$1" ref="$2" label="$3" sha short p n f out h r ids outside nd paths what
  sha="$(git rev-parse --verify -q "${ref}^{commit}")" || { miss "${label}: ref ${ref} does not resolve to a commit — nothing was checked"; return; }  # GUARD:ref
  short="${sha:0:12}"
  paths="$(cites "$body")" || { miss "${label}: reading the body failed — nothing was checked"; return; }
  if [ -z "$paths" ]; then
    info "${label} cites no todos/*.md file — nothing to check"
    return
  fi
  n=0
  while IFS= read -r p; do
    n=$((n + 1)); CITES=$((CITES + 1))
    if [ "$(git cat-file -t "${sha}:${p}" 2>/dev/null)" != blob ]; then
      warn "${label} cites ${p}, which is not a file at ${short} — the citation was not checked"  # GUARD:absent
      continue
    fi
    f="$WORK/f$n.md"
    git show "${sha}:${p}" > "$f" 2>/dev/null || { miss "${label}: ${p} at ${short} could not be read — nothing in it was checked"; continue; }
    out="$(scan "$f")" || { miss "${label}: the status scan of ${p} at ${short} errored — nothing in it was checked"; continue; }
    h="$(sed -n 's/^H //p' <<<"$out")"; r="$(sed -n 's/^R //p' <<<"$out")"
    if [ "$h" -eq 0 ] && grep -qE '^###[[:space:]]+[0-9]' "$f"; then
      miss "${label}: ${p} at ${short} has ### N headings, but none survived body extraction (no frontmatter, or an unclosed fence) — nothing in it was checked"  # GUARD:nobody
      continue
    fi
    if [ "$h" -gt 0 ] && [ "$r" -eq 0 ]; then
      miss "${label}: ${p} at ${short} has ${h} ### N heading(s) and ZERO status rows — the pattern did not fire, so 0 deferred would be a false clean"  # GUARD:norows
      continue
    fi
    ids="$(sed -n 's/^D //p' <<<"$out" | grep -v '^-$' | sort -u | sort -t- -k1,1n -k2,2n | sed 's/^/### /' | paste -sd, - | sed 's/,/, /g')"
    outside="$(grep -c '^D -$' <<<"$out")"
    nd="$(sed -n 's/^D //p' <<<"$out" | grep -v '^-$' | sort -u | grep -c .)"
    if [ "$nd" -eq 0 ] && [ "$outside" -eq 0 ]; then
      info "${label} cites ${p}: 0 deferred of ${h} finding(s) at ${short}"
      continue
    fi
    what=""
    [ "$nd" -eq 0 ] || what="${nd} deferred finding(s): ${ids}"
    [ "$outside" -eq 0 ] || what="${what:+${what}; }${outside} deferred row(s) outside any ### N heading"  # GUARD:outside
    warn "${label} cites ${p}, which holds ${what} at ${short} — confirm each is open on purpose; a decided or fixed finding needs its status written back"
    FLAGGED="${FLAGGED} ${label#PR }"
  done <<<"$paths"
}

# fetch_body <pr> <out> — the body as GitHub holds it now. Never through a
# shell string: gh writes it, grep reads it.
fetch_body() {
  gh api "repos/{owner}/{repo}/pulls/$1" --jq '.body // ""' > "$2"
}

usage() {
  printf 'usage: %s --pr N [--ref REF] | --commit SHA | --body-file F --ref REF | --replay\n' "${0##*/}" >&2
  exit 2
}

summary() {
  printf -- '-- %s MISS, %s WARN — %s PR body(ies), %s citation(s) --\n' "$MISSES" "$WARNS" "$PRS" "$CITES"
  [ "$MISSES" -eq 0 ]
}

case "${1:-}" in
  --pr)
    [ $# -eq 2 ] || [ $# -eq 4 ] || usage
    [[ "$2" =~ ^[0-9]+$ ]] || usage
    ref=HEAD
    if [ $# -eq 4 ]; then [ "$3" = --ref ] || usage; ref="$4"; fi
    PRS=1
    if fetch_body "$2" "$WORK/body"; then check_body "$WORK/body" "$ref" "PR #$2"
    else miss "PR #$2: fetching its body failed — nothing was checked"; fi
    ;;
  --commit)
    [ $# -eq 2 ] || usage
    [[ "$2" =~ ^[0-9a-f]{40}$ ]] || usage
    nums="$(gh api "repos/{owner}/{repo}/commits/$2/pulls" --jq ".[] | select(.merge_commit_sha == \"$2\") | .number")" \
      || { miss "commit ${2:0:12}: looking up its merged PR failed — nothing was checked"; summary; exit $?; }
    if [ -z "$nums" ]; then
      info "commit ${2:0:12} is the merge commit of no PR (a direct push) — no body to check"
    fi
    for pr in $nums; do
      [[ "$pr" =~ ^[0-9]+$ ]] || { miss "commit ${2:0:12}: the PR lookup returned a non-number — nothing was checked"; continue; }
      PRS=$((PRS + 1))
      if fetch_body "$pr" "$WORK/body"; then check_body "$WORK/body" "$2" "PR #$pr"
      else miss "PR #$pr: fetching its body failed — nothing was checked"; fi
    done
    ;;
  --body-file)
    [ $# -eq 4 ] && [ "$3" = --ref ] || usage
    [ -r "$2" ] || { miss "the body file is not readable — nothing was checked"; summary; exit $?; }
    PRS=1
    check_body "$2" "$4" "the body"
    ;;
  --replay)
    [ $# -eq 1 ] || usage
    gh api --paginate "repos/{owner}/{repo}/pulls?state=closed&per_page=100" \
      --jq '.[] | select(.merged_at != null) | "\(.number) \(.merge_commit_sha) \(.body // "" | @base64)"' > "$WORK/prs" \
      || { miss "listing merged PRs failed — nothing was checked"; summary; exit $?; }
    while read -r pr sha b64; do
      [[ "$pr" =~ ^[0-9]+$ && "$sha" =~ ^[0-9a-f]{40}$ ]] || { miss "the merged-PR list held a malformed row — it was not checked"; continue; }
      PRS=$((PRS + 1))
      base64 -d <<<"$b64" > "$WORK/body" 2>/dev/null || { miss "PR #$pr: its body did not decode — nothing was checked"; continue; }
      check_body "$WORK/body" "$sha" "PR #$pr"
    done < <(sort -n "$WORK/prs")
    [ "$PRS" -gt 0 ] || miss "the merged-PR list was empty — a replay over nothing is not a pass"
    printf -- '-- replay flagged: %s --\n' "$(tr ' ' '\n' <<<"$FLAGGED" | grep -v '^$' | sort -t'#' -k2,2n -u | paste -sd' ' -)"
    ;;
  *) usage ;;
esac
summary
