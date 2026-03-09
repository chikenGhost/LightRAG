{{/*
Expand the name of the chart.
*/}}
{{- define "lightrag.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "lightrag.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "lightrag.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Chart name and version.
*/}}
{{- define "lightrag.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selector labels.
*/}}
{{- define "lightrag.selectorLabels" -}}
app.kubernetes.io/name: {{ include "lightrag.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Common labels.
*/}}
{{- define "lightrag.labels" -}}
helm.sh/chart: {{ include "lightrag.chart" . }}
{{ include "lightrag.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
Resolve image repository with optional global registry override.
*/}}
{{- define "lightrag.imageRepository" -}}
{{- $registry := .Values.image.registry -}}
{{- if .Values.global.imageRegistry -}}
{{- $registry = .Values.global.imageRegistry -}}
{{- end -}}
{{- if $registry -}}
{{- printf "%s/%s" $registry .Values.image.repository -}}
{{- else -}}
{{- .Values.image.repository -}}
{{- end -}}
{{- end -}}

{{/*
Resolve full image reference.
*/}}
{{- define "lightrag.image" -}}
{{- $imageRepository := include "lightrag.imageRepository" . -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" $imageRepository .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" $imageRepository (default .Chart.AppVersion .Values.image.tag) -}}
{{- end -}}
{{- end -}}

{{/*
Resolve container HTTP port.
*/}}
{{- define "lightrag.httpPort" -}}
{{- if and .Values.containerPorts (hasKey .Values.containerPorts "http") (index .Values.containerPorts "http") -}}
{{- printf "%v" (index .Values.containerPorts "http") -}}
{{- else if and .Values.env (hasKey .Values.env "PORT") -}}
{{- printf "%v" (index .Values.env "PORT") -}}
{{- else -}}
9621
{{- end -}}
{{- end -}}

{{/*
Render image pull secrets list.
*/}}
{{- define "lightrag.imagePullSecrets" -}}
{{- $pullSecrets := list -}}
{{- $imageValues := default (dict) .Values.image -}}
{{- $localPullSecrets := concat (default (list) (index $imageValues "pullSecrets")) (default (list) (index $imageValues "imagePullSecrets")) -}}
{{- range (default (list) .Values.global.imagePullSecrets) -}}
  {{- if kindIs "string" . -}}
    {{- $pullSecrets = append $pullSecrets (dict "name" .) -}}
  {{- else if and (kindIs "map" .) (hasKey . "name") -}}
    {{- $pullSecrets = append $pullSecrets (dict "name" .name) -}}
  {{- end -}}
{{- end -}}
{{- range $localPullSecrets -}}
  {{- if kindIs "string" . -}}
    {{- $pullSecrets = append $pullSecrets (dict "name" .) -}}
  {{- else if and (kindIs "map" .) (hasKey . "name") -}}
    {{- $pullSecrets = append $pullSecrets (dict "name" .name) -}}
  {{- end -}}
{{- end -}}
{{- if gt (len $pullSecrets) 0 -}}
{{ toYaml $pullSecrets }}
{{- end -}}
{{- end -}}

{{/*
Get the name of the service account to use.
*/}}
{{- define "lightrag.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "lightrag.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Compute storageClassName snippet from local/global values.
*/}}
{{- define "lightrag.storageClass" -}}
{{- $persistence := default (dict) .persistence -}}
{{- $storageClass := default "" $persistence.storageClass -}}
{{- if and (not $storageClass) .global.defaultStorageClass -}}
{{- $storageClass = .global.defaultStorageClass -}}
{{- end -}}
{{- if $storageClass -}}
{{- if eq $storageClass "-" -}}
storageClassName: ""
{{- else -}}
storageClassName: {{ $storageClass | quote }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Environment secret name.
*/}}
{{- define "lightrag.envSecretName" -}}
{{- if .Values.envSecret.existingSecret -}}
{{- .Values.envSecret.existingSecret -}}
{{- else -}}
{{- printf "%s-env" (include "lightrag.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Compute checksum used to trigger pod rollout on env secret updates.
*/}}
{{- define "lightrag.envSecretChecksum" -}}
{{- if .Values.envSecret.existingSecret -}}
{{- $externalSecret := lookup "v1" "Secret" .Release.Namespace .Values.envSecret.existingSecret -}}
{{- if and $externalSecret (hasKey $externalSecret "data") (hasKey $externalSecret.data .Values.envSecret.secretKey) -}}
{{- index $externalSecret.data .Values.envSecret.secretKey | sha256sum -}}
{{- else -}}
{{- printf "%s:%s:%v" .Values.envSecret.existingSecret .Values.envSecret.secretKey (default "" .Values.envSecret.existingSecretVersion) | sha256sum -}}
{{- end -}}
{{- else -}}
{{- include "lightrag.envContent" . | sha256sum -}}
{{- end -}}
{{- end -}}

{{/*
RAG storage PVC name.
*/}}
{{- define "lightrag.ragStorageClaimName" -}}
{{- if .Values.persistence.ragStorage.existingClaim -}}
{{- .Values.persistence.ragStorage.existingClaim -}}
{{- else -}}
{{- printf "%s-rag-storage" (include "lightrag.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Inputs PVC name.
*/}}
{{- define "lightrag.inputsClaimName" -}}
{{- if .Values.persistence.inputs.existingClaim -}}
{{- .Values.persistence.inputs.existingClaim -}}
{{- else -}}
{{- printf "%s-inputs" (include "lightrag.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Render .env file content from values.env.
*/}}
{{- define "lightrag.envContent" -}}
{{- $env := default (dict) .Values.env -}}
{{- $keys := keys $env | sortAlpha -}}
{{- $lines := list -}}
{{- range $key := $keys -}}
{{- $lines = append $lines (printf "%s=%v" $key (index $env $key)) -}}
{{- end -}}
{{- join "\n" $lines -}}
{{- end -}}

{{/*
Resolve reference name from either string or object {name: ...}.
*/}}
{{- define "lightrag.refName" -}}
{{- if kindIs "string" . -}}
{{- . -}}
{{- else if and (kindIs "map" .) (hasKey . "name") -}}
{{- .name -}}
{{- end -}}
{{- end -}}
