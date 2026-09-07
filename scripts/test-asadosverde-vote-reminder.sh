#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

repo_root=$(git rev-parse --show-toplevel)
chart="$repo_root/charts/asadosverde"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

assert_contains() {
    local file=$1
    local expected=$2
    if ! grep -Fq -- "$expected" "$file"; then
        printf 'Expected %s to contain: %s\n' "$file" "$expected" >&2
        exit 1
    fi
}

assert_not_contains() {
    local file=$1
    local unexpected=$2
    if grep -Fq -- "$unexpected" "$file"; then
        printf 'Expected %s not to contain: %s\n' "$file" "$unexpected" >&2
        exit 1
    fi
}

helm template default-release "$chart" > "$tmp_dir/default.yaml"
assert_not_contains "$tmp_dir/default.yaml" "kind: CronJob"

helm template valid-release "$chart" \
    --set voteReminder.enabled=true \
    --set voteReminder.secret.existingSecret=vote-reminder-secret \
    > "$tmp_dir/valid.yaml"
assert_contains "$tmp_dir/valid.yaml" "kind: CronJob"
assert_contains "$tmp_dir/valid.yaml" "- -e"
assert_contains "$tmp_dir/valid.yaml" "const timeout = setTimeout(() => controller.abort(), 30000);"
assert_contains "$tmp_dir/valid.yaml" "if (!response.ok)"
assert_contains "$tmp_dir/valid.yaml" 'headers: { authorization: `Bearer ${token}` }'
assert_contains "$tmp_dir/valid.yaml" 'schedule: "0 * * * *"'
assert_contains "$tmp_dir/valid.yaml" 'timeZone: "America/Argentina/Buenos_Aires"'
assert_contains "$tmp_dir/valid.yaml" "app.kubernetes.io/component: vote-reminder"
assert_contains "$tmp_dir/valid.yaml" "automountServiceAccountToken: false"
assert_contains "$tmp_dir/valid.yaml" "runAsNonRoot: true"
assert_contains "$tmp_dir/valid.yaml" "type: RuntimeDefault"
assert_contains "$tmp_dir/valid.yaml" "drop:"
assert_contains "$tmp_dir/valid.yaml" 'name: "vote-reminder-secret"'
assert_contains "$tmp_dir/valid.yaml" 'key: "VOTE_REMINDER_SCHEDULER_SECRET"'

if helm template missing-secret "$chart" --set voteReminder.enabled=true > /dev/null 2> "$tmp_dir/missing-secret.err"; then
    printf 'Expected rendering to fail without voteReminder.secret.existingSecret\n' >&2
    exit 1
fi
assert_contains "$tmp_dir/missing-secret.err" "voteReminder.secret.existingSecret is required when voteReminder.enabled is true"

if helm template missing-key "$chart" \
    --set voteReminder.enabled=true \
    --set voteReminder.secret.existingSecret=vote-reminder-secret \
    --set voteReminder.secret.key= \
    > /dev/null 2> "$tmp_dir/missing-key.err"; then
    printf 'Expected rendering to fail without voteReminder.secret.key\n' >&2
    exit 1
fi
assert_contains "$tmp_dir/missing-key.err" "voteReminder.secret.key is required when voteReminder.enabled is true"

helm template custom-release "$chart" \
    --set voteReminder.enabled=true \
    --set-string voteReminder.schedule='15 */2 * * *' \
    --set-string voteReminder.timeZone= \
    --set-string voteReminder.endpointPath=/custom/reminders \
    --set voteReminder.secret.existingSecret=custom-secret \
    --set voteReminder.secret.key=custom-key \
    --set voteReminder.concurrencyPolicy=Replace \
    --set voteReminder.startingDeadlineSeconds=123 \
    --set voteReminder.activeDeadlineSeconds=124 \
    --set voteReminder.backoffLimit=4 \
    --set voteReminder.successfulJobsHistoryLimit=2 \
    --set voteReminder.failedJobsHistoryLimit=5 \
    --set voteReminder.restartPolicy=OnFailure \
    --set voteReminder.resources.requests.cpu=20m \
    --set voteReminder.resources.requests.memory=32Mi \
    --set voteReminder.resources.limits.memory=96Mi \
    --set image.repository=registry.example.com/asadosverde \
    --set image.tag=test \
    --set image.pullPolicy=Always \
    --set 'imagePullSecrets[0].name=registry-secret' \
    --set serviceAccount.create=false \
    --set serviceAccount.name=custom-service-account \
    --set service.port=8080 \
    > "$tmp_dir/custom.yaml"
assert_contains "$tmp_dir/custom.yaml" 'schedule: "15 */2 * * *"'
assert_not_contains "$tmp_dir/custom.yaml" "timeZone:"
assert_contains "$tmp_dir/custom.yaml" 'value: "http://custom-release-asadosverde:8080/custom/reminders"'
assert_contains "$tmp_dir/custom.yaml" 'name: "custom-secret"'
assert_contains "$tmp_dir/custom.yaml" 'key: "custom-key"'
assert_contains "$tmp_dir/custom.yaml" 'image: "registry.example.com/asadosverde:test"'
assert_contains "$tmp_dir/custom.yaml" "imagePullPolicy: Always"
assert_contains "$tmp_dir/custom.yaml" "name: registry-secret"
assert_contains "$tmp_dir/custom.yaml" "serviceAccountName: custom-service-account"
assert_contains "$tmp_dir/custom.yaml" "concurrencyPolicy: Replace"
assert_contains "$tmp_dir/custom.yaml" "startingDeadlineSeconds: 123"
assert_contains "$tmp_dir/custom.yaml" "activeDeadlineSeconds: 124"
assert_contains "$tmp_dir/custom.yaml" "backoffLimit: 4"
assert_contains "$tmp_dir/custom.yaml" "successfulJobsHistoryLimit: 2"
assert_contains "$tmp_dir/custom.yaml" "failedJobsHistoryLimit: 5"
assert_contains "$tmp_dir/custom.yaml" "restartPolicy: OnFailure"
assert_contains "$tmp_dir/custom.yaml" "cpu: 20m"
assert_contains "$tmp_dir/custom.yaml" "memory: 96Mi"

printf 'All asadosverde vote-reminder render tests passed.\n'
