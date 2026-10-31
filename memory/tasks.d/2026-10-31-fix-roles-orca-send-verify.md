# Residuals — fix/roles/orca-send-verify (L33)

## 2026-10-31 — send paths not yet mechanized (L33 item 3)
- P2 — `orchestration reply` (rule 7's answer path) is not run through
  `orca-send.sh`: nothing proves the reply stored before its nudge. Its reply
  shape was not measured. Next: measure `reply --json` on a probe pair, then
  give `orca-send.sh` a reply mode or a sibling — plugins/cepa/skills/autonomy/SKILL.md
  §12b rule 7 (coordinator kind)
- P2 — A dispatched worker's `worker_done` (rule 3) is checked by prose only
  ("counts only when Orca returns `"ok": true` with a `result.message.id`").
  Orca refuses a bad one loudly (exit 1, `"ok": false`), so a session that reads
  the result sees it; one that pipes it to grep does not. Next: a checked
  wrapper that takes the preamble's IDs — plugins/cepa/skills/autonomy/SKILL.md §12b rule 3
- P3 — The global `~/.claude/CLAUDE.md` Orca section names the guarded nudge
  (`orca-nudge.sh`) as the wake step; after merge it should name rule 1's
  send block (`orca-send.sh`), which nudges only after a stored send — operator

## 2026-10-31 — root cause not fully proven
- P3 — tab24's D6 `--type question` (~16:00Z) stored nothing; its terminal
  buffer no longer holds the call (oldest retained cursor 164853). `question`
  itself is NOT refused for a run_unbound legacy recipient (5 of 5 probe sends
  stored). Measured candidates, all now caught by `orca-send.sh`: `ask` from a
  sender with no Dispatch (`dispatch_inactive`, UUID envelope id), a command
  line of about 32 KB (empty stdout, exit 1), a body starting `--`
  (`invalid_argument`), the WSL vsock error. Which one hit D6 is unknown —
  artist360 tab24 (read-only evidence)

## 2026-10-31 — observed, not fixed
- P3 — `orchestration send --from <any term_ handle>` from an unbound pane is
  accepted and stored with that `from_handle`
  (probe2 s7, `term_00000000-…`, stored as `msg_e31e77e61751`). Rule 7 replies
  to a question's `from` field, so a forged `from` redirects the nudge. The
  nudge's guard limits the harm to one fixed line — Orca (upstream)
