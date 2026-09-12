#!/usr/bin/env bash
set -euo pipefail

DEFAULT_CONTEXT="nkp-demo-mgmt-admin@nkp-demo-mgmt"
CONTEXT="${1:-$DEFAULT_CONTEXT}"

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

kubectl --context "$CONTEXT" apply --dry-run=server -k nkp-grafana/sock-shop
echo
read -r -p "Apply Grafana dashboard ConfigMap to NKP management cluster? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || exit 0

kubectl --context "$CONTEXT" apply -k nkp-grafana/sock-shop
