# Residuals — chore/main/orca-config (PR #95)

## 2026-10-30 — /cepa:review of PR #95

- status: deferred
  severity: P3
  `orca.yaml:1` — No committed validator for orca.yaml or .worktreeinclude.
  A duplicate key or bad YAML makes Orca ignore the whole file, a non-hex
  colour is dropped, and a `.worktreeinclude` entry that stops being gitignored
  is skipped, all silently. Validated once by hand with Orca 1.4.244's own
  `parseOrcaYaml`. Candidate: a stdlib check (hex colours + `git check-ignore`
  per include line). Finding 4 of `todos/review-2026-10-30-111256.md`.
