# NKP monitoring enablement for `nkp-demo-01`

This directory enables the NKP monitoring platform applications for the `nkp-demo-01` workload cluster from the `other-project-rxmz5` project namespace on the management cluster.

The bundle mirrors the working application set used by the `nai-demo` project:

- `kube-prometheus-stack` `82.13.6`
- `prometheus-adapter` `5.3.0`
- `prometheus-thanos-traefik` `0.0.5`

All three `AppDeployment` resources are restricted by:

```yaml
clusterSelector:
  matchExpressions:
    - key: kommander.d2iq.io/cluster-name
      operator: In
      values:
        - nkp-demo-01
```

The resources are created in the NKP project namespace:

```text
other-project-rxmz5
```

## Why this exists

`nkp-demo-01` did not have a `kube-prometheus-stack` HelmRelease, and centralized Thanos returned no `kube_pod_info` or `container_cpu_usage_seconds_total` series for `other-project-rxmz5`. The project also had no `AppDeployment` resources.

This is a platform-level change: applying this bundle instructs NKP to reconcile the monitoring stack onto `nkp-demo-01`. It does not modify the Sock Shop application manifests.

## Apply safely

From the repository root:

```bash
bash ./nkp-platform/monitoring/nkp-demo-01/apply.sh
```

The script performs:

1. management-context validation;
2. project-namespace validation;
3. server-side dry-run;
4. `kubectl diff`;
5. explicit confirmation before apply.

## Verify after apply

Management cluster:

```bash
kubectl --context nkp-demo-mgmt-admin@nkp-demo-mgmt \
  -n other-project-rxmz5 get appdeployments
```

Workload cluster:

```bash
kubectl --context nkp-demo-01-admin@nkp-demo-01 \
  get helmreleases.helm.toolkit.fluxcd.io -A \
  | grep -E 'prometheus|thanos'
```

Then check that Prometheus and kube-state-metrics Pods appear:

```bash
kubectl --context nkp-demo-01-admin@nkp-demo-01 \
  get pods -A | grep -E 'prometheus|kube-state'
```
