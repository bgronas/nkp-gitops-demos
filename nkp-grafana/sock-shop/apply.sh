#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${1:?Usage: $0 <management-cluster-context>}"

kubectl --context "$CONTEXT" apply --dry-run=server -k nkp-grafana/sock-shop
echo
read -r -p "Apply dashboard ConfigMap to NKP management cluster? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || exit 0
kubectl --context "$CONTEXT" apply -k nkp-grafana/sock-shop
