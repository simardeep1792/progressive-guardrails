#!/bin/bash
set -e

CLUSTER_NAME="progressive-guardrails"

echo "Deleting cluster ${CLUSTER_NAME}..."
kind delete cluster --name="${CLUSTER_NAME}"

echo "Cluster ${CLUSTER_NAME} deleted"