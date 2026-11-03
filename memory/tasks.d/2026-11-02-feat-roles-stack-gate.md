# Residuals — feat/roles/stack-gate (PR #126, punch-list L66)

## Undone Items from feat/roles/stack-gate (2026-11-02)
1. ~~[P2] `plugins/cepa/scripts/stack-gate.sh` holds its lock for the command's whole run. A cold `compose up -d --build` (5-8 min) per lane at fleet launch can push the third lane past `lock_wait_seconds` (600) and refuse it as "lock busy" with capacity to spare. The header now says the command must return once started, and a waiting start prints one line. Open choices: build outside the gate (`compose build`, then gate `up -d --no-build`); a holder file naming who holds the lock; a separate exit code for "lock busy". `todos/review-2026-11-02-092950-feat-roles-stack-gate.md` #7.~~ Fixed by L68 (fix/roles/gate-build-outside-lock): build outside the gate, gate `up -d --no-build` only.
2. [P3] SIGTERM/SIGKILL to the gate orphans its start command without the lock (Ctrl-C is fine). Forwarding needs background + wait + trap, which changes the command's stdin. Same file, #23.
3. [P3] No case tests a hung docker: removing `timeout` from the `docker ps` call stays green. Needs a test-only bound override and a `STUB_DOCKER_HANG` stub mode. Same file, #24.
4. [P3] Lock and config follow `$HOME`; Docker is machine-wide. A start under sudo or another WSL distro takes a different lock. Not live under Orca today (HOME is kept). Same file, #25.
5. [P3] A restart of an already-running stack is refused when the others fill the limit or memory is low (fail-closed by choice). Same file, #26.
6. [P3] docker, timeout and date run with the lock fd open; a child docker leaves behind could hold the lock. Same file, #27.
7. [P3] Exit 2/3 can be the wrapped command's own codes (`make` exits 2). Documented: the `STACK gate:` line is authoritative. Changing codes needs coord@main (Builder-check 6 fixes them). Same file, #28.
8. [P3] L67's `/cepa:setup` check and L61's orca-health `stacks:over:<n>` leg consume `stack-gate.sh --count` (contract sent to coord@main as `msg_f437b979fb0a` for tab4@gain): exit 1 / `running=unknown` is its own alert, never zero.
