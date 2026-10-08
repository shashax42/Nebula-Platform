{{- define "nebula-edge.labels" -}}
app.kubernetes.io/name: nebula-edge
app.kubernetes.io/managed-by: {{ .Release.Service }}
nebula.io/environment: {{ .Values.environment }}
{{- end -}}
