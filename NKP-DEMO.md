# NKP demo additions

This fork contains NKP-specific GitOps and observability additions on top of the original example applications.

## Sock Shop observability

The complete end-to-end guide is:

[`docs/NKP-SOCK-SHOP-OBSERVABILITY.md`](docs/NKP-SOCK-SHOP-OBSERVABILITY.md)

It documents:

- the final NKP monitoring architecture;
- the required local commands;
- enabling `kube-prometheus-stack` and `prometheus-adapter` at workspace scope;
- why Project-scope deployment failed;
- Prometheus and Thanos validation;
- the NKP centralized Grafana dashboard;
- cluster/namespace selection;
- cleanup and rollback;
- the exact failure modes encountered during implementation.

Relevant repository paths:

```text
sock-shop/
nkp-platform/monitoring/nkp-demo-01/
nkp-grafana/sock-shop/
docs/NKP-SOCK-SHOP-OBSERVABILITY.md
```
