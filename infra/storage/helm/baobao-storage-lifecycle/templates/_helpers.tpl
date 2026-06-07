{{- define "baobao-storage-lifecycle.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "baobao-storage-lifecycle.fullname" -}}
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

{{- define "baobao-storage-lifecycle.labels" -}}
helm.sh/chart: {{ include "baobao-storage-lifecycle.name" . }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "baobao-storage-lifecycle.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
baobao.io/component: storage-lifecycle
{{- end }}

{{- define "baobao-storage-lifecycle.selectorLabels" -}}
app.kubernetes.io/name: {{ include "baobao-storage-lifecycle.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "baobao-storage-lifecycle.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "baobao-storage-lifecycle.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
