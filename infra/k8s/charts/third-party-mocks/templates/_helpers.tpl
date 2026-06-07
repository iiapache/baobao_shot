{{- define "third-party-mocks.mockFullname" -}}
{{- printf "%s-%s" (include "baobao.fullname" .root) .name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "third-party-mocks.mockLabels" -}}
{{- $root := .root }}
{{- $name := .name }}
helm.sh/chart: {{ include "baobao.chart" $root }}
app.kubernetes.io/name: {{ $name }}
app.kubernetes.io/instance: {{ $root.Release.Name }}
app.kubernetes.io/managed-by: {{ $root.Release.Service }}
app.kubernetes.io/part-of: baobao
baobao.io/component: third-party-mocks
{{- with $root.Values.global.cluster }}
baobao.io/cluster: {{ . | quote }}
{{- end }}
{{- with $root.Values.global.region }}
baobao.io/region: {{ . | quote }}
{{- end }}
{{- with $root.Values.global.environment }}
baobao.io/environment: {{ . | quote }}
{{- end }}
{{- with $root.Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}
