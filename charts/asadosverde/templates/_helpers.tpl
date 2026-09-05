{{/* Expand the chart name. */}}
{{- define "asadosverde.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Create a fully qualified application name. */}}
{{- define "asadosverde.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/* Chart label value. */}}
{{- define "asadosverde.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Common labels. */}}
{{- define "asadosverde.labels" -}}
helm.sh/chart: {{ include "asadosverde.chart" . }}
{{ include "asadosverde.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Application selector labels. */}}
{{- define "asadosverde.selectorLabels" -}}
app.kubernetes.io/name: {{ include "asadosverde.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: application
{{- end }}

{{/* PostgreSQL selector labels. */}}
{{- define "asadosverde.postgresql.selectorLabels" -}}
app.kubernetes.io/name: {{ include "asadosverde.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: database
{{- end }}

{{/* PostgreSQL resource labels. */}}
{{- define "asadosverde.postgresql.labels" -}}
helm.sh/chart: {{ include "asadosverde.chart" . }}
{{ include "asadosverde.postgresql.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Service account name. */}}
{{- define "asadosverde.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "asadosverde.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/* PostgreSQL resource names. */}}
{{- define "asadosverde.postgresql.fullname" -}}
{{- printf "%s-postgresql" (include "asadosverde.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "asadosverde.postgresql.secretName" -}}
{{- default (printf "%s-postgresql" (include "asadosverde.fullname" .) | trunc 63 | trimSuffix "-") .Values.postgresql.auth.existingSecret }}
{{- end }}

{{- define "asadosverde.uploadsClaimName" -}}
{{- default (printf "%s-uploads" (include "asadosverde.fullname" .) | trunc 63 | trimSuffix "-") .Values.persistence.existingClaim }}
{{- end }}

{{- define "asadosverde.postgresql.claimName" -}}
{{- default (printf "%s-data" (include "asadosverde.postgresql.fullname" .) | trunc 63 | trimSuffix "-") .Values.postgresql.persistence.existingClaim }}
{{- end }}
