#!/usr/bin/env python3
# Stub `gh` for scripts/check-orca-lane.sh: answers the two calls
# plugins/cepa/scripts/orca-lane-reflog.sh makes, from a JSON file, and logs
# each argv as one JSON line. Never reaches GitHub. It refuses a `--json` or
# `--jq` other than the ones below, so a typo in the script's field list or
# jq program fails here instead of passing against a stub that ignores it.
#   gh pr list --state all --head <b> --limit 50 --json <PR_FIELDS> --jq <PR_JQ>
#       prints the TSV rows the real --jq would print.
#   gh repo view --json defaultBranchRef --jq .defaultBranchRef.name
# Env: STUB_GH (JSON: {"prs": {branch: [[n, state, base, headRefOid,
#      isCrossRepository], …]}, "default": "main", "fail": bool}), STUB_GH_LOG.
import json, os, sys

PR_FIELDS = "number,state,baseRefName,headRefOid,isCrossRepository"
PR_JQ = '.[] | [.number, .state, .baseRefName, .headRefOid, (.isCrossRepository | tostring)] | @tsv'
argv = sys.argv[1:]
with open(os.environ["STUB_GH_LOG"], "a") as f:
    f.write(json.dumps(argv) + "\n")
try:
    st = json.load(open(os.environ["STUB_GH"]))
except (OSError, ValueError, KeyError):
    st = {}


def opt(n):
    return argv[argv.index(n) + 1] if n in argv else None


if st.get("fail"):
    print("HTTP 502", file=sys.stderr)
    sys.exit(1)
if argv[:2] == ["pr", "list"] and "--head" in argv:
    if opt("--json") != PR_FIELDS or opt("--jq") != PR_JQ or opt("--state") != "all":
        print("stub gh: unexpected --json/--jq/--state %r" % argv, file=sys.stderr)
        sys.exit(2)
    for n, state, base, head, cross in st.get("prs", {}).get(opt("--head"), []):
        print("%d\t%s\t%s\t%s\t%s" % (n, state, base, head, "true" if cross else "false"))
    sys.exit(0)
if argv[:2] == ["repo", "view"]:
    if opt("--json") != "defaultBranchRef" or opt("--jq") != ".defaultBranchRef.name":
        sys.exit(2)
    print(st.get("default", "main"))
    sys.exit(0)
print("stub gh does not know %r" % argv[:2], file=sys.stderr)
sys.exit(1)
