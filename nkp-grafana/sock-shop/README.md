# NKP centralized Grafana — Sock Shop dashboard

This directory provisions the Sock Shop dashboard into **NKP centralized Grafana**.

## Why this is separate from `sock-shop/`

The Sock Shop application belongs on a workload cluster. NKP centralized Grafana belongs on the management cluster.

The centralized Grafana sidecar watches ConfigMaps labelled:

```yaml
grafana_dashboard_kommander: "1"
```

Do not add this Kustomization to `sock-shop/kustomization.yaml` unless that source is explicitly reconciled on the management cluster.

## Apply on the NKP management cluster

Dry run:

```bash
kubectl --context <management-cluster> apply --dry-run=server -k nkp-grafana/sock-shop
```

Apply:

```bash
kubectl --context <management-cluster> apply -k nkp-grafana/sock-shop
```

Or create a dedicated NKP/Flux GitOps source that targets the management cluster and path:

```text
./nkp-grafana/sock-shop
```

## Datasource

The dashboard expects the NKP centralized Grafana datasource:

```text
ThanosQuery
```

It filters on NKP's `cluster` external label and the Kubernetes `namespace`.

## Default namespace

The dashboard defaults to:

```text
other-project-rxmz5
```

If the generated project namespace differs, select it from the dashboard variable.

## Visual reference

Grafana.com dashboard `15758` — Kubernetes / Views / Namespaces.
The checked-in dashboard is intentionally tuned for NKP and Sock Shop rather than copied unmodified.
