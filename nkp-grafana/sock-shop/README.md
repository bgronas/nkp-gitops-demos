# NKP centralized Grafana — workload namespace dashboard

This directory provisions one additional dashboard into **NKP centralized Grafana** on the management cluster. It does not change the Grafana, Prometheus, Thanos, NKP, or workload-cluster configuration.

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

Or use the guarded helper script from any working directory:

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

The dashboard design is based on the Grafana.com Kubernetes Views namespace dashboard family and is adapted for NKP centralized Grafana/Thanos rather than copied unmodified.
