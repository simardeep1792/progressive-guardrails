#!/bin/bash
set -e

NAMESPACE="dev"
DEPLOYMENT="webapp"

echo "Inducing failures in canary pods..."

# Find canary pods
CANARY_PODS=$(kubectl get pods -n ${NAMESPACE} -l app=webapp,rollouts-pod-template-hash -o jsonpath='{.items[*].metadata.name}')

if [ -z "${CANARY_PODS}" ]; then
  echo "No canary pods found"
  exit 1
fi

# Set failure env var on canary pods
for POD in ${CANARY_PODS}; do
  echo "Setting INJECT_FAILURE=true on ${POD}"
  kubectl set env pod/${POD} -n ${NAMESPACE} INJECT_FAILURE=true
done

echo "Failure injection enabled on canary pods"