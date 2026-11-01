# Residuals — refactor/roles/send-block-stdin (L38)

## 2026-10-31 — tab21@roles, implementation

- [ ] P3 — `plugins/cepa/skills/autonomy/SKILL.md` §12b rule 8 block — `bash "$CEPA_ROOT/scripts/orca-health.sh" "<cli>"` (and its `ack` form) still puts a model-filled value in double quotes on the command line: the #19 class, in the health check's block. Move it onto a quoted heredoc as L38 did for the send, or accept (the script checks `<cli>` as orca-send.sh does). Probe: `grep -n 'orca-health.sh" "<cli>"' plugins/cepa/skills/autonomy/SKILL.md`.
- [ ] P3 — `plugins/cepa/skills/autonomy/SKILL.md` §12b rule 6 block — `timeout -k 0.5 3 <cli> terminal rename` splices `<cli>` unquoted into the command. Same class; same fix. Probe: `grep -n '<cli> terminal rename' plugins/cepa/skills/autonomy/SKILL.md`.

## 2026-10-31 — /cepa:review of #110 (todos/review-2026-10-31-230000.md)

- [ ] P2 — `plugins/cepa/skills/autonomy/SKILL.md` §12b rule 1 block — a subject or body line exactly `CEPA_BODY` ends the heredoc and the lines after it run as shell commands; only prose (indent such a line) guards it, and bodies carry relayed repo content (finding 3). Fix: a per-send delimiter the session invents (`<<'CEPA_BODY_<hex>'`), or the message in a file passed by a `file:` field. Interface change, so it needs the operator's call.
- [ ] P2 — raises the rule 6 entry above: `timeout -k 0.5 3 <cli> terminal rename` runs `<cli>` unchecked and unquoted (`orca-ide;touch${IFS}/tmp/x` runs the touch, per security-sentinel). Fix: read it from a quoted heredoc and run orca-nudge.sh's cli check first (finding 4).
- [ ] P3 — `plugins/cepa/commands/sweep.md:510` (`b='<branch>'`), `plugins/cepa/skills/autonomy/SKILL.md` `run='<run>'` / `mode='<mode>'` (§11b), `plugins/cepa/commands/compound.md` `'<short-run-id>'` — model-filled values in single quotes; a `'` breaks out before the later check (finding 5). Probe: `grep -n "='<" plugins/cepa/commands/*.md plugins/cepa/skills/autonomy/SKILL.md`.
- [ ] P3 — `plugins/cepa/scripts/orca-send.sh` — the `session:` name is the session's claim; nothing checks it matches the handle, so a wrong name points the operator at the wrong tab (finding 6). The handle is printed beside it.
- [ ] P3 — `plugins/cepa/scripts/orca-health.sh` REASONS — `[A-Za-z0-9._/-]{1,200} is not on PATH` lets a planted alert file choose a 200-char spaceless word (finding 7, pre-existing). Anchor to `orca-ide|orca-dev|orca|/<path>`.
- [ ] P3 — `plugins/cepa/scripts/orca-health.sh` REASONS — the three pre-1.43.0 refusal patterns are kept for one release; drop them in the next minor (finding 8).
- [ ] P3 — operator, after merge: live Orca sessions still hold the old §12b rule 1 block in context; their sends refuse loudly (`takes no arguments`, exit 4, alert) until they re-read rule 1 or restart (finding 8).
