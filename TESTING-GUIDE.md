# Progressive Guardrails - Complete Testing Guide

## ⚠️ IMPORTANT: Follow Steps in EXACT Order

This guide takes you from zero to a working progressive delivery demo in 30 minutes.

## Prerequisites

### 1. Install Required Tools

```bash
# Check each tool (all must work)
docker --version          # Must work
kind --version            # Must work  
kubectl version --client  # Must work
helm version              # Must work
hey -h                    # If fails: brew install hey
kubectl argo rollouts version  # If fails: brew install argoproj/tap/kubectl-argo-rollouts
```

### 2. Setup System Requirements

```bash
# Add hostname to /etc/hosts (REQUIRED)
echo "127.0.0.1 webapp.local" | sudo tee -a /etc/hosts

# Verify it was added
grep webapp.local /etc/hosts
# Should show: 127.0.0.1 webapp.local
```

### 3. Navigate to Project Directory

```bash
cd progressive-guardrails
pwd
# Should show: .../progressive-guardrails
```

---

## PHASE 1: Infrastructure Setup (10 minutes)

### Step 1: Create Kubernetes Cluster

```bash
# In terminal window #1
cd progressive-guardrails
make kind-up
```

**Expected output:** 
- Cluster creation messages
- "Cluster progressive-guardrails created with registry at localhost:5001"

### Step 2: Install Istio Service Mesh

```bash
# Same terminal
make istio-install
```

**Expected output:**
- Istio download and installation
- "✅ Istio installation complete"

### Step 3: Install Monitoring Stack

```bash
# Same terminal  
make monitoring-install
```

**Expected output:**
- Helm repo additions
- Prometheus and Kiali installation
- This takes 3-5 minutes

### Step 4: Install Argo CD & Rollouts

```bash
# Same terminal
make argo-install
```

**Expected output:**
- Argo CD and Argo Rollouts installation
- "✅ Argo installation complete"

---

## PHASE 2: Application Build & Deploy (5 minutes)

### Step 5: Build Application

```bash
# Same terminal
make app-build
make app-test
make app-push
```

**Expected output:**
- Docker build completes
- Go tests pass
- Image pushed to localhost:5001

### Step 6: Deploy to Kubernetes

```bash
# Same terminal
make deploy-dev
```

**Expected output:**
- Namespace creation
- Application deployment via Argo CD
- "✅ Application deployed"

---

## PHASE 3: Access Dashboards (2 minutes)

**IMPORTANT: Open 4 NEW terminal windows and keep them running**

### Terminal Window #2 - Argo CD

```bash
cd progressive-guardrails
make open-argocd
```

1. Copy the password shown in terminal
2. Open: http://localhost:8080
3. Login: admin / [paste password]
4. **KEEP THIS TERMINAL RUNNING**

### Terminal Window #3 - Argo Rollouts

```bash
cd progressive-guardrails
make open-rollouts
```

1. Open: http://localhost:3100/rollouts/rollout/dev/webapp
2. Should show rollout in "Healthy" state
3. **KEEP THIS TERMINAL RUNNING**

### Terminal Window #4 - Grafana

```bash
cd progressive-guardrails
make open-grafana
```

1. Open: http://localhost:3000
2. Login: admin / admin
3. **KEEP THIS TERMINAL RUNNING**

### Terminal Window #5 - Gateway

```bash
cd progressive-guardrails
make open-gateway
```

1. **KEEP THIS TERMINAL RUNNING**
2. Test app access:

```bash
# In a 6th terminal
curl -H "Host: webapp.local" http://localhost:8081/
```

**Expected response:** JSON with "Hello from webapp"

---

## PHASE 4: Successful Canary Demo (5 minutes)

### Step 7: Start Canary Deployment

**In terminal window #1:**

```bash
cd progressive-guardrails

# Build new version
make app-build IMAGE_TAG=v1.1
make app-push IMAGE_TAG=v1.1

# Start canary rollout
make canary-start IMAGE_TAG=v1.1
```

### Step 8: Generate Traffic

**In a NEW terminal window #6:**

```bash
cd progressive-guardrails
make test-canary
```

**This will send traffic for 60 seconds. KEEP IT RUNNING.**

### Step 9: Watch Rollout Progress

**In terminal window #1:**

```bash
make canary-watch
```

**What you'll see:**
- Traffic shifts: 10% → 30% → 60% → 100%
- Each step pauses for analysis
- "Healthy" status throughout

**In Argo Rollouts dashboard (terminal #3):**
- Real-time traffic shifting visualization
- Analysis runs showing "Successful"

---

## PHASE 5: Auto-Rollback Demo (8 minutes)

### Step 10: Deploy with Failure Injection

**In terminal window #1 (stop canary-watch with Ctrl+C first):**

```bash
# Build new version
make app-build IMAGE_TAG=v1.2
make app-push IMAGE_TAG=v1.2

# Start new canary
make canary-start IMAGE_TAG=v1.2
```

### Step 11: Start Traffic First

**In terminal window #6:**

```bash
make test-canary
```

**IMPORTANT: Start traffic BEFORE injecting failures**

### Step 12: Inject Failures

**After traffic starts, in terminal window #1:**

```bash
make induce-failure
```

### Step 13: Observe Auto-Rollback

**Watch in dashboards:**

**Argo Rollouts (terminal #3):**
- Analysis runs start showing "Failed"
- Automatic rollback to stable version
- Traffic returns to 100% stable

**Expected timeline:**
1. Canary reaches 10%
2. Analysis runs (30 seconds)
3. Failure injection causes success rate < 99%
4. Automatic rollback triggered
5. Traffic returns to stable version

---

## PHASE 6: Successful Promotion (5 minutes)

### Step 14: Deploy Working Version

**In terminal window #1:**

```bash
# Build without failure injection
make app-build IMAGE_TAG=v1.3
make app-push IMAGE_TAG=v1.3

# Start canary
make canary-start IMAGE_TAG=v1.3
```

### Step 15: Generate Clean Traffic

**In terminal window #6:**

```bash
make test-canary
```

### Step 16: Watch Successful Progression

**In terminal window #1:**

```bash
make canary-watch
```

**Expected progression:**
1. 10% traffic → Analysis passes → Continue
2. 30% traffic → Analysis passes → Continue  
3. 60% traffic → Analysis passes → Continue
4. 100% traffic → Rollout complete

### Step 17: Manual Promotion (Optional)

**If you want to speed up:**

```bash
make canary-promote
```

---

## Verification Checklist

### ✅ Argo CD (http://localhost:8080)
- [ ] Login works with admin/[password]
- [ ] Application "webapp" shows "Synced" and "Healthy"
- [ ] All resources have green checkmarks

### ✅ Argo Rollouts (http://localhost:3100/rollouts/rollout/dev/webapp)
- [ ] Shows current rollout status
- [ ] Traffic weights visible during canary
- [ ] Analysis runs show success/failure status
- [ ] Step progression: 1→3→5→7→8 (completed)

### ✅ Application Access
- [ ] `curl -H "Host: webapp.local" http://localhost:8081/` returns JSON
- [ ] Health check: `curl -H "Host: webapp.local" http://localhost:8081/healthz` returns "healthy"

---

## Key Commands Reference

```bash
# Check rollout status
kubectl argo rollouts get rollout webapp -n dev

# Delete failed analysis runs
kubectl delete analysisrun -n dev --all

# Check pods
kubectl get pods -n dev

# Check application
curl -H "Host: webapp.local" http://localhost:8081/
```

---

## Troubleshooting

### Dashboard Loading Issues

```bash
# Check port-forwards
ps aux | grep "kubectl port-forward"

# Restart if needed
kill $(ps aux | grep "kubectl port-forward" | awk '{print $2}') 2>/dev/null
cd progressive-guardrails
make open-rollouts  # or other dashboard
```

### Analysis Errors

```bash
# Delete failed analysis runs
kubectl get analysisrun -n dev
kubectl delete analysisrun <name> -n dev

# Start fresh
make canary-start IMAGE_TAG=v1.4
```

### App Not Accessible

```bash
# Check /etc/hosts
grep webapp.local /etc/hosts

# Check gateway port-forward is running
curl http://localhost:8081/
```

### Image Pull Errors

```bash
# Always build and push before starting canary
make app-build IMAGE_TAG=v1.x
make app-push IMAGE_TAG=v1.x
make canary-start IMAGE_TAG=v1.x
```

---

## Cleanup

```bash
# Stop all port-forwards
kill $(ps aux | grep "kubectl port-forward" | awk '{print $2}') 2>/dev/null

# Reset application
cd progressive-guardrails
make reset

# Full cleanup (removes cluster)
make nuke
```

---

## Success Criteria

You've successfully demonstrated:

1. **✅ CI Gate Enforcement** - Tests must pass before deployment
2. **✅ Progressive Traffic Shifting** - 10→30→60→100% with analysis
3. **✅ Automated Analysis** - Prometheus metrics drive decisions  
4. **✅ Auto-Rollback** - SLO breaches trigger automatic rollback
5. **✅ GitOps Workflow** - All changes tracked and deployed via Argo CD
6. **✅ Full Observability** - Real-time visibility into rollout process

**The POC proves you can deploy safely with zero downtime and automatic rollback on failure!**