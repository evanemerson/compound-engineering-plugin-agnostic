# Changelog

<!--
  GENERATED FILE - do not edit by hand.
  Produced by scripts/generate-changelog.sh from this repository's GitHub
  Releases, which are themselves generated from merged PR titles. Every run
  rewrites this file in full, so hand edits are lost at the next release.
  To change an entry, edit the release (or the PR title) it came from.
-->

Every version below is a tag you can check out: `git checkout vX.Y.Z`.

## [v1.20.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.20.0) - 2026-08-09

_CI templates off the dying runtime + installed-copy drift check_

* feat: derive CHANGELOG.md from GitHub Releases on publish by @evanemerson in #39
* chore: bump actions/checkout to v7.0.1 (node24) before the 2026-09-16 runner removal by @evanemerson in #40
* chore: reconcile memory/tasks.d/ against the tree + solution doc for the closure-claim pattern by @evanemerson in #41
* feat: observe the runner's own runtime-deprecation warning by @evanemerson in #42
* fix: evidence is a run with the same pins, not a run at the tip by @evanemerson in #43
* chore: adopt Dependabot for pinned actions by @evanemerson in #44
* fix: CI templates target a runtime that dies on 2026-09-16 (1.19.1) by @evanemerson in #45

[Compare v1.19.0...v1.20.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.19.0...v1.20.0)

## [v1.19.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.19.0) - 2026-08-04

_mutation-sweep harness tier_

* feat: a mutation-sweep tier that mutates the sweep's own driver (1.19.0) by @evanemerson in #38

[Compare v1.18.4...v1.19.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.18.4...v1.19.0)

## [v1.18.4](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.18.4) - 2026-08-03

_fix: run_checker refuses an unbounded per-case timeout_

* fix: run_checker refuses an unbounded per-case timeout (1.18.4) by @evanemerson in #37

[Compare v1.18.3...v1.18.4](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.18.3...v1.18.4)

## [v1.18.3](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.18.3) - 2026-08-03

_feat: executable hang-path guard for the sweep's controls capture_

* feat: executable hang-path guard for the sweep's controls capture (1.18.3) by @evanemerson in #36

[Compare v1.18.2...v1.18.3](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.18.2...v1.18.3)

## [v1.18.2](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.18.2) - 2026-08-03

_fix: structural outer bound for the sweep's controls transcript + -k on the per-case checker timeout_

* docs(compound): mutation-sweep vocabulary + detector self-exemption by @evanemerson in #34
* fix: structural outer bound for the sweep's controls transcript + -k on the per-case checker timeout (1.18.2) by @evanemerson in #35

[Compare v1.18.1...v1.18.2](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.18.1...v1.18.2)

## [v1.18.1](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.18.1) - 2026-08-02

_docs: §9f owns the sweep's exit codes and the freshness detector_

* docs: §9f owns the sweep's exit codes and the freshness detector (1.18.1) by @evanemerson in #33

[Compare v1.18.0...v1.18.1](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.18.0...v1.18.1)

## [v1.18.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.18.0) - 2026-08-02

_feat: mutation sweep harness + close the 21 control gaps it found_

* docs(compound): one-layer-down regression — vocabulary + residuals by @evanemerson in #31
* feat: mutation sweep harness + close the 21 control gaps it found (1.18.0) by @evanemerson in #32

[Compare v1.16.2...v1.18.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.16.2...v1.18.0)

## [v1.16.2](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.16.2) - 2026-08-01

_fix: -L/-R traversal symmetry in the model-pin checker_

* fix: -L/-R traversal symmetry in the model-pin checker (1.16.2) by @evanemerson in #30

[Compare v1.16.1...v1.16.2](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.16.1...v1.16.2)

## [v1.16.1](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.16.1) - 2026-07-31

_chore: control suite for the model-pin checker_

* chore: control suite for the model-pin checker (1.16.1) by @evanemerson in #29

[Compare v1.16.0...v1.16.1](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.16.0...v1.16.1)

## [v1.16.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.16.0) - 2026-07-31

_fix: cite the §8 trunk ladder once; generalize leg 4; relocate the checker; pin checkout_

* fix: cite the §8 trunk ladder once; generalize leg 4; relocate the checker; pin checkout (1.16.0) by @evanemerson in #28

[Compare v1.15.1...v1.16.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.15.1...v1.16.0)

## [v1.15.1](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.15.1) - 2026-07-31

_docs(compound): restatement-drift meta-pattern — vocabulary + two live instances_

* docs(compound): restatement-drift meta-pattern — vocabulary + two live instances by @evanemerson in #27

[Compare v1.15.0...v1.15.1](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.15.0...v1.15.1)

## [v1.15.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.15.0) - 2026-07-30

_fix: one dispatch-model contract + mode-conditional persona tier_

* fix: one dispatch-model contract + mode-conditional persona tier (1.15.0) by @evanemerson in #26

[Compare v1.14.0...v1.15.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.14.0...v1.15.0)

## [v1.14.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.14.0) - 2026-07-30

_fix: pin every remaining subagent dispatch + structural enforcement_

* fix: pin every remaining subagent dispatch + structural enforcement (1.14.0) by @evanemerson in #25

[Compare v1.13.1...v1.14.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.13.1...v1.14.0)

## [v1.13.1](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.13.1) - 2026-07-29

_fix: close model-inherit leaks in dispatch paths_

* fix: close model-inherit leaks in dispatch paths (1.13.1) by @evanemerson in #24

[Compare v1.13.0...v1.13.1](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.13.0...v1.13.1)

## [v1.13.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.13.0) - 2026-07-29

_feat: sharded residual sink — memory/tasks.d/_

* feat: sharded residual sink — memory/tasks.d/ (1.13.0) by @evanemerson in #23

[Compare v1.12.0...v1.13.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.12.0...v1.13.0)

## [v1.12.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.12.0) - 2026-07-27

_feat: executable fan-out contract + trunk resolution_

* feat: executable fan-out contract + trunk resolution (1.12.0) by @evanemerson in #22

[Compare v1.11.1...v1.12.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.11.1...v1.12.0)

## [v1.11.1](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.11.1) - 2026-07-27

_fix: weekly scope preconditions fail on real repos_

* fix: weekly scope preconditions fail on real repos (1.11.1) by @evanemerson in #20

[Compare v1.11.0...v1.11.1](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.11.0...v1.11.1)

## [v1.11.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.11.0) - 2026-07-26

_feat: review cadence tier — weekly debt roster_

* feat: review cadence tier — weekly debt roster (1.11.0) by @evanemerson in #19

[Compare v1.10.2...v1.11.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.10.2...v1.11.0)

## [v1.10.2](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.10.2) - 2026-07-19

_feat: enforce brain cross-repo provenance filter_

* feat: enforce brain cross-repo provenance filter (1.10.2) by @evanemerson in #18

[Compare v1.10.1...v1.10.2](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.10.1...v1.10.2)

## [v1.10.1](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.10.1) - 2026-07-13

_fix: brain writeback source_refs requires kind field_

_Release body has no parseable change list; see the release page._

[Compare v1.10.0...v1.10.1](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.10.0...v1.10.1)

## [v1.10.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.10.0) - 2026-07-12

_feat: optional OB1 cross-repo brain provider_

* feat: optional OB1 cross-repo brain provider (1.10.0) by @evanemerson in #17

[Compare v1.9.3...v1.10.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.9.3...v1.10.0)

## [v1.9.3](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.9.3) - 2026-07-12

_fix: task-start reads todos/ as canonical open-findings store_

* fix: task-start reads todos/ as canonical open-findings store (1.9.3) by @evanemerson in #16

[Compare v1.9.2...v1.9.3](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.9.2...v1.9.3)

## [v1.9.2](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.9.2) - 2026-07-12

_fix: /cepa:review interactive report ends with §6 Next steps tail_

* fix: /cepa:review interactive report ends with §6 Next steps tail (1.9.2) by @evanemerson in #15

[Compare v1.9.1...v1.9.2](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.9.1...v1.9.2)

## [v1.9.1](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.9.1) - 2026-07-12

_fix: mandate §6 numbered Next steps tail in autonomous reports_

* fix: mandate §6 numbered Next steps tail in autonomous reports (1.9.1) by @evanemerson in #14

[Compare v1.9.0...v1.9.1](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.9.0...v1.9.1)

## [v1.9.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.9.0) - 2026-07-12

_feat: optional graphify grounding provider_

* feat: optional graphify grounding provider (1.9.0) by @evanemerson in #13

[Compare v1.8.0...v1.9.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.8.0...v1.9.0)

## [v1.8.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.8.0) - 2026-07-12

_feat: /cepa:sweep + /cepa:resolve-pr — the loop closes itself_

* feat: /cepa:sweep + /cepa:resolve-pr — the loop closes itself (1.8.0) by @evanemerson in #12

[Compare v1.7.0...v1.8.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.7.0...v1.8.0)

## [v1.7.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.7.0) - 2026-07-11

_feat: plan-review panel + Implementation Units + execution-contract upgrades_

* feat: plan-review panel + Implementation Units + execution-contract upgrades (1.7.0) by @evanemerson in #11

[Compare v1.6.1...v1.7.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.6.1...v1.7.0)

## [v1.6.1](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.6.1) - 2026-07-11

_fix(compound-refresh): commit placement — never move HEAD, never commit into foreign branches_

* fix(compound-refresh): commit placement — never move HEAD, never commit into foreign branches (1.6.1) by @evanemerson in #10

[Compare v1.6.0...v1.6.1](https://github.com/evanemerson/compound-engineering-plugin-agnostic/compare/v1.6.0...v1.6.1)

## [v1.6.0](https://github.com/evanemerson/compound-engineering-plugin-agnostic/releases/tag/v1.6.0) - 2026-07-11

_feat: compounding hygiene — /cepa:compound-refresh, CONCEPTS.md vocabulary map, mandatory Detection sections_

* Rewrite README for newcomers, add setup script by @evanemerson in #1
* feat(review): promote pr-review-toolkit companion agents to default rotation by @evanemerson in #2
* Fix dead /revise-claude-md reference in /cepa:compound by @evanemerson in #4
* Audit open PRs before branching in /cepa:task Phase 1 by @evanemerson in #5
* feat: autonomous execution — /cepa:lfg, autonomy contract, confidence-gated auto-fix by @evanemerson in #6
* feat: review upgrades — conditional persona tier, 3 new reviewers, Go/No-Go deploys by @evanemerson in #7
* feat: /cepa:setup health check + CI templates by @evanemerson in #8
* feat: compounding hygiene — /cepa:compound-refresh, CONCEPTS.md vocabulary map, mandatory Detection sections (1.6.0) by @evanemerson in #9

