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

**1. Initial Setup**
```bash
# Add to /etc/hosts
echo "127.0.0.1 webapp.local" | sudo tee -a /etc/hosts

# Navigate to project directory
cd progressive-guardrails

# Setup infrastructure (takes 5-10 minutes)
make kind-up
make istio-install
make monitoring-install
make argo-install
```

**2. Build and Deploy**
```bash
# Build, test, and deploy application
make app-build app-test app-push
make deploy-dev
```

**3. Access Dashboards (open 4 terminals)**
```bash
# Terminal 1: Argo CD (password displayed)
make open-argocd      # http://localhost:8080

# Terminal 2: Argo Rollouts
make open-rollouts    # http://localhost:3100/rollouts/rollout/dev/webapp

# Terminal 3: Grafana
make open-grafana     # http://localhost:3000 (admin/admin)

# Terminal 4: Gateway
make open-gateway     # Enables http://webapp.local:8081
```

**4. Test Canary Deployment**
```bash
# In main terminal
make app-build IMAGE_TAG=v1.1
make app-push IMAGE_TAG=v1.1
make canary-start IMAGE_TAG=v1.1

# In 6th terminal: Send traffic
make test-canary

# Watch progression: 10% → 30% → 60% → 100%
make canary-watch
```

**5. Test Auto-Rollback**
```bash
# Start new canary
make app-build IMAGE_TAG=v1.2
make app-push IMAGE_TAG=v1.2
make canary-start IMAGE_TAG=v1.2

# Send traffic, then inject failures
make test-canary &
make induce-failure

# Observe automatic rollback in dashboards
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

## Port Mappings & URLs

| Service | Local Port | URL | Credentials |
|---------|------------|-----|-------------|
| Argo CD | 8080 | http://localhost:8080 | admin/[shown in terminal] |
| Argo Rollouts | 3100 | http://localhost:3100/rollouts/rollout/dev/webapp | none |
| Grafana | 3000 | http://localhost:3000 | admin/admin |
| Kiali | 20001 | http://localhost:20001 | none |
| Gateway | 8081 | http://webapp.local:8081 | none |
| Application | 8081 | curl -H "Host: webapp.local" http://localhost:8081/ | none |

## Troubleshooting

**Dashboard Loading Issues:**
```bash
# Check port-forwards are running
ps aux | grep "kubectl port-forward"

# Restart if needed
kill $(ps aux | grep "kubectl port-forward" | awk '{print $2}') 2>/dev/null
cd progressive-guardrails && make open-rollouts
```

**Analysis Errors:**
```bash
# Delete failed analysis runs
kubectl get analysisrun -n dev
kubectl delete analysisrun <name> -n dev
```

**General Issues:**
- Ensure Docker has 8GB+ memory allocated
- Check pod status: `kubectl get pods -A`
- View rollout events: `kubectl describe rollout webapp -n dev`
- Check /etc/hosts: `grep webapp.local /etc/hosts`