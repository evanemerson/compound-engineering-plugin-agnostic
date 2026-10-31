# Residuals — fix/roles/orca-send-verify (L33)

## 2026-10-31 — send paths not yet mechanized (L33 item 3)
- P2 — `orchestration reply` (rule 7's answer path) is not run through
  `orca-send.sh`: rule 7 now runs `orca-nudge.sh` alone after a reply that
  printed a message id, but no script proves the reply stored. Its reply
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
  itself is NOT refused for a run_unbound legacy recipient: probe terminal A
  (no Run) sent 7 `orchestration send --type question --to <B term_> --json`
  calls (r1 s2, s6; r2 s1, s4-s7) and every one under 32 KB returned
  `"ok": true` with a `msg_` id. Measured candidates, each now refused,
  excluded or failed loudly by `orca-send.sh`: `ask` from a
  sender with no Dispatch (`dispatch_inactive`, UUID envelope id; `ask` is
  not a type the script sends), a command
  line of about 32 KB (empty stdout, exit 1), a body starting `--`
  (`invalid_argument`), the WSL vsock error. Which one hit D6 is unknown —
  artist360 tab24 (read-only evidence)

## 2026-10-31 — observed, not fixed
- P3 — `orchestration send --from <any term_ handle>` from an unbound pane is
  accepted and stored with that `from_handle`
  (probe2 s7, `term_00000000-…`, stored as `msg_e31e77e61751`). Rule 7 replies
  to a question's `from` field, so a forged `from` redirects the nudge. The
  nudge's guard limits the harm to one fixed line — Orca (upstream)

## 2026-10-31 — /cepa:review deferred findings (PR #105)
- P3 — The 28,000-byte cap counts bytes before the WSL bridge escapes `"` and
  `\`; a quote-heavy body under the cap can still exceed the Windows limit.
  It fails loudly (empty stdout, exit 5) — plugins/cepa/scripts/orca-send.sh size cap
- P3 — The four `<cli>`/`<target>`/`<type>`/`<nudge>` values sit in double
  quotes on the block's command line; the script validates them only after
  bash parsed the line. Moving them onto stdin closes it —
  plugins/cepa/skills/autonomy/SKILL.md §12b rule 1 block
- P3 — The vsock retry of a send is blind; the new inbox re-read could check
  for the first try's row before retrying (#101 finding 8) — orca-send.sh cepa_send_orca
- P3 — The ending line names a terminal handle, not a session (#101 finding
  9) now also on every refused or failed send — orca-send.sh cepa_send_ending
- P3 — Untested send branches: the send's own cli checks, the
  `timeout`/`python3`/`mktemp` guards, "orca-nudge.sh not found", and the
  `to_handle` fallback have no case or mutant — scripts/check-orca-nudge.sh STORE
- P3 — `Bash(orca-ide orchestration send:*)` is still granted beside the
  script, so "never run `orchestration send` by hand" is prose only —
  plugins/cepa/commands/*.md allowed-tools
- P3 — Rule 7's "When the send and its nudge both succeeded" does not name a
  `no-nudge` send to a Run coordinator (rule 1 already says the send alone
  completes it) — plugins/cepa/skills/autonomy/SKILL.md §12b rule 7 (finding 24)
