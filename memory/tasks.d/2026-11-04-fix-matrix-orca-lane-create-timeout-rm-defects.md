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
4. [P3] #134 review, deferred finding 12: step 2b's park can meet a later
   Orca step; it fails closed. Open: add a settled read before parking? —
   `plugins/cepa/scripts/orca-lane.sh` (create, step 2b).
5. [P3] #134 review, deferred finding 13: unbounded local git work is outside
   the worst-case sums (`status --ignored` on a large lane) —
   `plugins/cepa/scripts/orca-lane.sh` (rm).
6. [P3] #134 review, deferred finding 14: `grep` exit 2 reads as no match in
   the need filter; pre-existing —
   `plugins/cepa/scripts/orca-lane-reflog.sh` (need filter).

## Learnings (2026-11-04)

1. A second instance of CLAUDE.md's "a CI command checked only with the local
   tool version" rule: git 2.48 and later create `origin/HEAD` on fetch, so a
   fixture that relies on it being absent behaves differently on the runner
   (2.56.0) and a dev machine (2.43.0). A mutant stayed green only on CI. A
   fixture pins `remote.origin.followRemoteHEAD=never` for that shape.
2. Bash's `$(<dir)` exits 0. Test the file type before reading it.
3. Drafted rule, for the coordinator to decide: "An Orca CLI failure after the
   request was sent is no result, for every write verb: read Orca's state
   before reporting a failure." L79 was create; #134's review found the same
   class in rm.
