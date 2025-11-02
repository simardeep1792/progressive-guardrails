REGISTRY_HOST ?= localhost:5001
IMAGE_TAG ?= v1.0

.PHONY: kind-up
kind-up:
	@./hack/kind-create.sh

.PHONY: kind-down
kind-down:
	@./hack/kind-delete.sh

.PHONY: istio-install
istio-install:
	@echo "Installing Istio..."
	@curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.20.1 sh -
	@./istio-1.20.1/bin/istioctl install --set values.defaultRevision=default -y
	@kubectl label namespace default istio-injection=enabled --overwrite
	@kubectl wait --for=condition=Ready pods -l app=istiod -n istio-system --timeout=300s
	@kubectl wait --for=condition=Ready pods -l app=istio-ingressgateway -n istio-system --timeout=300s
	@kubectl apply -f deploy/base/istio/gateway.yaml

.PHONY: monitoring-install
monitoring-install:
	@echo "Installing monitoring stack..."
	@kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	@helm repo add kiali https://kiali.org/helm-charts
	@helm repo update
	@helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
		-n monitoring -f deploy/base/prometheus/values.yaml --wait
	@helm upgrade --install kiali-server kiali/kiali-server \
		-n monitoring --set auth.strategy=anonymous --set istio_namespace=istio-system --wait
	@kubectl apply -f deploy/base/prometheus/servicemonitor.yaml
	@kubectl apply -f deploy/base/grafana/webapp-dashboard.yaml

.PHONY: argo-install
argo-install:
	@echo "Installing Argo CD..."
	@kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@echo "Installing Argo Rollouts..."
	@kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
	@echo "Waiting for Argo CD to be ready..."
	@kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
	@echo "Waiting for Argo Rollouts to be ready..."
	@kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=argo-rollouts -n argo-rollouts --timeout=300s
	@kubectl apply -f deploy/base/argo/argo-rollouts-dash.yaml
	@echo "Setting up dashboard permissions..."
	@kubectl create clusterrolebinding argo-rollouts-dashboard --clusterrole=argo-rollouts --serviceaccount=argo-rollouts:default --dry-run=client -o yaml | kubectl apply -f -

.PHONY: ingress-check
ingress-check:
	@kubectl get svc -n istio-system istio-ingressgateway

.PHONY: app-build
app-build:
	@cd app && make build TAG=$(IMAGE_TAG)

.PHONY: app-test
app-test:
	@cd app && make test

.PHONY: app-push
app-push:
	@cd app && make push TAG=$(IMAGE_TAG)

.PHONY: deploy-dev
deploy-dev:
	@kubectl apply -f deploy/base/namespace.yaml
	@kubectl apply -f deploy/base/argo/application.yaml
	@echo "Waiting for application to be healthy..."
	@timeout 300 bash -c 'until kubectl get application webapp -n argocd -o jsonpath="{.status.health.status}" | grep -q "Healthy"; do sleep 5; done' || true
	@echo "✅ Application deployed"

.PHONY: rollout-status
rollout-status:
	@kubectl argo rollouts get rollout webapp -n dev

.PHONY: canary-start
canary-start:
	@kubectl argo rollouts set image webapp webapp=$(REGISTRY_HOST)/webapp:$(IMAGE_TAG) -n dev

.PHONY: canary-watch
canary-watch:
	@kubectl argo rollouts get rollout webapp -n dev -w

.PHONY: canary-abort
canary-abort:
	@kubectl argo rollouts abort webapp -n dev

.PHONY: canary-promote
canary-promote:
	@kubectl argo rollouts promote webapp -n dev --full

.PHONY: induce-failure
induce-failure:
	@./hack/induce-failure.sh

.PHONY: test-canary
test-canary:
	@./hack/test-canary.sh

.PHONY: open-argocd
open-argocd:
	@echo "Argo CD admin password:"
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
	@echo "\nStarting port-forward to localhost:8080..."
	@kubectl port-forward svc/argocd-server -n argocd 8080:443

.PHONY: open-rollouts
open-rollouts:
	@kubectl port-forward svc/argo-rollouts-dashboard -n argo-rollouts 3100:3100

.PHONY: open-grafana
open-grafana:
	@kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80

.PHONY: open-kiali
open-kiali:
	@kubectl port-forward svc/kiali -n monitoring 20001:20001

.PHONY: open-gateway
open-gateway:
	@kubectl port-forward svc/istio-ingressgateway -n istio-system 8081:80

.PHONY: reset
reset:
	@kubectl delete application webapp -n argocd --ignore-not-found
	@kubectl delete namespace dev --ignore-not-found
	@./hack/local-registry.sh stop

.PHONY: nuke
nuke: kind-down
	@docker rm -f kind-registry 2>/dev/null || true