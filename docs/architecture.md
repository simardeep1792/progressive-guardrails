# Progressive Delivery Architecture

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐    ┌──────────────┐
│  Developer  │───▶│ Git Repository│───▶│ CI/CD Pipeline│───▶│Container Registry│
│             │    │               │    │             │    │ localhost:5001  │
└─────────────┘    └──────────────┘    └─────────────┘    └──────────────┘
                                                                    │
                                                                    ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          Kubernetes Cluster (Kind)                              │
│                                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │    GitOps    │  │ Progressive  │  │ Service Mesh │  │  Monitoring  │      │
│  │  (Argo CD)   │  │  Delivery    │  │   (Istio)    │  │(Prometheus + │      │
│  │   :8080      │  │(Argo Rollouts)│  │              │  │  Grafana)    │      │
│  │              │  │   :3100      │  │              │  │   :3000      │      │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                    Application Workloads                                │  │
│  │                                                                         │  │
│  │  ┌─────────────┐            ┌─────────────┐                            │  │
│  │  │   Stable    │  90%       │   Canary    │  10%                       │  │
│  │  │ webapp:v1.0 │◀─traffic──▶│ webapp:v1.1 │                            │  │
│  │  └─────────────┘            └─────────────┘                            │  │
│  │                                                                         │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                        │
│  │Analysis Engine│  │Service Graph │  │External Access│                        │
│  │• Success Rate │  │   (Kiali)    │  │Istio Gateway │                        │
│  │• P95 Latency  │  │   :20001     │  │   :8081      │                        │
│  │• Auto-Rollback│  │              │  │webapp.local  │                        │
│  └──────────────┘  └──────────────┘  └──────────────┘                        │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Traffic Flow

1. **10% Canary** → Analysis (60s) → **30% Canary** → Analysis (60s) → **60% Canary** → Analysis (60s) → **100% Deployment**

2. **SLO Monitoring:**
   - Success Rate ≥ 99%
   - P95 Latency ≤ 300ms
   - Error Rate < 1%

3. **Auto-Rollback Triggers:**
   - Success rate < 99%
   - P95 latency > 300ms
   - Analysis timeout/failure

## Component Responsibilities

### GitOps (Argo CD)
- Synchronizes application manifests from Git
- Manages deployment lifecycle
- Provides deployment visibility

### Progressive Delivery (Argo Rollouts)
- Executes canary deployment strategy
- Manages traffic splitting via Istio
- Performs automated analysis and rollback

### Service Mesh (Istio)
- Traffic management and routing
- Security policies and mTLS
- Observability and metrics collection

### Monitoring Stack
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and SLO dashboards
- **Kiali**: Service mesh topology and traffic flow

### Analysis Engine
- Real-time SLO evaluation
- Automated promotion/rollback decisions
- Integration with Prometheus metrics

## Automation Commands

```bash
./run.sh setup           # Complete infrastructure setup
./run.sh dashboards      # Access all monitoring UIs
./run.sh canary-success  # Demonstrate successful deployment
./run.sh canary-failure  # Demonstrate auto-rollback
```