# Residuals — L55 plan review (Orca lane lifecycle)

Plan (local; `docs/` is gitignored): `docs/plans/2026-11-01-orca-lane-lifecycle.md`.
Canonical findings: `todos/review-2026-11-01-135437.md` (21 findings; 6 applied to the plan, 15 judgment; the L55 build, PR #118, applied 14 of the 15, and #19 stays open below).
Build waits for the operator's approval and for PR #116 (L46). These judgment items are decided at approval
or at build; finding numbers match the findings file.

- [x] DECIDED 2026-11-01 (operator: "Approve as recommended"; #4: "List them, then remove"; binds the L55 build) — P1 — #3 U1 parks before rm, so rm's branch deletion is never measured — `docs/plans/2026-11-01-orca-lane-lifecycle.md` U1.
- [x] DECIDED 2026-11-01 (operator: "Approve as recommended"; #4: "List them, then remove"; binds the L55 build) — P1 — #4 rm guards vs §11b: refuse on ignored files (used lanes never removable) or list them and proceed (operator decision) — U2.
- [x] DECIDED 2026-11-01 (operator: "Approve as recommended"; #4: "List them, then remove"; binds the L55 build) — P1 — #5 Orca returns Windows UNC paths; the script must convert them — U2.
- [x] DECIDED 2026-11-01 (operator: "Approve as recommended"; #4: "List them, then remove"; binds the L55 build) — P2 — #9 validate cli/action/lane/base fields — U2.
- [x] DECIDED 2026-11-01 (operator: "Approve as recommended"; #4: "List them, then remove"; binds the L55 build) — P2 — #10 per-action required fields (name takes cli, action only) — U2.
- [x] DECIDED 2026-11-01 (operator: "Approve as recommended"; #4: "List them, then remove"; binds the L55 build) — P2 — #11 draft CLAUDE.md drops the not-in-orca.yaml init case — draft section.
- [x] DECIDED 2026-11-01 (operator: "Approve as recommended"; #4: "List them, then remove"; binds the L55 build) — P2 — #12 D6 fallback path undefined (use .claude/worktrees/<wt>) — D6.
- [x] DECIDED 2026-11-01 (operator: "Approve as recommended"; #4: "List them, then remove"; binds the L55 build) — P2 — #13 capped or failed worktree list/ps reads must be UNKNOWN — U2.
- [x] DECIDED 2026-11-01 (operator: "Approve as recommended"; #4: "List them, then remove"; binds the L55 build) — P2 — #14 check the created path's basename after create — U2.
- [x] DECIDED 2026-11-01 (operator: "Approve as recommended"; #4: "List them, then remove"; binds the L55 build) — P3 — #16 drop the optional repo: field — U2.
- [x] DECIDED 2026-11-01 (operator: "Approve as recommended"; #4: "List them, then remove"; binds the L55 build) — P3 — #17 draft removal bullet should cite §12b rule 2, not restate guards — draft section.
- [x] DECIDED 2026-11-01 (operator: "Approve as recommended"; #4: "List them, then remove"; binds the L55 build) — P3 — #18 --setup run vs inherit; U1 records the repo setup policy — D2.
- [ ] P3 — #19 artist360 probe create/rm via hand-off after merge — U5. Owner: cepa coord@main, after PR #118 merges and the plugin hops run; record the result against F6 before U6 goes to the operator. (Decided 2026-11-01 as recommended; still to do.)
- [x] DECIDED 2026-11-01 (operator: "Approve as recommended"; #4: "List them, then remove"; binds the L55 build) — P3 — #20 U3 verification: no text keeps new-child as default — U3.
- [x] DECIDED 2026-11-01 (operator: "Approve as recommended"; #4: "List them, then remove"; binds the L55 build) — P3 — #21 fold U4 into U3 — U4.
