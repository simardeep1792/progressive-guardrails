#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Progressive Delivery Automation"
echo "==============================="

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

echo -e "${BLUE}Checking prerequisites...${NC}"
for cmd in docker kind kubectl helm hey tmux; do
    if command_exists "$cmd"; then
        echo "✓ $cmd"
    else
        echo "✗ $cmd - please install"
        exit 1
    fi
done

if grep -q "webapp.local" /etc/hosts; then
    echo "✓ /etc/hosts configured"
else
    echo -e "${YELLOW}Adding webapp.local to /etc/hosts...${NC}"
    echo "127.0.0.1 webapp.local" | sudo tee -a /etc/hosts
fi

wait_for_user() {
    echo -e "${YELLOW}$1${NC}"
    read -p "Press Enter to continue..."
}

open_dashboards() {
    echo -e "${BLUE}Opening dashboards in browser...${NC}"
    
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d 2>/dev/null || echo "admin")
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open "http://localhost:8080"
        open "http://localhost:3100/rollouts/rollout/dev/webapp"
        open "http://localhost:3000"
        open "http://localhost:20001"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        xdg-open "http://localhost:8080" &
        xdg-open "http://localhost:3100/rollouts/rollout/dev/webapp" &
        xdg-open "http://localhost:3000" &
        xdg-open "http://localhost:20001" &
    fi
    
    echo -e "${GREEN}Dashboards opened. Login credentials:${NC}"
    echo "  Argo CD: admin / $ARGOCD_PASSWORD"
    echo "  Grafana: admin / admin"
    echo "  Kiali: no login required"
}

setup_tmux() {
    SESSION_NAME="progressive-guardrails"
    
    tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true
    
    echo -e "${BLUE}Setting up tmux session: $SESSION_NAME${NC}"
    
    tmux new-session -d -s "$SESSION_NAME" -x 120 -y 30
    
    tmux rename-window -t "$SESSION_NAME:0" "Main"
    tmux send-keys -t "$SESSION_NAME:0" "cd '$SCRIPT_DIR'" Enter
    
    tmux new-window -t "$SESSION_NAME" -n "ArgoCD"
    tmux send-keys -t "$SESSION_NAME:ArgoCD" "cd '$SCRIPT_DIR'" Enter
    
    tmux new-window -t "$SESSION_NAME" -n "Rollouts"
    tmux send-keys -t "$SESSION_NAME:Rollouts" "cd '$SCRIPT_DIR'" Enter
    
    tmux new-window -t "$SESSION_NAME" -n "Grafana"
    tmux send-keys -t "$SESSION_NAME:Grafana" "cd '$SCRIPT_DIR'" Enter
    
    tmux new-window -t "$SESSION_NAME" -n "Gateway"
    tmux send-keys -t "$SESSION_NAME:Gateway" "cd '$SCRIPT_DIR'" Enter
    
    tmux new-window -t "$SESSION_NAME" -n "Traffic"
    tmux send-keys -t "$SESSION_NAME:Traffic" "cd '$SCRIPT_DIR'" Enter
    
    # Window 6: Kiali
    tmux new-window -t "$SESSION_NAME" -n "Kiali"
    tmux send-keys -t "$SESSION_NAME:Kiali" "cd '$SCRIPT_DIR'" Enter
    
    tmux select-window -t "$SESSION_NAME:Main"
}

start_port_forwards() {
    echo -e "${BLUE}Starting port-forwards in tmux...${NC}"
    
    tmux send-keys -t "progressive-guardrails:ArgoCD" "make open-argocd" Enter
    sleep 2
    tmux send-keys -t "progressive-guardrails:Rollouts" "make open-rollouts" Enter  
    sleep 2
    tmux send-keys -t "progressive-guardrails:Grafana" "make open-grafana" Enter
    sleep 2
    tmux send-keys -t "progressive-guardrails:Gateway" "make open-gateway" Enter
    sleep 2
    tmux send-keys -t "progressive-guardrails:Kiali" "make open-kiali" Enter
    
    echo -e "${GREEN}Port-forwards started in tmux windows${NC}"
    echo "  View with: tmux attach -t progressive-guardrails"
    echo "  Switch windows: Ctrl+b then 0-6"
    echo "  Detach: Ctrl+b then d"
}

case "${1:-setup}" in
    "setup")
        echo -e "${BLUE}PHASE 1: Infrastructure Setup${NC}"
        echo "This will take approximately 10 minutes..."
        
        make kind-up
        wait_for_user "Kubernetes cluster created. Continue with Istio installation?"
        
        make istio-install  
        wait_for_user "Istio installed. Continue with monitoring stack?"
        
        make monitoring-install
        wait_for_user "Monitoring stack installed. Continue with Argo installation?"
        
        make argo-install
        wait_for_user "Argo installed. Continue with application deployment?"
        
        echo -e "${BLUE}PHASE 2: Application Deployment${NC}"
        make app-build app-test app-push
        make deploy-dev
        
        echo -e "${GREEN}Setup complete. Next: ./run.sh dashboards${NC}"
        ;;
        
    "dashboards")
        echo -e "${BLUE}PHASE 3: Dashboard Access${NC}"
        setup_tmux
        start_port_forwards
        sleep 5
        open_dashboards
        
        echo -e "${GREEN}Dashboards ready.${NC}"
        echo -e "${BLUE}Next steps:${NC}"
        echo "  1. Login to dashboards using provided credentials"
        echo "  2. Run: ./run.sh canary-success"
        echo "  3. Run: ./run.sh canary-failure"
        echo "  4. Attach to tmux: tmux attach -t progressive-guardrails"
        ;;
        
    "canary-success")
        echo -e "${BLUE}PHASE 4: Successful Canary Deployment${NC}"
        
        tmux send-keys -t "progressive-guardrails:Main" "make app-build IMAGE_TAG=v1.1" Enter
        wait_for_user "Build complete. Continue with push and deploy?"
        
        tmux send-keys -t "progressive-guardrails:Main" "make app-push IMAGE_TAG=v1.1" Enter
        tmux send-keys -t "progressive-guardrails:Main" "make canary-start IMAGE_TAG=v1.1" Enter
        wait_for_user "Canary started. Continue with traffic generation?"
        
        tmux send-keys -t "progressive-guardrails:Traffic" "make test-canary" Enter
        tmux send-keys -t "progressive-guardrails:Main" "make canary-watch" Enter
        
        echo -e "${GREEN}Watch the 10% → 30% → 60% → 100% progression in dashboards${NC}"
        echo -e "${BLUE}Press Ctrl+C in Main window when rollout completes${NC}"
        ;;
        
    "canary-failure")
        echo -e "${BLUE}PHASE 5: Auto-Rollback Demonstration${NC}"
        
        tmux send-keys -t "progressive-guardrails:Main" "kubectl delete analysisrun -n dev --all" Enter
        sleep 2
        
        tmux send-keys -t "progressive-guardrails:Main" "make app-build IMAGE_TAG=v1.2" Enter
        wait_for_user "Build complete. Continue with deployment?"
        
        tmux send-keys -t "progressive-guardrails:Main" "make app-push IMAGE_TAG=v1.2" Enter
        tmux send-keys -t "progressive-guardrails:Main" "make canary-start IMAGE_TAG=v1.2" Enter
        wait_for_user "Canary started. Continue with traffic generation?"
        
        tmux send-keys -t "progressive-guardrails:Traffic" "make test-canary" Enter
        wait_for_user "Traffic started. Now inject failures..."
        
        tmux send-keys -t "progressive-guardrails:Main" "make induce-failure" Enter
        tmux send-keys -t "progressive-guardrails:Main" "make canary-watch" Enter
        
        echo -e "${GREEN}Watch the automatic rollback in dashboards${NC}"
        echo -e "${YELLOW}Analysis will fail and traffic will return to stable version${NC}"
        ;;
        
    "test")
        echo -e "${BLUE}Testing application connectivity...${NC}"
        curl -H "Host: webapp.local" http://localhost:8081/ && echo
        curl -H "Host: webapp.local" http://localhost:8081/healthz && echo
        ;;
        
    "status")
        echo -e "${BLUE}Current system status:${NC}"
        kubectl get pods -A | grep -E "(argo|monitoring|dev|istio)"
        echo
        kubectl argo rollouts get rollout webapp -n dev 2>/dev/null || echo "No rollout found"
        ;;
        
    "cleanup")
        echo -e "${YELLOW}Cleaning up application resources...${NC}"
        tmux kill-session -t progressive-guardrails 2>/dev/null || true
        make reset
        ;;
        
    "nuke")
        echo -e "${RED}Full cleanup - removing cluster...${NC}"
        tmux kill-session -t progressive-guardrails 2>/dev/null || true
        make nuke
        ;;
        
    *)
        echo "Usage: $0 {setup|dashboards|canary-success|canary-failure|test|status|cleanup|nuke}"
        echo
        echo "Commands:"
        echo "  setup           Complete infrastructure setup"
        echo "  dashboards      Start tmux and open browser dashboards"  
        echo "  canary-success  Demonstrate successful canary deployment"
        echo "  canary-failure  Demonstrate auto-rollback on failure"
        echo "  test            Test application connectivity"
        echo "  status          Show current system status"
        echo "  cleanup         Reset application resources"
        echo "  nuke            Full cleanup - removes cluster"
        ;;
esac