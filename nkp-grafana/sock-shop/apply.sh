#!/usr/bin/env bash
set -euo pipefail

DEFAULT_CONTEXT="nkp-demo-mgmt-admin@nkp-demo-mgmt"
CONTEXT="${1:-$DEFAULT_CONTEXT}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if ! kubectl config get-contexts -o name | grep -Fxq "$CONTEXT"; then
  echo "kubectl context not found: $CONTEXT" >&2
  exit 1
fi

if ! kubectl --context "$CONTEXT" get namespace kommander >/dev/null; then
  echo "Namespace 'kommander' is not accessible through context: $CONTEXT" >&2
  exit 1
fi

echo "Target context: $CONTEXT"
echo "Target namespace: kommander"

echo "Running server-side dry run..."
kubectl --context "$CONTEXT" apply --dry-run=server -k "$SCRIPT_DIR"
echo
read -r -p "Apply Grafana dashboard ConfigMap to NKP management cluster? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || exit 0

kubectl --context "$CONTEXT" apply -k "$SCRIPT_DIR"
