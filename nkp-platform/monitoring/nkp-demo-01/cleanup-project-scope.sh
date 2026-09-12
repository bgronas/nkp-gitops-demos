#!/usr/bin/env bash
set -euo pipefail

MGMT_CONTEXT="${MGMT_CONTEXT:-nkp-demo-mgmt-admin@nkp-demo-mgmt}"
PROJECT_NAMESPACE="${PROJECT_NAMESPACE:-other-project-rxmz5}"

kubectl config get-contexts -o name | grep -Fxq "$MGMT_CONTEXT"
kubectl --context "$MGMT_CONTEXT" get namespace "$PROJECT_NAMESPACE" >/dev/null

echo "Project-scoped AppDeployments currently present:"
kubectl --context "$MGMT_CONTEXT" -n "$PROJECT_NAMESPACE" get appdeployments 2>/dev/null || true

echo
read -r -p "Delete project-scoped monitoring AppDeployments from $PROJECT_NAMESPACE? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || exit 0

kubectl --context "$MGMT_CONTEXT" -n "$PROJECT_NAMESPACE" delete appdeployment \
  kube-prometheus-stack \
  prometheus-adapter \
  prometheus-thanos-traefik \
  --ignore-not-found

echo
echo "Remaining AppDeployments in $PROJECT_NAMESPACE:"
kubectl --context "$MGMT_CONTEXT" -n "$PROJECT_NAMESPACE" get appdeployments 2>/dev/null || true
