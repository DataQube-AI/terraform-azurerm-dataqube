#!/bin/sh
# Waits until Terraform's own credential may install into the cluster. An Azure RBAC grant reaches
# AKS's API minutes after it exists (up to 5, AKS's docs say; Azure's, up to 10), and meanwhile some
# calls are allowed while others are refused. So this asks the API, with the credential the
# Kubernetes and Helm providers use, whether it may create Secrets and CustomResourceDefinitions,
# until it says yes 3 times in a row, 10 seconds apart. It gives up after 10 minutes; another
# terraform apply then carries on.
#
# Env: HOST (the API server's URL), CA (its CA certificate, PEM), TOKEN_COMMAND (the providers'
# exec command and arguments, which print an ExecCredential). Needs curl and jq. The token goes to
# curl on its standard input, never on a command line.
set -eu
ca=$(mktemp)
trap 'rm -f "$ca"' EXIT
printf '%s\n' "$CA" > "$ca"

allowed() { # verb resource group: "true" or "false"
  token=$($TOKEN_COMMAND | jq -r .status.token) || return 1
  printf 'header = "Authorization: Bearer %s"\n' "$token" \
    | curl -sS --max-time 10 -K - --cacert "$ca" -H 'Content-Type: application/json' \
      -X POST "$HOST/apis/authorization.k8s.io/v1/selfsubjectaccessreviews" \
      -d "{\"apiVersion\": \"authorization.k8s.io/v1\", \"kind\": \"SelfSubjectAccessReview\", \"spec\": {\"resourceAttributes\": {\"verb\": \"$1\", \"resource\": \"$2\", \"group\": \"$3\"}}}" \
    | jq -r '.status.allowed // false'
}

$TOKEN_COMMAND > /dev/null || { echo "can't get a token for the cluster with: $TOKEN_COMMAND" >&2; exit 1; }
in_a_row=0 waited=0
while :; do
  if [ "$(allowed create secrets "" 2>/dev/null)" = true ] \
    && [ "$(allowed create customresourcedefinitions apiextensions.k8s.io 2>/dev/null)" = true ]; then
    in_a_row=$((in_a_row + 1))
    [ "$in_a_row" -lt 3 ] || break
  else
    in_a_row=0
  fi
  if [ "$waited" -ge 600 ]; then
    echo "the cluster still refuses Terraform's credential after 10 minutes; run terraform apply again" >&2
    exit 1
  fi
  sleep 10
  waited=$((waited + 10))
done
echo "the cluster accepts Terraform's credential (after ${waited}s)"
