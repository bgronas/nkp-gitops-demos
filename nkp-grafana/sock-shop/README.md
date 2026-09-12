# NKP centralized Grafana — workload namespace dashboard

For the complete end-to-end procedure, architecture, validation commands, monitoring enablement, failure modes and rollback, see [`docs/NKP-SOCK-SHOP-OBSERVABILITY.md`](../../docs/NKP-SOCK-SHOP-OBSERVABILITY.md).

This directory provisions one additional dashboard into **NKP centralized Grafana** on the management cluster. It does not replace or reinstall Grafana, Prometheus, Thanos, NKP, or any workload cluster component.

## Target

- Management cluster: `nkp-demo-mgmt`
- kubectl context: `nkp-demo-mgmt-admin@nkp-demo-mgmt`
- NKP workspace namespace: `kommander`
- Grafana datasource: `ThanosQuery`

The centralized Grafana sidecar discovers ConfigMaps labelled:

```yaml
grafana_dashboard_kommander: "1"
```

## Multi-cluster behaviour

The dashboard queries `ThanosQuery` and exposes `cluster` and `namespace` variables. Both default to `All`, so the dashboard is not tied to the current Sock Shop project namespace or to one workload cluster. Select the Sock Shop workload cluster and project namespace in Grafana for the demo.

In this lab the working selection is:

```text
Cluster   = 04bc1e62-babc-41fe-ac2d-c6249d78d227
Namespace = other-project-rxmz5
```

The UUID is environment-specific. Discover the current value from Thanos rather than hard-coding it into a reusable dashboard.

## Apply manually

Run a server-side dry run first:

```bash
kubectl --context nkp-demo-mgmt-admin@nkp-demo-mgmt \
  apply --dry-run=server -k nkp-grafana/sock-shop
```

Then apply:

```bash
kubectl --context nkp-demo-mgmt-admin@nkp-demo-mgmt \
  apply -k nkp-grafana/sock-shop
```

Or use the guarded helper script from the repository root:

```bash
bash ./nkp-grafana/sock-shop/apply.sh
```

The script verifies the kubectl context and the `kommander` namespace, performs a server-side dry run, and asks for confirmation before applying.

## GitOps

For GitOps, create a dedicated source/reconciliation that targets the **management cluster** and this path:

```text
./nkp-grafana/sock-shop
```

Do not add this Kustomization to `sock-shop/kustomization.yaml`; the Sock Shop application belongs on a workload cluster while centralized Grafana runs on the management cluster.

## Dashboard reference

The dashboard design is based on Grafana.com dashboard `15758` (`Kubernetes / Views / Namespaces`) and adapted for NKP centralized Grafana/Thanos rather than copied unmodified.

The `Deployments` panel intentionally uses `kube_deployment_spec_replicas` rather than `kube_deployment_labels`, because the latter was not present in this environment's kube-state-metrics data set.
