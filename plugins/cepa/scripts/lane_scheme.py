#!/usr/bin/env python3
"""cepa lane & stack scheme check — read-only (punch-list L67).

/cepa:setup's check of one repo against the `cepa:lane-stack` skill. The skill
owns the contract and its scope for this check ("The worktree properties,
updated for Orca"); `stack-gate.sh` owns the gate. This file only probes for
them, so read the skill for what each fact means.

Usage: python3 lane_scheme.py [<repo root>]     (default: the current dir)
  Prints one fact per line, the same shape as check-health.sh:
    OK   lane:<key> — <fact>
    MISS lane:<key> — <gap>
    INFO lane:<key> — <fact, or NOT CHECKED and why>
  Exit 0 unless it crashes: it reports facts; /cepa:setup classifies them.
  check-health.sh bounds it at 60 s and reports a crash or a timeout as MISS.
  Every repo string in a row is put on one line and cut (`one()`), so a value
  holding a newline cannot forge a row. The rows are still repo-derived data:
  /cepa:setup check 8 carries the §7 clause for them.
  Imported by scripts/check-lane-stack.sh (ORCA_KEYS, load_orca_yaml), so the
  skill's own orca.yaml example and every repo's file go through one parser.

POPULATION (what it reads): at the repo root, `cepa.local.md` (only the
`lanes:` key, below); `orca.yaml`; `CLAUDE.md` (for contract item 6 only);
the first of `GNUmakefile`, `makefile`, `Makefile` (make's own order); the compose files named `compose*` or `docker-compose*`
with a .yml or .yaml extension; and whether `.worktreeinclude` exists. A
repo is a Docker repo when it has such a compose file or its Makefile runs
`docker compose`. Then the "setup closure": the Makefile targets
`scripts.setup` runs, their prerequisites, the targets their recipes run
with `make`, and the repo scripts (`*.sh`, `*.bash`, `*.py`) that the setup
command or those recipes name. Makefile variables, `define` blocks and
`$(call …)` are expanded; continuation lines, conditionals inside a recipe
and a target defined in two rules are read as make reads them (both branches
of a conditional count). Only regular files up to MAX_BYTES are read; any
other file is unreadable, never absent.

NON-POPULATION (what it cannot see — each is a stated limit):
  - contract item 5 (Orca's saved hook settings): Orca state, not a file.
    `orca-lane.sh create` refuses a shadow (its header, H1).
  - the opt-out (punch-list L90; CONFIGURATION.md documents the key). This
    header owns what is read. One `lanes:` line (list marker `-`/`*`
    optional, at most 3 spaces in) under a `## Conventions` heading, outside
    fenced code and HTML comments, with the value `none` (any case; quotes,
    backticks and a trailing `# comment` stripped), skips the check with an
    `INFO lane:opted-out` row that carries no repo text. Every other shape
    is checked: a key under another `#`/`##` heading, a second key, another
    value, a `lanes:` line in another form, an unreadable file, an unclosed
    fence or comment, or a repo that also has an `orca.yaml`. Each gets an
    `INFO lane:opt-out` row. A `###` heading stays inside its section. No
    repo name is matched.
  - files a Makefile `include`s; scripts that a script calls; a target run
    only from a script; a compose file outside the repo root unless the
    Makefile runs compose.
  - start sites inside scripts: a script is searched only for the gate's name,
    `-wt-`, a compose stop and `timeout`. Start sites are Makefile recipes.
    `podman compose`, and `docker` global flags before `compose` (`--context`),
    are not compose calls here.
  - order: "setup ends by stopping its stack" is checked as "the setup
    closure runs a compose `stop` verb", not that the stop is last.
  - `-wt-`: any `-wt-` in the setup closure counts, a `case` guard included.
  - the gated-start verdict is textual. A start target counts as gated when
    its expanded recipe names the gate (`stack-gate`, `STACK_GATE`), as
    refusing in a lane when it carries a refusal marker (REFUSAL_RE) outside
    messages and comments, or as run under the gate when a recipe runs it as
    the gate's command (`<gate> <project> -- make <target>`). A marker in a
    branch that does not guard the start still reads as OK; /cepa:setup reads
    the line. A start whose target is named prod/proxy, or whose every -f
    file is a prod/proxy/traefik file, is INFO, not checked.
  - contract item 7: `timeout --foreground` alone passes, by decision L91.
    The skill's item 7 owns which part is the rule and which the advised
    hardening. check-lane-scheme.sh pins the decision with a case.
  - `compose run` is not a start site here (#20 names up, start, restart).
  - per-branch `worktree.sharedDirectories` names are the PER_BRANCH list.
  - `stack-gate.sh --count` is not called: this check is static. The running
    stack count belongs to orca-health.sh (punch-list L61).
"""
import glob, os, re, sys

# The top-level keys Orca 1.4.245's parser reads, measured 2026-11-02 in its
# out/shared/orca-yaml.js (lane-stack skill, "The `orca.yaml` contract").
# A later Orca can add keys; nothing here sees that. scripts/check-lane-stack.sh
# imports this set.
ORCA_KEYS = frozenset({"scripts", "setupAgentStartupPolicy", "issueCommand",
                       "defaultTabs", "environmentRecipes", "worktree"})
POLICY_VALUES = ("wait-for-setup", "start-immediately")
PER_BRANCH = re.compile(r"^(node_modules|\.venv|venv|dist|build|\.next|\.astro|out|target|\.env(\..+)?)/?$")
GATE_RE = re.compile(r"stack[-_]gate", re.I)
REFUSAL_RE = re.compile(r"refus|main[-_]only|require-main|is-main|not run in a lane", re.I)
OTHER_STACK_TARGET = re.compile(r"(^|[-_])(prod|proxy)([-_]|$)")
OTHER_STACK_FILE = re.compile(r"(^|[/._-])(prod|production|proxy|traefik)([/._-]|$)", re.I)
COMPOSE_RE = r"(?:\bdocker[ -]compose\b)"
START_VERBS = ("up", "start", "restart")
VALUE_FLAGS = {"-f", "--file", "-p", "--project-name", "--profile", "--env-file",
               "--project-directory", "--ansi", "--progress", "--parallel"}
MAX_BYTES = 2 * 1024 * 1024
SEP = re.compile(r"\s*(?:;|&&|\|\||\||\bthen\b|\bdo\b|\belse\b)\s*")


class YamlUnavailable(Exception):
    pass


def one(x, n=80):
    """Repo text on one line, cut: a key holding a newline cannot forge a row."""
    return re.sub(r"[\x00-\x1f\x7f]", "?", " ".join(str(x).split()))[:n]


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
                if knode.tag == "tag:yaml.org,2002:merge":   # `<<: *anchor` is not a key
                    continue
                key = self.construct_object(knode, deep=deep)
                if key in seen:
                    raise yaml.constructor.ConstructorError(
                        None, None, "duplicate key %r" % (key,), knode.start_mark)
                seen.append(key)
            return super().construct_mapping(node, deep)

    try:
        doc = yaml.load(text, Loader=UniqueKeyLoader)
    except (yaml.YAMLError, ValueError, OverflowError, RecursionError) as e:
        # ValueError: a scalar PyYAML cannot build (`2023-02-30`); RecursionError:
        # deep nesting. Each is a file this probe cannot read as Orca would.
        return None, one(e, 160)
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

    COND = re.compile(r"^(ifn?eq|ifn?def|else|endif)\b")
    INCLUDE = re.compile(r"^(-?include|sinclude)\b")
    DEFINE = re.compile(r"^(?:override\s+|export\s+)*define\s+([A-Za-z_][A-Za-z0-9_.-]*)\s*(\+=|\?=|:=|::=|=)?\s*$")

    def __init__(self, text):
        self.vars, self.targets, self.notes = {}, {}, []
        self.budget = 200000          # expansion steps; a pathological Makefile stops here
        lines = text.split("\n")
        i, cur = 0, []                # cur: the records the next recipe line belongs to
        while i < len(lines):
            raw, lineno = lines[i], i + 1
            # join continuations into one logical line
            while raw.endswith("\\") and i + 1 < len(lines):
                i += 1
                raw = raw + "\n" + lines[i]
            i += 1
            if raw.startswith("\t"):
                for rec in cur:
                    rec["recipe"].append((lineno, raw[1:]))
                continue
            flat = raw.replace("\\\n", " ").strip()   # one line, for the regexes
            if not flat or flat.startswith("#"):
                continue
            if self.COND.match(flat):     # a conditional keeps the recipe context
                continue
            m = self.DEFINE.match(flat)
            if m:
                body, depth = [], 1
                while i < len(lines):
                    st = lines[i].strip()
                    if self.DEFINE.match(st):
                        depth += 1
                    elif re.match(r"^endef\b", st):
                        depth -= 1
                        if depth == 0:
                            break
                    body.append(lines[i])
                    i += 1
                if i >= len(lines):
                    self.notes.append("define %s at line %d has no endef" % (m.group(1), lineno))
                i += 1
                name, op = m.group(1), m.group(2) or "="
                val = "\n".join(body)
                if op == "+=":
                    val = self.vars.get(name, "") + "\n" + val
                if not (op == "?=" and name in self.vars):
                    self.vars[name] = val
                cur = []
                continue
            m = self.VAR.match(flat)
            if m:
                name, op, val = m.groups()
                if op == "+=":
                    self.vars[name] = self.vars.get(name, "") + " " + val
                elif not (op == "?=" and name in self.vars):
                    self.vars[name] = val
                cur = []
                continue
            m = self.RULE.match(flat)
            if m and not self.INCLUDE.match(flat):
                names, rest = m.group(1).split(), m.group(2)
                help_text = rest.split("##", 1)[1].strip() if "##" in rest else ""
                rest = rest.split("#", 1)[0]
                inline = None
                if ";" in rest:
                    rest, inline = rest.split(";", 1)
                if "=" in rest:          # target-specific variable
                    cur = []
                    continue
                cur, fresh = [], None
                for n in names:
                    if n.startswith("."):
                        continue
                    rec = self.targets.get(n)
                    if rec is None:      # a target defined twice is merged, as make does
                        if fresh is None:
                            fresh = {"line": lineno, "prereqs": [], "help": help_text, "recipe": []}
                        rec = self.targets[n] = fresh
                    if all(rec is not c for c in cur):
                        cur.append(rec)
                for rec in cur:
                    rec["prereqs"] += rest.split()
                    rec["help"] = rec["help"] or help_text
                    if inline and inline.strip():
                        rec["recipe"].append((lineno, inline.strip()))
                continue
            cur = []

    def expand(self, s, args=None, depth=0):
        if depth > 12 or self.budget <= 0:
            if self.budget <= 0 and "expansion budget spent" not in self.notes:
                self.notes.append("expansion budget spent")
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
        self.budget -= 1
        if args is not None and inner.isascii() and inner.isdigit():
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

MSG_RE = re.compile(r"""\b(echo|die|warn|fail|error|info|log)((?:\s+-[A-Za-z]+|\s+[0-9]?>&[0-9])*)\s+("(?:[^"\\]|\\.)*"|'[^']*')""")
PRINTF_RE = re.compile(r"""\b(printf)((?:\s+-v\s+\S+)?)\s+("(?:[^"\\]|\\.)*"|'[^']*')""")
NOOP_RE = re.compile(r"""(^|[;&|]\s*|\s):\s+("(?:[^"\\]|\\.)*"|'[^']*')""")


def code_of(text, printf=False):
    """Text with comments removed and message strings blanked, so a word
    inside an `echo`, a `die` or a comment never counts as code. `printf`
    strings are data by default (a project name is built with one); a caller
    that judges a refusal passes printf=True to blank them too."""
    out = []
    for line in text.replace("\\\n", " ").split("\n"):
        if re.match(r"^\s*[@+-]*\s*#", line):
            continue
        line = MSG_RE.sub(r'\1\2 ""', line)
        if printf:
            line = PRINTF_RE.sub(r'\1\2 ""', line)
        line = re.sub(r"""(^|\s)#[^'"]*$""", r"\1", line)     # a trailing comment
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
        t = tokens[k].strip("\"';")
        if t in VALUE_FLAGS:
            if t in ("-f", "--file") and k + 1 < len(tokens):
                files.append(tokens[k + 1].strip("\"'"))
            k += 2
            continue
        if t.startswith("$"):            # `dc_project "$P" stop`: an argument, not the verb
            k += 1
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
            if t in ("-f", "-C", "--file", "--directory", "-o", "-W", "-j", "-l", "-I",
                     "--jobs", "--load-average", "--max-load", "--include-dir"):
                skip = True
                continue
            if t.startswith("-") or "=" in t:
                continue
            if re.fullmatch(r"[A-Za-z0-9_.-]+", t):
                found.append(t)
            else:
                break
    return found


def script_paths_in(code, root, missing=None):
    """Repo scripts a command names. A relative path that is not a file inside
    the repo goes to `missing` when given."""
    out = []
    for m in re.finditer(r"""[\w./${}()-]*[\w-]\.(?:sh|py|bash)\b""", code):
        p = m.group(0).strip("\"'")
        if p.startswith("./"):
            p = p[2:]
        if "$" in p or p.startswith("/"):
            continue
        full = os.path.realpath(os.path.join(root, p))
        if full.startswith(os.path.realpath(root) + os.sep) and os.path.isfile(full):
            if p not in out:
                out.append(p)
        elif missing is not None and p not in missing \
                and re.fullmatch(r"[\w.][\w./-]*/[\w.-]+\.(?:sh|bash)", p):
            # a repo shell script by its shape; `manage.py` runs in a container
            missing.append(p)
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
        if not os.path.isfile(path):         # a FIFO or a device never returns
            return None, "not a regular file"
        if os.path.getsize(path) > MAX_BYTES:
            return None, "larger than %d bytes" % MAX_BYTES
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read(), None
    except OSError as e:
        return None, str(e)


FENCE_RE = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
LANES_RE = re.compile(r"^ {0,3}(?:[-*]\s+)?lanes\s*:\s*(.*)$", re.I)
LOOSE_LANES_RE = re.compile(r"\blanes\s*\**\s*:", re.I)


def lanes_key(root):
    """The repo opt-out: the `lanes:` key under `## Conventions` in
    cepa.local.md (CONFIGURATION.md). Returns (value, notes). value is the
    one key's value, or None when there is no single key to honor; notes are
    why a `lanes:` line was seen but not read, one INFO row each. Fenced code
    (CommonMark: a closing fence is the same character, at least as long, with
    no info string), an HTML comment and an indented code line are examples,
    never the key. Every unclear case returns None: the repo is checked."""
    path = os.path.join(root, "cepa.local.md")
    if not os.path.lexists(path):
        return None, []
    text, err = read(path)
    if err:
        return None, ["cepa.local.md is unreadable (%s): the `lanes:` opt-out is not read" % one(err)]
    section, fence, comment = None, None, False
    found, notes = [], []
    for n, line in enumerate(text.split("\n"), 1):
        line = line.rstrip("\r")
        if fence:
            f = FENCE_RE.match(line)
            if f and f.group(1)[0] == fence[1][0] and len(f.group(1)) >= len(fence[1]) and not f.group(2).strip():
                fence = None
            continue
        if comment:
            if "-->" in line:
                comment, line = False, line.split("-->", 1)[1]
            else:
                continue
        line = re.sub(r"<!--.*?-->", "", line)
        if "<!--" in line:
            comment, line = True, line.split("<!--", 1)[0]
        f = FENCE_RE.match(line)
        if f and not (f.group(1)[0] == "`" and "`" in f.group(2)):
            fence = (n, f.group(1))
            continue
        h = re.match(r"^ {0,3}(#{1,2})\s+(.*?)\s*#*\s*$", line)
        if h:
            section = h.group(2) if h.group(1) == "##" else "# " + h.group(2)
            continue
        k = LANES_RE.match(line)
        if k:
            if section == "Conventions":
                found.append((n, k.group(1).split("#", 1)[0].strip().strip("`\"'")))
            else:
                notes.append("cepa.local.md line %d has a `lanes:` key outside ## Conventions: not read" % n)
        elif LOOSE_LANES_RE.search(line):
            notes.append("cepa.local.md line %d looks like a `lanes:` key but is not in the form read "
                         "(`- lanes: none`, at most 3 spaces in): not read" % n)
    if fence:
        notes.append("cepa.local.md has a code fence opened at line %d that never closes: no `lanes:` key after it is read" % fence[0])
    if comment:
        notes.append("cepa.local.md has an HTML comment that never closes: no `lanes:` key after it is read")
    if len(found) > 1:
        notes.append("cepa.local.md has %d `lanes:` keys in ## Conventions (lines %s): none is read"
                     % (len(found), ", ".join(str(x) for x, _ in found)))
        return None, notes
    if found and found[0][1].lower() != "none":
        notes.append("cepa.local.md `lanes: %s` is not a value this check reads (only `none`)" % one(found[0][1], 40))
        return None, notes
    return (found[0][1] if found else None), notes


def check(root):
    r = Report()
    yml = os.path.join(root, "orca.yaml")
    lanes, notes = lanes_key(root)
    if lanes is not None and os.path.lexists(yml):
        notes.append("cepa.local.md sets `lanes: none`, but the repo has an orca.yaml: the opt-out is not honored")
    elif lanes is not None:
        r.add("INFO", "opted-out", "cepa.local.md sets `lanes: none` (## Conventions) — not checked")
        return r
    for note in notes:
        r.add("INFO", "opt-out", note + ", so the repo is checked")
    if not os.path.lexists(yml):
        r.add("INFO", "orca-yaml", "no orca.yaml — this repo is not on the lane scheme; a repo coordinated under Orca needs one (lane-stack skill)")
        return r
    composes = sorted(os.path.basename(p) for p in glob.glob(os.path.join(root, "*compose*.y*ml"))
                      if re.fullmatch(r"(docker-)?compose[\w.-]*\.ya?ml", os.path.basename(p)))
    mk, mk_path, mtext, merr = None, None, "", None
    for n in ("GNUmakefile", "makefile", "Makefile"):     # make's own order
        if os.path.lexists(os.path.join(root, n)):
            mk_path = n
            break
    if mk_path:
        mtext, merr = read(os.path.join(root, mk_path))
        if merr:
            mtext = ""
        else:
            mk = Makefile(mtext)
    mk_compose = bool(mk) and bool(re.search(COMPOSE_RE, code_of(mtext)))
    docker = bool(composes) or mk_compose
    r.add("INFO", "kind", ("Docker repo (compose: %s)" % " ".join(composes)) if composes
          else ("Docker repo (%s runs docker compose; no root compose file)" % mk_path) if docker
          else "non-Docker repo (no root compose file, no Makefile running compose): orca.yaml contract only")
    if merr:
        r.add("MISS", "makefile", "%s is unreadable: %s" % (mk_path, one(merr)))
    if mk and mk.notes:
        r.add("INFO", "makefile", "%s read partly: %s" % (mk_path, one("; ".join(mk.notes), 160)))

    # -- orca.yaml contract
    text, err = read(yml)
    doc = None
    if err:
        r.add("MISS", "yaml-parse", "orca.yaml is unreadable: %s" % one(err))
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
        extra = sorted(one(k, 40) for k in set(doc) - ORCA_KEYS)
        if extra:
            r.add("INFO", "yaml-keys", "top-level keys Orca does not read (ignored, not fatal): %s" % one(", ".join(extra)))
        for key in ("scripts", "worktree"):
            if doc.get(key) is not None and not isinstance(doc.get(key), dict):
                r.add("MISS", "yaml-shape", "`%s` is not a mapping: Orca reads nothing under it" % key)
        sc = doc.get("scripts") if isinstance(doc.get("scripts"), dict) else {}
        setup, archive = sc.get("setup"), sc.get("archive")
        if archive is not None and not isinstance(archive, str):
            r.add("MISS", "archive", "scripts.archive is not a string")
            archive = "x" if not docker else None
        # every value below is a str or None: str() of an aliased list can be huge
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
            r.add("MISS", "policy", "setupAgentStartupPolicy %s is not a value Orca accepts; Orca drops it silently"
                  % (one(repr(pol)) if isinstance(pol, str) else "of type " + type(pol).__name__))
        elif setup_cmd:
            r.add("OK" if pol == "wait-for-setup" else "MISS", "policy",
                  "setupAgentStartupPolicy: wait-for-setup" if pol == "wait-for-setup"
                  else "scripts.setup exists, so setupAgentStartupPolicy must be wait-for-setup (contract item 3); it is %s" % one(repr(pol)))
        elif pol is not None:
            r.add("INFO", "policy", "setupAgentStartupPolicy set with no scripts.setup: it orders nothing")
        wt = doc.get("worktree") if isinstance(doc.get("worktree"), dict) else {}
        shared = wt.get("sharedDirectories") or []
        shared = shared if isinstance(shared, list) else [shared]
        bad = [one(s) if isinstance(s, str) else "a " + type(s).__name__
               for s in shared if not isinstance(s, str) or PER_BRANCH.match(s.strip())]
        r.add("MISS" if bad else "OK", "shared-dirs",
              "worktree.sharedDirectories holds per-branch state, or an entry that is not a path: %s (contract item 4)"
              % ", ".join(bad) if bad
              else "no worktree.sharedDirectories entry holds per-branch state")
    if os.path.lexists(os.path.join(root, ".worktreeinclude")):
        r.add("MISS", "worktreeinclude", ".worktreeinclude exists — remove it (contract item 4)")
    else:
        r.add("OK", "worktreeinclude", "no .worktreeinclude")
    r.add("INFO", "hook-shadow", "contract item 5 NOT CHECKED here (Orca state, not a file): `orca-lane.sh create` refuses a shadow (its header, H1)")

    # -- contract item 6: `make worktree branch=` is never an entry point
    bad, unread = [], []
    ctext, cerr = read(os.path.join(root, "CLAUDE.md")) if os.path.lexists(os.path.join(root, "CLAUDE.md")) else ("", None)
    for fname, body, ferr in (("orca.yaml", text, err), (mk_path or "Makefile", mtext, merr), ("CLAUDE.md", ctext, cerr)):
        if ferr or body is None:
            unread.append(fname)
            continue
        for m in re.finditer(r"make\s+worktree\s+branch=", body):
            win = body[max(0, m.start() - 120): m.end() + 120]
            if not re.search(r"\b(not|never|forbidden|fallback)\b|orca-lane\.sh", win, re.I):
                bad.append("%s:%d" % (fname, body.count("\n", 0, m.start()) + 1))
    if mk and "worktree" in mk.targets and mk.targets["worktree"]["help"] \
            and "orca-lane" not in mk.targets["worktree"]["help"]:
        bad.append("%s:%d (the `worktree` help line does not name orca-lane.sh create)" % (mk_path, mk.targets["worktree"]["line"]))
    if bad:
        r.add("MISS", "entry", "`make worktree branch=` named as an entry point: %s (contract item 6)" % ", ".join(bad))
    elif unread:
        r.add("INFO", "entry", "NOT CHECKED in %s (unreadable)" % ", ".join(unread))
    else:
        r.add("OK", "entry", "`make worktree branch=` is never named as an entry point")

    # -- setup closure
    texts = [("orca.yaml", setup_cmd)] if setup_cmd else []
    unresolved = []
    if setup_cmd:
        queue, seen, missing = list(make_targets_in(code_of(setup_cmd))), set(), []
        scripts = script_paths_in(code_of(setup_cmd), root, missing)
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
            queue += mk.expand(" ".join(mk.targets[t]["prereqs"])).split() + make_targets_in(rec)
            scripts += [s for s in script_paths_in(rec, root, missing) if s not in scripts]
        for s in scripts:
            body, serr = read(os.path.join(root, s))
            if serr:
                r.add("MISS", "setup-closure", "setup runs %s, which is unreadable: %s" % (one(s), one(serr)))
            else:
                texts.append((s, code_of(body)))
        reached = ", ".join(lbl for lbl, _ in texts[1:]) or "orca.yaml's own command only"
        if unresolved:
            r.add("MISS", "setup-closure", "scripts.setup runs make target(s) with no rule in %s: %s" % (mk_path or "a Makefile (none found)", one(", ".join(unresolved))))
        if missing:
            r.add("INFO", "setup-missing", "setup names script(s) that are not files in this repo, not read: %s" % one(", ".join(missing)))
        r.add("INFO", "setup-closure", "setup reaches: %s" % one(reached, 300))
    closure = "\n".join(t for _, t in texts)

    bare = bare_timeouts(closure)
    if doc is None:
        r.add("INFO", "timeout", "NOT CHECKED: orca.yaml was not read, so what setup runs is unknown")
    elif bare:
        r.add("MISS", "timeout", "setup runs `timeout` without --foreground or `-T </dev/null`: %s (contract item 7)" % one(" | ".join(bare[:3]), 300))
    else:
        r.add("OK", "timeout", "no bare `timeout` in what setup runs")

    if not docker:
        return r

    # -- Docker repo: -wt- name, gate in setup, stop after setup
    if doc is None:
        r.add("INFO", "setup-closure", "NOT CHECKED: orca.yaml was not read, so -wt-, gate and stop are not checked")
    elif len(texts) <= 1:
        r.add("MISS", "setup-closure", "scripts.setup reaches no Makefile target or repo script this check can read, so -wt-, gate and stop are NOT CHECKED")
    else:
        r.add("OK" if "-wt-" in closure else "MISS", "wt-name",
              "setup names its compose project with -wt-" if "-wt-" in closure
              else "no -wt- in what setup runs: the gate cannot count this lane's stack")
        r.add("OK" if GATE_RE.search(closure) else "MISS", "setup-gate",
              "setup calls the stack gate" if GATE_RE.search(closure)
              else "setup never names stack-gate.sh (skill, Setup step 4)")
        aliases = set()
        for _, t in texts:
            aliases |= compose_aliases(t)
        stops = any(compose_verb(toks)[0] == "stop"
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
        for sub in mk.expand(" ".join(mk.targets["up"]["prereqs"])).split() + make_targets_in(rec):
            if sub in mk.targets and sub != "up":    # `up: dev-up`: one level down
                rec += "\n" + code_of(mk.recipe(sub))
        via = [s for s in script_paths_in(rec, root) if GATE_RE.search(code_of(read(os.path.join(root, s))[0] or ""))]
        # an unreadable script is not "via": it reads as no gate, never as a gate
        ok = bool(GATE_RE.search(rec)) or bool(via)
        r.add("OK" if ok else "MISS", "make-up",
              ("`make up` starts through the gate%s" % (" (via %s)" % ", ".join(via) if via and not GATE_RE.search(rec) else ""))
              if ok else "`make up` (%s:%d) never names the gate" % (mk_path, mk.targets["up"]["line"]))

    # -- gated start targets
    gated_callers = {}
    for t in mk.targets:
        rec = code_of(mk.recipe(t))
        if not GATE_RE.search(rec):
            continue
        for line in rec.split("\n"):
            for seg in SEP.split(line):
                # only `<gate> <project> -- make <callee>`: the gate runs it
                if " -- " in seg and re.search(r"\bGATE\b|stack[-_]gate", seg, re.I):
                    for callee in make_targets_in(seg.split(" -- ", 1)[1]):
                        gated_callers.setdefault(callee, t)
    seen_ids = set()
    for t, info in sorted(mk.targets.items(), key=lambda kv: kv[1]["line"]):
        if id(info) in seen_ids:
            continue
        seen_ids.add(id(info))
        raw = code_of("\n".join(l for _, l in info["recipe"]), printf=True)   # unexpanded: macro names count
        rec = code_of(mk.recipe(t))
        sites = []
        for _, toks in compose_segments(rec):
            verb, files = compose_verb(toks)
            if verb in START_VERBS:
                sites.append((verb, files))
        if not sites:
            continue
        where = "%s:%d" % (mk_path, info["line"])
        # A site is another stack when its target is named prod/proxy, or every
        # -f/-p it names is a prod/proxy/traefik file. A site with no -f is the
        # repo's default compose file: a lane stack.
        lane_sites = [(v, f) for v, f in sites if not OTHER_STACK_TARGET.search(t)
                      and not (f and all(OTHER_STACK_FILE.search(x) for x in f))]
        verbs = "/".join(sorted({v for v, _ in (lane_sites or sites)}))
        if not lane_sites:
            r.add("INFO", "start:" + t, "%s runs compose %s on a production or shared-proxy stack — not a lane stack, not checked" % (where, verbs))
        elif GATE_RE.search(rec):
            r.add("OK", "start:" + t, "%s runs compose %s through the gate" % (where, verbs))
        elif REFUSAL_RE.search(code_of(mk.recipe(t), printf=True)) or REFUSAL_RE.search(raw):
            mark = REFUSAL_RE.search(code_of(mk.recipe(t), printf=True)) or REFUSAL_RE.search(raw)
            r.add("OK", "start:" + t, "%s runs compose %s behind a lane refusal or a main-only branch (marker: %s)" % (where, verbs, one(mark.group(0))))
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
