# Add the Asadosverde mail retry worker

## Intent

- **Objective:** Add one opt-in Helm Deployment for the Morfiverde mail retry worker.
- **Problem:** The chart cannot run the packaged worker that retries queued transactional mail.
- **Why now:** Morfiverde 1.10.0 is expected to provide the worker contract required by this chart.

## Scope and constraints

- Authorized root: the dedicated sibling worktree `helm-charts-worktrees/asadosverde-mail-worker`.
- Start from refreshed `origin/main` and preserve existing application and media-worker identities and defaults.
- Add chart values, helpers, one Deployment template, focused render tests, generated chart documentation, and CI values only as required for the mail worker.
- Keep the worker disabled by default. It must not create a Service, ports, probes, upload volumes, or media/R2 configuration.
- Read `DATABASE_URL`, the Resend API key, and the optional sender address through explicit `secretKeyRef` entries; never import a complete Secret with `envFrom`.
- Do not merge, release, deploy, access a cluster, inspect Secret values, force-push, modify Git configuration, or operate on another repository.
- TDD mode: not configured; no repository TDD configuration exists. Use focused render and negative tests alongside implementation.
- Delivery strategy: one cohesive PR unless authored additions plus deletions exceed 400; then require verified `size:exception` authority and rationale or stop.
- Delegated route evidence: the user explicitly required direct implementation in this repository and authorized its exact origin for issue, branch, push, draft PR, and label operations.

## CI recovery work unit

- **Objective:** Restore PR #33 validation by provisioning the exact Python, Go, and Helm toolchains required by existing workflow steps.
- **Root evidence:** Commit `5b8ad233bc2c7b28f6ab3b5a1939ae1cdd59a375` fixed Python setup and the Go-backed pinned `yq` installation. The next `validate` run reached `scripts/validate-pr.sh` and failed only because `helm` was absent from `PATH` (`exec: "helm": executable file not found in $PATH`). Commit `bacb4cf941bb0b0df4d881377fc9c25a3a868d40` then provisioned Helm with `azure/setup-helm@v1` and version `v3.8.2`.
- **Authorized files:** This correction is limited to `.github/workflows/validate-pr.yaml` and this ODD tracker; the earlier Python and Go setup files remain otherwise unchanged.
- **Checks:** Local workflow YAML parsing, Bash syntax for `scripts/validate-pr.sh`, the focused mail-worker script, Helm lint, and `git diff --check` passed. The naturally triggered `validate`, `CODEOWNERS`, and `lint-test` checks passed.
- **Rollback:** Revert only the Helm correction commit to remove Helm setup while preserving both the completed chart feature and the earlier Python/Go repair.
- **Route:** Continue on `feat/asadosverde-mail-worker`, push normally once to its configured `origin`, and update only PR #33 in `sebagarayco/helm-charts`; do not merge, release, or operate on a cluster.
- **Commits:** Python/Go repair `5b8ad233bc2c7b28f6ab3b5a1939ae1cdd59a375`; Helm correction `bacb4cf941bb0b0df4d881377fc9c25a3a868d40`.

## Super-Linter recovery work unit

- **Objective:** Make Super-Linter v3.12.0 build its file list entirely from the checked-out workspace without Git network or branch operations.
- **Root cause:** The failing workflow sets `VALIDATE_ALL_CODEBASE=false`. Upstream v3.12.0 `lib/buildFileList.sh` handles that value by running `git pull` and checking out `DEFAULT_BRANCH`; the observed job failed during that Git operation with a TLS reset, before linting. Setting it to `true` selects the local `find` path and deterministically removes both Git operations.
- **Authorized files:** This correction is limited to `.github/workflows/linter.yml` and this ODD tracker. All filters, disabled validators, action version, permissions, runner, and token configuration must remain unchanged.
- **Verification:** Psych 3.1.0 parsed `.github/workflows/linter.yml`; the focused assertion found one `VALIDATE_ALL_CODEBASE: true` and no `VALIDATE_ALL_CODEBASE: false`; `git diff --check` passed; status and structural diff review showed only the two authorized modified files plus preserved untracked `.codegraph/`. After a future commit and push, observe only newly triggered CI without rerunning old jobs.
- **Rollback:** Revert only the future Super-Linter recovery commit, or restore this single environment value to `false`, without reverting either dependency-recovery commit or any chart source.
- **Route evidence:** The delegated direct ODD instruction explicitly authorizes this two-file local repair for PR #33 and prohibits commit, push, CI rerun, GitHub operations, merge, release, and deployment in this work unit.

## Acceptance

- The chart version advances one feature minor from refreshed main and `appVersion` is `1.10.0`.
- Default rendering contains no mail-worker resource.
- Enabled rendering creates exactly one secure Deployment using the application image, pull secrets, service account, security contexts, placement, and resource conventions.
- Startup runs Prisma migrations and then replaces the shell with the packaged mail worker command.
- Bundled and external database Secret selection both render correctly.
- Resend API key and optional sender address use explicit configurable Secret names and keys, preferring `app.existingSecret` when configured.
- Retry defaults are poll `300000` ms, lease `120000` ms, batch `20`, and max attempts `5`; termination grace is `10` seconds.
- Required-value failures occur only when the worker is enabled and name the missing setting clearly.
- Existing media-worker and vote-reminder focused tests continue to pass.
- README template and generated README explain enablement, Secret wiring, release dependency, and rollback.

## Checks

- Focused mail-worker render and negative test script.
- Existing media-worker and vote-reminder render scripts.
- ShellCheck for modified scripts.
- `helm lint`, default rendering, enabled bundled-database rendering, and enabled external-database rendering.
- `helm-docs` regeneration with no residual diff.
- `ct lint` and chart version checks when available.
- `git diff --check` and final branch/status review.
- No `ct install` against a live cluster; use only a repository-provided isolated local harness if one exists.

## Release dependencies and boundary

- The draft PR is blocked until the Morfiverde application PR is merged and the `1.10.0` image exists with the packaged `mail:worker` command.
- Local rendering verifies chart structure but does not claim an image pull, worker execution, database migration, Secret availability, cluster install, or deployment.
- Publication stops at a pushed branch and draft PR. Merge, release, and deployment remain maintainer actions.

## Rollback

- Disable `mailWorker.enabled` to remove the worker Deployment while leaving the application and media worker unchanged.
- Reverting the work-unit commit removes the mail-worker values, helpers, template, focused test, and documentation as one cohesive chart change.
- No database downgrade is attempted; migrations remain owned by the Morfiverde image contract.

## Stable tasks

| ID | Task | Status | Evidence |
|---|---|---|---|
| ODD-AMW-01 | Establish the refreshed worktree, chart baseline, TDD mode, and release contract. | Complete | Worktree is based on refreshed `origin/main` at `0709fbd`; chart baseline is `1.4.0` / app `1.9.0`; repository has no TDD configuration. |
| ODD-AMW-02 | Implement values, helpers, Deployment, focused tests, CI values, and documentation. | Complete | Chart 1.5.0 targets app 1.10.0; focused tests cover disabled, bundled, external, optional sender, explicit Secret keys, and negative renders; helm-docs generated README.md idempotently. |
| ODD-AMW-03 | Run focused and repository verification, then record rollback and review evidence. | Complete with limitation | Focused, media-worker, and vote-reminder scripts passed; Helm lint and all required renders passed; ct lint/version check passed; bash syntax and diff hygiene passed. ShellCheck is unavailable locally and no cached ShellCheck container exists, so the draft PR records that unexecuted check. Runtime harness: N/A because no isolated cluster harness exists and live-cluster install is prohibited. Rollback boundary is the mail-worker values, helpers, template, test, docs, and version metadata. |
| ODD-AMW-04 | Resolve an approved issue, create one signed work-unit commit, push, and open a labeled draft PR. | Complete | Signed commit `0028e89778aa58a39b1f18ce9263bb56fabe9317` was pushed and PR #33 was opened against approved issue #32; the 311-line complete chart change remained within the 400-line single-PR budget. |
| ODD-AMW-05 | Provision missing CI dependencies, verify locally, push bounded recovery commits, update PR metadata, and observe checks. | Complete | Commits `5b8ad233bc2c7b28f6ab3b5a1939ae1cdd59a375` and `bacb4cf941bb0b0df4d881377fc9c25a3a868d40` repaired Python, Go, and Helm provisioning. Local verification passed, and the naturally triggered `validate`, `CODEOWNERS`, and `lint-test` checks passed. |
| ODD-AMW-06 | Make Super-Linter v3.12.0 enumerate workspace files locally and verify the bounded repair. | In progress | Root cause and two-file boundary are recorded. The local workflow edit, YAML parse, focused value assertion, diff hygiene, and structural review passed; commit, push, and newly triggered CI evidence remain pending. |

## Progress and next step

- The completed chart task remains recorded separately from the bounded CI recovery work unit.
- Morfiverde release `morfiverde-v1.10.0` is published, satisfying the application release dependency; chart 1.5.0 remains unpublished until a maintainer merges and releases it.
- ODD-AMW-05 is complete: both dependency-recovery commits are recorded, and `validate`, `CODEOWNERS`, and `lint-test` passed.
- Next: a later authorized work unit must commit and push ODD-AMW-06 and observe only its newly triggered PR #33 checks; do not rerun old jobs.
