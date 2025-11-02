# progressive-guardrails

Local proof-of-concept demonstrating progressive delivery with automated rollback based on SLO breaches.

## Prerequisites

- Docker Desktop
- kind 0.20+
- kubectl
- helm
- hey or ab
- kubectl-argo-rollouts plugin

## Quick Start

```bash
# Add to /etc/hosts
echo "127.0.0.1 webapp.local" | sudo tee -a /etc/hosts

# Setup infrastructure
make kind-up
make istio-install
make monitoring-install
make argo-install

# Build and deploy
make app-build app-test app-push
make deploy-dev

# Access dashboards
make open-argocd      # admin password shown
make open-rollouts    # localhost:3100
make open-grafana     # localhost:3000 admin/admin
make open-kiali       # localhost:20001
make open-gateway     # localhost:8081

# Canary deployment
make canary-start
make test-canary      # in another terminal
make canary-watch

# Test rollback
make induce-failure
# observe auto-rollback in dashboards

# Fix and promote
make app-build app-push
make canary-start
make canary-promote
```

## Architecture

- Kind cluster with local registry at localhost:5001
- Istio service mesh for traffic management
- Argo CD for GitOps deployment
- Argo Rollouts for progressive delivery
- Prometheus + Grafana for metrics
- Kiali for service mesh visualization

## Canary Strategy

1. 10% traffic → pause → analysis
2. 30% traffic → pause → analysis
3. 60% traffic → pause → analysis
4. 100% traffic

Auto-rollback triggers:
- Success rate < 99% over 1 minute
- P95 latency > 300ms

## Local Development

```bash
# Clean slate
make reset

# Full cleanup
make nuke

# Check rollout status
kubectl argo rollouts get rollout webapp -n dev
```

## Port Mappings

| Service | Local Port | Access |
|---------|------------|--------|
| Argo CD | 8080 | make open-argocd |
| Rollouts | 3100 | make open-rollouts |
| Grafana | 3000 | make open-grafana |
| Kiali | 20001 | make open-kiali |
| Gateway | 8081 | make open-gateway |
| Prometheus | 9090 | kubectl port-forward |

## Troubleshooting

- Ensure Docker has 8GB+ memory allocated
- Check pod status: `kubectl get pods -A`
- View rollout events: `kubectl describe rollout webapp -n dev`
- Gateway logs: `kubectl logs -n istio-system -l app=istio-ingressgateway`