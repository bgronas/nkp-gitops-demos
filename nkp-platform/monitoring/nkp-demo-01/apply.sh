#!/usr/bin/env bash
set -euo pipefail

MGMT_CONTEXT="${MGMT_CONTEXT:-nkp-demo-mgmt-admin@nkp-demo-mgmt}"
WORKSPACE_NAMESPACE="${WORKSPACE_NAMESPACE:-kommander-default-workspace}"
TARGET_CLUSTER="${TARGET_CLUSTER:-nkp-demo-01}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
KUSTOMIZE_DIR="$ROOT_DIR/nkp-platform/monitoring/nkp-demo-01"

kubectl config get-contexts -o name | grep -Fxq "$MGMT_CONTEXT"
kubectl --context "$MGMT_CONTEXT" get namespace "$WORKSPACE_NAMESPACE" >/dev/null

echo "Management context  : $MGMT_CONTEXT"
echo "Workspace namespace : $WORKSPACE_NAMESPACE"
echo "Target cluster      : $TARGET_CLUSTER"
echo

echo "Existing workspace AppDeployments:"
kubectl --context "$MGMT_CONTEXT" -n "$WORKSPACE_NAMESPACE" get appdeployments 2>/dev/null | grep -E 'NAME|kube-prometheus-stack|prometheus-adapter|prometheus-thanos-traefik' || true

echo
echo "Running server-side dry run..."
kubectl --context "$MGMT_CONTEXT" apply --dry-run=server -k "$KUSTOMIZE_DIR"

echo
echo "Diff against management cluster:"
set +e
kubectl --context "$MGMT_CONTEXT" diff -k "$KUSTOMIZE_DIR"
DIFF_RC=$?
set -e
if (( DIFF_RC > 1 )); then
  exit "$DIFF_RC"
fi

echo
read -r -p "Apply workspace-scoped NKP monitoring AppDeployments for $TARGET_CLUSTER? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || exit 0

kubectl --context "$MGMT_CONTEXT" apply -k "$KUSTOMIZE_DIR"

echo
echo "Workspace AppDeployment status:"
kubectl --context "$MGMT_CONTEXT" -n "$WORKSPACE_NAMESPACE" get appdeployments \
  -o custom-columns='NAME:.metadata.name,APP:.spec.appRef.name,CLUSTERS:.status.clusters[*].name' \
  | grep -E 'NAME|kube-prometheus-stack|prometheus-adapter|prometheus-thanos-traefik' || true

echo
echo "Verify workload reconciliation with:"
echo "kubectl --context nkp-demo-01-admin@nkp-demo-01 get kustomizations.kustomize.toolkit.fluxcd.io -A | grep -E 'kube-prometheus|prometheus-adapter|prometheus-thanos'"
echo "kubectl --context nkp-demo-01-admin@nkp-demo-01 get helmreleases.helm.toolkit.fluxcd.io -A | grep -E 'kube-prometheus|prometheus-adapter|prometheus-thanos'"
