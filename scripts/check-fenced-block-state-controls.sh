#!/usr/bin/env bash
# Controls for scripts/check-fenced-block-state.sh — proves the gate actually
# GATES. Read-only with respect to this repository: every case is planted into
# a throwaway fixture tree under $TMPDIR, never into the working tree.
#
# WHY THIS EXISTS. A control that passes with AND without the construct under
# test is the silent-pass shape this repo keeps rediscovering, and residual
# 2i's own record names the sharpest instance: `sv_oneline` hardcoded the seal
# it was comparing against, so under a line-counting mutant the case still
# failed — for the wrong reason, never exercising the counting at all. So every
# case here NAMES THE MUTANT it kills, and `mut_*` cases below re-introduce a
# known-bad construct and assert the checker goes RED, then green on restore.
#
# The headline mutant is `mut_instance5`: the CLIENT="$CEPA_ROOT/scripts/…"
# shape from PR #80's first cut. That line expanded to /scripts/brain-client.sh
# and exited 127 — the signature that reads as a missing binary and put a false
# "brain unreachable" claim into 42 artist360 review files. It is the fifth
# instance of 2g's class and the obvious thing a gate for 2g must catch.
#
# WHY A SYNTHETIC FIXTURE. check-residual-integrity-controls.sh records the
# argument in full and this suite shares it: the live tree is the baseline, so
# planting cases into it would make the baseline dirty by construction. Each
# case is a minimal delta from a hand-built tree that is genuinely clean. The
# COST, recorded rather than left implicit: a synthetic fixture exercises the
# shapes it was built with. The `real` case is the mitigation — it runs the
# checker over the ACTUAL command files and asserts 0 MISS, so a change in what
# the live tree produces reddens this suite instead of passing silently.
#
# Usage: bash scripts/check-fenced-block-state-controls.sh
# Exit: 0 when every case behaves as recorded. 1 otherwise.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$ROOT/scripts/check-fenced-block-state.sh"
EXTRACT="$ROOT/scripts/extract-fenced-blocks.py"

[ -f "$CHECKER" ] || { echo "FATAL: missing $CHECKER"; exit 1; }
[ -f "$EXTRACT" ] || { echo "FATAL: missing $EXTRACT"; exit 1; }

pass=0; fail=0
WORK="$(mktemp -d -t cepa-fbs-controls.XXXXXX)"
# EXIT trap, not a per-branch rm: check-brain-client-args.sh's record shows a
# ten-branch cleanup list where exactly ONE branch cleaned up. A list has to
# stay complete as branches are added; a trap is the mechanism.
trap 'rm -rf "$WORK"' EXIT

# Build a fixture tree that the checker can run against. The checker resolves
# its own ROOT from BASH_SOURCE, so a fixture needs the same layout: a copy of
# the checker, the real extractor, and a plugins/cepa/commands/ dir.
new_fixture() {
  local d="$WORK/$1"
  rm -rf "$d"
  mkdir -p "$d/scripts" "$d/plugins/cepa/commands"
  cp "$CHECKER" "$d/scripts/"
  cp "$EXTRACT" "$d/scripts/"
  printf '%s\n' "$d"
}

# A clean baseline command file: two blocks, each self-contained. Anything the
# checker flags here would be a false positive on correct code.
clean_cmd() {
  cat > "$1" <<'MD'
# A command

Setup:

```bash
set -euo pipefail
WIDGET="$(mktemp)"
echo hi > "$WIDGET"
```

Later, in a DIFFERENT shell:

```bash
set -euo pipefail
WIDGET="$(ls /tmp/widget 2>/dev/null || echo /dev/null)"
cat "$WIDGET"
```
MD
}

# $1 name, $2 expected rc (0 pass / 1 red), $3 why-this-case-exists (the
# mutant it kills — printed on failure), $4 fixture dir
reg() {
  local name="$1" want="$2" why="$3" dir="$4" out rc
  out="$(bash "$dir/scripts/check-fenced-block-state.sh" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ]; then
    pass=$((pass + 1)); printf 'ok   %-18s rc=%d\n' "$name" "$rc"
  else
    fail=$((fail + 1))
    printf 'FAIL %-18s rc=%d want=%d\n' "$name" "$rc" "$want"
    printf '     kills: %s\n' "$why"
    printf '%s\n' "$out" | sed 's/^/       | /'
  fi
}

echo "=== baseline ==="

d="$(new_fixture clean)"; clean_cmd "$d/plugins/cepa/commands/a.md"
# The fixture uses none of the real allowlisted names, so EVERY entry would be
# stale there — leg 3 behaving correctly, but it makes the real allowlist
# unusable as a fixture baseline. So each fixture gets the ALLOW array it needs:
# empty when the case has no external names, or a one-entry array for the cases
# that test admission. Done in python rather than sed because the array spans
# lines and a line-oriented edit on it is how a fixture quietly stops testing
# what it claims to.
python3 - "$d/scripts/check-fenced-block-state.sh" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
s = re.sub(r"^ALLOW=\(.*?^\)$", "ALLOW=()", s, flags=re.S | re.M)
p.write_text(s)
PY
reg clean 0 "a checker that flags self-contained blocks — i.e. fires on correct code, which is how a gate gets disabled by its users" "$d"

echo
echo "=== leg 1: the cross-block signal (2g itself) ==="

# mut_instance5 — THE named mutant. PR #80's first cut, verbatim shape.
d="$(new_fixture instance5)"
cat > "$d/plugins/cepa/commands/a.md" <<'MD'
# A command

Step 3 resolves the plugin root:

```bash
set -euo pipefail
. /opt/cepa/resolve-plugin-root.sh     # sets $CEPA_ROOT
CLIENT="${CEPA_ROOT:-}/scripts/brain-client.sh"
echo "$CLIENT"
```

Step 4, a DIFFERENT shell — and it FORGETS to re-resolve:

```bash
set -euo pipefail
CLIENT="$CEPA_ROOT/scripts/brain-client.sh"
bash "$CLIENT" writeback
```
MD
# THIS CASE HAS BEEN WRONG TWICE, AND BOTH ERRORS WERE FOUND BY MUTATION-
# TESTING THE CONTROLS RATHER THAN BY READING THEM. Recorded in full because
# the file's whole premise is that a control passing for the wrong reason is
# worse than no control.
#
# Cut 1: an EMPTY allowlist. The case then produced TWO MISSes — leg 2 (name
# not allowlisted) AND leg 1 — so disabling leg 1 left rc=1 and the case still
# passed. Removing 2g's own detection killed ZERO of 13 cases.
#
# Cut 2: allowlisted the name and declared "leg 1 is the ONLY leg that can
# redden this case". That was true when written and FALSE by the time it
# shipped: leg 2s was added later, and because block 1 sourced nothing, leg 2s
# became a second trigger. Measured — removing leg 1 killed only
# `mut_instance3`; this case survived and was a duplicate of `mut_sourced_gap`.
# A later leg silently de-isolated an earlier leg's only headline control.
#
# Cut 3: this case is now documented as a DOUBLE-covered case (leg 1 and leg
# 2s both fire on it) rather than falsely claimed to isolate leg 1, and the
# leg-1 isolation it was supposed to provide moved to `mut_leg1_literal`
# below. Trying to isolate it in place does not work and the attempt is worth
# recording: making block 1 source an unrelated script satisfies leg 2s, but
# leg 1 STRUCTURALLY cannot fire for a `sourced` name either — the extractor
# never records such a name as `assigned`, which is the header's own stated
# reason leg 2s had to exist. Measured: that variant reported 0 MISS. So for a
# sourced name there is no leg-1 coverage to isolate; the right fixture uses a
# directly-assigned name.
#
# THE LESSON FOR WHOEVER ADDS THE NEXT LEG: adding a leg can silently take
# over an existing case's kill, leaving the older leg uncovered while the suite
# still reports green. Re-run the per-leg mutation sweep after ANY new leg and
# check that every leg still kills at least one case *that no other leg also
# kills* — a green suite is not evidence that each leg is covered.
python3 - "$d/scripts/check-fenced-block-state.sh" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
s = re.sub(r"^ALLOW=\(.*?^\)$",
           'ALLOW=(\n  "CEPA_ROOT|sourced|fixture: set by a sourced resolve script"\n)',
           s, flags=re.S | re.M)
p.write_text(s)
PY
reg mut_instance5 1 "the CLIENT=\"\$CEPA_ROOT/scripts/…\" shape from PR #80's first cut: CEPA_ROOT assigned in block 0, used in block 1, re-assigned nowhere there. Expands to /scripts/brain-client.sh and exits 127. DOUBLE-COVERED by design — measured, it dies to leg 1 AND to leg 2s. Leg 1's isolating case is mut_leg1_literal; do not re-add an ONLY-leg claim here." "$d"

# The FIX for that mutant must go green — a gate that reddens on both shapes
# is the re.M defect the extractor already shipped once (broken and fixed
# produced IDENTICAL reports). This case is what distinguishes them.
d="$(new_fixture instance5fix)"
# The fix SOURCES a resolve script in each block, which is what production
# actually does — and it matters for this fixture. A direct `CEPA_ROOT=` in
# both blocks would make the name vanish from the candidate list entirely,
# which then trips leg 3 as a stale entry (measured: rc=1 for that reason, not
# leg 1's). Sourcing keeps the name a candidate the allowlist legitimately
# admits, exactly as it is in compound.md, compound-refresh.md and setup.md,
# where $CEPA_ROOT surfaces in every block because the parser cannot see
# through `.` — so this case now differs from mut_instance5 only in whether
# block 1 re-resolves.
cat > "$d/plugins/cepa/commands/a.md" <<'MD'
# A command

Step 3:

```bash
set -euo pipefail
. /opt/cepa/resolve-plugin-root.sh     # sets $CEPA_ROOT
CLIENT="${CEPA_ROOT:-}/scripts/brain-client.sh"
echo "$CLIENT"
```

Step 4, a DIFFERENT shell — re-resolve:

```bash
set -euo pipefail
. /opt/cepa/resolve-plugin-root.sh     # sets $CEPA_ROOT
CLIENT="${CEPA_ROOT:-}/scripts/brain-client.sh"
bash "$CLIENT" writeback
```
MD
# Same allowlist as mut_instance5, so the two cases differ ONLY in whether
# block 1 re-resolves the name. That is what makes this pair a mutant proof
# rather than two unrelated observations.
python3 - "$d/scripts/check-fenced-block-state.sh" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
s = re.sub(r"^ALLOW=\(.*?^\)$",
           'ALLOW=(\n  "CEPA_ROOT|sourced|fixture: set by a sourced resolve script"\n)',
           s, flags=re.S | re.M)
p.write_text(s)
PY
reg instance5_fixed 0 "a gate that cannot tell the fix from the defect — the extractor's own re.M bug, where both shapes reported identically. Restore-to-green is half the mutant proof." "$d"

# mut_instance3 — v1.26.8's P="$P.scrubbed" reaching a later block.
d="$(new_fixture instance3)"
cat > "$d/plugins/cepa/commands/a.md" <<'MD'
# A command

```bash
set -euo pipefail
P=/tmp/payload.json
P="$P.scrubbed"
echo "{}" > "$P"
```

Later:

```bash
set -euo pipefail
bash client writeback "$P"
```
MD
# $P allowlisted for the same reason CEPA_ROOT is in mut_instance5: isolate
# leg 1. In production $P is genuinely carried through the filesystem (2j's
# pointer file), so a `literal` class is the honest fixture analogue.
python3 - "$d/scripts/check-fenced-block-state.sh" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
s = re.sub(r"^ALLOW=\(.*?^\)$",
           'ALLOW=(\n  "P|literal|fixture: payload path the prose tells the agent to substitute"\n)',
           s, flags=re.S | re.M)
p.write_text(s)
PY
reg mut_instance3 1 "2g instance 3 (v1.26.8, fixed v1.26.9): \$P set in one block, writeback in a later one where it is unset, so the post fell back to the UNSCRUBBED original. A PHI leak one block later. Isolates leg 1 — RE-MEASURED 2026-10-03: dies to leg-1 removal, survives leg-2 and leg-2s removal. A \`literal\`-class name cannot reach leg 2s, which is what keeps this true as legs are added; re-verify by mutation after any new leg rather than trusting this sentence." "$d"

echo
echo "=== leg 2: unallowlisted external names ==="

# A name used but assigned nowhere at all, and not allowlisted. Distinct from
# leg 1: nothing assigned it in an earlier block either, so it is an undeclared
# environment dependency rather than a stale carry-over.
d="$(new_fixture unallowed)"
cat > "$d/plugins/cepa/commands/a.md" <<'MD'
# A command

```bash
set -euo pipefail
echo "$TOTALLY_UNDECLARED_THING"
```
MD
python3 - "$d/scripts/check-fenced-block-state.sh" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
s = re.sub(r"^ALLOW=\(.*?^\)$", "ALLOW=()", s, flags=re.S | re.M)
p.write_text(s)
PY
reg mut_unallowed 1 "an undeclared external name passing silently — the allowlist's whole point is that a name is admitted BY DECISION, not by default." "$d"

# The same name, allowlisted with a default-guard. Must go green.
d="$(new_fixture allowed)"
cat > "$d/plugins/cepa/commands/a.md" <<'MD'
# A command

```bash
set -euo pipefail
echo "${MY_OPERATOR_VAR:-unset}"
```
MD
python3 - "$d/scripts/check-fenced-block-state.sh" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
s = re.sub(r"^ALLOW=\(.*?^\)$",
           'ALLOW=(\n  "MY_OPERATOR_VAR|env|fixture operator override, guarded"\n)',
           s, flags=re.S | re.M)
p.write_text(s)
PY
reg allowed_env 0 "an allowlist that cannot actually admit a name — a gate nobody can satisfy gets deleted, which is the failure mode of a checker that flags everything." "$d"

# mut_unguarded — an `env` entry whose use is NOT default-guarded. The
# allowlist's claim ("an empty value is the designed case") is then false:
# under `set -u` the block aborts.
d="$(new_fixture unguarded)"
cat > "$d/plugins/cepa/commands/a.md" <<'MD'
# A command

```bash
set -euo pipefail
echo "$MY_OPERATOR_VAR"
```
MD
python3 - "$d/scripts/check-fenced-block-state.sh" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
s = re.sub(r"^ALLOW=\(.*?^\)$",
           'ALLOW=(\n  "MY_OPERATOR_VAR|env|fixture operator override, guarded"\n)',
           s, flags=re.S | re.M)
p.write_text(s)
PY
reg mut_unguarded 1 "leg 2b: an \`env\` allowlist entry whose uses are bare \$NAME. Removing leg 2b makes the allowlist a rubber stamp — the entry CLAIMS the empty case is designed while \`set -u\` aborts the block." "$d"

# mut_leg1_literal — the ONLY case that isolates leg 1, and it exists because
# the adversarial review of PR #82 measured that `mut_instance5` does not.
# A `literal`-class name sidesteps leg 2s entirely (that leg only guards
# `sourced`) and the allowlist entry satisfies leg 2, so leg 1 — the
# cross-block signal, 2g's own detection — is the single remaining trigger.
# This is also the realistic shape for a documented literal that an author
# substituted in ONE block and then relied on in a later one, which is 2g
# instances 3 and 4 exactly.
d="$(new_fixture leg1literal)"
cat > "$d/plugins/cepa/commands/a.md" <<'MD'
# A command

```bash
set -euo pipefail
P=/tmp/payload.json
echo "{}" > "$P"
```

A DIFFERENT shell, relying on the earlier substitution:

```bash
set -euo pipefail
bash client writeback "$P"
```
MD
python3 - "$d/scripts/check-fenced-block-state.sh" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
new = re.sub(r"^ALLOW=\(.*?^\)$",
             'ALLOW=(\n  "P|literal|fixture: payload path the prose tells the agent to substitute"\n)',
             s, flags=re.S | re.M)
assert new != s, "ALLOW substitution matched nothing"
p.write_text(new)
PY
reg mut_leg1_literal 1 "leg 1 — the cross-block signal, 2g's OWN detection. This is leg 1's only isolating case: a literal-class name cannot trigger leg 2s, and the allowlist entry satisfies leg 2. The adversarial review measured that mut_instance5 does NOT isolate leg 1 (it dies to leg 2s), so without this case removing 2g's core detection kills only mut_instance3." "$d"

# mut_env_launder — leg 2b must decide guardedness PER BLOCK. The first cut
# grepped the whole .md file, so one guarded mention anywhere laundered every
# unguarded use elsewhere: measured by PR #82's adversarial review, unguarded
# `$MY_VAR` in block 0 plus `${MY_VAR:-}` in block 1 gave 0 MISS, while block 0
# aborts under the `set -euo pipefail` every block in this corpus sets.
# mut_unguarded alone cannot catch this — it is single-block, where per-file
# and per-block scope coincide, so the gap was invisible to the suite.
d="$(new_fixture envlaunder)"
cat > "$d/plugins/cepa/commands/a.md" <<'MD'
# A command

```bash
set -euo pipefail
echo "$MY_OPERATOR_VAR"
```

```bash
set -euo pipefail
echo "${MY_OPERATOR_VAR:-fallback}"
```
MD
python3 - "$d/scripts/check-fenced-block-state.sh" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
new = re.sub(r"^ALLOW=\(.*?^\)$",
             'ALLOW=(\n  "MY_OPERATOR_VAR|env|fixture operator override, guarded"\n)',
             s, flags=re.S | re.M)
assert new != s, "ALLOW substitution matched nothing"
p.write_text(new)
PY
reg mut_env_launder 1 "leg 2b scoped per FILE instead of per BLOCK. One guarded mention then launders every unguarded use in every other block — and the laundering mention need not even be code: a comment, or markdown prose outside any fence, satisfied a claim about shell state." "$d"

# mut_env_scope_exact — rc alone cannot pin leg 2b's SCOPE. Mutation-tested
# 2026-10-03: replacing the per-block body with the whole file still reddens
# mut_env_launder, because the whole-file scan over-reports and flags BOTH
# blocks — 2 MISSes instead of 1. The case survives for the wrong reason, so
# it cannot tell per-block from per-file. This asserts the EXACT finding set:
# block 0 is unguarded and must be flagged; block 1 is guarded and must NOT be.
# Counting findings, not just rc, is the lesson a-control-suite-proves-only-
# the-branch-it-exercises records as "assert the exit code, not just message
# text" — one level further in.
out="$(bash "$d/scripts/check-fenced-block-state.sh" 2>&1)"
n_miss="$(printf '%s\n' "$out" | grep -cE '^MISS' || true)"
if [ "$n_miss" -eq 1 ] && printf '%s\n' "$out" | grep -q 'block 0: \$MY_OPERATOR_VAR'; then
  pass=$((pass + 1)); printf 'ok   %-18s exactly block 0 flagged\n' mut_env_scope_exact
else
  fail=$((fail + 1))
  printf 'FAIL %-18s expected exactly 1 MISS naming block 0, got %s\n' mut_env_scope_exact "$n_miss"
  printf '     kills: leg 2b reading the whole FILE rather than this block. That over-reports (flags the guarded block too), which still reddens an rc-only case — so without this assertion the scope is untested in both directions.\n'
  printf '%s\n' "$out" | sed 's/^/       | /'
fi

echo
echo "=== leg 2s: a sourced name needs sourcing IN ITS OWN block ==="

# mut_sourced_gap — the hole that mutation-testing the controls found, and the
# reason leg 2s exists. $CEPA_ROOT is set by a SOURCED script, so the extractor
# never records it as `assigned` and leg 1 structurally cannot fire for it.
# With the allowlist admitting the name unconditionally, the reconstructed
# instance-5 shape reported 0 MISS — the gate green-lighting the exact defect
# it was built for. 2g instances 2, 4 and 5 are all this name.
d="$(new_fixture sourcedgap)"
cat > "$d/plugins/cepa/commands/a.md" <<'MD'
# A command

```bash
set -euo pipefail
. /opt/cepa/resolve-plugin-root.sh     # sets $CEPA_ROOT
echo "${CEPA_ROOT:-}"
```

A DIFFERENT shell that forgets to re-source:

```bash
set -euo pipefail
bash "$CEPA_ROOT/scripts/brain-client.sh" writeback
```
MD
python3 - "$d/scripts/check-fenced-block-state.sh" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
s = re.sub(r"^ALLOW=\(.*?^\)$",
           'ALLOW=(\n  "CEPA_ROOT|sourced|fixture: set by a sourced resolve script"\n)',
           s, flags=re.S | re.M)
p.write_text(s)
PY
reg mut_sourced_gap 1 "leg 2s: a \`sourced\` name used in a block that sources nothing. Leg 1 CANNOT cover this (a sourced name is never 'assigned'), so without leg 2s the allowlist admits it everywhere and the instance-5 shape passes at 0 MISS." "$d"

echo
echo "=== leg 2f: the fragment marker is an exception, not an off switch ==="

# A single marked block is exempt — compound-refresh.md's real shape, whose own
# prose states the assembly requirement twice.
d="$(new_fixture frag1)"
cat > "$d/plugins/cepa/commands/a.md" <<'MD'
# A command

```bash
set -euo pipefail
. /opt/cepa/resolve-plugin-root.sh     # sets $CEPA_ROOT
echo "${CEPA_ROOT:-}"
```

```bash
set -euo pipefail
# PASTE THIS AFTER the resolver loop above, in ONE block. Not standalone.
bash "$CEPA_ROOT/scripts/brain-client.sh" writeback
```
MD
python3 - "$d/scripts/check-fenced-block-state.sh" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
s = re.sub(r"^ALLOW=\(.*?^\)$",
           'ALLOW=(\n  "CEPA_ROOT|sourced|fixture: set by a sourced resolve script"\n)',
           s, flags=re.S | re.M)
p.write_text(s)
PY
reg frag_one_ok 0 "a gate with no fragment path — it would flag compound-refresh.md's writeback block, whose prose already states the assembly requirement twice. A gate that fires on a documented contract gets switched off." "$d"

# mut_frag_abuse — mark BOTH blocks. If this passed, any file could exempt
# itself wholesale by pasting the marker everywhere.
#
# BLOCK 0 SOURCES, DELIBERATELY, and that is what isolates the cap. Mutation-
# tested 2026-10-03: when block 0 did NOT source, it produced its own leg-2s
# MISS, so the case stayed red through that finding and removing the cap killed
# nothing — the cap looked tested and was not. The same run exposed the real
# bug behind it: `frag_blk` was a scalar holding only the LAST marked block, so
# the exemption depended on block order. Now block 0 is clean on every other
# leg, and ONLY the two-marker cap can fail this case.
d="$(new_fixture frag2)"
cat > "$d/plugins/cepa/commands/a.md" <<'MD'
# A command

```bash
set -euo pipefail
# PASTE THIS AFTER something, in ONE block.
. /opt/cepa/resolve-plugin-root.sh     # sets $CEPA_ROOT
echo "${CEPA_ROOT:-}"
```

```bash
set -euo pipefail
# PASTE THIS AFTER the resolver loop above, in ONE block. Not standalone.
bash "$CEPA_ROOT/scripts/brain-client.sh" writeback
```
MD
python3 - "$d/scripts/check-fenced-block-state.sh" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
s = re.sub(r"^ALLOW=\(.*?^\)$",
           'ALLOW=(\n  "CEPA_ROOT|sourced|fixture: set by a sourced resolve script"\n)',
           s, flags=re.S | re.M)
p.write_text(s)
PY
reg mut_frag_abuse 1 "leg 2f: removing the one-per-file cap turns the fragment marker into a wholesale off switch — paste it in every block and the file is exempt from leg 2s entirely." "$d"

# mut_frag_order — the marker must exempt the block that CARRIES it, whichever
# position that is. The original scalar `frag_blk` kept only the last marked
# block, so a marker on an EARLIER block silently exempted a LATER one instead:
# a real violation passing while a documented fragment was flagged, both wrong,
# and in opposite directions. Here the marker is on block 0 (which needs it,
# since it does not source) while block 1 sources properly, so a scalar
# implementation exempts the wrong block and reddens this case.
d="$(new_fixture fragorder)"
cat > "$d/plugins/cepa/commands/a.md" <<'MD'
# A command

```bash
set -euo pipefail
# PASTE THIS AFTER the resolver loop above, in ONE block. Not standalone.
bash "$CEPA_ROOT/scripts/brain-client.sh" health
```

```bash
set -euo pipefail
. /opt/cepa/resolve-plugin-root.sh     # sets $CEPA_ROOT
bash "${CEPA_ROOT:-}/scripts/brain-client.sh" writeback
```
MD
python3 - "$d/scripts/check-fenced-block-state.sh" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
s = re.sub(r"^ALLOW=\(.*?^\)$",
           'ALLOW=(\n  "CEPA_ROOT|sourced|fixture: set by a sourced resolve script"\n)',
           s, flags=re.S | re.M)
p.write_text(s)
PY
reg mut_frag_order 0 "a scalar frag_blk holding only the LAST marked block. The marker here is on block 0, so a scalar implementation exempts block 1 instead and flags block 0 — the exemption silently following block order rather than the marker." "$d"

# mut_frag_heredoc — the marker must be ONE FULL-LINE COMMENT carrying both
# strings. Two independent unanchored greps over the whole block was looser
# than the comment describing it, and PR #82's adversarial review measured the
# consequence: a block writing an operator note whose heredoc body happens to
# say "PASTE THIS AFTER the summary table, as ONE block of prose" was EXEMPTED
# (0 MISS) while carrying a real leg-2s violation. Reachable in this corpus
# specifically — command files routinely emit PR bodies and handoff prompts
# containing paste instructions.
d="$(new_fixture fragheredoc)"
cat > "$d/plugins/cepa/commands/a.md" <<'MD'
# A command

```bash
set -euo pipefail
. /opt/cepa/resolve-plugin-root.sh
echo "${CEPA_ROOT:-}"
```

```bash
set -euo pipefail
cat > /tmp/note.md <<'EOF'
PASTE THIS AFTER the summary table, as ONE block of prose.
EOF
bash "$CEPA_ROOT/scripts/brain-client.sh" writeback
```
MD
python3 - "$d/scripts/check-fenced-block-state.sh" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
new = re.sub(r"^ALLOW=\(.*?^\)$",
             'ALLOW=(\n  "CEPA_ROOT|sourced|fixture: set by a sourced resolve script"\n)',
             s, flags=re.S | re.M)
assert new != s, "ALLOW substitution matched nothing"
p.write_text(new)
PY
reg mut_frag_heredoc 1 "a fragment marker matched by two unanchored greps anywhere in the block. The strings then match inside a heredoc body writing an unrelated operator note, silently consuming the file's one fragment slot and disabling leg 2s on a block with a real violation." "$d"

# mut_frag_split — same class, different shape: the two strings on separate
# lines, in unrelated `echo` arguments. Also measured exempt before the fix.
d="$(new_fixture fragsplit)"
cat > "$d/plugins/cepa/commands/a.md" <<'MD'
# A command

```bash
set -euo pipefail
. /opt/cepa/resolve-plugin-root.sh
echo "${CEPA_ROOT:-}"
```

```bash
set -euo pipefail
echo "PASTE THIS AFTER the table"
echo "Summarise in ONE block quote"
bash "$CEPA_ROOT/scripts/brain-client.sh" writeback
```
MD
python3 - "$d/scripts/check-fenced-block-state.sh" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
new = re.sub(r"^ALLOW=\(.*?^\)$",
             'ALLOW=(\n  "CEPA_ROOT|sourced|fixture: set by a sourced resolve script"\n)',
             s, flags=re.S | re.M)
assert new != s, "ALLOW substitution matched nothing"
p.write_text(new)
PY
reg mut_frag_split 1 "the two marker strings on SEPARATE lines in unrelated echo arguments. A per-string grep pair cannot tell this from a real one-line assembly comment, so it grants the exemption to a block that never claimed it." "$d"

echo
echo "=== leg 3: allowlist honesty ==="

# mut_stale — an entry matching nothing. This case is not hypothetical: the
# first run of the real checker produced exactly this MISS for $RUN.
d="$(new_fixture stale)"; clean_cmd "$d/plugins/cepa/commands/a.md"
python3 - "$d/scripts/check-fenced-block-state.sh" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
s = re.sub(r"^ALLOW=\(.*?^\)$",
           'ALLOW=(\n  "GONE_AWAY|env|a name whose every use has been deleted"\n)',
           s, flags=re.S | re.M)
p.write_text(s)
PY
reg mut_stale 1 "leg 3: an allowlist entry that suppresses nothing. Removing leg 3 lets suppressions accrete, so a name allowlisted years ago still reads as decided when its guard is long gone — and that is how \$CEPA_ROOT would become instance 7." "$d"

echo
echo "=== leg 0: coverage announcement ==="

# A shell block under a non-bash label is invisible to legs 1 and 2. It must
# announce itself rather than silently shrinking coverage. WARN, not MISS:
# relabeling is the author's call, and a false MISS here would be fixed by
# mangling correct markdown.
d="$(new_fixture label)"
cat > "$d/plugins/cepa/commands/a.md" <<'MD'
# A command

```sh
set -euo pipefail
echo "$SOME_CARRIED_THING"
```
MD
python3 - "$d/scripts/check-fenced-block-state.sh" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
s = re.sub(r"^ALLOW=\(.*?^\)$", "ALLOW=()", s, flags=re.S | re.M)
p.write_text(s)
PY
out="$(bash "$d/scripts/check-fenced-block-state.sh" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q 'WARN:.*```sh fence'; then
  pass=$((pass + 1)); printf 'ok   %-18s rc=0 + WARN\n' mut_sh_label
else
  fail=$((fail + 1))
  printf 'FAIL %-18s rc=%d (want rc=0 WITH a ```sh WARN)\n' mut_sh_label "$rc"
  printf '     kills: a ```sh block silently escaping inspection — coverage shrinking with no signal, which reads as "nothing to find".\n'
  printf '%s\n' "$out" | sed 's/^/       | /'
fi

# mut_unlabeled_shell — leg 0's CONTENT probe. The label-only form of leg 0 was
# blind to an unlabeled fence: measured 2026-10-03, a reconstructed instance-5
# violation in an unlabeled block gave `0 MISS, 0 WARN, rc=0` — the gate
# passing a real 2g violation in total silence. The live corpus has 62
# unlabeled fences and one of them (handoff.md block 9) holds six shell-looking
# lines, so the blind spot was real, not hypothetical.
d="$(new_fixture unlabeled)"
printf '```bash\nset -e\n. /opt/r.sh\necho "${CEPA_ROOT:-}"\n```\n\n```\nset -euo pipefail\nbash "$CEPA_ROOT/x" writeback\n```\n' \
  > "$d/plugins/cepa/commands/a.md"
python3 - "$d/scripts/check-fenced-block-state.sh" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
s = re.sub(r"^ALLOW=\(.*?^\)$",
           'ALLOW=(\n  "CEPA_ROOT|sourced|fixture: set by a sourced resolve script"\n)',
           s, flags=re.S | re.M)
p.write_text(s)
PY
out="$(bash "$d/scripts/check-fenced-block-state.sh" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q 'UNLABELED'; then
  pass=$((pass + 1)); printf 'ok   %-18s rc=0 + UNLABELED WARN\n' mut_unlabeled_shell
else
  fail=$((fail + 1))
  printf 'FAIL %-18s rc=%d (want rc=0 WITH an UNLABELED warn)\n' mut_unlabeled_shell "$rc"
  printf '     kills: a leg 0 that checks only the fence LABEL. An unlabeled fence then escapes inspection entirely and a 2g violation placed there passes at 0 MISS / 0 WARN.\n'
  printf '%s\n' "$out" | sed 's/^/       | /'
fi

# mut_capital_bash — ```Bash. The extractor matches the label exactly and
# case-sensitively, so a capitalised label is NOT inspected by legs 1-2s. The
# original leg-0 label list omitted it and the gate went fully silent.
d="$(new_fixture capbash)"
printf '```bash\nset -e\n. /opt/r.sh\necho "${CEPA_ROOT:-}"\n```\n\n```Bash\nset -euo pipefail\nbash "$CEPA_ROOT/x" writeback\n```\n' \
  > "$d/plugins/cepa/commands/a.md"
python3 - "$d/scripts/check-fenced-block-state.sh" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
s = re.sub(r"^ALLOW=\(.*?^\)$",
           'ALLOW=(\n  "CEPA_ROOT|sourced|fixture: set by a sourced resolve script"\n)',
           s, flags=re.S | re.M)
p.write_text(s)
PY
out="$(bash "$d/scripts/check-fenced-block-state.sh" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -qE 'case-sensitive|UNLABELED'; then
  pass=$((pass + 1)); printf 'ok   %-18s rc=0 + WARN\n' mut_capital_bash
else
  fail=$((fail + 1))
  printf 'FAIL %-18s rc=%d (want rc=0 WITH a warn)\n' mut_capital_bash "$rc"
  printf '     kills: a leg-0 label list omitting capitalised spellings. ```Bash looks inspected to a reader and is invisible to the extractor.\n'
  printf '%s\n' "$out" | sed 's/^/       | /'
fi

echo
echo "=== extractor regressions (the gate rests on these) ==="

# mut_prose_read — a bare \bread\b in READ_RE harvests English words from
# comments as ASSIGNED names, and a bogus `assigned` entry SUPPRESSES a real
# candidate of the same name. Measured on compound.md: `from`, `it`, `rather`,
# `than`, `the`, `there`, `retyping`, `path`, `payload`, `pointer`.
probe="$WORK/prose.md"
cat > "$probe" <<'MD'
```bash
set -euo pipefail
# Re-read the payload path from the pointer rather than retyping it
echo ok
```
MD
out="$(python3 "$EXTRACT" "$probe" --report 2>&1)"
# Anchored to the `assigned:` line: an unanchored `assigned:` also matches
# inside `used-not-assigned:`, so a prose word appearing only as a USE would
# read as a phantom assignment. Same defect as mut_comment_assign's first cut.
if printf '%s\n' "$out" | grep -qE '^  assigned: .*(\brather\b|\bretyping\b|\bpointer\b)'; then
  fail=$((fail + 1))
  printf 'FAIL %-18s prose words parsed as assigned\n' mut_prose_read
  printf '     kills: READ_RE anchored with a bare \\bread\\b. An over-reported `assigned` name silently suppresses a real 2g candidate — a wrong all-clear in the exact class this gate exists to find.\n'
  printf '%s\n' "$out" | sed 's/^/       | /'
else
  pass=$((pass + 1)); printf 'ok   %-18s no prose leakage\n' mut_prose_read
fi

# mut_read_loop — `while read -r NAME` must register as an assignment, or the
# loop variable reports as a 2g candidate forever (and the tempting fix is an
# allowlist entry, which papers a parser gap into a permanent suppression).
probe="$WORK/readloop.md"
cat > "$probe" <<'MD'
```bash
set -euo pipefail
printf 'a\nb\n' | while read -r item; do echo "$item"; done
```
MD
out="$(python3 "$EXTRACT" "$probe" --report 2>&1)"
if printf '%s\n' "$out" | grep -q 'used-not-assigned: .*item'; then
  fail=$((fail + 1))
  printf 'FAIL %-18s `while read -r item` not seen as an assignment\n' mut_read_loop
  printf '     kills: a command-position list omitting while/until. Measured: `id` in compound.md returned as a candidate until they were added.\n'
  printf '%s\n' "$out" | sed 's/^/       | /'
else
  pass=$((pass + 1)); printf 'ok   %-18s read loop assigns\n' mut_read_loop
fi

# mut_no_reM — the extractor's own first-cut defect, kept dead. Without re.M,
# an indented or non-first-line re-assignment is invisible, so the FIX and the
# DEFECT report identically. Assert a late indented assignment is seen.
probe="$WORK/reM.md"
cat > "$probe" <<'MD'
```bash
set -euo pipefail
  LATE_INDENTED=1
echo "$LATE_INDENTED"
```
MD
out="$(python3 "$EXTRACT" "$probe" --report 2>&1)"
# Anchored, and here it is a FALSE-PASS risk rather than a false-fail one:
# unanchored, `used-not-assigned: LATE_INDENTED` satisfies the test, so the
# case would pass precisely when re.M was broken and the name was NOT seen as
# assigned. That is this suite's subject matter one level down.
if printf '%s\n' "$out" | grep -qE '^  assigned: .*\bLATE_INDENTED\b'; then
  pass=$((pass + 1)); printf 'ok   %-18s re.M intact\n' mut_no_reM
else
  fail=$((fail + 1))
  printf 'FAIL %-18s indented late assignment invisible\n' mut_no_reM
  printf '     kills: ASSIGN_RE without re.M — the extractor shipped this once, and the broken and fixed shapes of compound.md produced IDENTICAL reports. A 2g checker that cannot see a re-assignment is worse than none.\n'
  printf '%s\n' "$out" | sed 's/^/       | /'
fi

# mut_source_anchor — SOURCE_RE must match a `.` in COMMAND POSITION, not only
# at line start. This repo's actual idiom is `[ -f "$R" ] && . "$R" && break`.
# Measured 2026-10-03: with a line-anchored probe, 6 of 7 blocks the gate
# flagged were false positives in compound.md, compound-refresh.md and
# setup.md — an absence claim that was a fact about the probe.
probe="$WORK/srcanchor.md"
cat > "$probe" <<'MD'
```bash
set -euo pipefail
for R in /a/resolve.sh /b/resolve.sh; do
  [ -f "$R" ] && . "$R" && break
done
echo "${CEPA_ROOT:-}"
```
MD
out="$(python3 "$EXTRACT" "$probe" --report 2>&1)"
if printf '%s\n' "$out" | grep -q 'sources a script'; then
  pass=$((pass + 1)); printf 'ok   %-18s && . "$R" detected\n' mut_source_anchor
else
  fail=$((fail + 1))
  printf 'FAIL %-18s `&& . "$R"` not seen as sourcing\n' mut_source_anchor
  printf '     kills: a line-anchored SOURCE_RE. It reports "sources nothing" for every resolve loop in this repo, which makes leg 2s fire on 6 correct blocks — and a gate with 6 false positives is a gate nobody runs.\n'
  printf '%s\n' "$out" | sed 's/^/       | /'
fi

# mut_comment_use — a name mentioned ONLY in a full-line comment is not a use.
# setup.md block 1 carries "do NOT resolve it through $CEPA_ROOT" and nothing
# else, so the gate reported a 2g violation in a block whose prose says the
# opposite. Note the asymmetry this case locks in: uses are comment-stripped,
# ASSIGNMENTS deliberately are not.
probe="$WORK/commentuse.md"
cat > "$probe" <<'MD'
```bash
set -euo pipefail
# do NOT resolve it through $CEPA_ROOT — this is repo tooling
echo hi
```
MD
out="$(python3 "$EXTRACT" "$probe" --report 2>&1)"
if printf '%s\n' "$out" | grep -q 'used-not-assigned: (none)'; then
  pass=$((pass + 1)); printf 'ok   %-18s comment-only use ignored\n' mut_comment_use
else
  fail=$((fail + 1))
  printf 'FAIL %-18s comment-only mention counted as a use\n' mut_comment_use
  printf '     kills: an unstripped uses scan. It flags a block whose comment says the OPPOSITE of the finding — the false-positive shape that gets a gate disabled.\n'
  printf '%s\n' "$out" | sed 's/^/       | /'
fi

# mut_comment_assign — the dangerous DIRECTION of the comment question, and the
# control's first rationale was wrong about where the protection comes from.
#
# A phantom ASSIGNMENT is strictly worse than a false positive: it adds a name
# to `assigned` and so SUPPRESSES every real candidate of that name in the
# block. Mutation-tested 2026-10-03: stripping comments before the assignment
# scan killed nothing, because stripping can only ever make `assigned` SMALLER.
# The real hazard is ASSIGN_RE matching `#WIDGET=/opt/w` and treating it as an
# assignment. Verified it does not: the regex requires `^[ \t]*` or a `;`/`|`/`&`
# separator before the name, and `#` is in neither set. So THIS is the invariant
# worth pinning, and it lives in ASSIGN_RE's anchor rather than in any comment
# handling. Both the no-space and with-space forms are checked, because only the
# no-space form is a near-miss for the `^[ \t]*` branch.
probe="$WORK/commentassign.md"
cat > "$probe" <<'MD'
```bash
set -euo pipefail
echo "${WIDGET:-}"
```

```bash
set -euo pipefail
#WIDGET=/opt/w
# WIDGET=/opt/w
bash "$WIDGET/x" run
```
MD
out="$(python3 "$EXTRACT" "$probe" --report 2>&1)"
# ANCHORED. A bare `grep 'assigned: WIDGET'` also matches the substring inside
# `used-not-assigned: WIDGET`, which inverts this case: it reported the phantom
# assignment it was built to detect on a tree that never had one. Measured
# 2026-10-03 — the probe-shape defect this repo's own rule names, inside the
# control for a probe-shape defect.
if printf '%s\n' "$out" | grep -qE '^  assigned: .*\bWIDGET\b'; then
  fail=$((fail + 1))
  printf 'FAIL %-18s commented-out assignment counted as an assignment\n' mut_comment_assign
  printf '     kills: an ASSIGN_RE that admits `#NAME=`. A phantom assignment SUPPRESSES every real candidate of that name — the wrong-all-clear direction, strictly worse than a false positive.\n'
  printf '%s\n' "$out" | sed 's/^/       | /'
else
  pass=$((pass + 1)); printf 'ok   %-18s commented assignment is not an assignment\n' mut_comment_assign
fi

# mut_heredoc_assign — a heredoc BODY line shaped like an assignment must not
# count as one. Found by PR #82's adversarial review, reproduced here: a block
# writing an operator runbook that documents `P=/tmp/payload.json` reported
# `assigned: P`, which SUPPRESSED the real candidate, so leg 1 saw nothing and
# the gate passed a block where `$P` is genuinely unset. On compound.md's
# writeback path that is the v1.26.8 shape — writeback falls back to the
# unscrubbed original, a PHI leak. `task.md` block 9 already has a heredoc.
probe="$WORK/heredoc.md"
cat > "$probe" <<'MD'
```bash
set -euo pipefail
P="$(mktemp)"
echo '{}' > "$P"
```

```bash
set -euo pipefail
cat > /tmp/runbook.md <<'EOF'
To reproduce by hand:
P=/tmp/payload.json
then run writeback.
EOF
bash client writeback "$P"
```
MD
out="$(python3 "$EXTRACT" "$probe" --report 2>&1)"
# Anchored, per mut_comment_assign's precedent: an unanchored `assigned: P`
# also matches inside `used-not-assigned: P` and would invert this case.
if printf '%s\n' "$out" | grep -qE '^  assigned: .*\bP\b.*$' &&
   printf '%s\n' "$out" | sed -n '/^block 1:/,$p' | grep -qE '^  assigned: .*\bP\b'; then
  fail=$((fail + 1))
  printf 'FAIL %-18s heredoc text counted as an assignment\n' mut_heredoc_assign
  printf '     kills: an ASSIGN_RE scan over the raw body with no heredoc masking. A phantom assignment suppresses every real candidate of that name — the wrong-all-clear direction, and a PHI-leak path on compound.md.\n'
  printf '%s\n' "$out" | sed 's/^/       | /'
else
  pass=$((pass + 1)); printf 'ok   %-18s heredoc text is not an assignment\n' mut_heredoc_assign
fi

# mut_heredoc_use — the OTHER direction, and it must NOT be masked. A `$NAME`
# inside an unquoted-delimiter heredoc really is expanded by the shell, so
# masking the uses scan would HIDE a real use. Masking is for `assigned` only.
probe="$WORK/heredocuse.md"
cat > "$probe" <<'MD'
```bash
set -euo pipefail
cat > /tmp/out.txt <<EOF
value is $WIDGET
EOF
```
MD
out="$(python3 "$EXTRACT" "$probe" --report 2>&1)"
if printf '%s\n' "$out" | grep -q 'used-not-assigned: .*WIDGET'; then
  pass=$((pass + 1)); printf 'ok   %-18s heredoc use still counted\n' mut_heredoc_use
else
  fail=$((fail + 1))
  printf 'FAIL %-18s a real use inside a heredoc was masked away\n' mut_heredoc_use
  printf '     kills: applying heredoc masking to the USES scan. The shell expands $NAME in an unquoted-delimiter heredoc, so hiding it is a false negative on a real carry.\n'
  printf '%s\n' "$out" | sed 's/^/       | /'
fi

echo
echo "=== leg 4: the parse understood the report ==="

# mut_parse_drift — the gate reads the extractor's output by matching literal
# labels, and nothing pins that format. Measured 2026-10-03: renaming
# `block N:` to `chunk N:` in a copy of the extractor gave `scope: 0 block(s)`,
# `0 MISS`, rc=0 — a GREEN GATE THAT PARSED NOTHING, printing the evidence of
# its own failure in the scope line while nothing acted on it. That is the
# silent-pass shape this entire script exists to gate, inside the gate.
d="$(new_fixture parsedrift)"; clean_cmd "$d/plugins/cepa/commands/a.md"
python3 - "$d/scripts/check-fenced-block-state.sh" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
new = re.sub(r"^ALLOW=\(.*?^\)$", "ALLOW=()", s, flags=re.S | re.M)
assert new != s, "ALLOW substitution matched nothing"
p.write_text(new)
PY
# Drift the extractor's block header in the FIXTURE copy only.
python3 - "$d/scripts/extract-fenced-blocks.py" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
old = 'print(f"block {i}: {len(b[\'lines\'])} lines")'
assert old in s, "block-header print not found — update this mutant"
p.write_text(s.replace(old, 'print(f"chunk {i}: {len(b[\'lines\'])} lines")', 1))
PY
reg mut_parse_drift 1 "leg 4: the gate's label-matching parse silently reading NOTHING. Without the cross-check, a renamed block-header label gives scope:0 / 0 MISS / rc=0 — every leg's silence meaningless, reported as a clean run and cited as evidence." "$d"

# mut_no_bc — leg 4's extractor-independent probe must not need an external
# calculator. The first cut piped through `paste -sd+ | bc`, and `bc` is a
# dependency this repo explicitly must not assume (CLAUDE.md records the same
# gap for `jq`: "absent on the primary dev machine"). Measured 2026-10-03 with
# a PATH identical except for `bc`:
#
#   line 469: bc: command not found
#   line 474: [: : integer expression expected
#   cross-check: 28 via direct grep of the reports,  via fence count
#   result: 0 MISS, 1 WARN        <- rc=0
#
# The failed substitution left the count EMPTY rather than unset, so `set -u`
# could not see it, and the resulting `[` error was swallowed as an `if`
# CONDITION — residual 2i's 2^63 blind spot exactly. An unevaluable leg reading
# as a pass, inside the leg added to stop a probe from silently reading
# nothing. Found by PR #82's security review.
nobc="$WORK/nobc-path"
mkdir -p "$nobc"
# Link every tool on the real PATH EXCEPT bc, so bc-absence is the only delta.
while IFS= read -r dir; do
  [ -d "$dir" ] || continue
  for tool in "$dir"/*; do
    tname="${tool##*/}"
    [ "$tname" = bc ] && continue
    [ -e "$nobc/$tname" ] || ln -sf "$tool" "$nobc/$tname" 2>/dev/null
  done
done < <(printf '%s\n' "$PATH" | tr ':' '\n')

if [ -e "$nobc/bc" ]; then
  # Cannot build the fixture, so the case is UNEVALUABLE — which must never
  # read as a pass. That is this very control's own subject matter.
  fail=$((fail + 1))
  printf 'FAIL %-18s could not build a bc-free PATH; case UNEVALUABLE\n' mut_no_bc
elif ! env PATH="$nobc" bash -c 'command -v python3 >/dev/null'; then
  fail=$((fail + 1))
  printf 'FAIL %-18s bc-free PATH lacks python3; fixture is wrong, not the gate\n' mut_no_bc
else
  out="$(env PATH="$nobc" bash "$CHECKER" 2>&1)"; rc=$?
  # Two independent assertions: no shell-level arithmetic error leaked, and the
  # cross-check line carries a real number rather than a blank.
  if printf '%s\n' "$out" | grep -qE 'bc: command not found|integer expression expected'; then
    fail=$((fail + 1))
    printf 'FAIL %-18s leg 4 still needs an external calculator\n' mut_no_bc
    printf '     kills: `paste|bc` in leg 4. Without bc the count goes EMPTY (set -u cannot see it), the `[` error is swallowed as an if-condition, and the cross-check silently stops existing at rc=0.\n'
    printf '%s\n' "$out" | sed 's/^/       | /'
  elif ! printf '%s\n' "$out" | grep -qE 'cross-check: [0-9]+ via direct grep of the reports, [0-9]+ via fence count'; then
    fail=$((fail + 1))
    printf 'FAIL %-18s cross-check line is missing a numeric count\n' mut_no_bc
    printf '     kills: a leg-4 probe that prints a blank where its count belongs — the visible evidence of its own failure, with nothing acting on it.\n'
    printf '%s\n' "$out" | sed 's/^/       | /'
  else
    pass=$((pass + 1)); printf 'ok   %-18s rc=%d with no bc on PATH\n' mut_no_bc "$rc"
  fi
fi

echo
echo "=== real tree ==="

# The synthetic fixture exercises shapes it was built with. This runs the gate
# over the ACTUAL command files, so a change in what the live tree produces
# reddens this suite instead of passing silently.
out="$(bash "$CHECKER" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1)); printf 'ok   %-18s rc=0 over %s\n' real "plugins/cepa/commands/*.md"
else
  fail=$((fail + 1))
  printf 'FAIL %-18s rc=%d over the live tree\n' real "$rc"
  printf '     kills: a fixture-only suite. The live tree is the baseline; if it reddens, either a real 2g instance landed or the allowlist needs a decision.\n'
  printf '%s\n' "$out" | sed 's/^/       | /'
fi

echo
echo "result: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
exit 0
