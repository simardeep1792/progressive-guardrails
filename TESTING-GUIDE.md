# Progressive Delivery Automation Guide

## Overview

This guide provides a streamlined approach to demonstrating progressive delivery capabilities using automated scripts and tmux session management. The entire demonstration can be completed in 15 minutes using 4 commands.

## Prerequisites

### Required Software

```bash
# macOS
brew install docker kind kubectl helm hey tmux

# Linux
sudo apt-get install docker kind kubectl helm tmux
go install github.com/rakyll/hey@latest

# Install kubectl argo rollouts plugin
brew install argoproj/tap/kubectl-argo-rollouts
```

### System Requirements

- Docker Desktop with 8GB+ memory allocation
- Kubernetes 1.25+
- Available ports: 8080, 3000, 3100, 8081, 20001

## Automated Demo Execution

### Phase 1: Infrastructure Setup

```bash
cd progressive-guardrails
./run.sh setup
```

**Duration:** 10 minutes

**Operations performed:**
- Kind cluster creation with local registry
- Istio service mesh installation
- Prometheus and Grafana monitoring stack
- Argo CD and Argo Rollouts deployment
- Application build, test, and initial deployment

### Phase 2: Dashboard Access

```bash
./run.sh dashboards
```

**Duration:** 30 seconds

**Operations performed:**
- Tmux session creation with 7 organized windows
- Automated port-forward establishment
- Browser tab opening for all dashboards
- Login credential display

**Accessible services:**
- Argo CD: http://localhost:8080 (admin/[password displayed])
- Argo Rollouts: http://localhost:3100/rollouts/rollout/dev/webapp
- Grafana: http://localhost:3000 (admin/admin)
- Kiali: http://localhost:20001 (no authentication)

### Phase 3: Successful Canary Deployment

```bash
./run.sh canary-success
```

**Duration:** 3 minutes

**Operations performed:**
- New application version build (v1.1)
- Canary deployment initiation
- Automated traffic generation
- Progressive traffic shifting: 10% → 30% → 60% → 100%
- Analysis validation at each step

### Phase 4: Auto-Rollback Demonstration

```bash
./run.sh canary-failure
```

**Duration:** 3 minutes

**Operations performed:**
- New application version build (v1.2)
- Canary deployment initiation
- Traffic generation
- Failure injection
- Automatic rollback execution
- Traffic restoration to stable version

## Tmux Session Management

### Session Access

```bash
tmux attach -t progressive-guardrails
```

### Window Structure

- **Window 0: Main** - Primary control and command execution
- **Window 1: ArgoCD** - Argo CD port-forward (8080)
- **Window 2: Rollouts** - Argo Rollouts port-forward (3100)
- **Window 3: Grafana** - Grafana port-forward (3000)
- **Window 4: Gateway** - Istio gateway port-forward (8081)
- **Window 5: Traffic** - Traffic generation commands
- **Window 6: Kiali** - Kiali port-forward (20001)

### Navigation Commands

- `Ctrl+b then 0-6` - Switch between windows
- `Ctrl+b then d` - Detach from session
- `Ctrl+c` - Stop current command

## Monitoring and Analysis

### Argo Rollouts Dashboard

**Successful canary progression:**
- Traffic weight progression: 10% → 30% → 60% → 100%
- Analysis status: "Successful" for all steps
- Step progression: 1 → 3 → 5 → 7 → 8

**Auto-rollback scenario:**
- Traffic weight: 10% → 0% (rollback)
- Analysis status: "Failed"
- Automatic reversion to stable version

### Grafana Metrics Dashboard

**Key indicators:**
- Success rate gauge: >99% (healthy) / <99% (failing)
- P95 latency: <300ms (healthy) / >300ms (failing)
- Request rate: Traffic pattern visualization

### Service Mesh Visualization (Kiali)

- Real-time traffic flow visualization
- Service health status monitoring
- Request distribution analysis

## Additional Commands

### System Testing

```bash
# Application connectivity test
./run.sh test

# System status check
./run.sh status
```

### Cleanup Operations

```bash
# Application reset (preserve cluster)
./run.sh cleanup

# Complete environment removal
./run.sh nuke
```

## Troubleshooting

### Port-Forward Issues

```bash
# Restart tmux session
tmux kill-session -t progressive-guardrails
./run.sh dashboards
```

### Dashboard Access Problems

**Argo CD login issues:**
- Use credentials displayed in terminal
- Default fallback: admin/admin

**Grafana authentication:**
- Username: admin
- Password: admin

**Browser loading issues:**
- Refresh browser tabs
- Clear browser cache
- Verify port-forwards are active

### Application Connectivity

```bash
# Direct application test
curl -H "Host: webapp.local" http://localhost:8081/

# Health check endpoint
curl -H "Host: webapp.local" http://localhost:8081/healthz
```

### Rollout Recovery

```bash
# Check rollout status
kubectl argo rollouts get rollout webapp -n dev

# Clear failed analysis runs
kubectl delete analysisrun -n dev --all

# Reset and restart
./run.sh cleanup
./run.sh canary-success
```

## Validation Criteria

Upon completion, the demonstration validates:

1. **CI Gate Enforcement** - Automated testing gates deployment progression
2. **Progressive Traffic Management** - Gradual traffic shifting with analysis
3. **Automated Decision Making** - Metrics-driven deployment decisions
4. **SLO-Based Rollback** - Automatic failure detection and rollback
5. **GitOps Workflow** - Git-tracked configuration management
6. **Comprehensive Observability** - Full system visibility and monitoring

## Architecture Validation

The demonstration proves production-ready capabilities for:
- Zero-downtime deployments
- Automated failure detection
- Risk mitigation through progressive delivery
- Comprehensive monitoring and alerting
- Enterprise-grade GitOps practices

## Post-Demo Cleanup

```bash
# Remove environment
./run.sh nuke

# Remove hosts entry (optional)
sudo sed -i '' '/webapp.local/d' /etc/hosts
```
