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
assert_lacks "$tmp_dir/default.yaml" "app.kubernetes.io/component: media-worker"

helm template local-release "$chart" --show-only templates/media-worker-deployment.yaml \
    --set mediaWorker.enabled=true > "$tmp_dir/local.yaml"
for expected in "kind: Deployment" "replicas: 1" "type: Recreate" "revisionHistoryLimit: 3" \
    "terminationGracePeriodSeconds: 180" "app.kubernetes.io/component: media-worker" \
    "automountServiceAccountToken: false" "runAsNonRoot: true" "type: RuntimeDefault" \
    "MEDIA_WORKER_CONCURRENCY" 'value: "2"' "MEDIA_STORAGE_BACKEND" 'value: "LOCAL"' \
    "./node_modules/.bin/prisma migrate deploy" "exec ./node_modules/.bin/tsx scripts/media-worker.ts" \
    "persistentVolumeClaim:" "cpu: 250m" "memory: 2Gi"; do
    assert_has "$tmp_dir/local.yaml" "$expected"
done
assert_lacks "$tmp_dir/local.yaml" "seed"
assert_lacks "$tmp_dir/local.yaml" "envFrom:"
assert_lacks "$tmp_dir/local.yaml" "kind: Service"
assert_lacks "$tmp_dir/local.yaml" "kind: Ingress"
assert_lacks "$tmp_dir/local.yaml" "Probe:"
assert_lacks "$tmp_dir/local.yaml" "containerPort:"

helm template r2-release "$chart" --show-only templates/media-worker-deployment.yaml \
    --set mediaWorker.enabled=true --set mediaWorker.localPersistence=false \
    --set mediaWorker.r2.existingSecret=media-r2 \
    --set mediaWorker.r2.accountIdKey=account --set mediaWorker.r2.accessKeyIdKey=access \
    --set mediaWorker.r2.secretAccessKeyKey=secret --set mediaWorker.r2.bucketNameKey=bucket \
    > "$tmp_dir/r2.yaml"
for expected in 'value: "R2"' "R2_ACCOUNT_ID" "R2_ACCESS_KEY_ID" "R2_SECRET_ACCESS_KEY" \
    "R2_BUCKET_NAME" 'name: "media-r2"' 'key: "account"' 'key: "access"' 'key: "secret"' \
    'key: "bucket"' "DATABASE_URL" "secretKeyRef:"; do
    assert_has "$tmp_dir/r2.yaml" "$expected"
done
assert_lacks "$tmp_dir/r2.yaml" "persistentVolumeClaim:"
assert_lacks "$tmp_dir/r2.yaml" "envFrom:"

helm template external-db "$chart" --show-only templates/media-worker-deployment.yaml \
    --set mediaWorker.enabled=true --set postgresql.enabled=false \
    --set externalDatabase.existingSecret=external-db --set externalDatabase.existingSecretKey=url \
    > "$tmp_dir/external-db.yaml"
assert_has "$tmp_dir/external-db.yaml" "name: external-db"
assert_has "$tmp_dir/external-db.yaml" "key: url"

for value in 0 5 1.5; do
    expect_failure "bad-concurrency-${value}" "mediaWorker.concurrency must be an integer from 1 through 4" \
        --set mediaWorker.enabled=true --set mediaWorker.concurrency="$value"
done
expect_failure missing-r2 "mediaWorker.r2.existingSecret is required" \
    --set mediaWorker.enabled=true --set mediaWorker.localPersistence=false
expect_failure missing-persistence "persistence.enabled must be true" \
    --set mediaWorker.enabled=true --set persistence.enabled=false

printf 'All asadosverde media-worker render tests passed.\n'
