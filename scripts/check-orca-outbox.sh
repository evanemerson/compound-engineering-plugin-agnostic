#!/usr/bin/env bash
# Check for the `coord:<repo>` address and its outbox (punch-list L61):
# plugins/cepa/scripts/orca-send.sh (the target check, the outbox write, the
# resolver, the delivered move, the prune), orca-health.sh (the outbox
# alerts) and orca-outbox.sh (the receiver's drain), plus the drain block in
# `cepa:autonomy` §12b rule 8. It runs them in throwaway git repos against
# scripts/fixtures/orca-outbox-stub.py as `orca-ide` on PATH, with HOME,
# CEPA_ORCA_ALERT_DIR and CEPA_ORCA_OUTBOX_DIR in a temp directory, so it
# never reaches a real Orca or the real outbox.
#
# Usage: check-orca-outbox.sh [orca-send.sh [orca-health.sh [orca-outbox.sh [SKILL.md]]]]
#   The optional paths replace the shipped files. Only
#   check-orca-outbox-controls.sh sets them, to run this check against a
#   mutant. orca-send.sh is copied beside the shipped orca-nudge.sh.
#
# Every MISS line starts with its case name, so the controls can assert the
# exact set of cases each mutant breaks. Legs:
#   TARGET  — a coord: repo that is not its own slug (`..`, a leading `-`,
#             `--`, a `.`, a `/`, empty) is refused (exit 4) and kept only
#             under _invalid/, with no Orca call; escalation, reply and
#             worker_done refuse coord: and keep the copy under refused/; a
#             term_ target writes no outbox at all.
#   WRITE   — a pending write: exit 6, file mode 600, directories 700, the
#             exact header, the message verbatim; a refusal after the write
#             moves it to refused/; a symlinked or relative outbox root is
#             refused and writes nothing through it.
#   RESOLVE — exact objective match (a prefix repo never matches), the live
#             rule (terminal absent, not connected, no live pty), the main
#             checkout identity (#17: mismatch alert), ambiguous (alert, both
#             handles), one handle in two Runs, pagination (#24) and a bad
#             cursor, a failed or truncated read (unreadable alert), the send
#             argv and the delivered move, a failed send kept pending.
#   PRUNE   — files older than 7 days go in every status; a pending or
#             refused one leaves an outbox_pruned alert, a delivered one none.
#   HEALTH  — the sender's count alert (key = newest file, #25), its ack,
#             a new file re-alerting, worktree scope, the resolver alert
#             kinds, unknown-shape files shown only to the receiving main
#             checkout, the inbound note, and no body text in any output.
#   DRAIN   — show: oldest first, claims, a nonce per body, control
#             characters replaced, unknown-shape skipped unread, the #10
#             delivered-to-a-gone-handle rule, refused never shown; ack
#             moves the file; a linked worktree is refused.
#   BLOCK   — the rule 8 drain block, extracted from the skill and run under
#             `bash -e`, passes each argument as one word.
#
# STATED LIMITS: the stub's shapes are the 2026-11-02 measurements; a changed
# Orca shape is caught only when it is measured again. The `-O` owner checks
# cannot be tested without a second user.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

SEND=${1:-plugins/cepa/scripts/orca-send.sh}
HEALTH=${2:-plugins/cepa/scripts/orca-health.sh}
OUTBOX=${3:-plugins/cepa/scripts/orca-outbox.sh}
SKILL=${4:-plugins/cepa/skills/autonomy/SKILL.md}

python3 - "$SEND" "$HEALTH" "$OUTBOX" "$SKILL" <<'PY'
import glob, json, os, re, shutil, stat, subprocess, sys, tempfile, time

SEND, HEALTH, OUTBOX, SKILL = [os.path.abspath(p) for p in sys.argv[1:5]]
ROOT = os.getcwd()
STUB = os.path.join(ROOT, "scripts/fixtures/orca-outbox-stub.py")
NUDGE = os.path.join(ROOT, "plugins/cepa/scripts/orca-nudge.sh")
T = tempfile.mkdtemp(prefix="cepa-outbox-check-")
fails, passes = [], 0

def ok(name):
    global passes
    passes += 1
    print("PASS " + name)

def miss(name, why=""):
    fails.append(name)
    print("MISS %s%s" % (name, (": " + why) if why else ""))

def check(name, cond, why=""):
    (ok if cond else lambda n: miss(n, why))(name)

def sh(*a, cwd=None):
    subprocess.run(a, cwd=cwd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

# Binaries: the stub as orca-ide, and orca-send.sh beside the shipped nudge.
BIN = os.path.join(T, "bin")
os.makedirs(BIN)
with open(os.path.join(BIN, "orca-ide"), "w") as f:
    f.write("#!/bin/sh\nexec python3 %s \"$@\"\n" % STUB)
os.chmod(os.path.join(BIN, "orca-ide"), 0o755)
SD = os.path.join(T, "sendbin")
os.makedirs(SD)
shutil.copy(SEND, os.path.join(SD, "orca-send.sh"))
shutil.copy(NUDGE, os.path.join(SD, "orca-nudge.sh"))
SEND_RUN = os.path.join(SD, "orca-send.sh")

# Repos: sender `sendrepo` (main + linked lane), receiver `dpc-pro` (main +
# linked lane). No remote is needed.
W = os.path.join(T, "w")
def repo(name):
    p = os.path.join(W, name)
    os.makedirs(p)
    sh("git", "init", "-q", "-b", "main", cwd=p)
    sh("git", "-c", "user.email=x@y", "-c", "user.name=x", "commit", "-q", "--allow-empty", "-m", "i", cwd=p)
    lane = os.path.join(W, name + "-lane")
    sh("git", "worktree", "add", "-q", "--detach", lane, cwd=p)
    return p, lane
SMAIN, SLANE = repo("sendrepo")
RMAIN, RLANE = repo("dpc-pro")

ME = "term_" + "a" * 8 + "-0000-0000-0000-" + "a" * 12
HR = "term_" + "b" * 8 + "-0000-0000-0000-" + "b" * 12
H2 = "term_" + "c" * 8 + "-0000-0000-0000-" + "c" * 12
UNC_MAIN = "\\\\wsl.localhost\\U\\home\\x\\webapps\\dpc-pro"
UNC_LANE = "\\\\wsl.localhost\\U\\home\\x\\orca\\workspaces\\lanes\\dpc-pro"
UNC_OTHER = "\\\\wsl.localhost\\U\\home\\x\\webapps\\dpc-pro-docs"

def term(h, path=UNC_MAIN, n=1, connected=True):
    return {"handle": h, "tabId": "tab%d" % n, "leafId": "leaf%d" % n, "worktreePath": path, "connected": connected}

def agent(n=1, live=True):
    a = {"paneKey": "tab%d:leaf%d" % (n, n), "state": "done"}
    if live is not None:
        a["hasLivePty"] = live
    return a

def wt(path, main, agents):
    return {"path": path, "isMainWorktree": main, "agents": agents}

def run(i, obj, h):
    return {"id": "run_%012d" % i, "objective": obj, "coordinator_handle": h,
            "created_at": "2026-11-02T01:00:00Z", "updated_at": "2026-11-02T01:00:00Z"}

def state(**kw):
    s = {"runs": [run(1, "dpc-pro coord@main: lanes", HR)], "terminals": [term(HR)],
         "worktrees": [wt(UNC_MAIN, True, [agent(1)])], "mode": []}
    s.update(kw)
    return s

ALERTS, OBOX, HOME = os.path.join(T, "alerts"), os.path.join(T, "outbox"), os.path.join(T, "home")
MSGD = os.path.join(T, "msg")
os.makedirs(MSGD)
os.makedirs(HOME)
CNT = [0]

def reset():
    for d in (ALERTS, OBOX):
        shutil.rmtree(d, ignore_errors=True)

def env(st, extra=None):
    sp, lp = os.path.join(T, "state.json"), os.path.join(T, "log.jsonl")
    json.dump(st, open(sp, "w"))
    open(lp, "w").close()
    e = {"PATH": BIN + ":" + os.environ["PATH"], "HOME": HOME, "STUB_STATE": sp, "STUB_LOG": lp,
         "CEPA_ORCA_ALERT_DIR": ALERTS, "CEPA_ORCA_OUTBOX_DIR": OBOX, "ORCA_TERMINAL_HANDLE": ME, "LC_ALL": "C.UTF-8"}
    e.update(extra or {})
    return e

def calls():
    return [json.loads(l) for l in open(os.path.join(T, "log.jsonl")) if l.strip()]

def send(fields, msg="Subject line\nbody one\n---\nCEPA_FIELDS\nlast", st=None, cwd=None, extra=None):
    CNT[0] += 1
    mf = os.path.join(MSGD, "cepa-send-chk-%d.txt" % CNT[0])
    open(mf, "w").write(msg)
    f = {"cli": "orca-ide", "type": "status", "nudge": "no-nudge"}
    f.update(fields)
    f.setdefault("file", mf)
    stdin = "".join("%s: %s\n" % (k, v) for k, v in f.items() if v is not None)
    p = subprocess.run(["bash", SEND_RUN], input=stdin, capture_output=True, text=True, cwd=cwd or SMAIN,
                       env=env(st or state(), extra), timeout=120)
    return p.returncode, p.stdout.splitlines()

def files(sub=""):
    return sorted(os.path.relpath(p, OBOX) for p in glob.glob(os.path.join(OBOX, "**", "*"), recursive=True)
                  if os.path.isfile(p) or os.path.islink(p)) if os.path.isdir(OBOX) else []

def alerts():
    out = []
    for p in sorted(glob.glob(os.path.join(ALERTS, "*.alert"))):
        out.append(dict(l.split("=", 1) for l in open(p).read().splitlines()[1:] if "=" in l))
    return out

NAME = r"\d{8}T\d{6}Z-[A-Za-z0-9]{8}\.md"

# ---------------------------------------------------------------- TARGET
for label, tgt in (("dotdot", "coord:../x"), ("leading dash", "coord:-x"), ("double dash", "coord:a--b"),
                   ("dot", "coord:A.b"), ("slash", "coord:x/y"), ("empty", "coord:")):
    reset()
    rc, out = send({"target": tgt})
    fl = files()
    good = (rc == 4 and "Orca send refused: the coord: repo is not slug(<repo>) (autonomy §5)" in out
            and len(fl) == 1 and re.fullmatch(r"_invalid/" + NAME, fl[0]) and not calls()
            and "Orca outbox: kept as refused: _invalid/" + fl[0].split("/")[-1] in out
            and [a.get("target") for a in alerts()] == ["invalid"])
    check("TARGET %s is refused and kept in _invalid" % label, good, "rc=%s files=%s out=%s" % (rc, fl, out[:3]))
for typ, extra_f, reason in (
        ("escalation", {}, "an escalation cannot go to a coord: address; it keeps its Run path"),
        ("reply", {}, "a reply's target is not a msg_ message id"),
        ("worker_done", {"nudge": None, "outcome": "succeeded", "task": "task_abcdef"},
         "a worker_done target is not dispatch:ctx_<id>")):
    reset()
    f = {"target": "coord:dpc-pro", "type": typ}
    f.update(extra_f)
    rc, out = send(f)
    fl = files()
    check("TARGET %s refuses a coord address and keeps it as refused" % typ,
          rc == 4 and "Orca send refused: " + reason in out and len(fl) == 1
          and re.fullmatch(r"dpc-pro/refused/" + NAME, fl[0]) and not calls(), "rc=%s files=%s out=%s" % (rc, fl, out[:3]))
reset()
rc, out = send({"target": HR, "type": "bogus"})
check("TARGET a term_ target writes no outbox copy", rc == 4 and not os.path.exists(OBOX), "rc=%s" % rc)

# ---------------------------------------------------------------- WRITE
reset()
MSG = "Subject line\nbody one\n---\nCEPA_FIELDS\nlast"
rc, out = send({"target": "coord:dpc-pro", "session": "coord@main"}, msg=MSG, st=state(runs=[]))
fl = files()
pend = fl[0] if len(fl) == 1 and re.fullmatch(r"dpc-pro/" + NAME, fl[0]) else None
check("WRITE no live coord@main keeps it pending (exit 6)",
      rc == 6 and pend is not None
      and "Orca send pending: no live coord@main for dpc-pro; kept in the outbox as %s" % pend in out
      and not [c for c in calls() if c[:2] == ["orchestration", "send"]] and not alerts(),
      "rc=%s files=%s out=%s" % (rc, fl, out))
if pend:
    p = os.path.join(OBOX, pend)
    modes = (stat.S_IMODE(os.stat(p).st_mode), stat.S_IMODE(os.stat(OBOX).st_mode),
             stat.S_IMODE(os.stat(os.path.dirname(p)).st_mode))
    check("WRITE file 600, directories 700", modes == (0o600, 0o700, 0o700), "modes=%s" % [oct(m) for m in modes])
    lines = open(p).read().split("\n")
    want = ["cepa-outbox 1", None, "repo=sendrepo", "worktree=sendrepo", "sender=" + ME, "target=coord:dpc-pro",
            "type=status", "session=coord@main", "---"]
    good = len(lines) >= 9 and re.fullmatch(r"time=\d{9,12}", lines[1]) \
        and all(w is None or w == l for w, l in zip(want, lines)) and "\n".join(lines[9:]).rstrip("\n") == MSG
    check("WRITE header is exact and the message is verbatim", good, "lines=%r" % lines[:10])
else:
    miss("WRITE file 600, directories 700", "no pending file")
    miss("WRITE header is exact and the message is verbatim", "no pending file")
reset()
rc, out = send({"target": "coord:dpc-pro", "nudge": "yes"})
fl = files()
check("WRITE a refusal after the write moves it to refused",
      rc == 4 and len(fl) == 1 and re.fullmatch(r"dpc-pro/refused/" + NAME, fl[0])
      and "Orca outbox: kept as refused: " + fl[0] in out, "rc=%s files=%s" % (rc, fl))
reset()
REAL = os.path.join(T, "elsewhere")
os.makedirs(REAL, exist_ok=True)
os.symlink(REAL, OBOX)
rc, out = send({"target": "coord:dpc-pro"})
check("WRITE a symlinked outbox root is refused",
      rc == 4 and "Orca send refused: the outbox directory is not a directory this user owns" in out
      and not glob.glob(os.path.join(REAL, "**", "*.md"), recursive=True), "rc=%s out=%s" % (rc, out[:2]))
os.unlink(OBOX)
shutil.rmtree(REAL)
reset()
rc, out = send({"target": "coord:dpc-pro"}, extra={"CEPA_ORCA_OUTBOX_DIR": "rel/outbox"})
check("WRITE a relative outbox root is refused",
      rc == 4 and "Orca send refused: the outbox directory is not an absolute path" in out
      and not os.path.exists(os.path.join(SMAIN, "rel")), "rc=%s out=%s" % (rc, out[:2]))

# ---------------------------------------------------------------- RESOLVE
PENDING_END = ("Ending first line: Needed from you: nothing now; coord@main of dpc-pro shows the message "
               "from the outbox on its next turn (§12b rule 8)")

def resolve(name, st, want_rc, want_kind=None, sent_to=None, want_line=None):
    reset()
    rc, out = send({"target": "coord:dpc-pro"}, st=st)
    sends = [c for c in calls() if c[:2] == ["orchestration", "send"]]
    fl = files()
    kinds = [a.get("kind") for a in alerts()]
    good = rc == want_rc and kinds == ([want_kind] if want_kind else [])
    if sent_to:
        good = good and len(sends) == 1 and sends[0][sends[0].index("--to") + 1] == sent_to \
            and len(fl) == 1 and re.fullmatch(r"dpc-pro/delivered/\d{8}T\d{6}Z-[A-Za-z0-9]{8}\.to-%s\.md" % sent_to, fl[0]) \
            and "Orca send resolved: coord:dpc-pro is %s" % sent_to in out
    else:
        good = good and not sends and len(fl) == 1 and re.fullmatch(r"dpc-pro/" + NAME, fl[0])
    if want_rc == 6:
        good = good and out[-1] == PENDING_END
    if want_kind:
        good = good and [a.get("target") for a in alerts()] == ["coord:dpc-pro"]
    if want_line:
        good = good and any(want_line in l for l in out)
    check("RESOLVE " + name, good, "rc=%s kinds=%s files=%s sends=%d out=%s" % (rc, kinds, fl, len(sends), out))
    return out

resolve("one live coord@main is sent to and moved to delivered", state(), 0, sent_to=HR)
resolve("objective with nothing after the name matches", state(runs=[run(1, "dpc-pro coord@main", HR)]), 0, sent_to=HR)
resolve("a prefix repo never matches", state(runs=[run(1, "dpc-pro-docs coord@main: x", HR)]), 6,
        want_line="no live coord@main for dpc-pro")
resolve("an objective that runs on past coord@main never matches",
        state(runs=[run(1, "dpc-pro coord@main2: x", HR)]), 6, want_line="no live coord@main")
resolve("an objective that only contains the name never matches",
        state(runs=[run(1, "old dpc-pro coord@main", HR)]), 6, want_line="no live coord@main")
resolve("a handle absent from terminal list is not live", state(terminals=[]), 6, want_line="no live coord@main")
resolve("a terminal that is not connected is not live", state(terminals=[term(HR, connected=False)]), 6,
        want_line="no live coord@main")
resolve("an open tab with no live pty is not live", state(worktrees=[wt(UNC_MAIN, True, [agent(1, live=None)])]), 6,
        want_line="no live coord@main")
resolve("a live coord@main in a linked worktree is a mismatch",
        state(terminals=[term(HR, UNC_LANE)], worktrees=[wt(UNC_LANE, False, [agent(1)])]), 6, "outbox_mismatch",
        want_line="outside its main checkout: " + HR)
resolve("a live coord@main in another repo's main checkout is a mismatch",
        state(terminals=[term(HR, UNC_OTHER)], worktrees=[wt(UNC_OTHER, True, [agent(1)])]), 6, "outbox_mismatch")
resolve("two live coord@main handles are ambiguous",
        state(runs=[run(1, "dpc-pro coord@main: a", HR), run(2, "dpc-pro coord@main b", H2)],
              terminals=[term(HR), term(H2, n=2)], worktrees=[wt(UNC_MAIN, True, [agent(1), agent(2)])]),
        6, "outbox_ambiguous", want_line="more than one live coord@main claims dpc-pro: %s %s" % (HR, H2))
resolve("one handle in two Runs is one handle",
        state(runs=[run(1, "dpc-pro coord@main: a", HR), run(2, "dpc-pro coord@main: b", HR)]), 0, sent_to=HR)
out = resolve("a match on a later page is found",
              state(page=2, runs=[run(1, "x coord@main", H2), run(2, "y", H2), run(3, "dpc-pro coord@main", HR)]),
              0, sent_to=HR)
rl = [c for c in calls() if c[:2] == ["orchestration", "run-list"]]
check("RESOLVE pagination follows nextCursor", len(rl) == 2 and rl[1][rl[1].index("--cursor") + 1] == "c2", "calls=%s" % rl)
resolve("a bad cursor is unreadable", state(mode=["runlist_badcursor"]), 6, "outbox_unreadable",
        want_line="the Run list could not be read")
resolve("a failed run-list is unreadable", state(mode=["runlist_fail"]), 6, "outbox_unreadable",
        want_line="the Run list could not be read")
resolve("a truncated terminal list is unreadable", state(mode=["tlist_trunc"]), 6, "outbox_unreadable")
resolve("a failed worktree ps is unreadable", state(mode=["ps_fail"]), 6, "outbox_unreadable")
UNC_DOT = "\\\\wsl.localhost\\U\\home\\x\\webapps\\dpc.pro"
resolve("an objective named by the raw directory matches its slug",
        state(runs=[run(1, "dpc.pro coord@main: x", HR)], terminals=[term(HR, UNC_DOT)],
              worktrees=[wt(UNC_DOT, True, [agent(1)])]), 0, sent_to=HR)
reset()
rc, out = send({"target": "coord:dpc-pro"}, st=state(store_to="bogus"))
fl = files()
check("RESOLVE an unproven send stays pending",
      rc == 5 and len(fl) == 1 and re.fullmatch(r"dpc-pro/" + NAME, fl[0])
      and "Orca outbox: kept as pending: %s (the receiver's drain delivers it)" % fl[0] in out,
      "rc=%s files=%s out=%s" % (rc, fl, out))
reset()
rc, out = send({"target": "coord:dpc-pro"}, st=state(mode=["send_fail"]))
fl = files()
check("RESOLVE a failed send stays pending",
      rc == 5 and len(fl) == 1 and re.fullmatch(r"dpc-pro/" + NAME, fl[0])
      and "Orca outbox: kept as pending: %s (the receiver's drain delivers it)" % fl[0] in out,
      "rc=%s files=%s out=%s" % (rc, fl, out))

# ---------------------------------------------------------------- PRUNE
def plant(rel, header=None, body="planted body SENTINEL-BODY-TEXT", mode=0o600, raw=None):
    p = os.path.join(OBOX, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    os.chmod(OBOX, 0o700)
    sub = rel.split("/")[0]
    h = {"time": "1793600000", "repo": "sendrepo", "worktree": "sendrepo", "sender": ME,
         "target": "invalid" if sub == "_invalid" else "coord:" + sub, "type": "status", "session": ""}
    h.update(header or {})
    text = raw if raw is not None else "cepa-outbox 1\n" + "".join(
        "%s=%s\n" % (k, h[k]) for k in ("time", "repo", "worktree", "sender", "target", "type", "session")) \
        + "---\nSubject\n" + body + "\n"
    open(p, "w").write(text)
    os.chmod(p, mode)
    return p

def stamp(days_ago):
    return time.strftime("%Y%m%dT%H%M%SZ", time.gmtime(time.time() - days_ago * 86400))

reset()
old_p, old_r, old_d = (stamp(10) + "-Aold0001.md", stamp(10) + "-Aold0002.md", stamp(10) + "-Aold0003.to-%s.md" % HR)
new_p = stamp(1) + "-Anew0001.md"
plant("dpc-pro/" + old_p, header={"repo": "otherrepo", "worktree": "otherlane"})
plant("dpc-pro/refused/" + old_r)
plant("dpc-pro/delivered/" + old_d)
plant("helm/" + new_p)
rc, out = send({"target": "coord:dpc-pro"}, st=state(runs=[]))
fl = files()
kinds = sorted(a.get("kind") for a in alerts())
reasons = sorted(a.get("reason") for a in alerts())
check("PRUNE files older than 7 days go in every status",
      not [f for f in fl if "old000" in f] and "helm/" + new_p in fl, "files=%s" % fl)
check("PRUNE a pending or refused file leaves an alert, a delivered one none",
      kinds == ["outbox_pruned", "outbox_pruned"]
      and reasons == ["an outbox file was pruned unread after 7 days: dpc-pro/" + old_p,
                      "an outbox file was pruned unread after 7 days: dpc-pro/refused/" + old_r],
      "kinds=%s reasons=%s" % (kinds, reasons))
owner = sorted((a.get("reason", "").endswith(old_p), a.get("repo"), a.get("worktree"), a.get("target")) for a in alerts())
check("PRUNE an alert names the pruned file's own sender",
      owner == [(False, "sendrepo", "sendrepo", "coord:dpc-pro"), (True, "otherrepo", "otherlane", "coord:dpc-pro")],
      "owner=%s" % owner)

# ---------------------------------------------------------------- HEALTH
def health(args, cwd, st=None):
    p = subprocess.run(["bash", HEALTH, "orca-ide"] + args, capture_output=True, text=True, cwd=cwd,
                       env=env(st or state()), timeout=120)
    return p.returncode, p.stdout.splitlines()

reset()
n1, n2, n3 = stamp(1) + "-Aaaa0001.md", stamp(0.5) + "-Aaaa0002.md", stamp(0.2) + "-Aaaa0003.md"
plant("dpc-pro/" + n1)
plant("dpc-pro/" + n2)
plant("dpc-pro/refused/" + n3)
plant("dpc-pro/delivered/" + stamp(0.1) + "-Aaaa0004.to-%s.md" % HR)
plant("helm/" + stamp(0.1) + "-Abbb0001.md", header={"repo": "otherrepo", "worktree": "otherrepo"})
rc, out = health([], SMAIN)
key = "outbox:dpc-pro:" + n3
want = "ORCA alert: %s — 3 messages to coord:dpc-pro not delivered (2 pending, 1 refused); newest %s" % (key, n3)
check("HEALTH the sender sees one count alert keyed by the newest file",
      rc == 1 and want in out and not [l for l in out if "helm" in l], "out=%s" % out)
check("HEALTH never prints a body", not [l for l in out if "SENTINEL-BODY-TEXT" in l or "Subject" in l], "out=%s" % out)
rc2, out2 = health(["ack", key], SMAIN)
rc, out = health([], SMAIN)
check("HEALTH an acked count alert holds", rc2 == 0 and rc == 0 and out[-1].startswith("ORCA health: ok"), "out=%s" % (out2 + out))
n4 = stamp(0.05) + "-Aaaa0005.md"
plant("dpc-pro/" + n4)
rc, out = health([], SMAIN)
check("HEALTH a new file alerts again under a new key",
      rc == 1 and any(l.startswith("ORCA alert: outbox:dpc-pro:%s — 4 messages" % n4) for l in out), "out=%s" % out)
rc, out = health([], SLANE)
check("HEALTH a linked worktree sees only its own files", rc == 0 and not [l for l in out if "outbox:" in l], "out=%s" % out)
reset()
plant("dpc-pro/" + n1, header={"worktree": "sendrepo-lane"})
rc, out = health([], SLANE)
check("HEALTH a linked worktree sees the files it wrote",
      rc == 1 and any(l.startswith("ORCA alert: outbox:dpc-pro:%s — 1 message to coord:dpc-pro" % n1) for l in out),
      "out=%s" % out)
reset()
os.makedirs(ALERTS)
for i, (kind, reason) in enumerate((
        ("outbox_ambiguous", "more than one live coord@main claims dpc-pro: %s %s" % (HR, H2)),
        ("outbox_mismatch", "a live session claims coord@main of dpc-pro outside its main checkout: " + HR),
        ("outbox_unreadable", "the Run list could not be read"))):
    open(os.path.join(ALERTS, "1793600000-K%d.alert" % i), "w").write(
        "cepa-orca-alert 1\ntime=1793600000\nkind=%s\nrepo=sendrepo\nworktree=sendrepo\nsender=%s\n"
        "target=coord:dpc-pro\ntype=status\nreason=%s\n" % (kind, ME, reason))
rc, out = health([], SMAIN)
got = sorted(l.split(" — ")[0] for l in out if l.startswith("ORCA alert:"))
check("HEALTH resolver alert files become outbox class keys",
      got == ["ORCA alert: outbox:dpc-pro:%s:1793600000-K%d.alert" % (c, i) for i, c in
              enumerate(("ambiguous", "mismatch", "unreadable"))]
      and not [l for l in out if "an unrecognised reason" in l], "out=%s" % out)
rc, out = health(["ack", "outbox:dpc-pro:ambiguous:1793600000-K0.alert", "outbox:dpc-pro:pruned:1793600000-K9.alert"], SMAIN)
check("HEALTH an outbox class ack needs its alert file",
      rc == 1 and "ORCA ack: outbox:dpc-pro:ambiguous:1793600000-K0.alert" in out
      and any(l.startswith("ORCA ack failed: outbox:dpc-pro:pruned:1793600000-K9.alert") for l in out), "out=%s" % out)
rc, out = health(["ack", "outbox:../x:" + n1], SMAIN)
check("HEALTH a bad outbox key is refused", rc == 4, "rc=%s out=%s" % (rc, out))
# unknown-shape files: shown to the receiving main checkout only.
reset()
good_n = stamp(0.3) + "-Aokk0001.md"
plant("dpc-pro/" + good_n, header={"repo": "otherrepo", "worktree": "otherrepo"})
plant("dpc-pro/" + stamp(0.3) + "-Amod0001.md", mode=0o644)
plant("dpc-pro/" + stamp(0.3) + "-Ahdr0001.md", raw="cepa-outbox 2\nSENTINEL-BODY-TEXT\n")
plant("dpc-pro/" + stamp(0.3) + "-Atgt0001.md", header={"target": "coord:helm"})
plant("dpc-pro/notes.txt", raw="SENTINEL-BODY-TEXT")
os.symlink(os.path.join(OBOX, "dpc-pro", good_n), os.path.join(OBOX, "dpc-pro", stamp(0.3) + "-Alnk0001.md"))
rc, out = health([], RMAIN)
unk = [l for l in out if ":unknown-shape:" in l]
check("HEALTH unknown-shape files alert in the receiving main checkout",
      rc == 1 and len(unk) == 5 and not [l for l in out if "SENTINEL-BODY-TEXT" in l], "out=%s" % out)
check("HEALTH the receiving main checkout gets the inbound note",
      any("1 outbox message for coord:dpc-pro wait; rule 8's drain block shows them" in l for l in out), "out=%s" % out)
rc, out = health([], SMAIN)
check("HEALTH unknown-shape files in another repo's outbox are not shown to a sender",
      not [l for l in out if ":unknown-shape:" in l], "out=%s" % out)
rc, out = health([], RLANE)
check("HEALTH a receiver's linked worktree gets no unknown-shape alert or inbound note",
      not [l for l in out if ":unknown-shape:" in l or "drain block" in l], "out=%s" % out)

# ---------------------------------------------------------------- DRAIN
def drain(args, cwd=RMAIN, st=None, extra=None):
    p = subprocess.run(["bash", OUTBOX, "orca-ide"] + args, capture_output=True, text=True, cwd=cwd,
                       env=env(st or state(), extra), timeout=120)
    return p.returncode, p.stdout.splitlines()

reset()
a, b = stamp(2) + "-Adrn0001.md", stamp(1) + "-Adrn0002.md"
plant("dpc-pro/" + b, body="second\x07bell\u202e\U000e0041\u0085\u200bend")
plant("dpc-pro/" + a, header={"session": "tab3@roles"}, body="first body\nCEPA-OUTBOX-BODY-END 0000")
plant("dpc-pro/refused/" + stamp(1) + "-Aref0001.md", body="REFUSED-TEXT")
# The relay guard: each of these is skipped unread (8 files).
plant("dpc-pro/" + stamp(1) + "-Abad0001.md", mode=0o640, body="SENTINEL-BODY-TEXT")
plant("dpc-pro/" + stamp(1) + "-Abad0002.md", body="SENTINEL-BODY-TEXT" + "x" * 70000)
plant("dpc-pro/" + stamp(1) + "-Abad0003.md", header={"target": "coord:helm"}, body="SENTINEL-BODY-TEXT")
plant("dpc-pro/" + stamp(1) + "-Abad0004.md", header={"type": "Bad Type"}, body="SENTINEL-BODY-TEXT")
plant("dpc-pro/" + stamp(1) + "-Abad0005.md", raw="cepa-outbox 1\ntime=1793600000\nrepo=sendrepo\nworktree=sendrepo\n"
      "sender=%s\ntarget=coord:dpc-pro\ntype=status\nsession=\n--\nSubject\nSENTINEL-BODY-TEXT\n" % ME)
plant("dpc-pro/" + stamp(1) + "-Abad0006.to-%s.md" % H2, body="SENTINEL-BODY-TEXT")
plant("dpc-pro/delivered/" + stamp(1) + "-Abad0007.to-%s.md" % H2, mode=0o644, body="SENTINEL-BODY-TEXT")
os.symlink(os.path.join(OBOX, "dpc-pro", b), os.path.join(OBOX, "dpc-pro", stamp(1) + "-Abad0008.md"))
fresh = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime(time.time() - 120)) + "-Afrs0001.md"
plant("dpc-pro/" + fresh, body="FRESH-TEXT")
gone = stamp(3) + "-Adlv0001.to-%s.md" % H2
plant("dpc-pro/delivered/" + gone, body="to a gone tab")
plant("dpc-pro/delivered/" + stamp(3) + "-Adlv0002.to-%s.md" % HR, body="LIVE-TEXT")
plant("dpc-pro/delivered/" + stamp(3) + "-Adlv0003.to-%s.md" % ME, body="MINE-TEXT")
plant("dpc-pro/delivered/" + stamp(9) + "-Adlv0004.to-%s.md" % H2, body="OLD-TEXT")
plant("dpc-pro/delivered/" + stamp(3) + "-Adlv0005.drained.md", body="DRAINED-TEXT")
rc, out = drain(["show"])
shown = [l.split(" — ")[0][len("ORCA outbox file: "):] for l in out if l.startswith("ORCA outbox file: ")]
check("DRAIN shows pending and gone-handle files oldest first, nothing else",
      rc == 1 and shown == sorted([a, b, gone]),
      "rc=%s shown=%s" % (rc, shown))
check("DRAIN never shows refused, live, own, old, drained or unknown-shape files",
      not [l for l in out if re.search("REFUSED-TEXT|LIVE-TEXT|MINE-TEXT|OLD-TEXT|DRAINED-TEXT|SENTINEL-BODY-TEXT", l)]
      and out.count("ORCA outbox: skipped a file in an unknown shape (orca-health.sh alerts it; it is never shown)") == 8,
      "out=%s" % out)
txt = "\n".join(out)
begins = re.findall(r"CEPA-OUTBOX-BODY-BEGIN ([0-9a-f]{16})", txt)
ends = re.findall(r"^  CEPA-OUTBOX-BODY-END ([0-9a-f]{16})$", txt, re.M)
check("DRAIN each body sits between markers with its own nonce",
      len(begins) == 3 and begins == ends and len(set(begins)) == 3, "begins=%s ends=%s" % (begins, ends))
check("DRAIN header fields print as claims",
      "  claimed time: %s; claimed sender: %s; claimed from: sendrepo/sendrepo; claimed session: tab3@roles; "
      "claimed type: status" % (time.strftime("%Y-%m-%d %H:%M UTC", time.gmtime(1793600000)), ME) in out
      and out[-1] == "Ending first line: Needed from you: read the outbox messages below and say what to do with each",
      "out=%s" % out[:6])
check("DRAIN control, format and separator characters print as ?", "  | second?bell????end" in out, "out=%s" % out)
check("DRAIN a body line with a reserved prefix is removed and counted",
      "  | [line removed: reserved prefix]" in out and "  orca: stripped 1 reserved-prefix line in " + a in out
      and not [l for l in out if l.startswith("CEPA-OUTBOX-BODY-END 0000")], "out=%s" % out)
check("DRAIN every body line is indented", "  | first body" in out and "  | to a gone tab" in out, "out=%s" % out)
check("DRAIN a pending file under 10 minutes old is held back",
      "ORCA outbox: 1 file under 10 minutes old not shown yet (a send may still be in progress)" in out
      and not [l for l in out if "FRESH-TEXT" in l or fresh in l], "out=%s" % out)
rc, out = drain(["show"], st=state(mode=["tlist_fail"]))
shown2 = [l for l in out if l.startswith("ORCA outbox file: ")]
check("DRAIN a failed terminal read shows every recent delivered file", len(shown2) == 4, "out=%s" % shown2)
rc, out = drain(["ack", a, gone])
moved = sorted(os.listdir(os.path.join(OBOX, "dpc-pro", "delivered")))
check("DRAIN ack moves pending and delivered files to drained",
      rc == 0 and out == ["ORCA outbox ack: " + a, "ORCA outbox ack: " + gone]
      and a.replace(".md", ".drained.md") in moved and gone.split(".")[0] + ".drained.md" in moved
      and not os.path.exists(os.path.join(OBOX, "dpc-pro", a)), "rc=%s out=%s moved=%s" % (rc, out, moved))
rc, out = drain(["ack", a])
check("DRAIN ack of a file that is not waiting fails", rc == 1 and out[0].startswith("ORCA outbox ack failed: " + a), "out=%s" % out)
rc, out = drain(["ack", "../../etc/passwd"])
check("DRAIN ack of a bad name is refused", rc == 4 and out[0].startswith("ORCA outbox refused: not an outbox file name"), "out=%s" % out)
rc, out = drain(["show"], cwd=RLANE)
check("DRAIN refuses a linked worktree",
      rc == 4 and out == ["ORCA outbox refused: only a main checkout's coordinator drains the outbox"], "out=%s" % out)
reset()
rc, out = drain(["show"])
check("DRAIN an empty outbox prints none", rc == 0 and out == ["ORCA outbox: none for coord:dpc-pro"], "out=%s" % out)
plant("dpc-pro/" + stamp(1) + "-Abad0001.md", mode=0o640)
rc, out = drain(["show"])
check("DRAIN only unreadable files is never none",
      rc == 1 and not [l for l in out if "none" in l]
      and out[-1] == "Ending first line: Needed from you: check the outbox; 1 file for coord:dpc-pro could not be shown",
      "rc=%s out=%s" % (rc, out))
reset()
os.makedirs(os.path.join(T, "elsewhere2"), exist_ok=True)
os.makedirs(OBOX, mode=0o700)
os.symlink(os.path.join(T, "elsewhere2"), os.path.join(OBOX, "dpc-pro"))
rc, out = drain(["show"])
check("DRAIN an outbox directory it cannot trust fails, never none",
      rc == 5 and out[0] == "ORCA outbox failed: dpc-pro is not a directory this user owns"
      and not [l for l in out if "none" in l], "rc=%s out=%s" % (rc, out))
reset()

# ---------------------------------------------------------------- BLOCK
txt = open(SKILL).read()
m = re.search(r"\*\*A coord@main drains its outbox every turn\.\*\*.*?```bash\n(.*?)\n\s*```", txt, re.S)
if not m:
    miss("BLOCK the rule 8 drain block exists")
else:
    ok("BLOCK the rule 8 drain block exists")
    blk = "\n".join(l[5:] if l.startswith("     ") else l for l in m.group(1).split("\n"))
    def runblk(cli, action_lines, cwd=RMAIN, root=True):
        b = blk.replace("<cli>", cli).replace("show\nCEPA_ARGS", action_lines + "\nCEPA_ARGS")
        rd = os.path.join(T, "plug")
        shutil.rmtree(rd, ignore_errors=True)
        os.makedirs(os.path.join(rd, "scripts"))
        shutil.copy(OUTBOX, os.path.join(rd, "scripts", "orca-outbox.sh"))
        open(os.path.join(rd, "scripts", "resolve-plugin-root.sh"), "w").write('CEPA_ROOT="%s"\n' % rd)
        e = env(state(), {"CEPA_PLUGIN_ROOT": rd if root else os.path.join(T, "none")})
        p = subprocess.run(["bash", "-e", "-c", b], capture_output=True, text=True, cwd=cwd, env=e, timeout=60)
        return p.returncode, p.stdout.splitlines()
    reset()
    rc, out = runblk("orca-ide", "show")
    check("BLOCK show runs the script", rc == 0 and out == ["ORCA outbox: none for coord:dpc-pro"], "rc=%s out=%s" % (rc, out))
    marker = os.path.join(T, "pwned")
    rc, out = runblk("$(touch %s)orca-ide" % marker, "show")
    check("BLOCK a cli with a command substitution runs nothing",
          not os.path.exists(marker) and out and out[0].startswith("ORCA outbox refused: the cli"), "out=%s" % out)
    reset()
    plant("dpc-pro/" + a)
    rc, out = runblk("orca-ide", "ack\n" + a)
    check("BLOCK the ack form passes each name as one argument", out == ["ORCA outbox ack: " + a], "out=%s" % out)
    rc, out = runblk("orca-ide", "show", root=False)
    check("BLOCK with the script absent is skipped",
          rc == 0 and out == ["ORCA outbox skipped: orca-outbox.sh not found (set CEPA_PLUGIN_ROOT)"], "out=%s" % out)

shutil.rmtree(T, ignore_errors=True)
print("-- %d/%d checks passed --" % (passes, passes + len(fails)))
sys.exit(1 if fails else 0)
PY
