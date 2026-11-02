# Residuals — fix/roles/needs-you-attention-flag (PR #120, L57)

## 2026-11-01 — from the PR #120 review (todos/review-2026-11-01-200500.md)

- [ ] P3 `plugins/cepa/scripts/orca-attention.sh` mark — mark overwrites an existing non-empty worktree comment; keep it in a per-checkout state file and restore it on clear, or refuse to mark over one (finding 14).
- [ ] P3 `plugins/cepa/scripts/orca-attention.sh` re-reads — measure whether opening the worktree in Orca clears `isUnread`; if Orca moves it by itself, make the dot advisory in the re-read (finding 15).
- [ ] P3 `plugins/cepa/scripts/orca-attention.sh` question check — also reject Unicode format characters (category Cf: bidi overrides, zero-width) (finding 16).
- [ ] P3 `plugins/cepa/scripts/orca-attention.sh` and `orca-send.sh` file read — read the checked file through one open fd (same-user race only) (finding 17).

## Open parts of L57 this PR does not do (for coord@main to fold into L57)

- [ ] The dpc-pro miss is still unexplained; probe hypothesis (a), a lost PreToolUse(AskUserQuestion) hook post.
- [ ] Send the bug report drafted in PR #120's body to Orca's maintainers, with the probe log.
- [ ] Weigh Claude Code's push notification as a third signal.
- [ ] The flag only helps sessions that load cepa 1.49.0 or later.
