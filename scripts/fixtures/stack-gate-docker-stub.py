#!/usr/bin/env python3
"""`docker` stand-in for scripts/check-stack-gate.sh. Never reaches Docker.

State is a JSON list of containers in $STUB_DOCKER_STATE:
  {"project": str, "wd": str, "id": "<64 hex>",
   "state": "running"|"paused"|"restarting"|"created"|"exited",
   "started": "<RFC 3339>"}
A container may omit "project" (not a compose container). Every call is
appended to $STUB_DOCKER_LOG as one JSON argv list.

Strict like real docker where the gate depends on it:
  ps      accepts only -a/--all, --no-trunc, --filter <f>, --format <t>; any
          other flag exits 64. Without --no-trunc it prints 12-char ids, as
          docker does. Without -a it lists running, paused and restarting
          containers (docker's default); `status=` filters are OR-ed and
          replace that default; `label=<key>` keeps only containers that
          carry the label. --format replaces {{.Label "k"}} and {{.ID}}.
          $STUB_DOCKER_FAIL=ps exits 1.
  inspect --format '{{.Id}} {{.State.StartedAt}}' [--] <id…>: prints the full
          id; a 12-char prefix resolves. $STUB_DOCKER_FAIL=inspect exits 1.
  add <project> <wd> <id>   (not docker) appends a running container; the
          check's start command uses it to model a stack coming up.
  compose [<flag> <value>…] config --no-env-resolution --format json   prints
          the project as JSON,
          with Compose's shape: top-level `name` ($COMPOSE_PROJECT_NAME, so a
          read without the project name finds nothing) and `services`.
          $STUB_COMPOSE_IMAGES is comma-separated: `{p}-web` is a service
          `web` with a `build:` section and no `image:`; `build=<image>` has
          both; any other entry is a pull-only `image:`.
          $STUB_COMPOSE_JSON, when set, is a file printed instead, with
          `{p}` replaced as above. Only this exact form: `--images` exits 64,
          so a gate back on that list goes red.
          $STUB_DOCKER_FAIL=config exits 1 with no stdout;
          $STUB_DOCKER_FAIL=config-late prints the JSON, then exits 1.
  compose [<flag> <value>…] build   appends `start <project> <time>` and
          `end <project> <time>` to $STUB_BUILD_LOG around a sleep of
          $STUB_BUILD_SLEEP seconds, adds the built images to the image
          store, and exits $STUB_BUILD_RC (default 0).
  image inspect [--format <t>] [--] <ref…>   exits 1 unless every ref is in
          the JSON list in $STUB_DOCKER_IMAGES (a missing file is empty).
"""
import json, os, re, sys, time, fcntl

STATE = os.environ["STUB_DOCKER_STATE"]
LOG = os.environ.get("STUB_DOCKER_LOG")
FAIL = os.environ.get("STUB_DOCKER_FAIL", "")
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
    if FAIL == "ps":
        print("Cannot connect to the Docker daemon", file=sys.stderr)
        sys.exit(1)
    args, all_, notrunc, filters, fmt, i = argv[1:], False, False, [], None, 0
    while i < len(args):
        a = args[i]
        if a in ("-a", "--all"):
            all_ = True; i += 1
        elif a == "--no-trunc":
            notrunc = True; i += 1
        elif a == "--filter":
            filters.append(args[i + 1]); i += 2
        elif a == "--format":
            fmt = args[i + 1]; i += 2
        else:
            print(f"unknown flag: {a}", file=sys.stderr)
            sys.exit(64)
    statuses = [f.split("=", 1)[1] for f in filters if f.startswith("status=")]
    labels_req = [f.split("=", 1)[1] for f in filters if f.startswith("label=")]
    for r in load():
        st = r["state"]
        if statuses:
            if st not in statuses:
                continue
        elif not all_ and st not in ("running", "paused", "restarting"):
            continue
        labels = {}
        if "project" in r:
            labels = {"com.docker.compose.project": r["project"],
                      "com.docker.compose.project.working_dir": r.get("wd", "")}
        if any(k not in labels for k in labels_req):
            continue
        cid = r["id"] if notrunc else r["id"][:12]
        if fmt is None:
            print(cid); continue
        out = re.sub(r'\{\{\.Label "([^"]+)"\}\}', lambda m: labels.get(m.group(1), ""), fmt)
        print(out.replace("{{.ID}}", cid))
    sys.exit(0)

if argv and argv[0] == "inspect":
    if FAIL == "inspect":
        print("Error: inspect failed", file=sys.stderr)
        sys.exit(1)
    ids = [a for a in argv[1:] if a != "--format" and "{{" not in a and a != "--"]
    rows = load()
    for i in ids:
        hit = [r for r in rows if r["id"] == i or (len(i) == 12 and r["id"].startswith(i))]
        if not hit:
            print(f"Error: No such object: {i}", file=sys.stderr)
            sys.exit(1)
        print(f'{hit[0]["id"]} {hit[0]["started"]}')
    sys.exit(0)

IMAGES = os.environ.get("STUB_DOCKER_IMAGES", "")


def images():
    if IMAGES and os.path.exists(IMAGES):
        with open(IMAGES) as f:
            return json.load(f)
    return []


if argv[:1] == ["compose"]:
    proj = os.environ.get("COMPOSE_PROJECT_NAME", "")
    services, built = {}, []
    for n, x in enumerate(y for y in os.environ.get("STUB_COMPOSE_IMAGES", "").split(",") if y):
        if x.startswith("build="):
            image = x[len("build="):].replace("{p}", proj)
            services[f"s{n}"] = {"build": {"context": "/app"}, "image": image}
            built.append(image)
        elif x.startswith("{p}-"):
            services[x[len("{p}-"):]] = {"build": {"context": "/app"}}
            built.append(x.replace("{p}", proj))
        else:
            services[f"s{n}"] = {"image": x}
    rest = argv[1:]
    while rest and rest[0].startswith("-"):
        rest = rest[2:]
    if rest == ["config", "--no-env-resolution", "--format", "json"]:
        if FAIL == "config":
            print("config failed", file=sys.stderr)
            sys.exit(1)
        fixture = os.environ.get("STUB_COMPOSE_JSON")
        if fixture:
            with open(fixture) as f:
                print(f.read().replace("{p}", proj))
        else:
            print(json.dumps({"name": proj, "services": services}))
        sys.exit(1 if FAIL == "config-late" else 0)
    if rest == ["build"]:
        blog = os.environ.get("STUB_BUILD_LOG")
        def note(w):
            if blog:
                with open(blog, "a") as f:
                    f.write(f"{w} {proj} {time.time():.3f}\n")
        note("start")
        time.sleep(float(os.environ.get("STUB_BUILD_SLEEP", "0")))
        if IMAGES:
            have = images()
            with open(IMAGES, "w") as f:
                json.dump(sorted(set(have) | set(built)), f)
        note("end")
        sys.exit(int(os.environ.get("STUB_BUILD_RC", "0")))
    print(f"stub docker: unsupported compose {argv}", file=sys.stderr)
    sys.exit(64)

if argv[:2] == ["image", "inspect"]:
    refs, i, a = [], 2, argv
    while i < len(a):
        if a[i] == "--format":
            i += 2
        elif a[i] == "--":
            i += 1
        else:
            refs.append(a[i]); i += 1
    have = images()
    miss = [r for r in refs if r not in have]
    for r in refs:
        if r in have:
            print("sha256:" + r)
    for r in miss:
        print(f"Error response from daemon: No such image: {r}", file=sys.stderr)
    sys.exit(1 if miss or not refs else 0)

print(f"stub docker: unsupported {argv}", file=sys.stderr)
sys.exit(64)
