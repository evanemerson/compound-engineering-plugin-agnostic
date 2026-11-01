# Residuals — fix/integrity/send-heredoc-delimiter (L41)

## 2026-10-31 — /cepa:review of #112 (todos/review-2026-10-31-233000.md)

- [ ] P3 — `plugins/cepa/scripts/orca-send.sh` THE MESSAGE FILE — a same-user process can swap the file between the `-L`/`-O` checks and the `cat` (TOCTOU, finding 7). This is not a privilege boundary. Fix: read through one fd (`exec 3<"$f"`), or `mv` the file into a `mktemp -d` directory before the checks.
- [ ] P3 — `plugins/cepa/scripts/orca-send.sh` repo check — `git rev-parse … || top=` fails open on a git error (dubious ownership, a broken GIT_DIR) as well as outside a repo (finding 8). Fix: tell "not a git repository" from other failures, and refuse on the second.
- [ ] P3 — `plugins/cepa/scripts/orca-send.sh` subject/body split — the CR is dropped from the subject but kept on body lines, and NUL bytes are dropped silently (finding 9). Low risk: Write writes LF and no NUL.
- [ ] P3 — `plugins/cepa/scripts/orca-health.sh` REASONS — the pre-1.43.0 group (#110) and the pre-1.44.0 group (#112) each say "kept for one release". Drop both in the next minor after 1.44.0 (finding 10).
- [ ] P3 — operator, after merge and the two hops: a live session that loaded the 1.43.0 rule 1 block gets every send refused (`the heredoc holds a message after its fields…`, exit 4, alert) until it restarts. In that session the old heredoc can still break out, because that happens in the shell before the script runs. L30 item 3.
- [ ] P3 — `scripts/check-orca-nudge-controls.sh` — no mutant drops `-f` alone, and none drops `-O` (that needs a file of another user). A mutant `[ -z "$cepa_send_rest" ]` (whitespace no longer ignored) survives: no case puts a line of spaces after the empty line (pr-test-analyzer).
- [ ] P3 — `scripts/check-orca-nudge.sh` FIELDS — the `MF()` files are made when the case list is built, not when each case runs. That is readable but not wrong: build them in the runner (silent-failure-hunter).
- [x] P3 — `memory/tasks.d/2026-10-02-punch-list.md` L41 — close it on merge (coord@main is the only writer). Closed 2026-11-01 by triage: L41 CLOSED (PR #112).
