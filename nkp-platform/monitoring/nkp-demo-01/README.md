# NKP monitoring enablement for `nkp-demo-01`

For the complete end-to-end procedure, architecture, validation commands, failure modes, rollback and final design, see [`docs/NKP-SOCK-SHOP-OBSERVABILITY.md`](../../../docs/NKP-SOCK-SHOP-OBSERVABILITY.md).

This directory enables NKP monitoring for the `nkp-demo-01` workload cluster at **workspace scope**.

## Why workspace scope

`kube-prometheus-stack` and `prometheus-adapter` create cluster-scoped resources. Deploying them from the project namespace `other-project-rxmz5` caused two policy/RBAC failures:

- `kube-prometheus-stack`: the project service account could not patch cluster-scoped `ClusterRole` resources.
- `prometheus-adapter`: Gatekeeper rejected the generated `HelmRelease` because it had no `serviceAccountName`.

The correct workspace namespace for this environment is:

```text
kommander-default-workspace
```

The target cluster remains restricted to:

```text
nkp-demo-01
```

## Applications

- `kube-prometheus-stack` `82.13.6`
- `prometheus-adapter` `5.3.0`

`prometheus-thanos-traefik` is **not** created by this bundle because it already exists and is healthy at workspace scope for `nkp-demo-01`.

## Apply

From the repository root:

```bash
bash ./nkp-platform/monitoring/nkp-demo-01/apply.sh
```

The script performs a server-side dry run and `kubectl diff` before asking for confirmation.

## Verify

Management cluster:

```bash
kubectl --context nkp-demo-mgmt-admin@nkp-demo-mgmt \
  -n kommander-default-workspace \
  get appdeployments \
  -o custom-columns='NAME:.metadata.name,APP:.spec.appRef.name,CLUSTERS:.status.clusters[*].name' \
  | grep -E 'NAME|kube-prometheus-stack|prometheus-adapter|prometheus-thanos-traefik'
```

Workload cluster:

```bash
kubectl --context nkp-demo-01-admin@nkp-demo-01 \
  get kustomizations.kustomize.toolkit.fluxcd.io -A \
  | grep -E 'kube-prometheus|prometheus-adapter|prometheus-thanos'
```

```bash
kubectl --context nkp-demo-01-admin@nkp-demo-01 \
  get helmreleases.helm.toolkit.fluxcd.io -A \
  | grep -E 'kube-prometheus|prometheus-adapter|prometheus-thanos'
```

## Remove the earlier project-scoped attempt

After the workspace-scoped `kube-prometheus-stack` and `prometheus-adapter` are Ready, remove the earlier project-scoped AppDeployments:

```bash
bash ./nkp-platform/monitoring/nkp-demo-01/cleanup-project-scope.sh
```

This deletes only these AppDeployments from `other-project-rxmz5`:

- `kube-prometheus-stack`
- `prometheus-adapter`
- `prometheus-thanos-traefik`

The existing workspace-scoped `prometheus-thanos-traefik` remains untouched.
