#!/bin/bash
set -e

CLUSTER_NAME="progressive-guardrails"
REGISTRY_NAME="kind-registry"
REGISTRY_PORT="5001"

# Check if cluster exists
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "Cluster ${CLUSTER_NAME} already exists"
  exit 0
fi

# Start local registry if not running
./hack/local-registry.sh start

# Create kind cluster with containerd registry config
cat <<EOF | kind create cluster --name="${CLUSTER_NAME}" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${REGISTRY_PORT}"]
    endpoint = ["http://${REGISTRY_NAME}:5000"]
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

# Connect registry to cluster network
docker network connect "kind" "${REGISTRY_NAME}" 2>/dev/null || true

# Document registry
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    hostFromContainerRuntime: "${REGISTRY_NAME}:5000"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

echo "Cluster ${CLUSTER_NAME} created with registry at localhost:${REGISTRY_PORT}"