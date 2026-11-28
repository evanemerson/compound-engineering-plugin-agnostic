#!/usr/bin/env python3
"""Probe: open residual shard lines whose finding or punch-list item is closed.

    python3 -I scripts/probe-shard-lag.py      # run from the repo root

A PROBE, NOT A GATE. It prints CANDIDATES and always exits 0. Read each
candidate before you call it lag. A finding that was applied in part
legitimately leaves an open shard line for the rest (the finding's own
`**Fix:**` says "the rest is filed in the run's residual shard"), and a line
that names an `L<n>` only as context is not owned by that item. On the tree
this probe was written against (origin/main f4443ef), 5 of its 8 candidates
were of those two kinds and 3 were lag.

The rule it measures is repo CLAUDE.md "Flip the shard line in the commit that
closes its item". The evidence, the counts, and why this is not a gate are in
`memory/tasks.d/2026-11-27-docs-matrix-shard-flip-and-block-select-rules.md`.

Leg F (findings): an open `- [ ]` line in `memory/tasks.d/*.md` (the punch
list excluded) that names one findings file (`review-<stamp>[-<slug>]`, or the
section's `Canonical findings:` file when the line names none) and one or more
finding numbers (`finding N`, `(findings N, M)`, `#N`), when every one of those
numbers that the file holds is `applied`, `completed` or `skipped`. A `#N`
that is really a PR number is a known over-match; it shows up as a candidate,
never as a silent skip.

Leg L (punch list): an open `- [ ]` line that names `L<n>`, when every `L<n>`
it names that the punch list holds is `status: completed`.

Limits: a line that names two findings files is skipped (no single file to
check); a findings file that is not in the `### N` + `- status:` shape is
skipped. Both are absences of the probe, not of lag.
"""
import glob
import re

CLOSED = {"applied", "completed", "skipped"}
PUNCH = "memory/tasks.d/2026-10-02-punch-list.md"
OPEN_LINE = re.compile(r"^\s*- \[ \]")
RID = re.compile(r"review-(\d{4}-\d\d-\d\d-\d{6}(?:-[a-z0-9-]+)?)")
CANON = re.compile(r"Canonical findings: `todos/(review-[^`]+)\.md`")
FNUM = re.compile(r"\(findings? ([\d, and]+)\)|#(\d+)\b|finding (\d+)")
LREF = re.compile(r"\bL(\d+)\b")


def finding_status(path):
    """{finding number: status} for a `### N` / `- status:` findings file."""
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError:
        return {}
    st, cur = {}, None
    for line in lines:
        m = re.match(r"^### (\d+)\s*$", line)
        if m:
            cur = int(m.group(1))
            continue
        m = re.match(r"^- status: ([a-z_-]+)", line)
        if m and cur is not None and cur not in st:
            st[cur] = m.group(1)
    return st


def punch_status():
    text = open(PUNCH, encoding="utf-8").read()
    return {int(m.group(1)): m.group(2)
            for m in re.finditer(r"^L(\d+)\. .*?\n    status: (\w+)", text, re.M)}


def main():
    lst = punch_status()
    hits = []
    for shard in sorted(glob.glob("memory/tasks.d/*.md")):
        if shard == PUNCH:
            continue
        canon = None
        for i, line in enumerate(open(shard, encoding="utf-8").read().splitlines(), 1):
            if line.startswith("## "):
                canon = None
            m = CANON.search(line)
            if m:
                canon = m.group(1)
            if not OPEN_LINE.match(line):
                continue
            # Leg F
            rids = RID.findall(line)
            rid = "review-" + rids[0] if len(rids) == 1 else (canon if not rids else None)
            nums = set()
            for a, b, c in FNUM.findall(line):
                nums |= {int(x) for x in re.findall(r"\d+", a)} if a else {int(b or c)}
            st = finding_status("todos/%s.md" % rid) if rid and nums else {}
            held = [n for n in nums if n in st]
            if held and all(st[n] in CLOSED for n in held):
                hits.append("F %s:%d: %s findings %s are %s"
                            % (shard, i, rid, sorted(held), sorted({st[n] for n in held})))
            # Leg L
            refs = [r for r in {int(x) for x in LREF.findall(line)} if r in lst]
            if refs and all(lst[r] == "completed" for r in refs):
                hits.append("L %s:%d: %s completed"
                            % (shard, i, ", ".join("L%d" % r for r in sorted(refs))))
    for h in hits:
        print(h)
    print("%d candidate(s); read each before calling it lag" % len(hits))


if __name__ == "__main__":
    main()
