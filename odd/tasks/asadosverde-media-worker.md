# Add the Asados Verde media worker

## Intent

- **Objective:** Add an opt-in Asados Verde media worker and move trusted pull-request checks to the repository-scoped homelab runner.
- **Problem:** The chart cannot currently run the background media processor, and its trusted PR checks still use GitHub-hosted runners.
- **Why now:** Issue #30 is approved, while homelab PR #22 establishes the required `arc-runners-helm-charts` label.

## Scope and constraints

- Authorized root: `/Users/Seba/DATA/git/0.PERSONAL/0.GIT/helm-charts-worktrees/asadosverde-media-worker`.
- Change only the PR/check workflows and the `charts/asadosverde` chart, tests, and generated chart documentation required by issue #30.
- Do not merge, auto-merge, deploy, mutate Kubernetes or homelab, delete branches, or run privileged code for fork pull requests.
- Production enablement and Secret provisioning are out of scope.
- TDD mode: not configured; the repository contains no ODD/TDD configuration. Use focused render tests alongside implementation.
- Delivery strategy: `ask-on-risk`; stop before PR creation when authored additions plus deletions exceed 400.
- Delegated route evidence: direct execution is required by the user; delegation is prohibited.

## Acceptance and checks

- Trusted PR/check jobs use `arc-runners-helm-charts` and reject fork execution while preserving non-PR behavior.
- The worker is disabled by default and renders exactly one secure worker pod when enabled.
- Database, R2, persistence, command, concurrency, and lifecycle contracts are explicit and tested.
- Chart documentation is generated from `README.md.gotmpl` and values metadata.
- Verify workflow syntax/actionlint when available, Helm lint/render tests, existing Asados Verde scripts, ShellCheck, helm-docs consistency, `ct lint`, safe local-only `ct install` availability, diff hygiene, and attribution/privacy.

## Stable tasks

| ID | Task | Status | Evidence |
|---|---|---|---|
| ODD-AMW-01 | Migrate trusted PR CI to the repo-scoped homelab runner. | Complete | Signed commit `478ff29`; YAML parsing and fork-guard assertions passed. |
| ODD-AMW-02 | Add, test, and document the opt-in media worker chart. | Complete | Helm lint/templates, focused and existing render tests, helm-docs, and ct lint passed; signed work-unit commit contains this tracker. |
| ODD-AMW-03 | Verify CI after runner PR #22 is deployed. | Pending | No deployment is authorized here; checks may remain queued. |

## Progress and next step

- Tracker created before workflow or chart source edits.
- Next: apply the 400-line delivery gate, then publish the PR if admitted; ODD-AMW-03 remains blocked on homelab PR #22 deployment.
