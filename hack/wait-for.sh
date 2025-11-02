#!/bin/bash
set -e

NAMESPACE="${1}"
SELECTOR="${2}"
TIMEOUT="${3:-300}"

if [ -z "${NAMESPACE}" ] || [ -z "${SELECTOR}" ]; then
  echo "Usage: $0 <namespace> <label-selector> [timeout]"
  exit 1
fi

echo "Waiting for pods matching ${SELECTOR} in ${NAMESPACE}..."
kubectl wait --for=condition=Ready pods -l "${SELECTOR}" -n "${NAMESPACE}" --timeout="${TIMEOUT}s"