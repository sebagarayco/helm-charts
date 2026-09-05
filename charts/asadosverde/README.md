# asadosverde

![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)

A production-oriented Helm chart for Asados Verde

## Production setup

The default application image is the private GHCR package `ghcr.io/sebagarayco/asadosverde`. Create a registry Secret and reference it with `imagePullSecrets`:

```shell
kubectl create secret docker-registry ghcr-pull-secret \
  --docker-server=ghcr.io \
  --docker-username='<github-user>' \
  --docker-password='<github-token>'
```

Create a separate application Secret and set `app.existingSecret`. The container requires `BOOTSTRAP_ADMIN_NAME`, `BOOTSTRAP_ADMIN_EMAIL`, and `BOOTSTRAP_ADMIN_PASSWORD` on every startup. `BOOTSTRAP_ADMIN_NICKNAME` is optional. The same Secret can contain `VERIFICATION_CODE_PEPPER`, `RESEND_API_KEY`, `RESEND_FROM_EMAIL`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, and other sensitive application environment variables. Do not put their values in a values file.

The image entrypoint applies Prisma migrations and runs the idempotent seed before starting the server. This chart deliberately does not create a duplicate migration Job. Keep `app.command` and `app.args` empty unless using a test image.

## Database modes

PostgreSQL is enabled by default. The chart creates a stable headless Service, a single-replica StatefulSet, and a standalone chart-managed PVC mounted at the official image data root with `PGDATA` in a subdirectory. Keeping the claim outside `volumeClaimTemplates` allows supported size expansion without changing immutable StatefulSet fields. When `postgresql.auth.existingSecret` is empty, Helm generates an alphanumeric password and stores both `postgres-password` and `database-url` in a release Secret. `lookup` preserves the password on upgrades, and both PostgreSQL and the application read the same Secret.

To manage credentials externally, set `postgresql.auth.existingSecret`. That Secret must contain the keys configured by `postgresql.auth.passwordKey` and `postgresql.auth.databaseUrlKey`, and the URL must use the same password as the password key.

To use external PostgreSQL, disable the bundled database and reference a Secret containing the complete Prisma-compatible URL:

```yaml
postgresql:
  enabled: false
externalDatabase:
  existingSecret: asadosverde-external-db
  existingSecretKey: database-url
```

Rendering fails when PostgreSQL is disabled without both external Secret settings.

## Persistence

Uploaded profile images are written to `/app/uploads` and use a PVC by default. PostgreSQL uses its own stable standalone PVC, or the claim named by `postgresql.persistence.existingClaim`. Empty storage class values use the cluster default and keep the chart portable. Set either storage class explicitly, or use `values-homelab.yaml`, which selects `proxmox-zfs` for both claims.

PVC storage classes and access modes are immutable after creation. Changing either requires provisioning a replacement claim and migrating data, or selecting a prepared claim with `existingClaim`. Increasing `postgresql.persistence.size` is supported only when the selected StorageClass and CSI driver allow volume expansion; shrinking a PVC is not supported by Kubernetes.

## Homelab deployment

`values-homelab.yaml` provides the `cloudflare-tunnel` ingress class, `asados.sebops.co` host, external-dns and cert-manager annotations, `asados-tls`, and `proxmox-zfs` storage classes. It contains Secret names but no credentials:

```shell
helm upgrade --install asadosverde . \
  --namespace asadosverde --create-namespace \
  --values values-homelab.yaml
```

Create `ghcr-pull-secret` and `asadosverde-app` in that namespace before installation. Back up both PVCs and the generated PostgreSQL Secret. Helm cannot recover a generated database password if its Secret is deleted while the database volume remains.

## CI installation

`ci/ct-values.yaml` replaces the private application image with public unprivileged nginx, adjusts ports and probes, and disables upload persistence. Chart-testing automatically discovers this values file and can therefore exercise installation without weakening production defaults:

```shell
ct install --config ../../ct.yaml --charts .
```

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Application pod affinity rules. |
| app.args | list | `[]` | Override image arguments. |
| app.command | list | `[]` | Override the image entrypoint. Keep empty to run the container migration, seed, and server startup contract. |
| app.env | list | `[]` | Additional environment variables for the application container. |
| app.envFrom | list | `[]` | Additional envFrom entries for the application container. |
| app.existingSecret | string | `""` | Existing Secret imported with envFrom for bootstrap admin, verification pepper, Resend, Google OAuth, and other application settings. |
| externalDatabase.existingSecret | string | `""` | Existing Secret containing DATABASE_URL; required when postgresql.enabled is false. |
| externalDatabase.existingSecretKey | string | `"database-url"` | DATABASE_URL key in externalDatabase.existingSecret. |
| fullnameOverride | string | `""` | Override the fully qualified application name. |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy. |
| image.repository | string | `"ghcr.io/sebagarayco/asadosverde"` | Asados Verde container image repository. |
| image.tag | string | `""` | Image tag. Defaults to the chart appVersion when empty. |
| imagePullSecrets | list | `[]` | Image pull secrets, required when the GHCR package is private. |
| ingress.annotations | object | `{}` | Ingress annotations. |
| ingress.className | string | `""` | Ingress class name. |
| ingress.enabled | bool | `false` | Enable an Ingress for the application. |
| ingress.hosts | list | `[{"host":"chart-example.local","paths":[{"path":"/","pathType":"Prefix"}]}]` | Ingress hosts and paths. |
| ingress.tls | list | `[]` | Ingress TLS configuration. |
| mockData | bool | `false` | Enable the application's demo dataset. Production deployments should keep this false. |
| nameOverride | string | `""` | Override the chart name. |
| nodeSelector | object | `{}` | Application pod node selector. |
| persistence.accessModes | list | `["ReadWriteOnce"]` | PVC access modes. |
| persistence.annotations | object | `{}` | PVC annotations. |
| persistence.enabled | bool | `true` | Persist uploaded profile images. |
| persistence.existingClaim | string | `""` | Use an existing PVC instead of creating one. |
| persistence.size | string | `"2Gi"` | Requested upload storage size. |
| persistence.storageClass | string | `""` | Storage class. Empty uses the cluster default; "-" disables dynamic provisioning. |
| podAnnotations | object | `{}` | Additional application pod annotations. |
| podLabels | object | `{}` | Additional application pod labels. |
| podSecurityContext | object | `{"fsGroup":1001,"fsGroupChangePolicy":"OnRootMismatch"}` | Application pod security context. |
| postgresql.affinity | object | `{}` | PostgreSQL pod affinity rules. |
| postgresql.auth.database | string | `"asadosverde"` | PostgreSQL database name. |
| postgresql.auth.databaseUrlKey | string | `"database-url"` | DATABASE_URL key in the PostgreSQL Secret. |
| postgresql.auth.existingSecret | string | `""` | Existing Secret containing both passwordKey and databaseUrlKey. When empty, the chart generates and preserves both values. |
| postgresql.auth.passwordKey | string | `"postgres-password"` | Password key in the PostgreSQL Secret. |
| postgresql.auth.username | string | `"asadosverde"` | PostgreSQL user name. |
| postgresql.enabled | bool | `true` | Deploy the bundled PostgreSQL StatefulSet. |
| postgresql.image.pullPolicy | string | `"IfNotPresent"` | PostgreSQL image pull policy. |
| postgresql.image.repository | string | `"postgres"` | PostgreSQL image repository. |
| postgresql.image.tag | string | `"17-alpine"` | PostgreSQL image tag. |
| postgresql.nodeSelector | object | `{}` | PostgreSQL pod node selector. |
| postgresql.persistence.accessModes | list | `["ReadWriteOnce"]` | PostgreSQL PVC access modes. |
| postgresql.persistence.annotations | object | `{}` | PVC annotations for PostgreSQL data. |
| postgresql.persistence.enabled | bool | `true` | Persist PostgreSQL data. |
| postgresql.persistence.existingClaim | string | `""` | Use an existing PVC instead of creating a chart-managed PostgreSQL PVC. |
| postgresql.persistence.size | string | `"8Gi"` | Requested PostgreSQL storage size. Increases require volume expansion support from the StorageClass and CSI driver. |
| postgresql.persistence.storageClass | string | `""` | Storage class. Empty uses the cluster default; "-" disables dynamic provisioning. This field is immutable after PVC creation. |
| postgresql.podSecurityContext | object | `{"fsGroup":70,"fsGroupChangePolicy":"OnRootMismatch"}` | PostgreSQL pod security context. UID/GID 70 matches the default Alpine image. |
| postgresql.resources | object | `{"limits":{"memory":"512Mi"},"requests":{"cpu":"100m","memory":"256Mi"}}` | PostgreSQL resource requests and limits. |
| postgresql.revisionHistoryLimit | int | `3` | StatefulSet revision history limit. |
| postgresql.securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"runAsGroup":70,"runAsNonRoot":true,"runAsUser":70,"seccompProfile":{"type":"RuntimeDefault"}}` | PostgreSQL container security context. |
| postgresql.service.annotations | object | `{}` | PostgreSQL Service annotations. |
| postgresql.service.port | int | `5432` | PostgreSQL Service port. |
| postgresql.terminationGracePeriodSeconds | int | `60` | Grace period for PostgreSQL termination so the official image can stop cleanly. |
| postgresql.tolerations | list | `[]` | PostgreSQL pod tolerations. |
| probes.liveness.enabled | bool | `true` | Enable the liveness probe. |
| probes.liveness.failureThreshold | int | `3` |  |
| probes.liveness.path | string | `"/api/health"` |  |
| probes.liveness.periodSeconds | int | `20` |  |
| probes.liveness.timeoutSeconds | int | `3` |  |
| probes.readiness.enabled | bool | `true` | Enable the readiness probe. |
| probes.readiness.failureThreshold | int | `3` |  |
| probes.readiness.path | string | `"/api/health"` |  |
| probes.readiness.periodSeconds | int | `10` |  |
| probes.readiness.timeoutSeconds | int | `3` |  |
| probes.startup.enabled | bool | `true` | Enable the startup probe. |
| probes.startup.failureThreshold | int | `60` |  |
| probes.startup.initialDelaySeconds | int | `5` |  |
| probes.startup.path | string | `"/api/health"` |  |
| probes.startup.periodSeconds | int | `5` |  |
| probes.startup.timeoutSeconds | int | `3` |  |
| replicaCount | int | `1` | Number of application replicas. Keep at one with ReadWriteOnce persistence. |
| resources | object | `{"limits":{"memory":"512Mi"},"requests":{"cpu":"100m","memory":"256Mi"}}` | Application resource requests and limits. |
| revisionHistoryLimit | int | `3` | Deployment revision history limit. |
| securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"runAsGroup":1001,"runAsNonRoot":true,"runAsUser":1001,"seccompProfile":{"type":"RuntimeDefault"}}` | Application container security context. |
| service.annotations | object | `{}` | Service annotations. |
| service.nodePort | string | `""` | Optional fixed NodePort. |
| service.port | int | `3000` | Service port. |
| service.targetPort | int | `3000` | Application container port. |
| service.type | string | `"ClusterIP"` | Kubernetes Service type. |
| serviceAccount.annotations | object | `{}` | Service account annotations. |
| serviceAccount.automountServiceAccountToken | bool | `false` | Mount the service account token in the application pod. |
| serviceAccount.create | bool | `true` | Create a service account for the application. |
| serviceAccount.name | string | `""` | Existing service account name. Generated when empty and create is true. |
| strategy.type | string | `"Recreate"` | Deployment update strategy. Recreate is safe with the default ReadWriteOnce upload volume and startup migrations. |
| terminationGracePeriodSeconds | int | `30` | Grace period for application pod termination. |
| test.image.pullPolicy | string | `"IfNotPresent"` | Helm test image pull policy. |
| test.image.repository | string | `"busybox"` | Helm test image repository. |
| test.image.tag | string | `"1.36.1"` | Helm test image tag. |
| test.path | string | `"/api/health"` | HTTP path checked by the Helm test. |
| tolerations | list | `[]` | Application pod tolerations. |
