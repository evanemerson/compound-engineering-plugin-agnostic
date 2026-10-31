# Residuals — fix/roles/orca-send-verify (L33)

## 2026-10-31 — send paths not yet mechanized (L33 item 3)
- [x] P2 — **CLOSED in PR fix/roles/orca-loss-audit (1.40.0, L35): `orca-send.sh` reply mode** — `orchestration reply` (rule 7's answer path) is not run through
  `orca-send.sh`: rule 7 now runs `orca-nudge.sh` alone after a reply that
  printed a message id, but no script proves the reply stored. Its reply
  shape was not measured. Next: measure `reply --json` on a probe pair, then
  give `orca-send.sh` a reply mode or a sibling — plugins/cepa/skills/autonomy/SKILL.md
  §12b rule 7 (coordinator kind)
- [x] P2 — **CLOSED in PR fix/roles/orca-loss-audit (1.40.0, L35): `orca-send.sh` worker_done mode** — A dispatched worker's `worker_done` (rule 3) is checked by prose only
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
- [x] P3 — **CLOSED in PR fix/roles/orca-loss-audit (1.40.0, L35/L36 #20): every call carries one request id, so the retry replays** — The vsock retry of a send is blind; the new inbox re-read could check
  for the first try's row before retrying (#101 finding 8) — orca-send.sh cepa_send_orca
- P3 — The ending line names a terminal handle, not a session (#101 finding
  9) now also on every refused or failed send — orca-send.sh cepa_send_ending
- P3 — Untested send branches: the send's own cli checks, the
  `timeout`/`python3`/`mktemp` guards, "orca-nudge.sh not found", and the
  `to_handle` fallback have no case or mutant — scripts/check-orca-nudge.sh STORE
- P3 — `Bash(orca-ide orchestration send:*)` is still granted beside the
  script, so "never run `orchestration send` by hand" is prose only —
  plugins/cepa/commands/*.md allowed-tools
- [x] P3 — **CLOSED in PR fix/roles/orca-loss-audit (1.40.0, L35/L36 #24)** — Rule 7's "When the send and its nudge both succeeded" does not name a
  `no-nudge` send to a Run coordinator (rule 1 already says the send alone
  completes it) — plugins/cepa/skills/autonomy/SKILL.md §12b rule 7 (finding 24)

## 2026-10-31 — L35 audit: every place cepa reads an `orca-ide` result

Measured by tab17@roles on Orca 1.4.245 (WSL), with three throwaway probe
terminals in the `roles` worktree (A: coordinator of a throwaway Run
`run_ca27e456fd42`; B: given Dispatches with `orchestration dispatch`; C: no
Run). Each call ran inside its probe terminal, so `ORCA_TERMINAL_HANDLE` was
that terminal's. All three are closed (`terminal list` shows none). "Empty"
means stdout of 0 bytes: a ~33,000-char argument printed nothing and exited 1
(`powershell.exe: Invalid argument`) on `worker_done`, `ask`, `reply` and
`send`, measured once each; the WSL vsock error has the same shape (L26).

| Path | Read at | Proves success (measured) | Refusal (measured) | Empty stdout | Verdict |
|---|---|---|---|---|---|
| `status --json` | §12a | `"ok": true` | — | reads `ORCA: absent` | safe |
| `send` status/question/handoff/escalation/merge_ready | rule 1 → `orca-send.sh` | `"ok": true` + `result.message.id` `msg_…` + inbox row | exit 1, `"ok": false`, top-level `"id"` is `local` or a UUID: `terminal_not_found` (no such `term_`), `run_not_found`, `invalid_argument` (`--options`, `--question`, a `--` body, a bad `--type`) | exit 5 | safe (L33) |
| `send` to a Run coordinator's own `term_` | rule 1 | stored with `to_handle` `run:<id>`, from a dispatched AND an unbound sender | — | — | safe: script says "Run mailbox"; a plain `term_` target is never re-addressed (5 sends to C) |
| `send --type worker_done` | rule 3 | `"ok": true` + `msg_…` + `result.lifecycle` {`action` `completed`/`failed`, `taskId`, `dispatchId`}; a repeat is idempotent (same action) | wrong dispatch: exit 1 `run_required` | exit 1, nothing | **was prose only → fixed: `orca-send.sh` worker_done mode** |
| `send --type heartbeat` | preamble | `"ok": true` + `msg_…` | — | — | accepted AFTER the dispatch settled (`hb_after`), so an accepted heartbeat does not prove a live dispatch → L34 |
| `ask` | rule 4 | exit 0, `"ok": true`, `timedOut` false, `answer` non-null | settled dispatch: exit 1 `dispatch_inactive` | exit 1, nothing | **timeout: exit 1 but `"ok": true`, `answer: null` → fixed in prose (rule 4)** |
| `reply` | rule 7 | `"ok": true` + `msg_…` with `thread_id` = the question (+ `result.question.status` `answered` for an `ask`) | bad id `runtime_error`; second answer `answer_conflict`; `--` body `invalid_argument` | exit 1, nothing | **was prose only → fixed: reply mode; a reply to a message the replier sent is stored for the replier itself, `"ok": true`** |
| `check` / `check --ack` (bound Run) | rules 5, 8 | `deliveryId`, replay until acked | a wrong `--ack` id returns `"ok": true` and acks nothing | batch replays | safe: duplicate, never loss |
| `check` (no bound Run) | rule 8 | — | — | **the plain `check` marks read at once, returns no `deliveryId`, never replays; lost output = lost message (only `--all` still lists it)** | **fixed in prose (rule 8: drain from the peek)** |
| `inbox --limit 200` | `orca-send.sh` re-read | rows newest first; the whole store was 203 rows, `sequence` 1-203 with no gap | — | exit 5 | safe |
| `worker-start` / `dispatch` | rule 2, global CLAUDE.md | `"ok": true` + `result.dispatch.id` `ctx_…`, `status` `dispatched` | exit 1 `agent_unconfigured`, `task_not_found` | not proven either way | gap: no proof named → residual below |
| `agent launch` | global CLAUDE.md | `prompt.outcome` (global rule) | exit 1: `invalid_argument` (`"id": "local"`), `selector_not_found` | not proven | safe if the rule is read |
| `terminal close` | global CLAUDE.md (probes) | absence from `terminal list` | stale handle: exit 1 `terminal_handle_stale` | — | `"ok": true` also for a handle already closed: `ok` is not proof |
| `terminal rename` | rule 6 | `"ok": true` | exit 1 `terminal_handle_stale` | reads failed | safe |
| `terminal show` / `worktree ps` / `terminal send` | `orca-nudge.sh` | `"ok": true` | — | skip/fail | safe (gated) |
| `--retry-request <uuid>` + `request-show` | new in reply and worker_done modes | the same id replays the first result (same `msg_…`, `replayed: true`); different input with the same id: `request_mismatch`; `request-show` → `completed` with the receipt, or `absent` | — | `absent` after an empty-stdout send | recovery primitive |

**D6 `question` loss — narrowed, not proven.** The Orca store holds rows
`sequence` 1-203 with no gap (`orchestration inbox --limit 1000 --json`,
18:3xZ). No row from tab24's handle (`term_93d80256…`) falls between
`msg_eee168b9a25b` (15:54:27Z) and `msg_d15116438151` (17:25:55Z), so D6 never
became a row: Orca refused it before storage, or it never reached Orca. It was
not a row stored and then deleted or read. A new measured candidate:
`orchestration send … --options "a,b"` (`ask`'s flag, natural on a question)
is refused `invalid_argument` with `"id": "local"`, exit 1, no row. The other
candidates still stand (a `--` body, ~32 KB, vsock). Evidence that would
prove it: the tool call and its result in tab24's session transcript
(`~/.claude/projects/-home-evan-webapps-artist360--claude-worktrees-merch-builder-v2/*.jsonl`,
grep `orchestration send` near 16:00Z). That file is outside this worker's
read scope (the brief allows only Orca's API and `memory/` files); the
operator or artist360's own session can read it.
