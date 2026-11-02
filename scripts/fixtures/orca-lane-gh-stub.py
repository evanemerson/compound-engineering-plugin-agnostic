#!/usr/bin/env python3
# Stub `gh` for scripts/check-orca-lane.sh: answers the two calls
# plugins/cepa/scripts/orca-lane-reflog.sh makes, from a JSON file, and logs
# each argv as one JSON line. Never reaches GitHub.
#   gh pr list --state all --head <b> ... --jq …   prints the TSV rows the
#       real --jq would print: <number>\t<state>\t<mergedAt or ->.
#   gh repo view --json defaultBranchRef --jq …    prints the default branch.
# Env: STUB_GH (JSON: {"prs": {branch: [[n, state, mergedAt|null], …]},
#      "default": "main", "fail": bool}), STUB_GH_LOG.
import json, os, sys

argv = sys.argv[1:]
with open(os.environ["STUB_GH_LOG"], "a") as f:
    f.write(json.dumps(argv) + "\n")
try:
    st = json.load(open(os.environ["STUB_GH"]))
except (OSError, ValueError, KeyError):
    st = {}
if st.get("fail"):
    print("HTTP 502", file=sys.stderr)
    sys.exit(1)
if argv[:2] == ["pr", "list"] and "--head" in argv:
    b = argv[argv.index("--head") + 1]
    for n, state, at in st.get("prs", {}).get(b, []):
        print("%d\t%s\t%s" % (n, state, at or "-"))
    sys.exit(0)
if argv[:2] == ["repo", "view"]:
    print(st.get("default", "main"))
    sys.exit(0)
print("stub gh does not know %r" % argv[:2], file=sys.stderr)
sys.exit(1)
