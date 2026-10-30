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
# from the review's date (2026-07-12) until PR #79 (`86332d8`, 2026-10-02)
# closed three of them.
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
# prints — is `deferred`, matched case-blind. That value TAIL is local, and
# deliberately looser than the sourced VAL_TAIL (which the counter leg uses to
# pin a value at end of line): `status: deferred (decided 2026-07-12, …)` is
# still a deferred finding, and VAL_TAIL would not count it. The controls'
# `deferred` mutant swaps in VAL_TAIL and must lose `tail_comment`. The
# findings file's own
# `summary: deferred:` counter is never read: #17's file declared
# `deferred: 0` over a body with four deferred rows.
#
# A finding is the section under a `### N` (or `### N-M`) heading, to the next
# `#`, `##` or `###` heading. A deferred row outside every such section is
# reported as a row "outside any ### N heading", never dropped.
#
# BODY EXTRACTION IS SHARED, AND SO ARE ITS LIMITS. `_cff_body` toggles on
# ``` lines only: it does not know `~~~` fences, and an unclosed ``` fence
# swallows every line after it (residual 30 in
# memory/tasks.d/2026-10-22-fix-integrity-producer-self-check.md). This script
# does not fix that; it refuses to read past it. A file whose post-frontmatter
# ``` lines leave a fence open is a MISS, because every finding after the
# opener went unread — including the `~~~` block that quotes one ``` line.
#
# THE BODY IS UNTRUSTED. It is written to a temp file by `gh api --jq` and read
# only by grep. No body byte reaches the output except a cited path that
# passed the citation pattern below (letters, digits, `.`, `_`, `-` only).
# Every other interpolated value is a `### N` id, a SHA, a PR number, a count
# or a command-line argument, and `_flat` turns control characters into `?`
# on every line.
#
# Usage:
#   check-writeback-gap.sh --pr N [--ref REF]     PR N's body, at REF (default HEAD)
#   check-writeback-gap.sh --commit SHA...        each merged PR whose merge commit
#                                                 is one of the SHAs, at that SHA
#                                                 (a push to main)
#   check-writeback-gap.sh --body-file F --ref REF   a body on disk (the controls)
#   check-writeback-gap.sh --replay               every merged PR in the repo, each
#                                                 at its own merge commit
# Exit: 0 no MISS (WARN allowed), 1 any MISS, 2 usage.
#
# STATED LIMITS — none of these can read as a pass:
#   * Citation forms read: `todos/X.md`, `./todos/X.md`, `/todos/X.md`,
#     `../todos/X.md`, and a URL with `/blob/`, `/tree/` or `/raw/`, then a
#     ref (slashes allowed — `fix/<wt>/<desc>` is this repo's branch shape),
#     then `/todos/X.md` — anywhere in the body (link, bare text, code span).
#     The URL's owner and repo are NOT compared: a link to another repo's
#     todos/X.md is read as this repo's. A ref with slashes is ambiguous, so
#     `/blob/main/plugins/x/todos/X.md` is read as todos/X.md too; both
#     over-read, toward a WARN, never toward a silent pass.
#   * Any other token that contains `todos/…​.md` — a deeper path
#     (`plugins/x/todos/X.md`), a subdirectory of todos/, `X.mdx` — is not a
#     citation. It is counted in an INFO line, never dropped without a trace.
#     A file named only by its stamp (no `todos/`) is not seen.
#   * A cited file with no `### N` heading and no status row is a WARN: it
#     may not be a findings file at all, and 0 deferred would be a false
#     clean. The one exception is INFO: its frontmatter `summary:` declares
#     `total: 0`, so the empty body is what the file says it holds.
#   * Finding numbers in the body are not read. A PR that fixed ### 3 and
#     cites the file is reported with every deferred finding in it.
#   * `--commit` finds PRs through GitHub's commit→PR association, matched on
#     merge_commit_sha. That association can lag a fresh merge, so when it is
#     empty and the subject ends `(#N)` — this repo's squash subjects do —
#     PR N is fetched and used only if ITS merge_commit_sha is the commit. A
#     commit that neither route ties to a PR reports INFO (a direct push), not
#     a pass over anything. A rebase merge (a commit that is not the PR's
#     merge_commit_sha) is not tied to its PR. The workflow passes every
#     first-parent commit of the push (`before..HEAD`), or HEAD alone when the
#     push has no usable `before`; the pull_request run checks the same body
#     before merge.
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
  [ "${GITHUB_ACTIONS:-}" != true ] || printf '::warning title=Write-back gap::%s\n' "$m"  # GUARD:gha
}

# The citation pattern. A token is read with a wide class, then ACCEPTED only
# in the forms STATED LIMITS lists; the captured path is `todos/<name>.md`.
# The token runs past `.md` over word characters, so `X.mdx` is one token
# that fails CITE_NAME rather than a citation of `X.md`.
CITE_TOKEN='[A-Za-z0-9._/:%~+-]*todos/[A-Za-z0-9_-][A-Za-z0-9._-]*\.md[A-Za-z0-9_]*'
CITE_NAME='^todos/[A-Za-z0-9_-][A-Za-z0-9._-]*\.md$'
CITE_PREFIX='^((\./|/|(\.\./)+)?|.*/(blob|tree|raw)/.+/)$'

# cites <bodyfile> — `A <path>` per accepted citation (sorted, unique), and one
# `X` per token that held `todos/` but was not accepted.
cites() {
  local t name prefix
  { grep -oE "$CITE_TOKEN" "$1"; [ $? -le 1 ]; } | while IFS= read -r t; do
    name="todos/${t##*todos/}"; prefix="${t%"$name"}"
    if [[ "$name" =~ $CITE_NAME && "$prefix" =~ $CITE_PREFIX ]]; then printf 'A %s\n' "$name"; else printf 'X\n'; fi  # GUARD:accept
  done | sort -u -k1,1 -k2,2
}

# scan <file> — prints `H <headings>`, `R <status rows>`, then `D <id>` per
# deferred row (`-` when the row is outside every `### N` section). rc 2 when
# a pattern errored.
scan() {
  local f="$1" body tagged lines rc n fo ps
  # The fence state `_cff_body` ends in, by its own toggle rule. 1 means a
  # fence is still open, so every line after its opener was dropped.
  fo="$(awk 'NR==1 && /^---[[:space:]]*$/ {infm=1; next} infm && /^---[[:space:]]*$/ {infm=0; body=1; next} body && /^[[:space:]]*```/ {open = !open} END {print open + 0}' "$f")" || return 2
  printf 'F %s\n' "$fo"
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
  lines="$(awk -F'\t' '$1 != "#H" { sub(/^[^\t]*\t/, ""); print }' <<<"$tagged")" || return 2
  n="$(grep -ciE "${FIELD_PRE}status${FIELD_POST}[a-z_-]+" <<<"$lines")"; rc=$?
  [ "$rc" -le 1 ] || return 2
  printf 'R %s\n' "$n"
  grep -niE "${FIELD_PRE}status${FIELD_POST}deferred([^a-z_-]|$)" <<<"$lines" | cut -d: -f1 > "$WORK/hits"  # GUARD:deferred
  ps=("${PIPESTATUS[@]}")
  [ "${ps[0]}" -le 1 ] && [ "${ps[1]}" -eq 0 ] || return 2
  awk -F'\t' 'NR == FNR { want[$1] = 1; next } $1 != "#H" { i++; if (i in want) print "D " $1 }' \
    "$WORK/hits" <(printf '%s\n' "$tagged") || return 2
}

# check_body <bodyfile> <ref> <label> — one body against one tree.
check_body() {
  local body="$1" ref="$2" label="$3" sha short p n f out h r ids outside nd paths what all rejected entry fo raw total zero
  sha="$(git rev-parse --verify -q "${ref}^{commit}")" || { miss "${label}: ref ${ref} does not resolve to a commit — nothing was checked"; return; }  # GUARD:ref
  short="${sha:0:12}"
  all="$(cites "$body")" || { miss "${label}: reading the body failed — nothing was checked"; return; }
  paths="$(sed -n 's/^A //p' <<<"$all")"
  rejected="$(grep -c '^X$' <<<"$all")"
  [ "$rejected" -eq 0 ] || info "${label} holds a todos/ token in a form that is not a citation of this repo's todos/*.md — not read"  # GUARD:rejected
  if [ -z "$paths" ]; then
    info "${label} cites no todos/*.md file — nothing to check"
    return
  fi
  n=0
  while IFS= read -r p; do
    n=$((n + 1)); CITES=$((CITES + 1))
    # --full-tree: the path is from the repo root wherever the caller stands.
    entry="$(git ls-tree --full-tree "$sha" -- "$p")" || { miss "${label}: listing ${p} at ${short} failed — the citation was not checked"; continue; }
    if [ -z "$entry" ]; then
      warn "${label} cites ${p}, which is not a file at ${short} — the citation was not checked"  # GUARD:absent
      continue
    fi
    case "$entry" in 100644\ blob\ *|100755\ blob\ *) ;; *) miss "${label}: ${p} at ${short} is not a regular file (a symlink or a submodule) — nothing in it was checked"; continue ;; esac  # GUARD:mode
    f="$WORK/f$n.md"
    git show "${sha}:${p}" > "$f" 2>/dev/null || { miss "${label}: ${p} at ${short} could not be read — nothing in it was checked"; continue; }
    out="$(scan "$f")" || { miss "${label}: the status scan of ${p} at ${short} errored — nothing in it was checked"; continue; }
    fo="$(sed -n 's/^F //p' <<<"$out")"; h="$(sed -n 's/^H //p' <<<"$out")"; r="$(sed -n 's/^R //p' <<<"$out")"
    if [ "$fo" != 0 ]; then
      miss "${label}: ${p} at ${short} leaves a \`\`\` fence open (unclosed, or quoted inside a ~~~ fence) — every finding after its opener went unread"  # GUARD:fence
      continue
    fi
    if [ "$h" -eq 0 ] && [ "$r" -eq 0 ]; then
      raw="$(grep -ciE "${FIELD_PRE}status${FIELD_POST}[a-z_-]+|^###[[:space:]]+[0-9]" "$f")"
      if [ "${raw:-0}" -gt 0 ]; then
        miss "${label}: ${p} at ${short} has ### N headings or status rows, but none survived body extraction (no frontmatter, or a byte-order mark) — nothing in it was checked"  # GUARD:nobody
      else
        # A clean review declares `total: 0` and has an empty body; the two
        # agree, so it is not a false clean. Anything else is unexplained.
        total="$(awk 'NR == 1 && /^---[[:space:]]*$/ {fm = 1; next} fm && /^---[[:space:]]*$/ {exit} fm && /^summary:/ {s = 1; next} s && /^[^[:space:]]/ {s = 0} s && /^[[:space:]]+total:/ {sub(/^[[:space:]]+total:[[:space:]]*/, ""); sub(/[[:space:]]+$/, ""); print; exit}' "$f")"
        zero=0; [ "$total" != 0 ] || zero=1  # GUARD:zerototal
        if [ "$zero" = 1 ]; then
          info "${label} cites ${p}: it declares total: 0 and holds no finding at ${short}"
        else
          warn "${label} cites ${p}, which holds no ### N finding and no status row the pattern reads at ${short} — it was not checked as a findings file"  # GUARD:nofindings
        fi
      fi
      continue
    fi
    if [ "$h" -gt 0 ] && [ "$r" -eq 0 ]; then
      miss "${label}: ${p} at ${short} has ${h} ### N heading(s) and ZERO status rows — the pattern did not fire, so 0 deferred would be a false clean"  # GUARD:norows
      continue
    fi
    # One finding with two deferred rows is one finding: ids are unique.
    ids="$(sed -n 's/^D //p' <<<"$out" | grep -v '^-$' | sort -u | sort -t- -k1,1n -k2,2n | sed 's/^/### /' | paste -sd, - | sed 's/,/, /g')"  # GUARD:idsuniq
    outside="$(grep -c '^D -$' <<<"$out")"
    nd="$(sed -n 's/^D //p' <<<"$out" | grep -v '^-$' | sort -u | grep -c .)"  # GUARD:nduniq
    if [ "$nd" -eq 0 ] && [ "$outside" -eq 0 ]; then
      info "${label} cites ${p}: 0 deferred of ${h} finding(s) at ${short}"
      continue
    fi
    what=""
    [ "$nd" -eq 0 ] || what="${nd} deferred finding(s): ${ids}"
    [ "$outside" -eq 0 ] || what="${what:+${what}; }${outside} deferred row(s) outside any ### N heading"  # GUARD:outside
    warn "${label} cites ${p}, which holds ${what} at ${short} — confirm each is open on purpose; a decided or fixed finding needs its status written back"
    FLAGGED="${FLAGGED} ${label#PR }"  # GUARD:flagged
  done <<<"$paths"
}

# fetch_body <pr> <out> — the body as GitHub holds it now. Never through a
# shell string: gh writes it, grep reads it.
fetch_body() {
  gh api "repos/{owner}/{repo}/pulls/$1" --jq '.body // ""' > "$2"
}

# check_commit <sha> — every merged PR whose merge commit is <sha>, at <sha>.
check_commit() {
  local c="$1" nums subj pr m
  nums="$(gh api "repos/{owner}/{repo}/commits/$c/pulls" --jq ".[] | select(.merge_commit_sha == \"$c\") | .number")" \
    || { miss "commit ${c:0:12}: looking up its merged PR failed — nothing was checked"; return; }
  if [ -z "$nums" ]; then
    # The association can lag a fresh merge. A squash subject ends `(#N)`:
    # fetch N, and use it only if ITS merge commit is this one. The subject
    # is repo content — it is matched, never printed; only N's digits are.
    subj="$(git log -1 --format=%s "$c" 2>/dev/null)" || subj=''
    if [[ "$subj" =~ \(#([0-9]+)\)$ ]]; then
      pr="${BASH_REMATCH[1]}"
      m="$(gh api "repos/{owner}/{repo}/pulls/$pr" --jq '.merge_commit_sha // ""')" \
        || { miss "commit ${c:0:12}: its subject names #${pr}, and fetching that PR failed — nothing was checked"; return; }
      [ "$m" != "$c" ] || nums="$pr"  # GUARD:subject
    fi
  fi
  if [ -z "$nums" ]; then
    info "commit ${c:0:12} is the merge commit of no PR (a direct push) — no body to check"
    return
  fi
  for pr in $nums; do
    [[ "$pr" =~ ^[0-9]+$ ]] || { miss "commit ${c:0:12}: the PR lookup returned a non-number — nothing was checked"; continue; }
    PRS=$((PRS + 1))
    if fetch_body "$pr" "$WORK/body"; then check_body "$WORK/body" "$c" "PR #$pr"
    else miss "PR #$pr: fetching its body failed — nothing was checked"; fi
  done
}

usage() {
  printf 'usage: %s --pr N [--ref REF] | --commit SHA... | --body-file F --ref REF | --replay\n' "${0##*/}" >&2
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
    [ $# -ge 2 ] || usage
    shift
    for c in "$@"; do [[ "$c" =~ ^[0-9a-f]{40}$ ]] || usage; done
    for c in "$@"; do check_commit "$c"; done
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
      [ -n "$pr" ] || continue
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
