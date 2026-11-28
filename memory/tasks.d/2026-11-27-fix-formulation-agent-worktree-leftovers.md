# Residuals — fix/formulation/agent-worktree-leftovers (punch-list L96)

## 2026-11-27 — what was measured, and what stays unproven

Probe: three isolated Agent dispatches (haiku) from the formulation lane of
this repo, Claude Code 2.1.332, git 2.43. Before and after each one I ran
`git worktree list --porcelain` and `git branch --list 'worktree-agent-*'`.
I removed all three leftovers afterwards (`git worktree remove`, then
`git branch -D`). The worktree list then matched the snapshot taken before
the probe (`diff` printed nothing), and 0 `worktree-agent-*` branches were
left.

Measured (now recorded in `cepa:autonomy` §11):
- The agent changed nothing: the harness removed the worktree and its branch.
- The agent only ran `git checkout --detach HEAD~1` (HEAD~1 was `36ea2e6`, on
  `origin/main`): the harness removed the
  worktree and **kept the branch**. This is the proven leak. Before this
  branch, §11b printed `KEPT …: not a worktree of this repo` for it and never
  deleted the branch. Fixed here: the gone-worktree path deletes the branch
  under the snapshot guard and the branch guards (holder, tip, branch reflog).
- The agent made a commit: the harness kept both, and the completion notice
  named `worktreePath` and `worktreeBranch`. This closes the open question in
  `2026-10-21-fix-roles-review-agent-worktrees.md` item 2 (the Agent result's
  worktree field is unmeasured): this shard supersedes that item's
  "unmeasured" wording.
- Placement: `<main checkout>/.claude/worktrees/agent-<id>`, also when the
  session runs in a linked lane.
- The lock `locked claude agent agent-<id> (pid <session pid> …)` is there
  while the agent runs. After return, the kept worktree (the commit case) had
  no `locked` line. **The lock does not
  explain the leftovers.**

- [ ] **U1 — the 20 dpc-pro folders: cause not proven here.** The 59 − 20 = 39
  branches with no folder have the shape of the proven leak, if each of the
  20 folders has its own branch (counts sender-reported by orca-lab; probe
  not given; not re-measured here). The folders mean the
  harness kept a worktree, so the agent left changed or untracked files or
  new commits, and then §11b did not remove it. Candidates that this repo
  cannot settle: (a) the orchestrator passed no `<ids>`, so every agent
  worktree read `UNCLAIMED`. It fits L15's relayed record that dpc-pro's
  CLAUDE.md requires isolation for review agents (not verified here), while
  the cepa commands said "no isolation" and review.md said "normally none". §11b now
  says that such ids count. (b) §11b's `has status lines` guard kept it, for
  example ignored caches from a reader that ran code. (c) A dispatch outside
  any cepa command, where no §11b block runs at all. (d) `HEAD … on no origin
  ref`, when a reader checked out an unpushed local ref. To tell them apart,
  read the `agent_worktrees:` / KEPT / UNCLAIMED lines in that run's
  report. That check is for dpc-pro's coord@main (read-only).
- [ ] **U2 — other repos.** Whether other repos hold the same leftovers is not
  checked. Each repo's coord@main can check it read-only, with
  `git worktree list` and `git branch --list 'worktree-agent-*'`.
- [ ] **U3 — the ids rely on the orchestrator.** Nothing checks that an
  orchestrator passes the ids of readers that a project rule or a hook
  isolated. §11b's text now says it must, but that is a prompt contract (§11c
  stated limits).

## 2026-11-27 — /cepa:review PR #147 findings deferred

Source: `todos/review-2026-11-27-194433-fix-formulation-agent-worktree-leftovers.md`.
Numbers are that file's.

- [ ] **#14 P3** — `plugins/cepa/skills/autonomy/SKILL.md` §11 intro: add a
  pointer saying forced isolation on readers makes §11b depend on `<ids>`.
- [ ] **#15 P2** — `scripts/check-dispatch-isolation.sh`: the gone path's tip
  test is pinned only at a tip equal to an origin ref; a `--points-at` mutant
  would survive. Needs a fixture repo with an ancestor-only commit.
- [ ] **#16 P3** — `scripts/check-dispatch-isolation.sh`: no unknown-mode
  fixture on the gone path (the mode is normalized earlier, so low risk).
- [ ] **#17 P3** — `scripts/check-dispatch-isolation.sh`: no `agent-a1` /
  `agent-a10` prefix-collision fixture.
- [ ] **#18 P3** — `plugins/cepa/skills/autonomy/SKILL.md` §11b: the snapshot
  holds worktrees, not branches; a miscopied id can name another session's
  branch during its creation. Option: snapshot `refs/heads/worktree-agent-*`.
