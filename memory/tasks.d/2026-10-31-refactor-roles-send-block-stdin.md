# Residuals — refactor/roles/send-block-stdin (L38)

## 2026-10-31 — tab21@roles, implementation

- [ ] P3 — `plugins/cepa/skills/autonomy/SKILL.md` §12b rule 8 block — `bash "$CEPA_ROOT/scripts/orca-health.sh" "<cli>"` (and its `ack` form) still puts a model-filled value in double quotes on the command line: the #19 class, in the health check's block. Move it onto a quoted heredoc as L38 did for the send, or accept (the script checks `<cli>` as orca-send.sh does). Probe: `grep -n 'orca-health.sh" "<cli>"' plugins/cepa/skills/autonomy/SKILL.md`.
- [ ] P3 — `plugins/cepa/skills/autonomy/SKILL.md` §12b rule 6 block — `timeout -k 0.5 3 <cli> terminal rename` splices `<cli>` unquoted into the command. Same class; same fix. Probe: `grep -n '<cli> terminal rename' plugins/cepa/skills/autonomy/SKILL.md`.
