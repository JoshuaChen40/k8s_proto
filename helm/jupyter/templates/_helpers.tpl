{{/*
Return the name of the chart
*/}}
{{- define "jupyterlab.name" -}}
{{ .Chart.Name }}
{{- end }}

{{/*
Create a fully qualified name using release name and chart name
*/}}
{{- define "jupyterlab.fullname" -}}
{{ printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "jupyterlab.labels" -}}
app.kubernetes.io/name: {{ include "jupyterlab.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
