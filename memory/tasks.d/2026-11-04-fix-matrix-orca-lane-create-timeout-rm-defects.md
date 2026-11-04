# Residuals — fix/matrix/orca-lane-create-timeout-rm-defects (punch-list L79, L77 items 1-6)

## Undone items (2026-11-04)

1. [P3] `orca-lane.sh` step 2b ends after up to 120 s, and L79 saw Orca finish
   "minutes" later. Nothing stops a session that starts another create while
   the lane is absent: the Ending line is the only guard. A marker under the
   main checkout's git dir could refuse that create. Not in this brief.
2. [P3] A retry after a failed rm cannot know that an earlier rm failed, so
   its all-deletions refusal is worded conditionally. A marker would make it
   exact.
3. [P3] Measured T1 (`orca-lane.sh` header) saw no `orphaned: true` row, so
   the orphaned-terminal leg rests on the stubbed shape. Re-read a real one
   when a lane shows it.
