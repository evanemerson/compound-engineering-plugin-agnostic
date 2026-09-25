#!/usr/bin/env python3
"""
capture.py — the business/planning producer for the OB1 brain.

The third of three pipes:

    /cepa:compound   engineering knowledge IN   (built)
    capture.py       business knowledge IN      (this file)
    bundle.py        curated knowledge OUT      (not built)

WHAT IT DOES
    Walks a client folder under C:\\Users\\evan\\ClaudeWork\\<Client>\\ (or its
    WSL equivalent), finds explicitly-marked `brain` blocks in markdown files,
    and writes their atoms to the brain under project_id = THE CLIENT, so a
    single recall returns both the engineering half (from the repo) and the
    business half (from ClaudeWork).

WHAT IT DELIBERATELY DOES NOT DO
    It does not read your prose and decide what matters. That was considered
    and rejected: an extractor that re-derives atoms from prose produces
    slightly different strings on every run, every run changes the content
    hash, and OB1 writeback is row-positional with no upsert -- so every run
    would mark_stale and rewrite the whole document. Unbounded row growth,
    paid embedding per rewritten atom. See "THE CHURN CONSTRAINT" below.

    Instead, atoms are authored once, explicitly, in the document. They are
    stable because a human (or an agent, once) wrote them and nothing
    regenerates them. capture.py is a dumb, deterministic transport.

THE BLOCK FORMAT
    Anywhere in a markdown file, a fenced block with the info string `brain`:

        ```brain
        kind: decision
        date: 2026-08-11
        decisions:
          - Flat-rate membership pricing beat per-visit for the pilot cohort.
          - Launch is gated on the CFO review, not on engineering.
        constraints:
          - No new vendor security review will be approved before Q4.
        unresolved_questions:
          - Whether the pilot cohort can be expanded without a new contract.
        ```

    It renders as a visible code block in UpNote, GitHub and any markdown
    reader, which is the point -- you can see what you are publishing.
    Find them all with:  grep -rl '^```brain' .

    Recognised keys: the seven string-array memory types plus `kind` and
    `date`. Anything else is an error, not a warning.

        decisions  outputs  lessons  constraints
        unresolved_questions  next_steps  failures

    The schema has two more keys that this format deliberately refuses:

      entities   is z.record(string, string[]), and -- the part that matters --
                 memoryRows() never reads it. Entities produce no memory rows
                 and never return from a recall. A write would succeed and the
                 content would silently disappear. Put the sentence in lessons.
      artifacts  is an array of {kind, uri, description} objects. The document
                 is already in source_refs; there is nothing to add.

    One server-side behaviour worth knowing: next_steps atoms are stored with a
    "Next step: " prefix prepended by the API, so the stored row reads
    "Next step: [research 2026-07-18] Verify ...". And a payload that yields
    zero rows is rejected with a 400, not silently accepted.

EVERY ATOM MUST STAND ALONE
    Recall returns atoms, not documents. Two atoms written side by side in one
    block can come back separately, weeks apart, next to atoms from a different
    repo. There is nowhere to record that one depends on another:
    memory_payload values are plain string arrays with no fields, and
    source_refs is not returned at all (see below). No weights. No edges.

    So if atom B is only true given atom A, A must appear INSIDE B's text.

    Wrong -- the decision can surface without its premise:
        decisions:
          - Position on the audited write-agent.
        unresolved_questions:
          - Whether the audit trail is real in the shipped product.

    Right -- the caveat travels with the claim it qualifies:
        decisions:
          - Position on the audited write-agent. The audit-trail half of this
            is unverified in the shipped product.

    This is the same reason the [biz] prefix exists. The atom string is the
    only channel that survives a recall, so everything a reader needs has to
    be in it.

THE ATOM PREFIX -- why atoms carry [biz] in their text
    The obvious design was to tag the halves with source_refs.kind
    ("solution-doc" vs "business-doc") and filter at recall. That does not
    work. From the CEPA brain skill spec, verbatim:

        The `source_refs` written at writeback are stored server-side but
        never projected into the recall response, and `source.uri` is always
        null -- so the provenance repo a consumer filters on is
        `scope.project_id`, and a cross-repo hit CANNOT carry its originating
        doc path or blob SHA.

    So the only two channels that survive a recall are `scope.project_id` and
    the atom string itself. If you want to know at recall time whether an atom
    came from the code half or the business half, it has to be in the text.
    Hence the prefix. It is short, stable, and greppable.

    source_refs is still populated correctly -- it is stored server-side and
    it is how C2 (hard-delete remediation) will locate rows to purge. It is
    just not a recall-time discriminator.

THE CHURN CONSTRAINT
    Three guards, all implemented here:
      1. Content-hash gating -- a document whose block content is unchanged
         since the last successful write is skipped entirely.
      2. Few atoms -- --max-atoms (default 12) refuses a document that emits
         more. If you need more than twelve atoms from one business document,
         the document is the wrong unit.
      3. Cadence decoupling is your cron's job, not this script's. Run files
         hourly if you like; run capture.py daily.

SAFETY POSTURE
      * Dry run by default. --write is required to touch the brain.
      * PHI scrub is opt-OUT, not opt-in. It runs unless you pass --no-scrub.
      * dpc-pro is refused outright. Scrub redacts numeric patterns only
        (SSN, MRN-shaped runs, DOB) -- it does NOT redact names, and business
        documents are made of names. C2 is not built, so a mistake cannot be
        fully retracted. Pilot on helm or artist360.
      * The participant registry is checked first, fail-closed.

USAGE
    python3 capture.py --project helm --root ~/ClaudeWork/Helm
    python3 capture.py --project helm --root ~/ClaudeWork/Helm --write

REQUIREMENTS
    Python 3.9+, stdlib only. brain-client.sh on PATH or via --brain-client.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

# --------------------------------------------------------------------------
# Contract constants. These mirror plugins/cepa/skills/brain/SKILL.md.
# Do not add keys here without checking the spec -- an unknown key 400s.
# --------------------------------------------------------------------------

# Verified against the LIVE Edge Function, OB1
# supabase/functions/agent-memory-api/index.ts, memoryPayloadSchema.
# These seven are z.array(z.string()). Order matches memoryRows() so the
# printed output and the stored rows read in the same sequence.
MEMORY_KEYS = (
    "decisions",
    "outputs",
    "lessons",
    "constraints",
    "unresolved_questions",
    "next_steps",
    "failures",
)

# The schema has two more keys. Neither is a string array, and neither belongs
# in this block format. Rejected by name with the reason, because both fail in
# ways that are hard to notice later.
UNSUPPORTED_KEYS = {
    "entities": (
        "entities is z.record(string, string[]) -- {\"topics\": [...], \"people\": [...]} -- "
        "not a list of sentences. More important: memoryRows() in the Edge Function "
        "never reads it, so entities produce NO memory rows and never come back from "
        "a recall. A write would succeed and the content would silently vanish. "
        "Put the sentence in lessons or outputs instead."
    ),
    "artifacts": (
        "artifacts is an array of objects {kind, uri, description?}, which this flat "
        "block format cannot express. The document itself is already recorded in "
        "source_refs, so there is nothing to add here."
    ),
}

META_KEYS = ("kind", "date", "provenance")

# Maps the block's `provenance:` value to the writeback envelope's
# provenance.default_status. rankMemory() in the Edge Function scores
# user_confirmed at 0.30 and generated at 0.05, so this is the single biggest
# lever on whether an atom surfaces in a busy recall.
#
# Only default_status changes. requires_review stays true and
# can_use_as_instruction stays false: the governance rule is that memories are
# evidence, never instructions, and saying "a person wrote this" is not the
# same as saying "act on it unreviewed."
PROVENANCE = {
    "generated": "generated",   # default -- an agent drafted the block
    "confirmed": "user_confirmed",  # you wrote or reviewed these atoms yourself
}

WRITEBACK_SCHEMA = "openbrain.agent_memory.writeback.v1"

# source_refs elements REQUIRE a `kind` field -- an object without one 400s.
VALID_KINDS = ("business-doc", "meeting", "decision", "plan", "research")
DEFAULT_KIND = "business-doc"

# Short, stable prefixes stamped into each atom's text. Changing these
# rewrites every atom in the brain -- treat them as a schema.
KIND_PREFIX = {
    "business-doc": "biz",
    "meeting": "meeting",
    "decision": "decision",
    "plan": "plan",
    "research": "research",
}

# Refused outright. See SAFETY POSTURE.
PHI_FORCED_PROJECTS = {"dpc-pro"}

BLOCK_RE = re.compile(r"^```brain[ \t]*$(.*?)^```[ \t]*$", re.MULTILINE | re.DOTALL)

STATE_DIR = Path(
    os.environ.get("CAPTURE_STATE_DIR", Path.home() / ".local" / "state" / "capture")
)


class CaptureError(Exception):
    """A condition that should stop the run. Always fail closed."""


# --------------------------------------------------------------------------
# Block parsing
#
# This is a strict subset of YAML, hand-parsed on purpose: zero dependencies,
# and a bad block gets a precise error with a line number instead of a
# stack trace from a general-purpose parser.
#
# Grammar:
#     key: scalar          (metadata: kind, date)
#     key:                 (memory type, followed by list items)
#       - one-line atom
# --------------------------------------------------------------------------


def parse_block(body: str, where: str) -> dict[str, Any]:
    result: dict[str, Any] = {}
    current: str | None = None

    for lineno, raw in enumerate(body.splitlines(), start=1):
        line = raw.rstrip()
        if not line.strip() or line.strip().startswith("#"):
            continue

        stripped = line.lstrip()
        indent = len(line) - len(stripped)

        if stripped.startswith("- "):
            if current is None:
                raise CaptureError(
                    f"{where}, block line {lineno}: list item before any key"
                )
            atom = stripped[2:].strip()
            if not atom:
                raise CaptureError(f"{where}, block line {lineno}: empty list item")
            if atom.startswith(("'", '"')) and atom.endswith(("'", '"')) and len(atom) > 1:
                atom = atom[1:-1]
            result[current].append(atom)
            continue

        if indent != 0:
            raise CaptureError(
                f"{where}, block line {lineno}: unexpected indentation -- keys must be "
                f"flush left and list items indented with '- '"
            )

        if ":" not in stripped:
            raise CaptureError(f"{where}, block line {lineno}: expected 'key:' -- got {stripped!r}")

        key, _, rest = stripped.partition(":")
        key = key.strip()
        rest = rest.strip()

        if key in META_KEYS:
            if not rest:
                raise CaptureError(f"{where}, block line {lineno}: '{key}:' needs a value")
            if key == "provenance" and rest not in PROVENANCE:
                raise CaptureError(
                    f"{where}, block line {lineno}: provenance {rest!r} must be one of "
                    f"{', '.join(PROVENANCE)}"
                )
            result[key] = rest
            current = None
        elif key in MEMORY_KEYS:
            if rest:
                raise CaptureError(
                    f"{where}, block line {lineno}: '{key}:' takes a list, not an inline "
                    f"value -- put each atom on its own '- ' line"
                )
            result.setdefault(key, [])
            current = key
        elif key in UNSUPPORTED_KEYS:
            raise CaptureError(
                f"{where}, block line {lineno}: {key!r} is not supported.\n  "
                + UNSUPPORTED_KEYS[key]
            )
        else:
            raise CaptureError(
                f"{where}, block line {lineno}: unknown key {key!r}. "
                f"Valid: {', '.join(META_KEYS + MEMORY_KEYS)}"
            )

    return result


def find_blocks(path: Path) -> list[dict[str, Any]]:
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError as exc:
        raise CaptureError(f"{path}: not valid UTF-8 ({exc})") from exc

    blocks = []
    for match in BLOCK_RE.finditer(text):
        line = text[: match.start()].count("\n") + 1
        blocks.append(parse_block(match.group(1), f"{path} (brain block starting line {line})"))
    return blocks


# --------------------------------------------------------------------------
# Provenance
# --------------------------------------------------------------------------


def blob_sha(path: Path) -> str:
    """
    Git blob SHA when the file is inside a work tree, so the uri matches what
    the engineering half writes. Otherwise sha256 of the bytes, tagged so the
    two are never confused.

    ClaudeWork folders are not all git repos -- that is expected, not an error.
    """
    if shutil.which("git"):
        try:
            out = subprocess.run(
                ["git", "hash-object", str(path)],
                cwd=path.parent,
                capture_output=True,
                text=True,
                timeout=30,
                check=False,
            )
            if out.returncode == 0 and out.stdout.strip():
                return out.stdout.strip()
        except (OSError, subprocess.SubprocessError):
            pass
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    return f"sha256-{digest[:40]}"


def source_uri(project: str, relpath: str, sha: str) -> str:
    # Convention from the spec: pack repo+path+blob-SHA so provenance
    # survives file moves.
    return f"{project}:{relpath}@{sha}"


# --------------------------------------------------------------------------
# Payload
# --------------------------------------------------------------------------


def atom_prefix(kind: str, date: str | None) -> str:
    tag = KIND_PREFIX.get(kind, kind)
    return f"[{tag} {date}] " if date else f"[{tag}] "


def build_payload(
    project: str,
    workspace_id: str,
    docs: list[dict[str, Any]],
) -> dict[str, Any]:
    """
    memory_payload is an object keyed by memory type whose values are PLAIN
    STRING ARRAYS -- not objects, no per-atom type field. An atom is a string.
    """
    memory_payload: dict[str, list[str]] = {}
    source_refs: list[dict[str, str]] = []

    for doc in docs:
        prefix = atom_prefix(doc["kind"], doc.get("date"))
        for key in MEMORY_KEYS:
            for atom in doc["atoms"].get(key, []):
                memory_payload.setdefault(key, []).append(prefix + atom)
        source_refs.append({"kind": doc["kind"], "uri": doc["uri"]})

    # provenance is payload-level, not per-document. If one document in the
    # batch was agent-drafted, the whole payload drops to "generated" -- the
    # conservative direction, and it keeps the claim honest.
    status = (
        "user_confirmed"
        if docs and all(d.get("provenance") == "confirmed" for d in docs)
        else "generated"
    )

    return {
        "schema_version": WRITEBACK_SCHEMA,
        "workspace_id": workspace_id,
        "project_id": project,
        "memory_payload": memory_payload,
        "source_refs": source_refs,
        "provenance": {"default_status": status},
    }


def payload_hash(payload: dict[str, Any]) -> str:
    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


# --------------------------------------------------------------------------
# brain-client.sh
#
# Everything that touches the brain goes through this one binary. There is no
# HTTP client in this file and there must never be one: a second client is a
# second place for the envelope, the auth, the scrub and the registry filter
# to drift out of sync.
# --------------------------------------------------------------------------


# Set once in main(). Every brain-client call inherits it.
#
# WHY THIS EXISTS. brain-client.sh resolves both of its config files RELATIVE
# TO THE CURRENT DIRECTORY:
#
#     _load_env:     local envf="${BRAIN_ENV_FILE:-.env.local}"
#     participants:  _root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
#                    _sib="$(dirname "$_root")/brain-ops/brain-participants.tsv"
#
# That works when you run it from inside ~/webapps/<repo>, because the sibling
# ~/webapps/brain-ops is then one level up. capture.py runs with a ClaudeWork
# folder as its working directory. ClaudeWork folders are not git repos and
# have no .env.local, so BOTH lookups fail and every call dies on
# "BRAIN_URL not set" or exits 3.
#
# Setting both variables to absolute paths makes the working directory
# irrelevant, which is what we want for something that runs from cron.
_CLIENT_ENV: dict[str, str] = {}


def run_client(client: Path, args: list[str], timeout: int = 120) -> subprocess.CompletedProcess:
    env = os.environ.copy()
    env.update(_CLIENT_ENV)
    return subprocess.run(
        [str(client), *args],
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
        env=env,
    )


def check_participant(client: Path, project: str) -> None:
    """
    Fail closed. The exit codes are documented in brain-client.sh itself:

        0 + rows   registry resolved
        0 + EMPTY  resolved, but no active/retracted repos -> drop everything
        2          BRAIN_PARTICIPANTS_FILE set but unreadable (config error)
        3          manifest unresolved -> the recall side degrades; we refuse

    brain-client greps the manifest down to exactly `<id>\t(active|retracted)`
    before emitting it, dropping comments, blanks, CR-tainted and malformed
    lines at the relay point. So the tab split below is safe: anything that is
    not that shape never reaches us.
    """
    proc = run_client(client, ["participants"])

    if proc.returncode == 2:
        raise CaptureError(
            "participants exited 2 — BRAIN_PARTICIPANTS_FILE is set but is not "
            "a readable file. That is a config error, not a degrade.\n  "
            + proc.stderr.strip()
        )
    if proc.returncode == 3:
        raise CaptureError(
            "participants exited 3 — the manifest did not resolve. Refusing to "
            "write. Set BRAIN_PARTICIPANTS_FILE, or run from a repo that has "
            "brain-ops as a sibling."
        )
    if proc.returncode != 0:
        raise CaptureError(
            f"participants failed (exit {proc.returncode}): {proc.stderr.strip()}"
        )

    status: dict[str, str] = {}
    for line in proc.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) == 2:
            status[parts[0]] = parts[1]

    if not status:
        raise CaptureError(
            "the registry resolved but lists no repos (exit 0, empty output). "
            "Every project_id counts as absent. Refusing to write."
        )

    actual = status.get(project)
    if actual is None:
        raise CaptureError(
            f"project_id {project!r} is not in the registry. "
            f"Listed: {', '.join(sorted(status))}."
        )
    if actual != "active":
        raise CaptureError(
            f"project_id {project!r} is {actual!r}, not 'active'.\n"
            f"A retracted repo was pulled OUT of the brain deliberately. "
            f"Writing new atoms into it would undo that."
        )


def scrub_atoms(client: Path, docs: list[dict[str, Any]]) -> int:
    """
    Scrub the AUTHOR-WRITTEN atom text and nothing else.

    An earlier version scrubbed the whole payload JSON. That was wrong, and the
    first real dry run showed why: the redactor treats any YYYY-MM-DD as a date
    of birth, and capture.py generates two things that contain one --

        the atom prefix          [research 2026-07-18] ...
        the provenance uri       helm:.../2026-07-18-06-dual-differentiation.md@<sha>

    Redacting those corrupts every atom and breaks the uri that C2 needs to find
    rows for hard deletion. The scrub exists to protect content a person wrote,
    not metadata this script generated, so metadata now bypasses it entirely:
    atoms are scrubbed BEFORE prefixes are applied and the envelope is never
    passed through at all.

    Atoms are single-line by construction (the block parser rejects anything
    else), so one atom per line round-trips safely. The line count is checked
    anyway -- a redactor that changed it would silently misalign every atom.

    Returns the number of atoms the scrub changed.
    """
    items: list[tuple[dict[str, Any], str, int, str]] = []
    for doc in docs:
        for key, atoms in doc["atoms"].items():
            for i, atom in enumerate(atoms):
                items.append((doc, key, i, atom))
    if not items:
        return 0

    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        infile = tmp / "atoms.txt"
        outfile = tmp / "atoms.scrubbed.txt"
        infile.write_text(
            "\n".join(atom for *_, atom in items) + "\n", encoding="utf-8"
        )
        proc = run_client(client, ["scrub", str(infile), str(outfile)])
        if proc.returncode != 0:
            raise CaptureError(
                f"scrub failed (exit {proc.returncode}): {proc.stderr.strip()}"
            )
        if not outfile.exists():
            raise CaptureError("scrub reported success but wrote no output file")
        lines = outfile.read_text(encoding="utf-8").splitlines()

    if len(lines) != len(items):
        raise CaptureError(
            f"scrub returned {len(lines)} lines for {len(items)} atoms. "
            f"Refusing to write -- the atoms would be misaligned."
        )

    changed = 0
    for (doc, key, index, original), scrubbed in zip(items, lines):
        if scrubbed != original:
            changed += 1
            print(f"\n  REDACTED  {doc['relpath']}  {key}[{index}]")
            print(f"    was: {original}")
            print(f"    now: {scrubbed}")
            doc["atoms"][key][index] = scrubbed
    return changed


def make_idkey(client: Path, project: str, docpath: str, payload_file: Path) -> str | None:
    proc = run_client(client, ["idkey", project, docpath, str(payload_file)])
    if proc.returncode != 0:
        return None
    return proc.stdout.strip() or None


def writeback(client: Path, payload_file: Path) -> list[str]:
    proc = run_client(client, ["writeback", str(payload_file)], timeout=300)
    if proc.returncode != 0:
        # brain-client's curl config sets `fail-with-body`, so on a 400 the
        # server's explanation arrives on STDOUT while curl's own one-line
        # complaint goes to STDERR.
        #
        # The first version of this line was `proc.stderr.strip() or
        # proc.stdout.strip()`. stderr is never empty on a curl failure, so the
        # `or` short-circuited and threw away the body -- the only part that
        # says WHY. Print both, always.
        detail = []
        if proc.stderr.strip():
            detail.append(f"curl:          {proc.stderr.strip()}")
        if proc.stdout.strip():
            detail.append(f"response body: {proc.stdout.strip()}")
        else:
            detail.append("response body: (empty)")
        raise CaptureError(
            f"writeback failed (exit {proc.returncode})\n  " + "\n  ".join(detail)
        )
    try:
        body = json.loads(proc.stdout)
    except json.JSONDecodeError:
        print("warning: writeback succeeded but the response was not JSON; "
              "cannot promote review status", file=sys.stderr)
        return []
    ids = [m["memory_id"] for m in body.get("memories", []) if m.get("memory_id")]
    print(f"writeback accepted {len(ids)} memor{'y' if len(ids) == 1 else 'ies'}")
    return ids


def promote(client: Path, memory_ids: list[str]) -> None:
    """
    Move each new memory from `pending` review to `evidence_only`.

    This was step 6 of the original design and it was missing. Without it every
    atom sits at review_status "pending", which rankMemory() penalises by 0.08
    where evidence_only earns 0.05 -- so a freshly written memory ranks below
    one that has simply been acknowledged.

    `evidence_only`, never `confirm`: the governance rule is that these are
    reportable evidence, not local findings.

    A failure here is reported, never fatal. The write already happened, so the
    state file must still be saved or the next run rewrites all of it.
    """
    failed = []
    for mid in memory_ids:
        proc = run_client(client, ["review", mid, "evidence_only"])
        if proc.returncode != 0:
            failed.append((mid, proc.stderr.strip() or proc.stdout.strip()))
    ok = len(memory_ids) - len(failed)
    print(f"promoted {ok}/{len(memory_ids)} to evidence_only")
    for mid, err in failed:
        print(f"  FAILED {mid}: {err}", file=sys.stderr)


# --------------------------------------------------------------------------
# State -- the content-hash gate
# --------------------------------------------------------------------------


def state_path(project: str) -> Path:
    return STATE_DIR / f"{project}.json"


def load_state(project: str) -> dict[str, str]:
    path = state_path(project)
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        print(f"warning: {path} is corrupt, treating as empty", file=sys.stderr)
        return {}


def save_state(project: str, state: dict[str, str]) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    path = state_path(project)
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(state, indent=2, sort_keys=True), encoding="utf-8")
    tmp.replace(path)


# --------------------------------------------------------------------------
# Collection
# --------------------------------------------------------------------------


def collect(root: Path, project: str, max_atoms: int) -> list[dict[str, Any]]:
    docs = []
    for path in sorted(root.rglob("*.md")):
        if any(part.startswith(".") for part in path.relative_to(root).parts):
            continue

        blocks = find_blocks(path)
        if not blocks:
            continue

        relpath = path.relative_to(root).as_posix()
        merged: dict[str, list[str]] = {}
        kind = DEFAULT_KIND
        date = None
        provenance = "generated"

        for block in blocks:
            if "provenance" in block:
                provenance = block["provenance"]
            if "kind" in block:
                kind = block["kind"]
                if kind not in VALID_KINDS:
                    raise CaptureError(
                        f"{relpath}: kind {kind!r} is not one of {', '.join(VALID_KINDS)}"
                    )
            if "date" in block:
                date = block["date"]
                if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", date):
                    raise CaptureError(
                        f"{relpath}: date {date!r} must be YYYY-MM-DD "
                        f"(it goes into the atom text and must never drift)"
                    )
            for key in MEMORY_KEYS:
                if key in block:
                    merged.setdefault(key, []).extend(block[key])

        total = sum(len(v) for v in merged.values())
        if total == 0:
            print(f"  skip  {relpath} (brain block present but empty)")
            continue
        if total > max_atoms:
            raise CaptureError(
                f"{relpath}: {total} atoms exceeds --max-atoms {max_atoms}. "
                f"Emit fewer, more durable atoms, or split the document. "
                f"High atom counts are what make writeback churn expensive."
            )

        docs.append(
            {
                "path": path,
                "relpath": relpath,
                "kind": kind,
                "date": date,
                "atoms": merged,
                "provenance": provenance,
                "uri": source_uri(project, relpath, blob_sha(path)),
                "count": total,
            }
        )
    return docs


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Write business/planning atoms from a ClaudeWork folder into the brain.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--project", required=True, help="project_id -- THE CLIENT, not the repo")
    parser.add_argument("--root", required=True, type=Path, help="ClaudeWork folder for that client")
    parser.add_argument("--write", action="store_true", help="actually write (default is a dry run)")
    parser.add_argument("--no-scrub", action="store_true", help="disable PHI scrub (opt-out; refused on PHI-forced projects)")
    parser.add_argument("--force", action="store_true", help="ignore the content-hash gate")
    parser.add_argument(
        "--no-promote",
        action="store_true",
        help="skip the review->evidence_only promotion after a successful write",
    )
    parser.add_argument(
        "--payload-out",
        type=Path,
        default=None,
        help="also write the exact payload sent to this path, for debugging a rejection",
    )
    parser.add_argument("--max-atoms", type=int, default=12, help="per-document atom ceiling (default 12)")
    parser.add_argument("--brain-client", type=Path, default=None, help="path to brain-client.sh")
    parser.add_argument(
        "--brain-env",
        type=Path,
        default=Path("~/webapps/compound-engineering/.env.local"),
        help="absolute path to .env.local (exported as BRAIN_ENV_FILE)",
    )
    parser.add_argument(
        "--participants-file",
        type=Path,
        default=Path("~/webapps/brain-ops/brain-participants.tsv"),
        help="absolute path to the registry (exported as BRAIN_PARTICIPANTS_FILE)",
    )
    parser.add_argument("--workspace-id", default=os.environ.get("BRAIN_WORKSPACE_ID"), help="defaults to $BRAIN_WORKSPACE_ID")
    parser.add_argument(
        "--with-idkey",
        action="store_true",
        help="attach an idempotency_key to the envelope. UNVERIFIED -- see notes at the bottom of this file.",
    )
    args = parser.parse_args(argv)

    try:
        project = args.project.strip()

        if project in PHI_FORCED_PROJECTS:
            raise CaptureError(
                f"{project} is refused by design.\n"
                f"  * brain-client scrub redacts numeric patterns only -- NOT names.\n"
                f"  * Business documents are made of names.\n"
                f"  * C2 (hard-delete remediation) is not built, so a mistake cannot\n"
                f"    be fully retracted; the registry filter hides but does not erase.\n"
                f"Build C2 first. Pilot on helm or artist360."
            )
        if args.no_scrub and project in PHI_FORCED_PROJECTS:
            raise CaptureError("--no-scrub is not permitted on a PHI-forced project")

        root = args.root.expanduser().resolve()
        if not root.is_dir():
            raise CaptureError(f"--root {root} is not a directory")

        # Resolution order: explicit flag, then the sibling of this script, then
        # PATH. The sibling comes before PATH on purpose -- capture.py is
        # installed next to brain-client.sh, so the sibling is guaranteed to be
        # the same version of the contract this script was written against.
        #
        # The earlier version of these lines was:
        #     client = args.brain_client or Path(shutil.which(...) or "")
        #     if not client or not Path(client).exists(): raise ...
        # When `which` found nothing that becomes Path(""), which is PosixPath(".")
        # -- truthy, and it exists, because "." is the current directory. So the
        # guard passed and `client` silently resolved to the working directory.
        # Every call then tried to execute a directory. Check is_file() and the
        # executable bit, never just exists().
        if args.brain_client is not None:
            client = args.brain_client
        else:
            sibling = Path(__file__).resolve().parent / "brain-client.sh"
            if sibling.is_file():
                client = sibling
            else:
                found = shutil.which("brain-client.sh")
                if not found:
                    raise CaptureError(
                        f"brain-client.sh not found. Looked beside this script "
                        f"({sibling}) and on PATH. Pass --brain-client, or install "
                        f"capture.py next to brain-client.sh. This script will not "
                        f"talk to the brain any other way."
                    )
                client = Path(found)

        client = Path(client).expanduser().resolve()
        if not client.is_file():
            raise CaptureError(f"--brain-client {client} is not a file")
        if not os.access(client, os.X_OK):
            raise CaptureError(f"--brain-client {client} is not executable")

        brain_env = args.brain_env.expanduser().resolve()
        if not brain_env.is_file():
            raise CaptureError(
                f"--brain-env {brain_env} is not a file. brain-client.sh resolves "
                f".env.local against the CURRENT DIRECTORY, so capture.py must "
                f"point at it explicitly."
            )
        participants_file = args.participants_file.expanduser().resolve()
        if not participants_file.is_file():
            raise CaptureError(f"--participants-file {participants_file} is not a file")

        _CLIENT_ENV["BRAIN_ENV_FILE"] = str(brain_env)
        _CLIENT_ENV["BRAIN_PARTICIPANTS_FILE"] = str(participants_file)

        workspace_id = args.workspace_id
        if not workspace_id:
            # brain-client.sh sources .env.local for its own calls, but capture.py
            # needs the workspace id to build the envelope before handing it over.
            # Read it from the same file rather than making the caller repeat a
            # value that is already sitting there.
            try:
                for line in brain_env.read_text(encoding="utf-8").splitlines():
                    line = line.strip()
                    if line.startswith("BRAIN_WORKSPACE_ID="):
                        workspace_id = line.split("=", 1)[1].strip().strip("\"'")
                        break
            except OSError as exc:
                raise CaptureError(f"could not read {brain_env}: {exc}") from exc
        if not workspace_id:
            raise CaptureError(
                f"no workspace id. Pass --workspace-id, export BRAIN_WORKSPACE_ID, "
                f"or add a BRAIN_WORKSPACE_ID= line to {brain_env}."
            )

        print(f"project   {project}")
        print(f"root      {root}")
        print(f"client    {client}")
        print(f"env file  {brain_env}")
        print(f"registry  {participants_file}")
        print(f"mode      {'WRITE' if args.write else 'dry run'}")
        print(f"scrub     {'OFF (--no-scrub)' if args.no_scrub else 'on'}")
        print()

        docs = collect(root, project, args.max_atoms)
        if not docs:
            print("no brain blocks found -- nothing to do")
            print("(add a ```brain block to a markdown file; see the docstring)")
            return 0

        state = load_state(project)
        fresh = []
        for doc in docs:
            single = build_payload(project, workspace_id, [doc])
            digest = payload_hash(single)
            if not args.force and state.get(doc["relpath"]) == digest:
                print(f"  skip  {doc['relpath']} (unchanged)")
                continue
            doc["digest"] = digest
            fresh.append(doc)
            print(f"  take  {doc['relpath']}  [{doc['kind']}]  {doc['count']} atoms")

        if not fresh:
            print("\nnothing changed since the last write")
            return 0

        # Scrub before prefixes are applied, and before the payload exists.
        # Dry run scrubs too, so what you read is exactly what gets sent.
        if args.no_scrub:
            print("\nWARNING: scrub disabled. You are asserting no PHI in these documents.")
        else:
            n = scrub_atoms(client, fresh)
            if n:
                print(f"\nscrub changed {n} atom(s) -- read the diffs above before writing")

        payload = build_payload(project, workspace_id, fresh)
        total = sum(len(v) for v in payload["memory_payload"].values())

        print(f"\n{total} atoms across {len(fresh)} document(s)")
        for key in MEMORY_KEYS:
            atoms = payload["memory_payload"].get(key, [])
            if atoms:
                print(f"\n  {key}:")
                for atom in atoms:
                    print(f"    - {atom}")

        if not args.write:
            print("\n--- payload (dry run, nothing sent) ---")
            print(json.dumps(payload, indent=2))
            print("\nre-run with --write to send this to the brain")
            return 0

        check_participant(client, project)

        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            final = tmp / "payload.json"
            final.write_text(json.dumps(payload, indent=2), encoding="utf-8")

            if args.payload_out:
                keep = args.payload_out.expanduser().resolve()
                keep.write_text(json.dumps(payload, indent=2), encoding="utf-8")
                print(f"payload written to {keep}")

            if args.with_idkey:
                key = make_idkey(client, project, fresh[0]["relpath"], final)
                if key:
                    doc = json.loads(final.read_text(encoding="utf-8"))
                    doc["idempotency_key"] = key
                    final.write_text(json.dumps(doc, indent=2), encoding="utf-8")
                    print(f"idempotency_key {key}")
                else:
                    print("warning: idkey failed, continuing without it", file=sys.stderr)

            memory_ids = writeback(client, final)
            if memory_ids and not args.no_promote:
                promote(client, memory_ids)

        for doc in fresh:
            state[doc["relpath"]] = doc["digest"]
        save_state(project, state)
        print(f"\nwrote {total} atoms; state saved to {state_path(project)}")
        return 0

    except CaptureError as exc:
        print(f"\nerror: {exc}", file=sys.stderr)
        return 1
    except subprocess.TimeoutExpired as exc:
        print(f"\nerror: brain-client.sh timed out: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    sys.exit(main())

# --------------------------------------------------------------------------
# UNVERIFIED, VERIFY BEFORE RELYING ON IT
#
# 1. --with-idkey places `idempotency_key` at the top level of the writeback
#    envelope. The spec documents that brain-client.sh HAS an idkey subcommand
#    but does not state where the resulting key belongs in the payload, or
#    whether /writeback honours it at all. It is off by default for that
#    reason. Confirm against the OB1 Edge Function before turning it on --
#    an unrecognised top-level key may 400.
#
# 2. brain-client.sh idkey hashes the whole PAYLOAD FILE, so the key is
#    document-granular, not atom-granular:
#        <repo>:<docpath>:<sha256(file)[:12]>
#    Change one atom and the key for the entire document changes. It does not
#    solve row-positional churn on its own. Atom-granular keys would mean one
#    payload file per atom, which is a different call shape than /writeback
#    appears to accept.
#
# 3. VERIFIED 2026-09-12, no longer an assumption. brain-client.sh emits
#    exactly `<project_id>\t(active|retracted)` and greps out everything else
#    before it reaches us, so the tab split is safe. Two consequences that
#    were NOT obvious and are now handled above:
#      - `retracted` rows ARE emitted. Reading only column 1 would let
#        capture.py write into a repo that was deliberately pulled out of the
#        brain. It now requires column 2 == "active".
#      - Both config files resolve against the CURRENT DIRECTORY, not the
#        script. capture.py exports BRAIN_ENV_FILE and BRAIN_PARTICIPANTS_FILE
#        as absolute paths so cwd stops mattering.
#
# 4. brain-client.sh's own help text says `idkey <repo> <docpath> <index>`
#    while the implementation requires $3 to be an existing FILE and sha256s
#    its contents. The help text is wrong. Worth a one-line fix upstream.
# --------------------------------------------------------------------------
