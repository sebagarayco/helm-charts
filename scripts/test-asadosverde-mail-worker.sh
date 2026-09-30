#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

chart="$(git rev-parse --show-toplevel)/charts/asadosverde"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

assert_has() { grep -Fq -- "$2" "$1" || { printf 'Missing %s in %s\n' "$2" "$1" >&2; exit 1; }; }
assert_lacks() { ! grep -Fq -- "$2" "$1" || { printf 'Unexpected %s in %s\n' "$2" "$1" >&2; exit 1; }; }
expect_failure() {
    local name=$1 expected=$2
    shift 2
    if helm template "$name" "$chart" "$@" > /dev/null 2> "$tmp_dir/$name.err"; then
        printf 'Expected %s to fail\n' "$name" >&2
        exit 1
    fi
    assert_has "$tmp_dir/$name.err" "$expected"
}

helm template default-release "$chart" > "$tmp_dir/default.yaml"
assert_lacks "$tmp_dir/default.yaml" "app.kubernetes.io/component: mail-worker"

helm template bundled-db "$chart" --show-only templates/mail-worker-deployment.yaml \
    --set mailWorker.enabled=true --set app.existingSecret=application-secrets \
    > "$tmp_dir/bundled.yaml"
for expected in "kind: Deployment" "replicas: 1" "type: Recreate" "terminationGracePeriodSeconds: 10" \
    "app.kubernetes.io/component: mail-worker" "automountServiceAccountToken: false" "runAsNonRoot: true" \
    "./node_modules/.bin/prisma migrate deploy" "exec ./node_modules/.bin/tsx scripts/mail-retry-worker.ts" \
    "RESEND_API_KEY" "RESEND_FROM_EMAIL" 'name: "application-secrets"' "optional: true" \
    "MAIL_RETRY_POLL_MS" 'value: "300000"' "MAIL_RETRY_LEASE_MS" 'value: "120000"' \
    "MAIL_RETRY_BATCH_SIZE" 'value: "20"' "MAIL_RETRY_MAX_ATTEMPTS" 'value: "5"'; do
    assert_has "$tmp_dir/bundled.yaml" "$expected"
done
for unexpected in "envFrom:" "kind: Service" "containerPort:" "Probe:" "persistentVolumeClaim:" \
    "MEDIA_STORAGE_BACKEND" "R2_" "seed"; do
    assert_lacks "$tmp_dir/bundled.yaml" "$unexpected"
done

helm template external-db "$chart" --show-only templates/mail-worker-deployment.yaml \
    --set mailWorker.enabled=true --set mailWorker.secret.existingSecret=mail-secrets \
    --set mailWorker.secret.apiKeyKey=resend-key --set-string mailWorker.secret.fromEmailKey= \
    --set postgresql.enabled=false --set externalDatabase.existingSecret=external-db \
    --set externalDatabase.existingSecretKey=url > "$tmp_dir/external.yaml"
for expected in "name: external-db" "key: url" 'name: "mail-secrets"' 'key: "resend-key"'; do
    assert_has "$tmp_dir/external.yaml" "$expected"
done
assert_lacks "$tmp_dir/external.yaml" "RESEND_FROM_EMAIL"

expect_failure missing-mail-secret "mailWorker.secret.existingSecret or app.existingSecret is required" \
    --set mailWorker.enabled=true
expect_failure missing-api-key "mailWorker.secret.apiKeyKey is required" \
    --set mailWorker.enabled=true --set app.existingSecret=application-secrets \
    --set-string mailWorker.secret.apiKeyKey=
expect_failure missing-external-db "externalDatabase.existingSecret is required" \
    --set mailWorker.enabled=true --set app.existingSecret=application-secrets --set postgresql.enabled=false

printf 'All asadosverde mail-worker render tests passed.\n'
