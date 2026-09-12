#!/usr/bin/env bash
set -euo pipefail

MGMT_CONTEXT="${MGMT_CONTEXT:-nkp-demo-mgmt-admin@nkp-demo-mgmt}"
PROJECT_NAMESPACE="${PROJECT_NAMESPACE:-other-project-rxmz5}"
TARGET_CLUSTER="${TARGET_CLUSTER:-nkp-demo-01}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
KUSTOMIZE_DIR="$ROOT_DIR/nkp-platform/monitoring/nkp-demo-01"

if ! kubectl config get-contexts -o name | grep -Fxq "$MGMT_CONTEXT"; then
  echo "kubectl context not found: $MGMT_CONTEXT" >&2
  exit 1
fi

if ! kubectl --context "$MGMT_CONTEXT" get namespace "$PROJECT_NAMESPACE" >/dev/null 2>&1; then
  echo "NKP project namespace not found on management cluster: $PROJECT_NAMESPACE" >&2
  exit 1
fi

echo "Management context : $MGMT_CONTEXT"
echo "Project namespace  : $PROJECT_NAMESPACE"
echo "Target cluster     : $TARGET_CLUSTER"
echo

echo "Existing AppDeployments in project:"
kubectl --context "$MGMT_CONTEXT" -n "$PROJECT_NAMESPACE" get appdeployments 2>/dev/null || true

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
  echo "kubectl diff failed with exit code $DIFF_RC" >&2
  exit "$DIFF_RC"
fi

echo
read -r -p "Apply NKP monitoring AppDeployments for $TARGET_CLUSTER? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || exit 0

kubectl --context "$MGMT_CONTEXT" apply -k "$KUSTOMIZE_DIR"

echo
echo "AppDeployment status:"
kubectl --context "$MGMT_CONTEXT" -n "$PROJECT_NAMESPACE" get appdeployments

echo
echo "NKP will now reconcile the selected platform apps onto $TARGET_CLUSTER."
echo "Verify on the workload cluster with:"
echo "  kubectl --context nkp-demo-01-admin@nkp-demo-01 get helmreleases.helm.toolkit.fluxcd.io -A | grep -E 'prometheus|thanos'"
