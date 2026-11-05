#!/usr/bin/env bash
# Gate for the Linux `orca` arm of the cli check (punch-list L81). `cepa:autonomy`
# §12a owns the rule; this file owns how it is proved.
#
# LEGS
#   CASE <site> <case>  runs the real site against planted files, with a stub
#                       `uname`. A refused case must print the site's reason
#                       and must not run the file: each planted file writes a
#                       marker when it runs, so "refused" is proved by the
#                       marker's absence, never by the message alone.
#   SAME                the arm is one text at every site, after each site's
#                       variable prefix and its refusal form are normalised.
#   SITES               every file under plugins/ that lists the Orca cli names
#                       is a site below, so a new script with the old check
#                       turns this red.
#
# SITES: the seven scripts, and the two blocks of the autonomy skill, each
# extracted and run as it ships. Every Orca call reaches a stub: the run's PATH
# holds only the stub directory and system tools, and no ORCA_ variable of the
# calling session is passed on. Nothing runs a real lane action or the real
# screen reader; `/usr/bin/orca` is a case only as a refused path.
#
# `--site <name>` runs only that site's CASE legs (the controls use it).
# CEPA_CLI_PATH_ROOT reads the sites from another tree (the controls' mutants).
#
# STATED LIMITS: the good paths come from Orca 1.4.249's installed code and
# punch-list L81, not from a run on a Linux Orca host. A planted launcher is a
# stub of the same shape.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }
exec python3 - "$@" <<'PY'
import os, re, shutil, stat, subprocess, sys, tempfile, textwrap

ROOT = os.environ.get("CEPA_CLI_PATH_ROOT") or os.getcwd()
only = None
if sys.argv[1:2] == ["--site"] and len(sys.argv) == 3:
    only = sys.argv[2]
elif sys.argv[1:]:
    print("MISS usage: check-orca-cli-path.sh [--site <name>]"); sys.exit(1)

H = "term_11111111-2222-3333-4444-555555555555"
SCRIPT_REASONS = ("an orca path on Linux is not an Orca launcher", "bare orca on Linux is the screen reader")
DETECT_REASONS = ("ORCA_CLI_COMMAND is not an Orca launcher", "ORCA_CLI_COMMAND names bare orca on Linux")
failed = passed = 0


def miss(name):
    global failed
    failed += 1
    print("MISS " + name)


def script(name):
    return os.path.join(ROOT, "plugins/cepa/scripts/orca-%s.sh" % name)


def stdin_site(name, text):
    return lambda w, cli: ([script(name)], text % cli)


def send_site(w, cli):
    p = os.path.join(w.scratch, "cepa-send-t.txt")
    open(p, "w").write("subject\nbody\n")
    return [script("send")], "cli: %s\ntarget: %s\ntype: status\nnudge: no-nudge\nfile: %s\n" % (cli, H, p)


def skill_text():
    return open(os.path.join(ROOT, "plugins/cepa/skills/autonomy/SKILL.md")).read()


def detect_site(w, cli):
    m = re.search(r"^### 12a\..*?^```bash\n(.*?)^```$", skill_text(), re.M | re.S)
    p = os.path.join(w.scratch, "detect.sh")
    open(p, "w").write(m.group(1))
    return ["/bin/bash", "-e", p], ""


def title_site(w, cli):
    m = re.search(r"^     ```bash\n(     cepa_title_name=.*?)^     ```$", skill_text(), re.M | re.S)
    t = textwrap.dedent(m.group(1)).replace("<session>@<wt>", "tab1@wt", 1).replace("<handle-or-self>", "self", 1)
    p = os.path.join(w.scratch, "title.sh")
    open(p, "w").write(t.replace("\n<cli>\n", "\n%s\n" % cli, 1))
    return ["/bin/bash", "-e", p], ""


SITES = {
    "attention": (stdin_site("attention", "cli: %s\naction: clear\n"), SCRIPT_REASONS),
    "health": (lambda w, cli: ([script("health"), cli], ""), SCRIPT_REASONS),
    "lane": (stdin_site("lane", "cli: %s\naction: name\n"), SCRIPT_REASONS),
    "nudge": (lambda w, cli: ([script("nudge"), cli, H], ""), SCRIPT_REASONS),
    "outbox": (lambda w, cli: ([script("outbox"), cli, "show"], ""), SCRIPT_REASONS),
    "rebind": (stdin_site("rebind", "cli: %s\n"), SCRIPT_REASONS),
    "send": (send_site, SCRIPT_REASONS),
    "detect": (detect_site, DETECT_REASONS),
    "title": (title_site, SCRIPT_REASONS),
}


class World:
    def __init__(self):
        self.d = os.path.realpath(tempfile.mkdtemp(prefix="cepa-clipath-"))
        self.repo = os.path.join(self.d, "repo")
        self.scratch = os.path.join(self.d, "scratch")
        self.bin = os.path.join(self.d, "bin")
        self.marks = os.path.join(self.d, "marks")
        for p in (self.repo, self.scratch, self.bin, self.marks):
            os.makedirs(p)
        env = dict(os.environ, GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1")
        for a in (["init", "-q", self.repo],
                  ["-C", self.repo, "-c", "user.name=c", "-c", "user.email=c@c", "commit", "-q", "--allow-empty", "-m", "c"]):
            subprocess.run(["git"] + a, capture_output=True, check=True, env=env)
        self.write(os.path.join(self.bin, "gh"), "#!/bin/sh\nexit 1\n")
        self.write(os.path.join(self.bin, "orca-ide"), "#!/bin/sh\nexit 1\n")
        self.bash(os.path.join(self.bin, "orca"), "bare")

    def write(self, p, text):
        os.makedirs(os.path.dirname(p), exist_ok=True)
        open(p, "w").write(text)
        os.chmod(p, 0o755)

    def mark(self, tag):
        return os.path.join(self.marks, tag)

    def bash(self, p, tag, line="#!/usr/bin/env bash"):
        self.write(p, "%s\n: >%s\necho '{\"ok\": true, \"result\": {}}'\n" % (line, self.mark(tag)))

    def python(self, p, tag):
        self.write(p, "#!/usr/bin/env python3\nopen(%r, 'w').close()\nprint('{\"ok\": true, \"result\": {}}')\n" % self.mark(tag))

    def uname(self, sysname):
        self.write(os.path.join(self.bin, "uname"), "#!/bin/sh\necho %s\n" % sysname if sysname else "#!/bin/sh\nexit 1\n")

    def run(self, site, cli, env_cli):
        argv, text = SITES[site][0](self, cli)
        e = {"PATH": self.bin + ":/usr/bin:/bin", "HOME": self.d, "TMPDIR": self.scratch, "LANG": "C.UTF-8",
             "ORCA_TERMINAL_HANDLE": H, "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1",
             "CEPA_ORCA_ALERT_DIR": os.path.join(self.d, "alerts"), "CEPA_ORCA_OUTBOX_DIR": os.path.join(self.d, "outbox"),
             "XDG_STATE_HOME": os.path.join(self.d, "state"), "ORCA_CLI_COMMAND": env_cli}
        if argv[0] != "/bin/bash":
            argv = ["/bin/bash"] + argv
        try:
            r = subprocess.run(argv, input=text, env=e, cwd=self.repo, capture_output=True, text=True, timeout=5)
        except subprocess.TimeoutExpired:
            return None
        return r.stdout + r.stderr


def good_shim(w):
    p = os.path.join(w.d, ".config/orca/linux-orca-cli-shim/orca")
    w.bash(p, "shim")
    return p


def good_serve(w):
    p = os.path.join(w.d, ".config/orca/cli/bin/orca")
    w.bash(p, "serve", "#!/usr/bin/env sh")
    return p


def usr_bin(w):
    return "/usr/bin/orca"


def dispatcher(w):
    p = os.path.join(w.d, ".local/bin/orca")
    w.bash(p, "dispatcher")
    return p


def python_at_shim(w):
    p = os.path.join(w.d, "py/linux-orca-cli-shim/orca")
    w.python(p, "python-shim")
    return p


def python_at_serve(w):
    p = os.path.join(w.d, "py/cli/bin/orca")
    w.python(p, "python-serve")
    return p


def symlink_to_reader(w):
    real = os.path.join(w.d, "reader/orca")
    w.python(real, "symlink")
    p = os.path.join(w.d, "sl/cli/bin/orca")
    os.makedirs(os.path.dirname(p))
    os.symlink(real, p)
    return p


def shadowed_dir(w):
    real = os.path.join(w.d, "system/orca")
    w.python(real, "shadow")
    os.makedirs(os.path.join(w.d, "sh/cli"))
    os.symlink(os.path.join(w.d, "system"), os.path.join(w.d, "sh/cli/bin"))
    return os.path.join(w.d, "sh/cli/bin/orca")


def fifo_at_path(w):
    p = os.path.join(w.d, "ff/linux-orca-cli-shim/orca")
    os.makedirs(os.path.dirname(p))
    os.mkfifo(p)
    return p


def dir_at_path(w):
    p = os.path.join(w.d, "dd/cli/bin/orca")
    os.makedirs(p)
    return p


def empty_at_path(w):
    p = os.path.join(w.d, "em/cli/bin/orca")
    w.write(p, "")
    return p


def darwin_path(w):
    p = os.path.join(w.d, "Applications/orca")
    w.bash(p, "darwin")
    return p


# (name, uname, cli maker, 0 pass | 1 path refused | 2 bare refused)
CASES = [
    ("shim path passes", "Linux", good_shim, 0),
    ("serve path passes", "Linux", good_serve, 0),
    ("/usr/bin/orca refused", "Linux", usr_bin, 1),
    ("dispatcher path refused", "Linux", dispatcher, 1),
    ("python at shim path refused", "Linux", python_at_shim, 1),
    ("python at serve path refused", "Linux", python_at_serve, 1),
    ("symlink to a python file refused", "Linux", symlink_to_reader, 1),
    ("shadowed directory refused", "Linux", shadowed_dir, 1),
    ("fifo at a good path refused, no hang", "Linux", fifo_at_path, 1),
    ("directory at a good path refused", "Linux", dir_at_path, 1),
    ("empty file at a good path refused", "Linux", empty_at_path, 1),
    ("bare orca refused", "Linux", lambda w: "orca", 2),
    ("any path passes off Linux", "Darwin", darwin_path, 0),
    ("bare orca passes off Linux", "Darwin", lambda w: "orca", 0),
    ("failed uname reads as Linux, bare refused", None, lambda w: "orca", 2),
    ("failed uname reads as Linux, good path passes", None, good_shim, 0),
]

for site in SITES:
    if only and site != only:
        continue
    for name, sysname, make, want in CASES:
        w = World()
        try:
            w.uname(sysname)
            cli = make(w)
            out = w.run(site, cli, cli)
            label = "CASE %s %s" % (site, name)
            if out is None:
                miss(label + ": still running after 5s")
                continue
            ran = sorted(os.listdir(w.marks))
            reasons = SITES[site][1]
            bad = []
            if want and reasons[want - 1] not in out:
                bad.append("no refusal in %r" % out[:200])
            if want and ran:
                bad.append("ran %s" % ran)
            if not want and any(x in out for x in reasons):
                bad.append("refused: %r" % out[:200])
            # outbox `show` reads only local files, so it calls no Orca.
            if not want and site != "outbox" and not ran:
                bad.append("passed but never ran the launcher: %r" % out[:200])
            if bad:
                miss("%s: %s" % (label, "; ".join(bad)))
            else:
                passed += 1
        finally:
            shutil.rmtree(w.d, ignore_errors=True)

if not only:
    def arm(text, name):
        m = re.search(r"^( *)orca\) \[ .*? != Linux \] \|\| case .*?^\1esac ;;$", text, re.M | re.S)
        if not m:
            miss("SAME no Linux arm in %s" % name)
            return None
        t = textwrap.dedent(m.group(0))
        t = re.sub(r'"\$\(uname -s 2>/dev/null \|\| echo Linux\)"|"\$cepa_orca_os"', "OS", t)
        t = re.sub(r"cepa_[a-z]+_(cli|l)\b", r"\1", t)
        t = re.sub(r'refuse "[^"\n]*"|cepa_[a-z]+_why="[^"\n]*"', "REFUSE", t)
        return t

    arms = {}
    for n in ("attention", "health", "lane", "nudge", "outbox", "rebind", "send"):
        arms[n] = arm(open(script(n)).read(), n)
    s = skill_text()
    i = s.index("### 12a.")
    j = s.index("cepa_title_cli=$(cat")
    arms["detect"] = arm(s[i:j], "detect")
    arms["title"] = arm(s[j:], "title")
    if len(set(arms.values())) != 1:
        first = arms["health"]
        miss("SAME the arm differs at: %s" % ", ".join(sorted(k for k, v in arms.items() if v != first)))
    else:
        passed += 1
    tree = os.path.join(ROOT, "plugins")
    found = set()
    for d, _, names in os.walk(tree):
        for n in names:
            p = os.path.join(d, n)
            try:
                text = open(p, encoding="utf-8", errors="replace").read()
                if re.search(r"orca-(ide|dev)\s*\|\s*orca-(ide|dev)\s*\)", text):
                    found.add(os.path.relpath(p, ROOT))
            except OSError:
                pass
    want_files = {"plugins/cepa/scripts/orca-%s.sh" % n for n in
                  ("attention", "health", "lane", "nudge", "outbox", "rebind", "send")} | {"plugins/cepa/skills/autonomy/SKILL.md"}
    if found != want_files:
        miss("SITES files differ: %s" % sorted(found ^ want_files))
    else:
        passed += 1

print("check-orca-cli-path: %d passed, %d MISS" % (passed, failed))
sys.exit(1 if failed else 0)
PY
