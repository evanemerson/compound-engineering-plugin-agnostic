#!/usr/bin/env bash
# Mutant registry for the model-pin control suite.
#
# SOURCED by scripts/run-mutation-sweep.sh. Not executable on its own.
#
# WHAT A MUTANT IS. A declarative <target, old, new> substitution against a
# COPY of the checker, with a build-time assertion that `old` occurs EXACTLY
# ONCE in its target. `cepa:autonomy` §9f owns the rest — why substitutions and
# not .patch files, why a mutant must be silent on the clean tree, what each
# outcome means, and the re-anchoring rule for an ANCHOR-MISSING entry. Read it
# there; this header used to restate all four and is the reason the repo's
# cite-once rule keeps having to be relearned.
#
# The two facts that have to live HERE, because they constrain what you type
# below rather than describing policy:
#
#   1. `old` must match exactly once, so anchor on enough surrounding text to
#      be unique. The driver refuses the run otherwise.
#   2. A mutant must not change the checker's verdict on the CLEAN tree, or the
#      control harness aborts at its baseline gate and the mutant proves
#      nothing (§9f: BASELINE-DIRTY). In practice: blind a predicate, do not
#      break the script.
#
# HOW THIS IS ENUMERATED. By CONSTRUCT, in source order — shared helpers, then
# each leg individually, then the verdict path — and never by incident history,
# which is what put 22 of 26 cases of the first control-suite cut on one leg
# while 12 material mutants elsewhere survived. There is no target count.
#
# The set deliberately includes LOOSENING mutants (widen a predicate so it
# accepts what it should reject). Only a zero-MISS/zero-WARN false-positive
# guard can kill one, and that region of the control suite has the least prose
# to author from.
#
# THE MAPPING TO CONTROLS IS PROSE AND UNENFORCED (§9f). `why` names the
# control expected to kill the mutant, checked by nobody. Read what a `mut`
# claims; do not trust it.
#
# The section sign is built at runtime, never written literally. `scripts` is
# one of leg 4's citation roots, `.sh` is in its scanned extension set, and it
# has no prose-suppression hatch — a literal broken anchor in this file would
# be a real citation to a heading that does not exist, and would redden the
# baseline gate, the control suite, and the model-pins job together.
SS=$'\302\247'

# The harness tier's target, spelled once.
DRV='scripts/run-mutation-sweep.sh'

MUT_IDS=(); MUT_TARGET=(); MUT_OLD=(); MUT_NEW=(); MUT_WHY=(); MUT_LIMIT=()
MUT_HARNESS=()

# mut <id> <target> <old> <new> <why>
mut() {
  MUT_IDS+=("$1"); MUT_TARGET+=("$2"); MUT_OLD+=("$3"); MUT_NEW+=("$4")
  MUT_WHY+=("$5"); MUT_LIMIT+=(''); MUT_HARNESS+=('controls')
}

# hmut <id> <target> <old> <new> <why>  — a HARNESS mutant.
#
# Same substitution machinery, different subject and different judge: the
# target is the sweep's own driver, and the verdict comes from the driver's
# `--selftest` trailer rather than from the control suite. It exists because
# the verification chain terminates — every `mut` above proves the CONTROLS
# catch a weakened checker, and nothing proved the driver's own assertions
# catch a weakened driver. Four of them could not, and shipped green.
#
# THE CONSTRAINT THAT DECIDES WHETHER A `hmut` IS WRITEABLE, and it is not the
# one you would guess: the mutation must make an assertion print a `FAIL  `
# line **and still reach the trailer**. A mutation that makes the driver exit
# EARLY — broken argument parsing, a guard's own `exit 2`, a FATAL — produces
# no trailer, which is HARNESS-ERROR, which aborts the whole sweep. That is
# never a finding about the mutant.
#
# So a guard that kills by REFUSING cannot be a `hmut` at all today. Those need
# a `refuse` expectation keyed on a machine token, which does not exist yet;
# the two known instances are recorded in the branch's residual shard rather
# than registered here as mutants that would take the run down.
hmut() {
  MUT_IDS+=("$1"); MUT_TARGET+=("$2"); MUT_OLD+=("$3"); MUT_NEW+=("$4")
  MUT_WHY+=("$5"); MUT_LIMIT+=(''); MUT_HARNESS+=('selftest')
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
  MUT_HARNESS+=('controls')
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
  'kills: narrowing leg 4 extensions by one. Expected killer: 37, which plants a broken citation in a .yaml under .github — case 28 covers only .yml.'

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
  'kills: admitting the top tier to automatic dispatch. Expected killer: L1p. L3c plants fable in a mode-conditional marker, where tier_rank rejects it independently, so it cannot reach leg 1.'

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
  'kills: the per-file readability guard in leg 1. Expected killer: L1g. 33/34 plant under scripts/, which is leg 4.'

mut l1-bom "$CHK" \
  "sed \$'1s/^\xEF\xBB\xBF//; s/\r\$//' \"\$f\" 2>/dev/null |
    awk" \
  "cat \"\$f\" 2>/dev/null |
    awk" \
  'kills: BOM/CRLF normalization before frontmatter parsing — a BOM first line reads as "no frontmatter" and reports a pinned file as unpinned. Expected killer: L1h. CRLF alone cannot fail this: \r is in [[:space:]] under LC_ALL=C, so the BOM is the observable half.'

mut l1-awk-nofm "$CHK" \
  "awk 'NR==1 && \$0 !~ /^---[[:space:]]*\$/{exit} NR==1{next} /^---[[:space:]]*\$/{exit} /^model:/{print; exit}')" \
  "awk 'NR==1{next} /^---[[:space:]]*\$/{exit} /^model:/{print; exit}')" \
  'LOOSENING. kills: the guard that a file with no frontmatter at all has no pin — prose containing a model: line would satisfy leg 1. Expected killer: L1i.'

mut l1-awk-close "$CHK" \
  "awk 'NR==1 && \$0 !~ /^---[[:space:]]*\$/{exit} NR==1{next} /^---[[:space:]]*\$/{exit} /^model:/{print; exit}')" \
  "awk 'NR==1 && \$0 !~ /^---[[:space:]]*\$/{exit} NR==1{next} /^model:/{print; exit}')" \
  'LOOSENING. kills: the closing-delimiter exit — a model: line in the BODY, after frontmatter ends, would count as a pin. Expected killer: L1j.'

mut l1-value-comment "$CHK" \
  "s/^model:[[:space:]]*//; s/[[:space:]]*#.*\$//; " \
  "s/^model:[[:space:]]*//; " \
  'kills: inline-comment stripping in the value. `model: sonnet  # note` would stop reading as a pin. Expected killer: L1k.'

mut l1-value-lowercase "$CHK" \
  "    tr '[:upper:]' '[:lower:]')

  case \"\$value\" in" \
  "    cat)

  case \"\$value\" in" \
  'kills: lowercasing the frontmatter value. `model: Sonnet` would stop reading as a pin. Expected killer: L1m; case 8 lowercases a leg 4 qualifier, a different construct.'

mut l1-tier-exact "$CHK" \
  "grep -qx -- \"\$value\"" \
  "grep -q -- \"\$value\"" \
  'LOOSENING. kills: exact-line matching of the tier — the value becomes a substring pattern, so `model: son` validates against sonnet. Expected killer: L1n.'

mut l1-empty-branch "$CHK" \
  "    \"\"|\"~\"|null)" \
  "    \"zznever\")" \
  'kills: the empty/null branch. The value still fails the sanctioned-tier test, so only the MESSAGE distinguishes them. Expected killer: L1b.'

mut l1-nomodel-count "$CHK" \
  "    miss \"model-pin: \${f} — no model: key in frontmatter (dispatches at the invoking session's tier)\"
    misses=\$((misses + 1))" \
  "    miss \"model-pin: \${f} — no model: key in frontmatter (dispatches at the invoking session's tier)\"
    misses=\$((misses + 0))" \
  'kills: counting the no-frontmatter-key miss. The line still prints, so only a COUNT assertion can see it. Expected killers: L1i and L1j, which both reach this branch and both pin its count.'

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

survivor l2-grep-binary "$CHK" \
  "hits=\$(grep -naE \"\$DISPATCH_RE\" \"\$f\" 2>/dev/null)" \
  "hits=\$(grep -nE \"\$DISPATCH_RE\" \"\$f\" 2>/dev/null)" \
  scripts/check-model-pins.sh:311 \
  'declared survivor: -a is observable only on a file GNU grep calls binary, and under LC_ALL=C only a NUL does that — which the NUL probe two lines above refuses first. Measured on grep 3.11: 0x80/0xFF/0x01/0x1B with no NUL matches identically with and without -a.'

survivor l2-grep-rc "$CHK" \
  "  hits=\$(grep -naE \"\$DISPATCH_RE\" \"\$f\" 2>/dev/null)
  grc=\$?
  if [ \"\$grc\" -gt 1 ]; then printf 'UNREADABLE\n'; return; fi" \
  "  hits=\$(grep -naE \"\$DISPATCH_RE\" \"\$f\" 2>/dev/null)
  grc=\$?
  if [ \"\$grc\" -gt 9 ]; then printf 'UNREADABLE\n'; return; fi" \
  scripts/check-model-pins.sh:311 \
  'declared survivor: leg 2 readability probe reads the whole file first, so this arm never sees an unreadable one. Control L2j plants exactly that fixture and stays GREEN under this mutant while leg 3 identical arm dies to L3f — leg 3 has no probe. The redundancy runs both ways, so neither guard is individually observable.'

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
  'LOOSENING. kills: the left word boundary on the interactive= key, so a run-on token like noninteractive=haiku satisfies the branch. Expected killer: L3g.'

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
  'LOOSENING. kills: the line anchor on the heading index — a mid-line mention of a heading would DEFINE that anchor, so citations resolve against prose. Expected killer: 40.'

mut l4-index-bom "$CHK" \
  "sed \$'1s/^\xEF\xBB\xBF//; s/\r\$//' \"\$sk\" 2>/dev/null |" \
  "cat \"\$sk\" 2>/dev/null |" \
  'kills: BOM/CRLF normalization when building the anchor index — a BOM-led skill file defines no anchors, so every citation into it MISSes. Expected killer: 41, whose heading sits on line 1 because that is the only line a BOM can reach.'

mut l4-index-lowercase "$CHK" \
  "    sed 's/^### //; s/\\.\$//' | tr '[:upper:]' '[:lower:]')" \
  "    sed 's/^### //; s/\\.\$//')" \
  'kills: lowercasing the INDEX side of the anchor lookup. Expected killer: 42. Case 12 lowercases the CITATION, so it passes either way — the two sides are separate constructs.'

mut l4-skillfiles-zero "$CHK" \
  "if [ \"\$skill_files\" -eq 0 ]; then" \
  "if false; then" \
  'kills: the guard that citation targets are unverifiable when no SKILL.md was found. Expected killer: 38. NOT 20 — case 20 blanks the HEADINGS and keeps the files, so skill_files stays non-zero and this guard never runs.'

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
  'kills: blanking a leading-dash qualifier — qualifier sanitization, without which a dash attached to a real `cepa:`-prefixed owner reads as an owner claim. Expected killer: 39. NOT 5 — case 5 plants `-x`, which takes the unqualified branch with or without the blanking.'

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

survivor l4-range-inherit "$CHK" \
  "      [a-z]*) p=\"\${first_num}\${p}\" ;;" \
  "      [a-z]*) continue ;;" \
  scripts/check-model-pins.sh:614 \
  'declared survivor: the arm is unreachable from CITE_RE, which numbers both sides of every hyphen, so no part arriving here can start with a letter. Instrumented and measured at zero firings over this repo entire citation set. Kept as the correct handling for a widened range tail; a control becomes possible the day that widening lands.'

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

# ===========================================================================
# The HARNESS tier — subject is the driver, judge is the driver's --selftest
# ===========================================================================
# These close the gap the checker mutants above structurally cannot reach: all
# of them prove the CONTROLS catch a weakened checker, and none proves the
# driver's own assertions catch a weakened driver. On 2026-08-03 four of those
# assertions could not fail and were green the day they shipped.
#
# Each entry below corresponds to a defect that actually shipped and was caught
# by a human mutating this file by hand. Registering them makes the evidence
# re-runnable instead of reproducible-only-by-redoing-the-experiment.
#
# Two further defects from the same set are deliberately ABSENT, and their
# absence is the tier's stated limit rather than an oversight: `ST_NAP` margin
# and the controls suite's `run_checker` bound guard both kill by REFUSING —
# the driver exits before printing a trailer, which is HARNESS-ERROR, which
# aborts the whole sweep. Registering them would take the run down instead of
# reporting a kill. They need a `refuse` expectation keyed on a machine token;
# recorded in the branch shard with that design.

hmut sweep-rm-guard "$DRV" \
  '  rm -f "$out_file" || {
    printf '"'"'FATAL: could not clear the previous controls transcript. Stopping rather\n'"'"' >&2
    printf '"'"'       than risking classifying %s from a stale one.\n'"'"' "$label" >&2
    exit 2
  }' \
  '  rm -f "$out_file" 2>/dev/null || :' \
  'kills: the pre-clear guard on the controls transcript. Without it a failed open leaves the PREVIOUS mutant complete transcript in place to be classified as THIS mutant result — a false CAUGHT, reproduced under chmod 444. Expected killer: "an unclearable transcript path is fatal, never classified".'

hmut sweep-anchor-inline "$DRV" \
  '  capture_controls "$COPY" "$CONTROLS_REL" "$WORK/controls.out" 30 900 "mutant $id" ;;' \
  '  # capture_controls "$COPY" "$CONTROLS_REL" "$WORK/controls.out" 30 900 "mutant $id"
      ( cd "$COPY" && timeout -k 30 900 bash "$CONTROLS_REL" ) > "$WORK/controls.out" 2>&1 ;;' \
  'kills: routing the production capture through the guarded function. The commented-out call site keeps the literal in the file, so a text-counting anchor still reports PASS while the sweep has silently lost the structural bound. Expected killer: "the mutant loop still routes its capture through the guarded function".'

hmut sweep-zero-bound "$DRV" \
  '  if [ "$bound" -eq 0 ] || [ "$grace" -eq 0 ]; then' \
  '  if false; then' \
  'kills: the refusal of a zero bound/grace. GNU timeout reads 0 as "no timeout at all", so removing this lets a caller silently unbound the capture. Anchored on the REFUSAL, never on the call site 900 — --selftest exits long before the mutant loop, so mutating the call site changes nothing in the transcript. Expected killer: "a zero bound is refused, not silently unbounded".'
