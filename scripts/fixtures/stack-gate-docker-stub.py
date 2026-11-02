#!/usr/bin/env python3
"""`docker` stand-in for scripts/check-stack-gate.sh. Never reaches Docker.

State is a JSON list of containers in $STUB_DOCKER_STATE:
  {"project": str, "wd": str, "id": str, "state": "running"|"exited",
   "started": "<RFC 3339>"}
Every call is appended to $STUB_DOCKER_LOG as one JSON argv list.

  ps     honors -a/--all, `--filter status=running` and
         `--filter label=com.docker.compose.project`; renders --format by
         replacing {{.Label "k"}} and {{.ID}} (with \t for a tab, as Go
         templates in single quotes arrive literally as a tab already).
         $STUB_DOCKER_FAIL=ps makes it exit 1.
  inspect --format '{{.Id}} {{.State.StartedAt}}' <id…>
  add <project> <wd> <id>   (not docker) appends a running container; the
         check's start command uses it to model a stack coming up.
"""
import json, os, re, sys, fcntl

STATE = os.environ["STUB_DOCKER_STATE"]
LOG = os.environ.get("STUB_DOCKER_LOG")
argv = sys.argv[1:]
if LOG:
    with open(LOG, "a") as f:
        f.write(json.dumps(argv) + "\n")


def load():
    with open(STATE) as f:
        return json.load(f)


if argv and argv[0] == "add":
    with open(STATE, "r+") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        rows = json.load(f)
        rows.append({"project": argv[1], "wd": argv[2], "id": argv[3],
                     "state": "running", "started": "2026-11-02T12:00:00Z"})
        f.seek(0); f.truncate(); json.dump(rows, f)
    sys.exit(0)

if argv and argv[0] == "ps":
    if os.environ.get("STUB_DOCKER_FAIL") == "ps":
        print("Cannot connect to the Docker daemon", file=sys.stderr)
        sys.exit(1)
    args = argv[1:]
    all_ = "-a" in args or "--all" in args
    filters, fmt, i = [], None, 0
    while i < len(args):
        if args[i] == "--filter":
            filters.append(args[i + 1]); i += 2
        elif args[i] == "--format":
            fmt = args[i + 1]; i += 2
        else:
            i += 1
    rows = load()
    for r in rows:
        if not all_ and r["state"] != "running":
            continue
        if "status=running" in filters and r["state"] != "running":
            continue
        labels = {"com.docker.compose.project": r["project"],
                  "com.docker.compose.project.working_dir": r["wd"]}
        if fmt is None:
            print(r["id"]); continue
        out = re.sub(r'\{\{\.Label "([^"]+)"\}\}', lambda m: labels.get(m.group(1), ""), fmt)
        out = out.replace("{{.ID}}", r["id"])
        print(out)
    sys.exit(0)

if argv and argv[0] == "inspect":
    ids = [a for a in argv[1:] if not a.startswith("-") and "{{" not in a]
    byid = {r["id"]: r for r in load()}
    for i in ids:
        if i in byid:
            print(f'{i} {byid[i]["started"]}')
    sys.exit(0)

print(f"stub docker: unsupported {argv}", file=sys.stderr)
sys.exit(64)
