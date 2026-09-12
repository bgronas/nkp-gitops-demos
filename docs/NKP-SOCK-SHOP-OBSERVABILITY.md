# NKP Sock Shop observability with centralized Grafana

This document describes the complete setup that was required to make the Sock Shop workload on `nkp-demo-01` visible in NKP centralized Grafana through Prometheus and Thanos.

The goal was to use the monitoring stack already delivered by NKP instead of deploying a separate Prometheus/Grafana stack for the demo.

## Final result

The working data path is:

```text
Sock Shop Pods
other-project-rxmz5
        │
        ▼
kube-state-metrics + kubelet/cAdvisor
        │
        ▼
kube-prometheus-stack
Prometheus on nkp-demo-01
        │
        ▼
Thanos sidecar / StoreAPI :10901
        │
        ▼
NKP centralized Thanos Query
on nkp-demo-mgmt
        │
        ▼
NKP centralized Grafana
Datasource: ThanosQuery
        │
        ▼
NKP / Workload Namespace / Pods & Resources
```

Observed final state:

- Sock Shop namespace: `other-project-rxmz5`
- Sock Shop workload cluster: `nkp-demo-01`
- Management cluster: `nkp-demo-mgmt`
- Sock Shop Pods visible through Thanos: `15`
- Deployments visible in Grafana: `15`
- Container CPU series visible locally in Prometheus: `46`
- `kube-prometheus-stack`: `True`
- `prometheus-adapter`: `True`
- `prometheus-thanos-traefik`: `True`

## Tested environment

| Item | Value |
| --- | --- |
| NKP management cluster | `nkp-demo-mgmt` |
| Management kubectl context | `nkp-demo-mgmt-admin@nkp-demo-mgmt` |
| NKP workload cluster | `nkp-demo-01` |
| Workload kubectl context | `nkp-demo-01-admin@nkp-demo-01` |
| NKP management namespace | `kommander` |
| NKP default workspace namespace | `kommander-default-workspace` |
| NKP project namespace | `other-project-rxmz5` |
| Sock Shop Git path | `./sock-shop` |
| Grafana datasource | `ThanosQuery` |
| kube-prometheus-stack | `82.13.6` |
| prometheus-adapter | `5.3.0` |
| prometheus-thanos-traefik AppDeployment | `0.0.5` |

The UUID values used by Thanos are environment-specific. In this lab the observed values were:

| NKP cluster | Thanos `cluster` label |
| --- | --- |
| `nkp-demo-mgmt` | `2eeca6ff-675e-4e73-a0a6-dae77b15b13c` |
| `nai-demo` | `6916de1b-91e9-4db5-9a6f-74d76b6bbb58` |
| `nkp-demo-01` | `04bc1e62-babc-41fe-ac2d-c6249d78d227` |

Do not hard-code these UUIDs in reusable dashboards. Discover them from Thanos and use Grafana variables.

## Repository layout

The NKP-specific files are kept separate from the application manifests:

```text
nkp-gitops-demos/
├── sock-shop/
│   └── ... application manifests ...
├── nkp-platform/
│   └── monitoring/
│       └── nkp-demo-01/
│           ├── README.md
│           ├── apply.sh
│           ├── cleanup-project-scope.sh
│           ├── kustomization.yaml
│           ├── kube-prometheus-stack.yaml
│           └── prometheus-adapter.yaml
├── nkp-grafana/
│   └── sock-shop/
│       ├── README.md
│       ├── apply.sh
│       ├── kustomization.yaml
│       └── sock-shop-nkp.json
└── docs/
    └── NKP-SOCK-SHOP-OBSERVABILITY.md
```

The application remains a workload concern. Platform monitoring is reconciled from NKP workspace scope. The centralized Grafana dashboard is provisioned on the management cluster.

# Clean installation procedure

## 1. Clone the repository

If the repository is not already present locally, do not create an empty directory and run `git pull`; an empty directory is not a Git repository.

Use:

```bash
mkdir -p ~/nkp-gitops-demos
cd ~/nkp-gitops-demos
git clone https://github.com/bgronas/nkp-gitops-demos.git .
```

Verify:

```bash
git status
git remote -v
git branch --show-current
```

Expected branch:

```text
master
```

For later updates:

```bash
cd ~/nkp-gitops-demos
git pull
```

## 2. Verify kubectl contexts

```bash
kubectl config get-contexts -o name
```

Required contexts in this lab:

```text
nkp-demo-mgmt-admin@nkp-demo-mgmt
nkp-demo-01-admin@nkp-demo-01
```

Verify that the management cluster contains the NKP management namespace:

```bash
kubectl --context nkp-demo-mgmt-admin@nkp-demo-mgmt \
  get namespace kommander
```

Verify the workload project namespace:

```bash
kubectl --context nkp-demo-01-admin@nkp-demo-01 \
  get namespace other-project-rxmz5
```

## 3. Verify the application before touching monitoring

```bash
kubectl --context nkp-demo-01-admin@nkp-demo-01 \
  -n other-project-rxmz5 \
  get pods -o wide
```

```bash
kubectl --context nkp-demo-01-admin@nkp-demo-01 \
  -n other-project-rxmz5 \
  get deploy,svc
```

In the working lab, Sock Shop plus the Guestbook workload produced 15 Running Pods and 15 Deployments.

This step is important: if the application itself is not healthy, Grafana is not the first problem to solve.

## 4. Check whether the workload cluster already has NKP monitoring

```bash
kubectl --context nkp-demo-01-admin@nkp-demo-01 \
  get pods -A | grep -E 'prometheus|kube-state'
```

```bash
kubectl --context nkp-demo-01-admin@nkp-demo-01 \
  get helmreleases.helm.toolkit.fluxcd.io -A \
  | grep -E 'kube-prometheus|prometheus-adapter|prometheus-thanos'
```

Before the fix, `nkp-demo-01` had `prometheus-thanos-traefik`, but no `kube-prometheus-stack` and no `prometheus-adapter`. This was the reason `other-project-rxmz5` did not exist in Grafana's namespace selector and returned no `kube_pod_info` or cAdvisor data through Thanos.

## 5. Enable monitoring at NKP workspace scope

The correct scope is the NKP workspace namespace:

```text
kommander-default-workspace
```

The AppDeployments in this repository are restricted to:

```yaml
clusterSelector:
  matchExpressions:
    - key: kommander.d2iq.io/cluster-name
      operator: In
      values:
        - nkp-demo-01
```

This means the AppDeployment CRs are stored on the management cluster because that is where NKP controls desired state, but the selected workload target is `nkp-demo-01`.

Run:

```bash
cd ~/nkp-gitops-demos
git pull
bash ./nkp-platform/monitoring/nkp-demo-01/apply.sh
```

The script performs:

1. management context validation;
2. workspace namespace validation;
3. display of existing workspace AppDeployments;
4. server-side dry-run;
5. `kubectl diff`;
6. explicit confirmation before apply.

The expected changes are only:

```text
kommander-default-workspace/kube-prometheus-stack
kommander-default-workspace/prometheus-adapter
```

`prometheus-thanos-traefik` already existed at workspace scope in this environment and is therefore not created by this bundle.

## 6. Verify NKP reconciliation

Management-side desired state:

```bash
kubectl --context nkp-demo-mgmt-admin@nkp-demo-mgmt \
  -n kommander-default-workspace \
  get appdeployments \
  -o custom-columns='NAME:.metadata.name,APP:.spec.appRef.name,CLUSTERS:.status.clusters[*].name' \
  | grep -E 'NAME|kube-prometheus-stack|prometheus-adapter|prometheus-thanos-traefik'
```

Expected target:

```text
nkp-demo-01
```

Watch workload Helm reconciliation:

```bash
watch -n 5 '
kubectl --context nkp-demo-01-admin@nkp-demo-01 \
  get helmreleases.helm.toolkit.fluxcd.io -A \
  | grep -E "kube-prometheus|prometheus-adapter|prometheus-thanos"
'
```

Final expected state:

```text
kommander-default-workspace   kube-prometheus-stack       True
kommander-default-workspace   prometheus-adapter          True
kommander-default-workspace   prometheus-thanos-traefik   True
```

It is normal for `prometheus-adapter` to report that its dependency is not ready while `kube-prometheus-stack` is still installing.

## 7. Verify monitoring Pods and Services

```bash
kubectl --context nkp-demo-01-admin@nkp-demo-01 \
  -n kommander-default-workspace \
  get pods | grep -E 'prometheus|kube-state|node-exporter|alertmanager'
```

A healthy deployment should contain resources similar to:

```text
alertmanager-kube-prometheus-stack-alertmanager-0
kube-prometheus-stack-grafana-...
kube-prometheus-stack-kube-state-metrics-...
kube-prometheus-stack-operator-...
kube-prometheus-stack-prometheus-node-exporter-...
prometheus-adapter-...
prometheus-kube-prometheus-stack-prometheus-0
```

Verify the Prometheus service:

```bash
kubectl --context nkp-demo-01-admin@nkp-demo-01 \
  -n kommander-default-workspace \
  get svc | grep prometheus
```

The important service is:

```text
kube-prometheus-stack-prometheus
```

with ports including:

```text
9090/TCP
10901/TCP
```

`9090` is Prometheus HTTP. `10901` is the Thanos StoreAPI/gRPC endpoint exposed by the Prometheus/Thanos integration.

## 8. Remove any earlier Project-scope attempt

This is required only if the earlier incorrect Project-scope AppDeployments were created.

Wait until all workspace-scoped monitoring components are `True`, then run:

```bash
cd ~/nkp-gitops-demos
bash ./nkp-platform/monitoring/nkp-demo-01/cleanup-project-scope.sh
```

The cleanup script removes only these AppDeployments from `other-project-rxmz5`:

```text
kube-prometheus-stack
prometheus-adapter
prometheus-thanos-traefik
```

It does not delete the workspace-scoped monitoring stack and does not modify the management cluster's own monitoring workload.

Verify afterwards:

```bash
kubectl --context nkp-demo-01-admin@nkp-demo-01 \
  get helmreleases.helm.toolkit.fluxcd.io -A \
  | grep -E 'kube-prometheus|prometheus-adapter|prometheus-thanos'
```

Only the workspace-scoped entries should remain.

# Validate the metrics path

## 9. Validate Prometheus locally on `nkp-demo-01`

Start a port-forward and leave it running:

```bash
kubectl --context nkp-demo-01-admin@nkp-demo-01 \
  -n kommander-default-workspace \
  port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

In another terminal, verify kube-state-metrics data:

```bash
curl -G -sS \
  'http://127.0.0.1:9090/api/v1/query' \
  --data-urlencode 'query=count by (namespace) (kube_pod_info{namespace="other-project-rxmz5"})' \
  | jq
```

Working result in this lab:

```text
15
```

Verify kubelet/cAdvisor data:

```bash
curl -G -sS \
  'http://127.0.0.1:9090/api/v1/query' \
  --data-urlencode 'query=count by (namespace) (container_cpu_usage_seconds_total{namespace="other-project-rxmz5"})' \
  | jq
```

Working result in this lab:

```text
46 series
```

These two checks prove that the workload Prometheus is collecting Kubernetes state and container resource metrics for the project namespace.

## 10. Validate centralized Thanos Query

Start a second port-forward on the management cluster:

```bash
kubectl --context nkp-demo-mgmt-admin@nkp-demo-mgmt \
  -n kommander \
  port-forward svc/thanos-query 10902:10902
```

In another terminal:

```bash
curl -G -sS \
  'http://127.0.0.1:10902/api/v1/query' \
  --data-urlencode 'query=count by (cluster,namespace) (kube_pod_info{namespace="other-project-rxmz5"})' \
  | jq
```

Working result:

```text
cluster   = 04bc1e62-babc-41fe-ac2d-c6249d78d227
namespace = other-project-rxmz5
value     = 15
```

This is the decisive end-to-end test. Local Prometheus plus a successful Thanos query proves that centralized Grafana can query the workload cluster.

To discover all current cluster IDs through Thanos:

```bash
curl -G -sS \
  'http://127.0.0.1:10902/api/v1/query' \
  --data-urlencode 'query=count by (cluster,namespace) (kube_pod_info)' \
  | jq
```

# Provision the NKP centralized Grafana dashboard

## 11. Dashboard design

The dashboard is stored as JSON in Git and is provisioned into NKP centralized Grafana through a ConfigMap.

Path:

```text
nkp-grafana/sock-shop/
```

The ConfigMap uses the label expected by the centralized Grafana sidecar:

```yaml
grafana_dashboard_kommander: "1"
```

The dashboard datasource is:

```text
ThanosQuery
```

The dashboard is inspired by Grafana.com dashboard `15758` (`Kubernetes / Views / Namespaces`) but was adapted for this NKP environment rather than copied unchanged.

## 12. Apply the dashboard

```bash
cd ~/nkp-gitops-demos
git pull
bash ./nkp-grafana/sock-shop/apply.sh
```

The script first performs a server-side dry-run against:

```text
context   = nkp-demo-mgmt-admin@nkp-demo-mgmt
namespace = kommander
```

The expected Kubernetes change is one ConfigMap:

```text
configmap/grafana-dashboard-sock-shop
```

This does not reinstall Grafana, Prometheus, Thanos, NKP, or any workload cluster component.

The dashboard appears as:

```text
NKP / Workload Namespace / Pods & Resources
```

## 13. Select the workload in Grafana

Select:

```text
Cluster   = 04bc1e62-babc-41fe-ac2d-c6249d78d227
Namespace = other-project-rxmz5
```

The dashboard then shows only the selected workload namespace rather than all management and workload namespaces.

Current panels include:

- Ready Pods
- Running Pods
- Deployments
- Restarts / 15 min
- CPU usage by Pod
- Memory working set by Pod
- CPU usage / request by Pod
- Memory usage / request by Pod
- Network receive by Pod
- Network transmit by Pod
- Container restarts by Pod
- Pod phases
- Desired vs available replicas
- CPU throttling by Pod

# Problems encountered and why they happened

## Grafana initially showed all clusters and hundreds of Pods

Cause:

```text
Cluster = All
Namespace = All
```

The dashboard was working, but it was showing the entire data set available through Thanos.

Fix: select the workload cluster and project namespace.

## `other-project-rxmz5` was missing from the namespace selector

Cause: `nkp-demo-01` did not have a working `kube-prometheus-stack`. There was no `kube_pod_info` or cAdvisor data for the namespace in centralized Thanos.

Evidence before the fix:

```promql
kube_pod_info{namespace="other-project-rxmz5"}
```

and:

```promql
container_cpu_usage_seconds_total{namespace="other-project-rxmz5"}
```

returned no data through centralized Thanos.

Fix: enable the NKP monitoring applications for `nkp-demo-01` at workspace scope.

## First monitoring attempt used Project scope and failed

The first attempt created AppDeployments in:

```text
other-project-rxmz5
```

That was incorrect for these platform applications.

`kube-prometheus-stack` failed because the Project service account could not patch cluster-scoped RBAC resources:

```text
User "system:serviceaccount:other-project-rxmz5:other-project-rxmz5"
cannot patch resource "clusterroles"
```

`prometheus-adapter` failed because Gatekeeper rejected the generated HelmRelease:

```text
[helmrelease-must-have-sa] must have a serviceAccountName set
```

Fix: move `kube-prometheus-stack` and `prometheus-adapter` to `kommander-default-workspace` and restrict them with `clusterSelector` to `nkp-demo-01`.

## Duplicate Project-scope `prometheus-thanos-traefik`

The Project-scope attempt successfully created a second `prometheus-thanos-traefik`, while a healthy workspace-scoped instance already existed.

Fix: after workspace monitoring was healthy, remove the Project-scope AppDeployments with:

```bash
bash ./nkp-platform/monitoring/nkp-demo-01/cleanup-project-scope.sh
```

## `Deployments` showed `No data`

The original Grafana panel used:

```promql
kube_deployment_labels
```

That metric was not available in this NKP/kube-state-metrics data set.

Fix: count deployments using:

```promql
count(
  kube_deployment_spec_replicas{
    cluster=~"$cluster",
    namespace=~"$namespace"
  }
)
```

This produced the expected value `15`.

## Cluster names in Grafana appeared as UUIDs

This is expected. NKP's Prometheus configuration adds a `cluster` external label and centralized Thanos exposes that label. The label value is the monitoring/cluster ID rather than the human-readable NKP cluster name.

Do not assume the UUID from another cluster. Identify it through Thanos and then select it in Grafana.

## A curl test returned no output

One command accidentally contained:

```bash
curl -G -s \ \
```

The extra escaped space broke the command and `-s` hid the error.

Use:

```bash
curl -G -sS \
```

`-sS` keeps successful output quiet while still displaying errors.

## Dex/Kubernetes Dashboard authentication was investigated but was not the Grafana problem

The Kubernetes Dashboard route redirected through Dex, but Dex logs showed a successful login. That path is independent of Grafana's Thanos datasource.

The Grafana problem was missing workload monitoring data, not Dex authentication.

# Management cluster safety boundary

The management cluster was not converted into the workload monitoring target.

Two types of objects are intentionally stored on `nkp-demo-mgmt`:

1. NKP `AppDeployment` desired-state objects, because the NKP control plane runs there.
2. The Grafana dashboard ConfigMap, because centralized Grafana runs there.

The monitoring AppDeployments use:

```yaml
values:
  - nkp-demo-01
```

under the cluster selector. Therefore the actual `kube-prometheus-stack` and `prometheus-adapter` workload is reconciled to `nkp-demo-01`, not to `nkp-demo-mgmt`.

The management cluster's existing Prometheus/Grafana/Thanos installation was not replaced by this setup.

# What the current dashboard measures

The current dashboard is primarily a Kubernetes workload/resource dashboard. It uses:

- kube-state-metrics
- kubelet/cAdvisor container metrics
- NKP Prometheus
- Thanos

It does not require Sock Shop application-specific `/metrics` endpoints for the current CPU, memory, Pod, Deployment, network, restart and capacity panels.

If the demo later needs application-level metrics such as HTTP request rate, latency, error rate, cart operations or order throughput, those application metrics must be exposed and scraped separately through Pod annotations, `ServiceMonitor`, `PodMonitor`, or another supported Prometheus scrape configuration.

# Useful operational checks

## Show workspace AppDeployments

```bash
kubectl --context nkp-demo-mgmt-admin@nkp-demo-mgmt \
  -n kommander-default-workspace \
  get appdeployments
```

## Show generated AppDeploymentInstances

```bash
kubectl --context nkp-demo-mgmt-admin@nkp-demo-mgmt \
  get appdeploymentinstances.apps.kommander.d2iq.io -A \
  | grep -E 'kube-prometheus|prometheus-adapter|prometheus-thanos'
```

## Show Flux Kustomizations on the workload cluster

```bash
kubectl --context nkp-demo-01-admin@nkp-demo-01 \
  get kustomizations.kustomize.toolkit.fluxcd.io -A \
  | grep -E 'kube-prometheus|prometheus-adapter|prometheus-thanos|other-project'
```

## Show HelmReleases

```bash
kubectl --context nkp-demo-01-admin@nkp-demo-01 \
  get helmreleases.helm.toolkit.fluxcd.io -A \
  | grep -E 'kube-prometheus|prometheus-adapter|prometheus-thanos'
```

## Show recent monitoring failures

```bash
kubectl --context nkp-demo-01-admin@nkp-demo-01 \
  get events -A \
  --sort-by=.lastTimestamp \
  | grep -Ei 'prometheus|other-project-rxmz5|failed|error' \
  | tail -50
```

# Rollback

## Remove only the custom Grafana dashboard

```bash
kubectl --context nkp-demo-mgmt-admin@nkp-demo-mgmt \
  -n kommander \
  delete configmap grafana-dashboard-sock-shop
```

This removes only the custom dashboard.

## Disable the monitoring additions for `nkp-demo-01`

Only do this if the workload cluster should no longer use the monitoring applications enabled by this demo:

```bash
kubectl --context nkp-demo-mgmt-admin@nkp-demo-mgmt \
  -n kommander-default-workspace \
  delete appdeployment kube-prometheus-stack prometheus-adapter
```

Do not delete the pre-existing workspace `prometheus-thanos-traefik` as part of this demo rollback.

# Summary: what had to fit together

The final solution depended on four separate layers being correct at the same time.

| Layer | Requirement | Working implementation |
| --- | --- | --- |
| Application | Sock Shop must be healthy on the workload cluster | 15 Running Pods in `other-project-rxmz5` |
| Workload monitoring | Prometheus, kube-state-metrics and cAdvisor collection must exist on `nkp-demo-01` | `kube-prometheus-stack` `82.13.6` at workspace scope |
| Multi-cluster aggregation | Workload Prometheus must be reachable through Thanos | Thanos sidecar/StoreAPI `10901` and centralized `ThanosQuery` |
| Visualization | Grafana must query Thanos and filter by cluster/namespace | Git-provisioned dashboard with `Cluster` and `Namespace` variables |

The main technical nuance was **scope**. Sock Shop belongs in a Project namespace, but the monitoring platform applications create cluster-scoped resources and therefore had to be enabled from NKP **workspace scope**. Once that was corrected, NKP reconciled the monitoring stack to `nkp-demo-01`, Prometheus immediately saw the Sock Shop namespace, Thanos exposed the data centrally, and Grafana could filter the same data by cluster and namespace.

The result is not a standalone monitoring stack built beside NKP. It uses NKP's own control plane, workspace application model, Prometheus stack, Thanos aggregation and centralized Grafana. The only custom visualization artifact is the dashboard JSON/ConfigMap stored in this repository.
