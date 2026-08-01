#!/usr/bin/env bash
# Mutant registry for the model-pin control suite.
#
# SOURCED by scripts/run-mutation-sweep.sh. Not executable on its own.
#
# WHAT A MUTANT IS. A declarative <target, old, new> substitution against a
# COPY of the checker. Never a .patch: a patch carries context lines, so every
# one rots on any edit to check-model-pins.sh — and the sweep exists to be run
# precisely when that file changes. A mutant whose anchor text is gone fails
# loudly as ANCHOR-MISSING instead of applying nowhere.
#
# `old` must occur EXACTLY ONCE in the target. The driver asserts it.
#
# THE AUTHORING RULE: A MUTANT MUST BE SILENT ON THE CLEAN TREE.
# The control harness runs a baseline gate before its runner loop and aborts
# if the mutated checker's verdict on the repo's own content is not
# 0 MISS / 0 WARN. A mutant that BREAKS the checker outright therefore runs
# zero controls, teaches nothing about the controls, and reports
# BASELINE-DIRTY — which is a FAIL, meaning "re-anchor this to the silent
# version of the same construct". The interesting mutation of any construct is
# the one that BLINDS a predicate while leaving the clean-tree verdict intact,
# because that is exactly the shape a real regression has. A loud mutation is
# caught by the model-pins job itself and is not what this sweep measures.
#
# HOW THIS IS ENUMERATED. By CONSTRUCT, not by incident history. The first
# control-suite cut put 22 of 26 cases on leg 4 because that is where the
# incidents came from, and 12 material mutants outside that region survived.
# Mutant authoring has the same bias, so the sections below walk the checker's
# constructs in source order — shared helpers, then each leg individually,
# then the verdict path — and every one gets at least one entry. There is no
# target count; reproducing a fixed number would mean the enumeration was done
# by incident history after all.
#
# The set deliberately includes LOOSENING mutants (widen a predicate so it
# accepts what it should reject). Only a zero-MISS/zero-WARN false-positive
# guard can kill one, and that region of the control suite has the least
# prose to author from.
#
# RETIRING A MUTANT. An ANCHOR-MISSING mutant is RE-ANCHORED to the construct
# it targeted. Retiring one requires naming the construct that is no longer
# mutable. Deleting it to green the build is never the fix — that is how a
# suite comes to claim coverage it lost.
#
# THE MAPPING TO CONTROLS IS PROSE, AND DELIBERATELY UNENFORCED. `why` names
# the control expected to kill the mutant the same way the control suite's own
# `why` field names the mutant it kills: in words, checked by nobody. A
# machine-checked link was drafted and removed — it was the thing a per-PR
# fast path needed, it is a second list to keep in sync, and its staleness is
# undetectable by the design that carries it. This is a stated limit, not an
# oversight. Read what a `mut` claims; do not trust it.
#
# The section sign is built at runtime, never written literally. `scripts` is
# one of leg 4's citation roots, `.sh` is in its scanned extension set, and it
# has no prose-suppression hatch — a literal broken anchor in this file would
# be a real citation to a heading that does not exist, and would redden the
# baseline gate, the control suite, and the model-pins job together.
SS=$'\302\247'

MUT_IDS=(); MUT_TARGET=(); MUT_OLD=(); MUT_NEW=(); MUT_WHY=(); MUT_LIMIT=()

# mut <id> <target> <old> <new> <why>
mut() {
  MUT_IDS+=("$1"); MUT_TARGET+=("$2"); MUT_OLD+=("$3"); MUT_NEW+=("$4")
  MUT_WHY+=("$5"); MUT_LIMIT+=('')
}

# survivor <id> <target> <old> <new> <file:line of the STATED LIMIT> <why>
#
# A declared survivor is a mutant no control can kill, where that gap is
# already recorded as a stated limit at a named location. The driver asserts
# the cited location carries the literal words STATED LIMIT, so a declaration
# cannot point at prose that no longer says so.
#
# A declared survivor that starts being CAUGHT is a FAIL: the limit was closed
# and this declaration is now false.
survivor() {
  MUT_IDS+=("$1"); MUT_TARGET+=("$2"); MUT_OLD+=("$3"); MUT_NEW+=("$4")
  MUT_WHY+=("$6"); MUT_LIMIT+=("$5")
}

CHK=scripts/check-model-pins.sh

# ===========================================================================
# Shared helper: traverse()
# ===========================================================================

mut t-predicate "$CHK" \
  "  if [ \"\$_rc\" -ne 0 ] || [ -s \"\$_err\" ]; then" \
  "  if false; then" \
  'kills: the whole traversal-failure predicate — a partial walk reads as a complete one. Expected killers: 31, 33, 34, 35.'

survivor t-rc-half "$CHK" \
  "[ \"\$_rc\" -ne 0 ] || [ -s \"\$_err\" ]" \
  "[ -s \"\$_err\" ]" \
  scripts/check-model-pins.sh:87 \
  'declared survivor: every failure a fixture can stage sets a non-zero exit AND writes stderr, so removing the exit half is invisible to any control. Kept for death-by-signal, which no fixture can produce.'

survivor t-err-half "$CHK" \
  "[ \"\$_rc\" -ne 0 ] || [ -s \"\$_err\" ]" \
  "[ \"\$_rc\" -ne 0 ]" \
  scripts/check-model-pins.sh:87 \
  'declared survivor: the other half of the same predicate, for the same measured reason. Kept for a future find that warns at exit 0.'

mut t-return "$CHK" \
  "    TRAVERSE_ERR=\"find exit \${_rc}: \$(head -1 \"\$_err\")\"
    rm -f \"\$_out\" \"\$_err\"
    return 1" \
  "    TRAVERSE_ERR=\"find exit \${_rc}: \$(head -1 \"\$_err\")\"
    rm -f \"\$_out\" \"\$_err\"
    return 0" \
  'kills: reporting a detected traversal failure as success — the diagnostic is built and then thrown away. Expected killers: 31, 33, 34, 35.'

# ===========================================================================
# Shared helper: dedup_resolved()
# ===========================================================================

mut dd-realpath "$CHK" \
  "    _r=\$(readlink -f -- \"\$_p\" 2>/dev/null) || _r=\"\$_p\"" \
  "    _r=\"\$_p\"" \
  'kills: dedup by RESOLVED path — two symlinks to one directory inflate the coverage counter. Expected killer: L1f.'

mut dd-seen "$CHK" \
  "    [ -n \"\${_seen[\$_r]:-}\" ] && continue" \
  "    [ -n \"\${_seen[\$_r]:-}\" ] && true" \
  'kills: the skip half of the dedup — the resolved path is computed and then ignored. Expected killer: L1f.'

# ===========================================================================
# Shared config: the extension sets
# ===========================================================================

mut ext-md "$CHK" \
  "MD_EXTS='md markdown'" \
  "MD_EXTS='md'" \
  'kills: narrowing the markdown extension set back to .md, the round-2 hole where a .markdown file was readable by leg 4 and invisible to legs 1-3. Expected killer: 24.'

mut ext-cite-yaml "$CHK" \
  "CITE_EXTS=\"\$MD_EXTS sh yml yaml\"" \
  "CITE_EXTS=\"\$MD_EXTS sh yml\"" \
  'kills: narrowing leg 4 extensions by one. LOOSENING-adjacent coverage loss with no control behind it — case 28 uses .yml, and nothing plants a .yaml.'

# ===========================================================================
# Shared config: the sanctioned tier set
# ===========================================================================

mut tier-inherit "$CHK" \
  "ALLOWED_TIERS='sonnet opus haiku'" \
  "ALLOWED_TIERS='sonnet opus haiku inherit'" \
  'kills: admitting `inherit` to the tier set, which is the entire defect the checker exists to prevent. Expected killer: L1.'

mut tier-fable "$CHK" \
  "ALLOWED_TIERS='sonnet opus haiku'" \
  "ALLOWED_TIERS='sonnet opus haiku fable'" \
  'kills: admitting the top tier to automatic dispatch. L3c plants fable in a mode-conditional marker, where tier_rank still rejects it — so leg 1 has no fable plant behind it.'

# ===========================================================================
# Shared config: the tier cost ladder
# ===========================================================================

mut rank-default "$CHK" \
  "    *) printf '0' ;;" \
  "    *) printf '1' ;;" \
  'kills: the unranked-tier sentinel — an unsanctioned tier in a mode-conditional marker silently acquires a rank. Expected killer: L3c.'

mut rank-sonnet "$CHK" \
  "TIER_RANK_sonnet=2" \
  "TIER_RANK_sonnet=3" \
  'kills: collapsing sonnet and opus in the cost ladder, so a sonnet/opus inversion no longer reads as one. Expected killer: L3d.'

mut rank-haiku "$CHK" \
  "TIER_RANK_haiku=1" \
  "TIER_RANK_haiku=3" \
  'kills: collapsing haiku and opus in the cost ladder. Expected killer: L3b.'

# ===========================================================================
# Leg 1: agent frontmatter
# ===========================================================================

mut l1-dir-symlink "$CHK" \
  "if ! traverse -L plugins -type d -name agents; then" \
  "if ! traverse plugins -type d -name agents; then" \
  'kills: dropping -L from AGENT_DIRS discovery — every definition in a symlinked agents/ goes unchecked. Expected killer: L1e.'

mut l1-file-symlink "$CHK" \
  "if ! traverse -L \"\${AGENT_DIRS[@]}\" \\( \"\${find_name_args[@]}\" \\) -type f; then" \
  "if ! traverse \"\${AGENT_DIRS[@]}\" \\( \"\${find_name_args[@]}\" \\) -type f; then" \
  'kills: dropping -L from leg 1 FILE discovery — a symlinked definition is a file nobody checked. Expected killer: L1d.'

mut l1-unreadable "$CHK" \
  "  if [ ! -r \"\$f\" ]; then" \
  "  if false; then" \
  'kills: the per-file readability guard in leg 1. No control plants an unreadable AGENT definition (33/34 plant under scripts/, which is leg 4).'

mut l1-bom "$CHK" \
  "sed \$'1s/^\xEF\xBB\xBF//; s/\r\$//' \"\$f\" 2>/dev/null |
    awk" \
  "cat \"\$f\" 2>/dev/null |
    awk" \
  'kills: BOM/CRLF normalization before frontmatter parsing — a CRLF or BOM first line reads as "no frontmatter" and reports a pinned file as unpinned. No control plants either.'

mut l1-awk-nofm "$CHK" \
  "awk 'NR==1 && \$0 !~ /^---[[:space:]]*\$/{exit} NR==1{next} /^---[[:space:]]*\$/{exit} /^model:/{print; exit}')" \
  "awk 'NR==1{next} /^---[[:space:]]*\$/{exit} /^model:/{print; exit}')" \
  'LOOSENING. kills: the guard that a file with no frontmatter at all has no pin — prose containing a model: line would satisfy leg 1. No control plants a frontmatter-free agent file.'

mut l1-awk-close "$CHK" \
  "awk 'NR==1 && \$0 !~ /^---[[:space:]]*\$/{exit} NR==1{next} /^---[[:space:]]*\$/{exit} /^model:/{print; exit}')" \
  "awk 'NR==1 && \$0 !~ /^---[[:space:]]*\$/{exit} NR==1{next} /^model:/{print; exit}')" \
  'LOOSENING. kills: the closing-delimiter exit — a model: line in the BODY, after frontmatter ends, would count as a pin. No control plants one.'

mut l1-value-comment "$CHK" \
  "s/^model:[[:space:]]*//; s/[[:space:]]*#.*\$//; " \
  "s/^model:[[:space:]]*//; " \
  'kills: inline-comment stripping in the value. `model: sonnet  # note` would stop reading as a pin. No control plants a commented value.'

mut l1-value-lowercase "$CHK" \
  "    tr '[:upper:]' '[:lower:]')

  case \"\$value\" in" \
  "    cat)

  case \"\$value\" in" \
  'kills: lowercasing the frontmatter value. `model: Sonnet` would stop reading as a pin. No control plants a capitalized tier in leg 1 (case 8 is leg 4).'

mut l1-tier-exact "$CHK" \
  "grep -qx -- \"\$value\"" \
  "grep -q -- \"\$value\"" \
  'LOOSENING. kills: exact-line matching of the tier — the value becomes a substring pattern, so `model: son` validates against sonnet. No control plants a truncated tier.'

mut l1-empty-branch "$CHK" \
  "    \"\"|\"~\"|null)" \
  "    \"zznever\")" \
  'kills: the empty/null branch. The value still fails the sanctioned-tier test, so only the MESSAGE distinguishes them. Expected killer: L1b.'

mut l1-nomodel-count "$CHK" \
  "    miss \"model-pin: \${f} — no model: key in frontmatter (dispatches at the invoking session's tier)\"
    misses=\$((misses + 1))" \
  "    miss \"model-pin: \${f} — no model: key in frontmatter (dispatches at the invoking session's tier)\"
    misses=\$((misses + 0))" \
  'kills: counting the no-frontmatter-key miss. The line still prints, so only a COUNT assertion can see it — and no control plants an agent file with no model: key at all.'

mut l1-count-zero "$CHK" \
  "if [ \"\$agent_count\" -eq 0 ]; then" \
  "if false; then" \
  'kills: the zero-definitions guard — a discovery that finds nothing reports as a clean run. Expected killer: L1c.'

# ===========================================================================
# Leg 2: dispatch instructions in prose
# ===========================================================================

mut l2-pin-re "$CHK" \
  "PIN_RE='model:[[:space:]]*\`?('\"\${ALLOWED_TIERS// /|}\"')'" \
  "PIN_RE='model:'" \
  'LOOSENING. kills: requiring a TIER after model: — the documented defect where an unpinned dispatch hides in the files densest with pin documentation. Expected killer: L2b.'

mut l2-dispatch-re "$CHK" \
  "|subagent_type|" \
  "|" \
  'kills: one DISPATCH_RE alternation. L2d fires all eight in separate blocks so a dropped one is a countable WARN, not silence. Expected killer: L2d.'

mut l2-nul "$CHK" \
  "  if [ \"\$(tr -d '\000' < \"\$f\" 2>/dev/null | wc -c)\" -ne \"\$(wc -c < \"\$f\" 2>/dev/null)\" ]; then" \
  "  if false; then" \
  'kills: the legs 2-3 NUL probe — one NUL byte makes GNU grep report no matches at exit 0, so every dispatch in the file reads as absent. Expected killer: L2f.'

mut l2-grep-binary "$CHK" \
  "hits=\$(grep -naE \"\$DISPATCH_RE\" \"\$f\" 2>/dev/null)" \
  "hits=\$(grep -nE \"\$DISPATCH_RE\" \"\$f\" 2>/dev/null)" \
  'kills: -a on the leg 2 scanning grep. Only observable once the NUL probe above is also gone, so L2f cannot reach it — a control-suite ordering dependency, not coverage.'

mut l2-grep-rc "$CHK" \
  "  hits=\$(grep -naE \"\$DISPATCH_RE\" \"\$f\" 2>/dev/null)
  grc=\$?
  if [ \"\$grc\" -gt 1 ]; then printf 'UNREADABLE\n'; return; fi" \
  "  hits=\$(grep -naE \"\$DISPATCH_RE\" \"\$f\" 2>/dev/null)
  grc=\$?
  if [ \"\$grc\" -gt 9 ]; then printf 'UNREADABLE\n'; return; fi" \
  'kills: distinguishing grep exit 1 (no matches) from a read error in leg 2. Nothing plants an unreadable file under plugins/ — 33 and 34 plant under scripts/.'

mut l2-block-lo "$CHK" \
  "      lo=1; for (i=n-1; i>=1; i--) if (blank[i]) { lo=i+1; break }" \
  "      lo=1;" \
  'LOOSENING. kills: the lower bound of block scoping — the scope opens at line 1, so any pin anywhere above the dispatch counts. Expected killer: L2c.'

mut l2-suppress-marker "$CHK" \
  "SUPPRESS_MARKER='model-pin: prose'" \
  "SUPPRESS_MARKER='model-pin'" \
  'LOOSENING. kills: the specificity of the suppression marker — any mention of model-pin near a dispatch would silence it. The false-positive guards L2g/L2h pass either way.'

mut l2-unreadable-branch "$CHK" \
  "      if [ \"\$hit\" = \"UNREADABLE\" ]; then" \
  "      if [ \"\$hit\" = \"ZZNEVER\" ]; then" \
  'kills: the leg 2 UNREADABLE arm — the sentinel is then warned about as if it were a line number. Expected killer: L2f.'

# ===========================================================================
# Leg 3: mode-conditional pairs
# ===========================================================================

mut l3-grep-rc "$CHK" \
  "  hits=\$(grep -naF \"\$MODECOND_MARKER\" \"\$f\" 2>/dev/null)
  grc=\$?
  if [ \"\$grc\" -gt 1 ]; then printf 'UNREADABLE\n'; return; fi" \
  "  hits=\$(grep -naF \"\$MODECOND_MARKER\" \"\$f\" 2>/dev/null)
  grc=\$?
  if [ \"\$grc\" -gt 9 ]; then printf 'UNREADABLE\n'; return; fi" \
  'kills: leg 3 own read-error check. Leg 3 must not lean on leg 2 catching the same file first — that is loop order, not a guarantee.'

mut l3-marker-boundary "$CHK" \
  "      sed -n 's/.*[^a-z]interactive=\\([a-z]*\\).*/\\1/p' | tr '[:upper:]' '[:lower:]')" \
  "      sed -n 's/.*interactive=\\([a-z]*\\).*/\\1/p' | tr '[:upper:]' '[:lower:]')" \
  'LOOSENING. kills: the left word boundary on the interactive= key, so a run-on token like noninteractive=haiku satisfies the branch. No control plants one.'

mut l3-malformed "$CHK" \
  "    if [ -z \"\$inter\" ] || [ -z \"\$head\" ]; then" \
  "    if [ -z \"\$inter\" ] && [ -z \"\$head\" ]; then" \
  'kills: the malformed arm for a HALF-declared pair — leg 2 is satisfied by any one tier, so a deleted headless branch would pass clean. Expected killer: L3a.'

mut l3-unsanctioned "$CHK" \
  "    if [ \"\$ri\" -eq 0 ] || [ \"\$rh\" -eq 0 ]; then" \
  "    if false; then" \
  'kills: the unsanctioned arm — the third arm, which L3a and L3b do not reach. Expected killer: L3c.'

mut l3-inverted "$CHK" \
  "    if [ \"\$rh\" -gt \"\$ri\" ]; then" \
  "    if [ \"\$rh\" -gt 9 ]; then" \
  'kills: the inversion check — an unattended run costing more than the attended one it mirrors. Expected killers: L3b, L3d.'

mut l3-tab-read "$CHK" \
  "    while IFS=\$'\t' read -r cln ckind cdetail; do" \
  "    while IFS= read -r cln ckind cdetail; do" \
  'kills: the field split on leg 3 rows. The kind lands in the line-number slot, every case arm falls through, and the miss counter still increments — a count with no message. Expected killers: L3a-L3d.'

# ===========================================================================
# Leg 4: citation resolution
# ===========================================================================

mut l4-root-scripts "$CHK" \
  "CITE_ROOTS='plugins CLAUDE.md README.md .github scripts'" \
  "CITE_ROOTS='plugins CLAUDE.md README.md .github'" \
  'kills: dropping a citation root. Both the numerator and the denominator of the roots INFO line shrink together, so the coverage probe cannot see it. Expected killer: 27.'

mut l4-root-github "$CHK" \
  "CITE_ROOTS='plugins CLAUDE.md README.md .github scripts'" \
  "CITE_ROOTS='plugins CLAUDE.md README.md scripts'" \
  'kills: dropping the workflow root, where this repo pins its actions and states its CI rules. Expected killer: 28.'

mut l4-root-exists "$CHK" \
  "  if [ ! -e \"\$r\" ]; then" \
  "  if false; then" \
  'kills: the missing-root arm — a renamed root falls through to traverse and reports as a walk failure instead of shrunken coverage. Expected killer: 16.'

mut l4-root-bytes "$CHK" \
  "  if [ \"\${#rfilelist[@]}\" -eq 0 ] || [ \"\$rbytes\" -eq 0 ]; then" \
  "  if [ \"\${#rfilelist[@]}\" -eq 0 ]; then" \
  'kills: the zero-BYTES half of the per-root coverage probe — a root whose only scannable files are empty reports as scanned. Expected killer: 36.'

mut l4-grep-rc "$CHK" \
  "  if [ \"\$rrc\" -gt 1 ]; then" \
  "  if [ \"\$rrc\" -gt 9 ]; then" \
  'kills: distinguishing grep exit 1 from a read error in the per-root scan. Expected killer: 34.'

mut l4-cite-re-truncate "$CHK" \
  "CITE_RE='(\`?[A-Za-z0-9_.:-]+\`?[[:space:]]+)?${SS}[0-9]+[A-Za-z]+(-[0-9]+[A-Za-z]+)*'" \
  "CITE_RE='(\`?[A-Za-z0-9_.:-]+\`?[[:space:]]+)?${SS}[0-9]+[A-Za-z](-[0-9]+[A-Za-z]+)*'" \
  'kills: the quantifier on the anchor letters — grep -o truncates a two-letter anchor to its first letter, so a typo validates against the wrong heading. Expected killer: 11.'

mut l4-cite-re-range "$CHK" \
  "CITE_RE='(\`?[A-Za-z0-9_.:-]+\`?[[:space:]]+)?${SS}[0-9]+[A-Za-z]+(-[0-9]+[A-Za-z]+)*'" \
  "CITE_RE='(\`?[A-Za-z0-9_.:-]+\`?[[:space:]]+)?${SS}[0-9]+[A-Za-z]+(-[0-9]*[A-Za-z]+)*'" \
  'LOOSENING. kills: the NUMBERED range tail — ordinary hyphenated English after an anchor parses as a range endpoint and invents an anchor that resolves to nothing. Expected killer: 15.'

mut l4-cite-re-qual "$CHK" \
  "CITE_RE='(\`?[A-Za-z0-9_.:-]+\`?[[:space:]]+)?${SS}[0-9]+[A-Za-z]+(-[0-9]+[A-Za-z]+)*'" \
  "CITE_RE='(\`?[A-Za-z0-9_.:-]+\`?[[:space:]]+)${SS}[0-9]+[A-Za-z]+(-[0-9]+[A-Za-z]+)*'" \
  'kills: the optionality of the qualifier group — every UNQUALIFIED citation stops matching at all, which is silent rather than red. Expected killers: 1, 2, 3, 4, 5.'

mut l4-index-anchored "$CHK" \
  "    grep -aoE '^### [0-9]+[A-Za-z]+\\.' 2>/dev/null |" \
  "    grep -aoE '### [0-9]+[A-Za-z]+\\.' 2>/dev/null |" \
  'LOOSENING. kills: the line anchor on the heading index — a mid-line mention of a heading would DEFINE that anchor, so citations resolve against prose. No control plants one.'

mut l4-index-bom "$CHK" \
  "sed \$'1s/^\xEF\xBB\xBF//; s/\r\$//' \"\$sk\" 2>/dev/null |" \
  "cat \"\$sk\" 2>/dev/null |" \
  'kills: BOM/CRLF normalization when building the anchor index — a CRLF skill file defines no anchors, so every citation into it MISSes. No control plants one.'

mut l4-index-lowercase "$CHK" \
  "    sed 's/^### //; s/\\.\$//' | tr '[:upper:]' '[:lower:]')" \
  "    sed 's/^### //; s/\\.\$//')" \
  'kills: lowercasing the INDEX side of the anchor lookup. Case 12 lowercases the CITATION, so it passes either way — the two sides are separate constructs.'

mut l4-skillfiles-zero "$CHK" \
  "if [ \"\$skill_files\" -eq 0 ]; then" \
  "if false; then" \
  'kills: the guard that citation targets are unverifiable when no SKILL.md was found. Expected killer: 20.'

mut l4-delimiter "$CHK" \
  "    cite_pairs=\"\${cite_pairs}\${qual}|\${p}\"\$'\n'
  done
done <<< \"\$cite_raw\"

cite_pairs=\$(printf '%s' \"\$cite_pairs\" | grep -v '^\$' | sort -u)

checked=0
while IFS='|' read -r q a; do" \
  "    cite_pairs=\"\${cite_pairs}\${qual} \${p}\"\$'\n'
  done
done <<< \"\$cite_raw\"

cite_pairs=\$(printf '%s' \"\$cite_pairs\" | grep -v '^\$' | sort -u)

checked=0
while IFS=' ' read -r q a; do" \
  'kills: the round-1 defect exactly — an IFS-WHITESPACE row delimiter collapses the leading empty field, so every unqualified citation arrives with an empty anchor and is skipped. Expected killers: 1, 2, 3, 4, 5.'

mut l4-qual-dash "$CHK" \
  "  case \"\$qual\" in -*) qual='' ;; esac" \
  "  case \"\$qual\" in -*) : ;; esac" \
  'kills: blanking a leading-dash qualifier — qualifier sanitization, without which a list bullet before an anchor reads as an owner claim. Expected killer: 5.'

mut l4-qual-prefix "$CHK" \
  "  qual=\${qual##*:}" \
  "  qual=\${qual}" \
  'kills: stripping the `cepa:` prefix from a qualifier — the dominant citation style in this repo, so every qualified citation would fall to the unqualified branch. Expected killer: 25.'

mut l4-qual-lowercase "$CHK" \
  "  qual=\$(printf '%s' \"\$qual\" | tr -d '\`' |
    sed 's/^[[:space:]]*//; s/[[:space:]]*\$//' | tr '[:upper:]' '[:lower:]')" \
  "  qual=\$(printf '%s' \"\$qual\" | tr -d '\`' |
    sed 's/^[[:space:]]*//; s/[[:space:]]*\$//')" \
  'kills: lowercasing the qualifier — a capitalized owner name stops matching any skill and falls to the unqualified branch, which resolves. Expected killer: 8.'

mut l4-anchor-lowercase "$CHK" \
  "  rest=\$(printf '%s' \"\${m#*${SS}}\" | tr '[:upper:]' '[:lower:]')" \
  "  rest=\$(printf '%s' \"\${m#*${SS}}\")" \
  'kills: lowercasing the anchor before lookup — an uppercase anchor resolves against nothing, or against the wrong heading. Expected killer: 12.'

mut l4-range-split "$CHK" \
  "  IFS='-' read -r -a parts <<< \"\$rest\"" \
  "  IFS='-' read -r -a parts <<< \"\${rest%%-*}\"" \
  'kills: range expansion past the first hyphen — the second and third endpoints of a range are verified by nothing. Expected killers: 13, 14.'

mut l4-range-inherit "$CHK" \
  "      [a-z]*) p=\"\${first_num}\${p}\" ;;" \
  "      [a-z]*) continue ;;" \
  'kills: inheriting the section NUMBER into a bare-letter range endpoint, so the endpoint is dropped instead of checked. Expected killers: 13, 14.'

mut l4-qualified-branch "$CHK" \
  "  if [ -n \"\$q\" ] && [ -n \"\${SKILL_NAMES[\"\$q\"]:-}\" ]; then" \
  "  if false; then" \
  'kills: the qualified branch entirely — every citation is checked as unqualified, so naming the WRONG owner resolves against any skill that defines the anchor. Expected killers: 7, 8, 25.'

mut l4-checked-zero "$CHK" \
  "if [ \"\$checked\" -eq 0 ] && [ \"\$skill_files\" -gt 0 ]; then" \
  "if false; then" \
  'kills: the guard that a scan verifying nothing is not a pass. Expected killer: 29.'

# ===========================================================================
# The verdict and exit path
# ===========================================================================

mut v-miss-prefix "$CHK" \
  "miss() { printf 'MISS %s\n' \"\$1\"; }" \
  "miss() { printf 'Miss %s\n' \"\$1\"; }" \
  'kills: the MISS line prefix, which is the machine-readable half of every finding. Counts and exit codes are unchanged, so only a message assertion can see it.'

mut v-warn-fails "$CHK" \
  "if [ \"\$misses\" -gt 0 ] || [ \"\$warns\" -gt 0 ]; then" \
  "if [ \"\$misses\" -gt 0 ]; then" \
  'kills: WARN failing the run. A warning channel that can never fail is not enforcement — leg 2 becomes advisory. Expected killers: L2, L2b, L2c, L2d, L2e, L2i.'

mut v-exit "$CHK" \
  "  echo \"FAIL: a dispatch can run at the invoking session's tier, or a check could not run.\"
  exit 1" \
  "  echo \"FAIL: a dispatch can run at the invoking session's tier, or a check could not run.\"
  exit 0" \
  'kills: the exit code, which is the entire mechanism by which CI fails. This mutant passed 26 of 26 controls before the suite asserted exit status. Expected killers: every non-zero-expectation case.'
