#!/usr/bin/env bash
# Controls for scripts/check-orca-cli-path.sh. Each mutant is one substitution
# in a temp copy of one site. It must turn the gate red with EXACTLY the MISS
# cases named beside it, so each mutant shows which case catches it and that no
# other case does. The unmutated tree must run with no MISS line, or every red
# below proves nothing. A mutant whose anchor text is gone is a MISS, never a
# skip: the site changed shape and these mutants need re-reading.
#
# Every site gets every ARM mutant, run with `--site`. SAME and SITES get one
# mutant each, run whole. Mutants run in parallel.
#
# STATED LIMITS: a mutant is one substitution; two compensating edits are not
# modeled. The controls prove each named case can fail, not that the case list
# is complete.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }
exec python3 - <<'PY'
import concurrent.futures, os, re, shutil, subprocess, sys, tempfile

CHECK = os.path.abspath("scripts/check-orca-cli-path.sh")
SKILL = "plugins/cepa/skills/autonomy/SKILL.md"
SCRIPTS = "plugins/cepa/scripts"
PFX = {"attention": "cepa_at", "health": "cepa_h", "lane": "cepa_ln", "nudge": "cepa_nudge", "outbox": "cepa_ob",
       "rebind": "cepa_rb", "send": "cepa_send", "detect": "cepa_orca", "title": "cepa_title"}
BAD_PATHS = {"dispatcher path refused", "/usr/bin/orca refused"}
READER = {"python at shim path refused", "python at serve path refused", "symlink to a python file refused",
          "shadowed directory refused", "empty file at a good path refused", "directory at a good path refused",
          "fifo at a good path refused, no hang"}


def path_of(site):
    return SKILL if site in ("detect", "title") else "%s/orca-%s.sh" % (SCRIPTS, site)


def refusal(site, why):
    if site == "detect":
        return 'cepa_orca_why="%s"' % {"path": "ORCA_CLI_COMMAND is not an Orca launcher",
                                       "bare": "ORCA_CLI_COMMAND names bare orca on Linux"}[why]
    text = {"path": "an orca path on Linux is not an Orca launcher", "bare": "bare orca on Linux is the screen reader"}[why]
    return 'cepa_title_why="%s"' % text if site == "title" else 'refuse "%s"' % text


def arm_mutants(site):
    v = PFX[site]
    path, bare = refusal(site, "path"), refusal(site, "bare")
    os_test = '"$cepa_orca_os" != Linux' if site == "detect" else '"$(uname -s 2>/dev/null)" != Linux'
    return [
        ("any-path", "/*) %s ;;\n" % path, "/*) ;;\n", BAD_PATHS),
        ("first-line-off", "*) %s ;;\n" % path, "*) ;;\n", READER),
        ("bare-allowed", "*) %s ;;\n" % bare, "*) ;;\n", {"bare orca refused"}),
        ("no-file-guard", '%s_l=; [ ! -f "$%s_cli" ] || {' % (v, v), '%s_l=; {' % v,
         {"fifo at a good path refused, no hang"}),
        ("no-sh-launcher", "'#!/usr/bin/env bash'|'#!/usr/bin/env sh') ;;", "'#!/usr/bin/env bash') ;;",
         {"serve path passes"}),
        ("no-shim-path", "/*/linux-orca-cli-shim/orca|/*/cli/bin/orca)", "/*/cli/bin/orca)",
         {"shim path passes"}),
        ("no-serve-path", "/*/linux-orca-cli-shim/orca|/*/cli/bin/orca)", "/*/linux-orca-cli-shim/orca)",
         {"serve path passes"}),
        ("check-off-linux", os_test, os_test.replace("!= Linux", "= Linux"), None),
    ]


def tree():
    d = tempfile.mkdtemp(prefix="cepa-clipath-ctl-")
    shutil.copytree("plugins", os.path.join(d, "plugins"), ignore=shutil.ignore_patterns("__pycache__"))
    return d


def run(root, *args):
    r = subprocess.run(["bash", CHECK] + list(args), env=dict(os.environ, CEPA_CLI_PATH_ROOT=root),
                       capture_output=True, text=True, timeout=240)
    return r.returncode, [l for l in r.stdout.splitlines() if l.startswith("MISS ")]


def names(lines, site):
    pre = "MISS CASE %s " % site
    return {l[len(pre):].split(":")[0] for l in lines if l.startswith(pre)}


def mutate(root, rel, old, new, site):
    p = os.path.join(root, rel)
    s = open(p).read()
    if site in ("detect", "title"):
        # The two skill blocks share the literal text: cut to the site's block.
        cut = s.index("cepa_title_cli=$(cat")
        head, tail = s[:cut], s[cut:]
        if site == "detect":
            if old not in head:
                return False
            head = head.replace(old, new, 1)
        else:
            if old not in tail:
                return False
            tail = tail.replace(old, new, 1)
        s = head + tail
    else:
        if old not in s:
            return False
        s = s.replace(old, new, 1)
    open(p, "w").write(s)
    return True


def control(job):
    site, name, old, new, want = job
    label = "%s %s" % (site, name)
    d = tree()
    try:
        if not mutate(d, path_of(site), old, new, site):
            return "MISS %s: anchor text is gone" % label
        rc, lines = run(d, "--site", site)
        got = names(lines, site)
        if want is None:
            # The whole arm is skipped or inverted: Linux cases go red, and
            # the off-Linux case does too. Only red is pinned here.
            return None if rc == 1 and got else "MISS %s: stayed green" % label
        return None if rc == 1 and got == want else "MISS %s: killed %s, want %s" % (label, sorted(got), sorted(want))
    finally:
        shutil.rmtree(d, ignore_errors=True)


rc, lines = run(os.getcwd())
if rc != 0 or lines:
    print("MISS unmutated tree is red: %r" % lines[:5]); sys.exit(1)

jobs = [(s,) + m for s in PFX for m in arm_mutants(s)]
errs = []
with concurrent.futures.ThreadPoolExecutor(max_workers=min(8, os.cpu_count() or 2)) as ex:
    errs = [e for e in ex.map(control, jobs) if e]

# SAME: a site that drifts in text while still behaving. SITES: a new file.
d = tree()
p = os.path.join(d, path_of("outbox"))
s = open(p).read()
old = "/*/linux-orca-cli-shim/orca|/*/cli/bin/orca)"
open(p, "w").write(s.replace(old, "/*/cli/bin/orca|/*/linux-orca-cli-shim/orca)", 1))
rc, lines = run(d)
if lines != ["MISS SAME the arm differs at: outbox"]:
    errs.append("MISS SAME drift: got %r" % lines)
shutil.rmtree(d, ignore_errors=True)

d = tree()
open(os.path.join(d, SCRIPTS, "orca-new.sh"), "w").write("case x in orca-ide|orca-dev) ;; esac\n")
rc, lines = run(d)
if not (len(lines) == 1 and lines[0].startswith("MISS SITES") and "orca-new.sh" in lines[0]):
    errs.append("MISS SITES new file: got %r" % lines)
shutil.rmtree(d, ignore_errors=True)

for e in errs:
    print(e)
print("check-orca-cli-path-controls: %d mutants, %d failed" % (len(jobs) + 2, len(errs)))
sys.exit(1 if errs else 0)
PY
