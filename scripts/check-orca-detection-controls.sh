#!/usr/bin/env bash
# Controls for scripts/check-orca-detection.sh. Each mutant is built FROM the
# shipped section 12a block of plugins/cepa/skills/autonomy/SKILL.md by one
# substitution, written to a temp copy of the skill file, and must turn the
# check red. The unmutated copy must stay green, or every red below proves
# nothing. A mutant whose anchor text is gone is a MISS, never a skip: the
# block changed shape and these mutants need re-reading.
#
# Why each mutant matters:
#   linux-bare      — `orca` for `orca-ide` on Linux: starts the GNOME screen
#                     reader. Killed by the bare-orca marker.
#   env-probes      — probes status although ORCA_CLI_COMMAND is set.
#   unbounded       — drops `timeout`, so a hung CLI hangs the run.
#   no-kill         — drops `-k 2`, so a CLI that ignores SIGTERM still hangs.
#   truthy-ok       — accepts any truthy "ok" (the string "true").
#   no-cli-check    — drops the PATH check; the reason line changes.
#   exit-ignored    — reads ok:true from a status call that exited non-zero.
#
# STATED LIMITS: a mutant is one substitution; two compensating edits are not
# modeled. The controls prove each FIXTURES case they rely on can fail, not
# that the case list is complete.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

python3 - <<'PY'
import os, shutil, subprocess, sys, tempfile

HOME = "plugins/cepa/skills/autonomy/SKILL.md"
CHECK = "scripts/check-orca-detection.sh"
MUTANTS = [
    ("linux-bare", "    cepa_orca_cli=orca-ide\n", "    cepa_orca_cli=orca\n"),
    ("env-probes",
     "  printf 'ORCA: present cli=%s via=ORCA_CLI_COMMAND\\n' \"$ORCA_CLI_COMMAND\"\n",
     "  \"$ORCA_CLI_COMMAND\" status --json >/dev/null 2>&1 || true\n"
     "  printf 'ORCA: present cli=%s via=ORCA_CLI_COMMAND\\n' \"$ORCA_CLI_COMMAND\"\n"),
    ("unbounded", "$(timeout -k 2 10 \"$cepa_orca_cli\" status", "$(\"$cepa_orca_cli\" status"),
    ("no-kill", "timeout -k 2 10 ", "timeout 10 "),
    ("truthy-ok", '.get("ok") is True else', '.get("ok") else'),
    ("no-cli-check", 'if ! command -v "$cepa_orca_cli" >/dev/null 2>&1; then', "if false; then"),
    ("exit-ignored", "status --json 2>/dev/null); then", "status --json 2>/dev/null || true); then"),
]
passed = failed = 0
TMP = tempfile.mkdtemp(prefix="cepa-orca-ctl-")

def ok(msg):
    global passed; passed += 1; print("PASS", msg)

def miss(msg):
    global failed; failed += 1; print("MISS", msg)

def run(path):
    return subprocess.run(["bash", CHECK, path], capture_output=True, text=True, timeout=600)

text = open(HOME).read()
clean = os.path.join(TMP, "clean.md")
open(clean, "w").write(text)
r = run(clean)
(ok if r.returncode == 0 else miss)("unmutated copy is green (rc=%d)" % r.returncode)
for name, old, new in MUTANTS:
    n = text.count(old)
    if n != 1:
        miss("%s: anchor occurs %d times, want 1" % (name, n)); continue
    p = os.path.join(TMP, name + ".md")
    open(p, "w").write(text.replace(old, new))
    r = run(p)
    killers = [l[5:] for l in r.stdout.splitlines() if l.startswith("MISS ")]
    if r.returncode != 0 and killers:
        ok("%s killed by: %s" % (name, killers[0]))
    else:
        miss("%s survived (rc=%d)" % (name, r.returncode))
shutil.rmtree(TMP, ignore_errors=True)
print("-- %d/%d controls passed, %d failed --" % (passed, passed + failed, failed))
sys.exit(1 if failed else 0)
PY
