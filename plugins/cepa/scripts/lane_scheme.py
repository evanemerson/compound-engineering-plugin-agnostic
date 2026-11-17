#!/usr/bin/env python3
"""cepa lane & stack scheme check — read-only (punch-list L67).

/cepa:setup's check of one repo against the `cepa:lane-stack` skill. The skill
owns the contract; `stack-gate.sh` owns the gate. This file only probes for
them, so read the skill for what each fact means. Scope is design
"Plan-review decisions" #20: the `orca.yaml` contract, the `-wt-` compose
project name, the gated start targets and stop-after-setup. The skill's other
worktree properties are guidance and are not checked here.

Usage: python3 lane_scheme.py [<repo root>]     (default: the current dir)
  Prints one fact per line, the same shape as check-health.sh:
    OK   lane:<key> — <fact>
    MISS lane:<key> — <gap>
    INFO lane:<key> — <fact, or NOT CHECKED and why>
  Exit 0 always: it reports facts; /cepa:setup classifies them.
  Imported by scripts/check-lane-stack.sh (ORCA_KEYS, load_orca_yaml), so the
  skill's own orca.yaml example and every repo's file go through one parser.

POPULATION (what it reads): the repo root's `orca.yaml`, `.worktreeinclude`,
`Makefile` (or `makefile`, `GNUmakefile`), `CLAUDE.md`, the root compose
files (`docker-compose*.yml`, `compose*.yml`), and the "setup closure": the
Makefile targets `scripts.setup` runs, their prerequisites, the targets their
recipes run with `make`, and the repo scripts (`*.sh`, `*.py`) those recipes
name. Makefile variables, `define` blocks and `$(call …)` are expanded.

NON-POPULATION (what it cannot see — each is a stated limit):
  - contract item 5 (Orca's saved hook settings): Orca state, not a file.
    `orca-lane.sh create` refuses a shadow (its header, H1).
  - files a Makefile `include`s; scripts that a script calls; a target run
    only from a script.
  - start sites inside scripts: a script is searched only for the gate's name,
    `-wt-`, a compose stop and `timeout`. Start sites are Makefile recipes.
  - order: "setup ends by stopping its stack" is checked as "the setup
    closure runs a compose stop", not that the stop is last.
  - the gated-start verdict is textual. A start target counts as gated when
    its expanded recipe names the gate (`stack-gate`, `STACK_GATE`), as
    refusing in a lane when it carries a refusal marker (REFUSAL_RE), or as
    run under the gate when a gated recipe runs it with `make`. A marker in
    a branch that does not guard the start still reads as OK; /cepa:setup
    reads the line.
  - `compose run` is not a start site here (#20 names up, start, restart).
  - per-branch `worktree.sharedDirectories` names are the PER_BRANCH list.
"""
import glob, os, re, subprocess, sys

# The top-level keys Orca 1.4.245's parser reads (lane-stack skill, "The
# `orca.yaml` contract"). scripts/check-lane-stack.sh imports this set.
ORCA_KEYS = frozenset({"scripts", "setupAgentStartupPolicy", "issueCommand",
                       "defaultTabs", "environmentRecipes", "worktree"})
POLICY_VALUES = ("wait-for-setup", "start-immediately")
PER_BRANCH = re.compile(r"^(node_modules|\.venv|venv|dist|build|\.next|\.astro|out|target|\.env(\..+)?)/?$")
GATE_RE = re.compile(r"stack[-_]gate", re.I)
REFUSAL_RE = re.compile(r"refus|main[-_]only|require-main|is-main|not run in a lane", re.I)
OTHER_STACK_TARGET = re.compile(r"(^|[-_])(prod|proxy)([-_]|$)")
OTHER_STACK_FILE = re.compile(r"prod|proxy|traefik", re.I)
COMPOSE_RE = r"(?:\bdocker[ -]compose\b)"
START_VERBS = ("up", "start", "restart")
VALUE_FLAGS = {"-f", "--file", "-p", "--project-name", "--profile", "--env-file",
               "--project-directory", "--ansi", "--progress", "--parallel"}
SEP = re.compile(r"\s*(?:;|&&|\|\||\||\bthen\b|\bdo\b|\belse\b)\s*")


class YamlUnavailable(Exception):
    pass


def load_orca_yaml(text):
    """Parse orca.yaml as Orca does: invalid YAML or a duplicate key voids the
    whole file. Returns (doc, error); error is None when it parsed."""
    try:
        import yaml
    except ImportError:
        raise YamlUnavailable("python3 cannot import yaml (PyYAML)")

    # A SafeLoader subclass: it adds the duplicate-key refusal and keeps
    # SafeLoader's refusal of every python/* tag.
    class UniqueKeyLoader(yaml.SafeLoader):
        def construct_mapping(self, node, deep=False):
            seen = []
            for knode, _ in node.value:
                key = self.construct_object(knode, deep=deep)
                if key in seen:
                    raise yaml.constructor.ConstructorError(
                        None, None, "duplicate key %r" % (key,), knode.start_mark)
                seen.append(key)
            return super().construct_mapping(node, deep)

    try:
        doc = yaml.load(text, Loader=UniqueKeyLoader)
    except yaml.YAMLError as e:
        return None, " ".join(str(e).split())[:160]
    if not isinstance(doc, dict):
        return None, "the file is not a mapping"
    return doc, None


# --- Makefile -----------------------------------------------------------------

def _match_close(s, i):
    """s[i] is '(' or '{'; return the index of its partner, or -1."""
    depth = 0
    for j in range(i, len(s)):
        if s[j] in "({":
            depth += 1
        elif s[j] in ")}":
            depth -= 1
            if depth == 0:
                return j
    return -1


def _split_top(s, sep=","):
    out, depth, cur = [], 0, []
    for ch in s:
        if ch in "({":
            depth += 1
        elif ch in ")}":
            depth -= 1
        if ch == sep and depth == 0:
            out.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    out.append("".join(cur))
    return out


class Makefile:
    VAR = re.compile(r"^(?:export\s+|override\s+)?([A-Za-z_][A-Za-z0-9_.-]*)\s*(\?=|::=|:=|\+=|!=|=)\s*(.*)$")
    RULE = re.compile(r"^([^\s:=#][^:=#]*?)\s*::?(?!=)\s*(.*)$")

    def __init__(self, text):
        self.vars, self.targets = {}, {}
        lines = text.split("\n")
        i, cur = 0, None
        while i < len(lines):
            raw, lineno = lines[i], i + 1
            # join continuations into one logical line
            while raw.endswith("\\") and i + 1 < len(lines):
                i += 1
                raw = raw + "\n" + lines[i]
            i += 1
            if raw.startswith("\t"):
                if cur is not None:
                    cur["recipe"].append((lineno, raw[1:]))
                continue
            stripped = raw.strip()
            if not stripped or stripped.startswith("#"):
                continue
            m = re.match(r"^define\s+([A-Za-z_][A-Za-z0-9_.-]*)", stripped)
            if m:
                body = []
                while i < len(lines) and lines[i].strip() != "endef":
                    body.append(lines[i])
                    i += 1
                i += 1
                self.vars[m.group(1)] = "\n".join(body)
                cur = None
                continue
            m = self.VAR.match(stripped)
            if m:
                name, op, val = m.groups()
                val = val.replace("\\\n", " ")
                self.vars[name] = (self.vars.get(name, "") + " " + val) if op == "+=" else val
                cur = None
                continue
            m = self.RULE.match(stripped)
            if m and not stripped.startswith(("ifeq", "ifneq", "ifdef", "ifndef", "else", "endif", "include", "-include")):
                names, rest = m.group(1).split(), m.group(2)
                help_text = rest.split("##", 1)[1].strip() if "##" in rest else ""
                rest = rest.split("#", 1)[0]
                inline = None
                if ";" in rest:
                    rest, inline = rest.split(";", 1)
                if "=" in rest:          # target-specific variable
                    cur = None
                    continue
                cur = {"line": lineno, "prereqs": rest.split(), "help": help_text, "recipe": []}
                if inline and inline.strip():
                    cur["recipe"].append((lineno, inline.strip()))
                for n in names:
                    if not n.startswith("."):
                        self.targets.setdefault(n, cur)
                continue
            cur = None

    def expand(self, s, args=None, depth=0):
        if depth > 12:
            return s
        out, i = [], 0
        while i < len(s):
            c = s[i]
            if c == "$" and i + 1 < len(s):
                n = s[i + 1]
                if n == "$":
                    out.append("$$")
                    i += 2
                    continue
                if n in "({":
                    j = _match_close(s, i + 1)
                    if j < 0:
                        out.append(s[i:])
                        break
                    out.append(self._ref(s[i + 2:j], args, depth))
                    i = j + 1
                    continue
            out.append(c)
            i += 1
        return "".join(out)

    def _ref(self, inner, args, depth):
        if args is not None and inner.isdigit():
            k = int(inner) - 1
            return args[k] if 0 <= k < len(args) else ""
        if inner.startswith("call "):
            parts = _split_top(inner[5:])
            name = self.expand(parts[0].strip(), args, depth + 1)
            if name not in self.vars:
                return "$(" + self.expand(inner, args, depth + 1) + ")"
            a = [self.expand(p, args, depth + 1) for p in parts[1:]]
            return self.expand(self.vars[name], a, depth + 1)
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_.-]*", inner) and inner in self.vars:
            return self.expand(self.vars[inner], args, depth + 1)
        return "$(" + self.expand(inner, args, depth + 1) + ")"

    def recipe(self, target):
        t = self.targets.get(target)
        if not t:
            return ""
        return "\n".join(self.expand(l) for _, l in t["recipe"])


# --- text helpers ---------------------------------------------------------------

MSG_RE = re.compile(r"""\b(echo|die|warn|fail|error|info|log)\s+("(?:[^"\\]|\\.)*"|'[^']*')""")
NOOP_RE = re.compile(r"""(^|[;&|]\s*|\s):\s+("(?:[^"\\]|\\.)*"|'[^']*')""")


def code_of(text):
    """Text with comment lines removed and message strings blanked, so a word
    inside an `echo` or a comment never counts as code."""
    out = []
    for line in text.replace("\\\n", " ").split("\n"):
        if re.match(r"^\s*[@+-]*\s*#", line):
            continue
        line = MSG_RE.sub(r'\1 ""', line)
        line = NOOP_RE.sub(r'\1: ""', line)
        out.append(line)
    return "\n".join(out)


def compose_aliases(code):
    """Shell functions whose body runs docker compose (`dc() { docker compose …; }`)."""
    names = set()
    lines = code.split("\n")
    for k, line in enumerate(lines):
        m = re.match(r"^\s*(?:function\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{(.*)$", line)
        if not m:
            continue
        body = m.group(2)
        if "}" not in body:
            for nxt in lines[k + 1:k + 40]:
                if re.match(r"^\s*\}\s*;?\s*$", nxt):
                    break
                body += "\n" + nxt
        if re.search(COMPOSE_RE, body):
            names.add(m.group(1))
    return names


def compose_segments(code, aliases=()):
    """Yield (head, tokens) for each command segment that calls compose; tokens
    are the words after the compose call, up to the segment's end."""
    alias = "|".join(re.escape(a) for a in sorted(aliases))
    pat = re.compile(COMPOSE_RE + (r"|(?:(?<![\w$-])(?:%s)\b)" % alias if alias else ""))
    for line in code.split("\n"):
        for seg in SEP.split(line):
            m = pat.search(seg)
            if m:
                yield m.group(0), seg[m.end():].split()


def compose_verb(tokens):
    """The compose verb and the -f files, skipping global flags."""
    files, k = [], 0
    while k < len(tokens):
        t = tokens[k].strip("\"'")
        if t in VALUE_FLAGS:
            if t in ("-f", "--file") and k + 1 < len(tokens):
                files.append(tokens[k + 1].strip("\"'"))
            if t in ("-p", "--project-name") and k + 1 < len(tokens):
                files.append("-p " + tokens[k + 1].strip("\"'"))
            k += 2
            continue
        if t.startswith("-"):
            if t.startswith(("--file=", "-f=")):
                files.append(t.split("=", 1)[1])
            k += 1
            continue
        return t, files
    return "", files


def make_targets_in(code):
    """Targets a recipe or command runs with `make` / `$(MAKE)`."""
    found = []
    for m in re.finditer(r"(?:^|[\s;&|(\"'])(?:make|\$\(MAKE\)|\$\{MAKE\})((?:[ \t]+[^\s;&|]+)*)", code):
        toks, skip, depth = m.group(1).split(), False, 0
        for t in toks:
            if skip or depth > 0:
                # a flag's value; `$(lastword $(MAKEFILE_LIST))` spans tokens
                depth += t.count("(") - t.count(")")
                skip = False
                continue
            while t.endswith(")") and t.count(")") > t.count("("):
                t = t[:-1]          # the end of a `$( … )` or `( … )` around the call
            t = t.strip("\"'")
            if t in ("-f", "-C", "--file", "--directory", "-o", "-W"):
                skip = True
                continue
            if t.startswith("-") or "=" in t:
                continue
            if re.fullmatch(r"[A-Za-z0-9_.-]+", t):
                found.append(t)
            else:
                break
    return found


def script_paths_in(code, root):
    out = []
    for m in re.finditer(r"""[\w./${}()-]*[\w-]\.(?:sh|py|bash)\b""", code):
        p = m.group(0).strip("\"'")
        if p.startswith("./"):
            p = p[2:]
        if "$" in p or p.startswith("/"):
            continue
        full = os.path.realpath(os.path.join(root, p))
        if full.startswith(os.path.realpath(root) + os.sep) and os.path.isfile(full) and p not in out:
            out.append(p)
    return out


def bare_timeouts(code):
    bad = []
    for line in code.split("\n"):
        for seg in SEP.split(line):
            if re.search(r"(?:^|[\s(])timeout\s", seg) and "--foreground" not in seg \
                    and not (re.search(r"(?:^|\s)-T(?:\s|$)", seg) and "</dev/null" in seg.replace(" ", "")):
                bad.append(" ".join(seg.split())[:100])
    return bad


# --- the check ------------------------------------------------------------------

class Report:
    def __init__(self):
        self.rows = []

    def add(self, status, key, text):
        self.rows.append((status, key, text))
        print("%-4s lane:%s — %s" % (status, key, text))


def read(path):
    """(text, error). A file that exists but cannot be read is an error, never
    an absence."""
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read(), None
    except OSError as e:
        return None, str(e)


def repo_name(root):
    try:
        cd = subprocess.run(["git", "-C", root, "rev-parse", "--path-format=absolute", "--git-common-dir"],
                            capture_output=True, text=True, timeout=10).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        cd = ""
    return os.path.basename(os.path.dirname(cd)) if cd else os.path.basename(os.path.realpath(root))


def check(root):
    r = Report()
    name = repo_name(root)
    if name == "farmtender":
        r.add("INFO", "kind", "farmtender is out of the lane scheme's scope (lane-stack skill) — not checked")
        return r
    yml = os.path.join(root, "orca.yaml")
    if not os.path.exists(yml):
        r.add("INFO", "orca-yaml", "no orca.yaml — this repo is not on the lane scheme; a repo coordinated under Orca needs one (lane-stack skill)")
        return r
    composes = sorted(os.path.basename(p) for p in glob.glob(os.path.join(root, "*compose*.y*ml"))
                      if re.fullmatch(r"(docker-)?compose[\w.-]*\.ya?ml", os.path.basename(p)))
    docker = bool(composes)
    r.add("INFO", "kind", ("Docker repo (compose: %s)" % " ".join(composes)) if docker
          else "non-Docker repo (no root compose file): orca.yaml contract only")

    # -- orca.yaml contract
    text, err = read(yml)
    doc = None
    if err:
        r.add("MISS", "yaml-parse", "orca.yaml is unreadable: %s" % err)
    else:
        try:
            doc, perr = load_orca_yaml(text)
        except YamlUnavailable as e:
            doc, perr = None, None
            r.add("INFO", "yaml-parse", "orca.yaml NOT CHECKED — %s" % e)
        if perr:
            r.add("MISS", "yaml-parse", "Orca ignores the whole file: %s" % perr)
        elif doc is not None:
            r.add("OK", "yaml-parse", "orca.yaml parses, no duplicate key")
    setup_cmd = ""
    if doc is not None:
        extra = sorted(str(k) for k in set(doc) - ORCA_KEYS)
        if extra:
            r.add("INFO", "yaml-keys", "top-level keys Orca does not read (ignored, not fatal): %s" % ", ".join(extra))
        sc = doc.get("scripts") if isinstance(doc.get("scripts"), dict) else {}
        setup, archive = sc.get("setup"), sc.get("archive")
        if setup is not None and not isinstance(setup, str):
            r.add("MISS", "setup", "scripts.setup is not a string")
            setup = None
        setup_cmd = (setup or "").strip()
        if docker:
            r.add("OK" if setup_cmd else "MISS", "setup",
                  "scripts.setup runs: %s" % " ".join(setup_cmd.split())[:120] if setup_cmd
                  else "a Docker repo needs scripts.setup (contract item 1)")
            r.add("OK" if str(archive or "").strip() else "MISS", "archive",
                  "scripts.archive present" if str(archive or "").strip()
                  else "a Docker repo needs scripts.archive (contract item 2)")
        else:
            r.add("INFO", "setup", "scripts.setup %s" % ("present" if setup_cmd else "absent (fine when a fresh lane needs nothing installed)"))
            r.add("MISS" if str(archive or "").strip() else "OK", "archive",
                  "a non-Docker repo has no scripts.archive (contract item 2)" if str(archive or "").strip()
                  else "no scripts.archive")
        pol = doc.get("setupAgentStartupPolicy")
        if pol is not None and pol not in POLICY_VALUES:
            r.add("MISS", "policy", "setupAgentStartupPolicy %r is not a value Orca accepts; Orca drops it silently" % (pol,))
        elif setup_cmd:
            r.add("OK" if pol == "wait-for-setup" else "MISS", "policy",
                  "setupAgentStartupPolicy: wait-for-setup" if pol == "wait-for-setup"
                  else "scripts.setup exists, so setupAgentStartupPolicy must be wait-for-setup (contract item 3); it is %r" % (pol,))
        elif pol is not None:
            r.add("INFO", "policy", "setupAgentStartupPolicy set with no scripts.setup: it orders nothing")
        wt = doc.get("worktree") if isinstance(doc.get("worktree"), dict) else {}
        shared = wt.get("sharedDirectories") or []
        shared = shared if isinstance(shared, list) else [shared]
        bad = [str(s) for s in shared if PER_BRANCH.match(str(s).strip())]
        r.add("MISS" if bad else "OK", "shared-dirs",
              "worktree.sharedDirectories holds per-branch state: %s (contract item 4)" % ", ".join(bad) if bad
              else "no worktree.sharedDirectories entry holds per-branch state")
    if os.path.lexists(os.path.join(root, ".worktreeinclude")):
        r.add("MISS", "worktreeinclude", ".worktreeinclude exists — remove it (contract item 4)")
    else:
        r.add("OK", "worktreeinclude", "no .worktreeinclude")
    r.add("INFO", "hook-shadow", "contract item 5 NOT CHECKED here (Orca state, not a file): `orca-lane.sh create` refuses a shadow (its header, H1)")

    # -- Makefile
    mk, mk_path, mtext = None, None, ""
    for n in ("GNUmakefile", "makefile", "Makefile"):
        if os.path.exists(os.path.join(root, n)):
            mk_path = n
    if mk_path:
        mtext, merr = read(os.path.join(root, mk_path))
        if merr:
            r.add("MISS", "makefile", "%s is unreadable: %s" % (mk_path, merr))
        else:
            mk = Makefile(mtext)

    # -- contract item 6: `make worktree branch=` is never an entry point
    bad = []
    for fname, body in (("orca.yaml", text or ""), (mk_path or "", mtext if mk else ""),
                        ("CLAUDE.md", read(os.path.join(root, "CLAUDE.md"))[0] or "")):
        for m in re.finditer(r"make\s+worktree\s+branch=", body):
            win = body[max(0, m.start() - 120): m.end() + 120]
            if not re.search(r"\b(not|never|forbidden|fallback)\b|orca-lane\.sh", win, re.I):
                bad.append("%s:%d" % (fname, body.count("\n", 0, m.start()) + 1))
    if mk and "worktree" in mk.targets and mk.targets["worktree"]["help"] \
            and "orca-lane" not in mk.targets["worktree"]["help"]:
        bad.append("%s:%d (the `worktree` help line does not name orca-lane.sh create)" % (mk_path, mk.targets["worktree"]["line"]))
    r.add("MISS" if bad else "OK", "entry",
          "`make worktree branch=` named as an entry point: %s (contract item 6)" % ", ".join(bad) if bad
          else "`make worktree branch=` is never named as an entry point")

    # -- setup closure
    texts = [("orca.yaml", setup_cmd)] if setup_cmd else []
    unresolved = []
    if setup_cmd:
        queue, seen = list(make_targets_in(code_of(setup_cmd))), set()
        scripts = script_paths_in(code_of(setup_cmd), root)
        while queue:
            t = queue.pop(0)
            if t in seen:
                continue
            seen.add(t)
            if not mk or t not in mk.targets:
                if not (mk and t in [p for v in mk.targets.values() for p in v["prereqs"]]):
                    unresolved.append(t)
                continue
            rec = code_of(mk.recipe(t))
            texts.append(("%s:%s" % (mk_path, t), rec))
            queue += mk.targets[t]["prereqs"] + make_targets_in(rec)
            scripts += [s for s in script_paths_in(rec, root) if s not in scripts]
        for s in scripts:
            body, serr = read(os.path.join(root, s))
            if serr:
                r.add("MISS", "setup-closure", "setup runs %s, which is unreadable: %s" % (s, serr))
            else:
                texts.append((s, code_of(body)))
        reached = ", ".join(lbl for lbl, _ in texts[1:]) or "orca.yaml's own command only"
        if unresolved:
            r.add("MISS", "setup-closure", "scripts.setup runs make target(s) with no rule in %s: %s" % (mk_path or "a Makefile (none found)", ", ".join(unresolved)))
        r.add("INFO", "setup-closure", "setup reaches: %s" % reached)
    closure = "\n".join(t for _, t in texts)

    bare = bare_timeouts(closure)
    r.add("MISS" if bare else "OK", "timeout",
          "setup runs `timeout` without --foreground or `-T </dev/null`: %s (contract item 7)" % " | ".join(bare[:3]) if bare
          else "no bare `timeout` in what setup runs")

    if not docker:
        return r

    # -- Docker repo: -wt- name, gate in setup, stop after setup
    if len(texts) <= 1:
        r.add("MISS", "setup-closure", "scripts.setup reaches no Makefile target or repo script this check can read, so -wt-, gate and stop are NOT CHECKED")
    else:
        r.add("OK" if "-wt-" in closure else "MISS", "wt-name",
              "setup names its compose project with -wt-" if "-wt-" in closure
              else "no -wt- in what setup runs: the gate cannot count this lane's stack")
        r.add("OK" if GATE_RE.search(closure) else "MISS", "setup-gate",
              "setup calls the stack gate" if GATE_RE.search(closure)
              else "setup never names stack-gate.sh (skill, Setup step 3)")
        aliases = set()
        for _, t in texts:
            aliases |= compose_aliases(t)
        stops = any("stop" in [x.strip("\"';") for x in toks]
                    for _, t in texts for _, toks in compose_segments(t, aliases))
        r.add("OK" if stops else "MISS", "stop",
              "setup runs a compose stop" if stops else "setup never runs a compose stop (skill, Setup step 5)")

    if not mk:
        r.add("MISS", "make-up", "a Docker repo needs a Makefile with a gated `make up` (none %s)" % ("readable" if mk_path else "found"))
        return r
    if "up" not in mk.targets:
        r.add("MISS", "make-up", "%s has no `up` target (the gated start target)" % mk_path)
    else:
        rec = code_of(mk.recipe("up"))
        via = [s for s in script_paths_in(rec, root) if GATE_RE.search(code_of(read(os.path.join(root, s))[0] or ""))]
        ok = bool(GATE_RE.search(rec)) or bool(via)
        r.add("OK" if ok else "MISS", "make-up",
              ("`make up` starts through the gate%s" % (" (via %s)" % ", ".join(via) if via and not GATE_RE.search(rec) else ""))
              if ok else "`make up` (%s:%d) never names the gate" % (mk_path, mk.targets["up"]["line"]))

    # -- gated start targets
    gated_callers = {}
    for t in mk.targets:
        rec = code_of(mk.recipe(t))
        if GATE_RE.search(rec):
            for callee in make_targets_in(rec):
                gated_callers.setdefault(callee, t)
    seen_ids = set()
    for t, info in sorted(mk.targets.items(), key=lambda kv: kv[1]["line"]):
        if id(info) in seen_ids:
            continue
        seen_ids.add(id(info))
        raw = code_of("\n".join(l for _, l in info["recipe"]))   # unexpanded: macro names count
        rec = code_of(mk.recipe(t))
        sites = []
        for _, toks in compose_segments(rec):
            verb, files = compose_verb(toks)
            if verb in START_VERBS:
                sites.append((verb, files))
        if not sites:
            continue
        verbs = "/".join(sorted({v for v, _ in sites}))
        where = "%s:%d" % (mk_path, info["line"])
        if OTHER_STACK_TARGET.search(t) or all(f and all(OTHER_STACK_FILE.search(x) for x in f) for _, f in sites):
            r.add("INFO", "start:" + t, "%s runs compose %s on a production or shared-proxy stack — not a lane stack, not checked" % (where, verbs))
        elif GATE_RE.search(rec):
            r.add("OK", "start:" + t, "%s runs compose %s through the gate" % (where, verbs))
        elif REFUSAL_RE.search(rec) or REFUSAL_RE.search(raw):
            r.add("OK", "start:" + t, "%s runs compose %s behind a lane refusal or a main-only branch (marker: %s)" % (where, verbs, (REFUSAL_RE.search(rec) or REFUSAL_RE.search(raw)).group(0)))
        elif t in gated_callers:
            r.add("OK", "start:" + t, "%s runs compose %s under the gate, from `%s`" % (where, verbs, gated_callers[t]))
        else:
            r.add("MISS", "start:" + t, "%s runs compose %s with no gate and no lane refusal seen — read the recipe" % (where, verbs))
    return r


def main(argv):
    root = os.path.abspath(argv[1] if len(argv) > 1 else ".")
    print("== cepa lane & stack scheme: %s ==" % root)
    check(root)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
