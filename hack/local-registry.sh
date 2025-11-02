#!/bin/bash
set -e

REGISTRY_NAME="kind-registry"
REGISTRY_PORT="5001"

start_registry() {
  if docker ps | grep -q "${REGISTRY_NAME}"; then
    echo "Registry already running"
    return
  fi
  
  if docker ps -a | grep -q "${REGISTRY_NAME}"; then
    echo "Starting existing registry"
    docker start "${REGISTRY_NAME}"
  else
    echo "Creating new registry"
    docker run -d --restart=always \
      -p "127.0.0.1:${REGISTRY_PORT}:5000" \
      --name "${REGISTRY_NAME}" \
      registry:2
  fi
  
  echo "Registry available at localhost:${REGISTRY_PORT}"
}

stop_registry() {
  if docker ps | grep -q "${REGISTRY_NAME}"; then
    echo "Stopping registry"
    docker stop "${REGISTRY_NAME}"
  fi
}

case "${1}" in
  start)
    start_registry
    ;;
  stop)
    stop_registry
    ;;
  *)
    echo "Usage: $0 {start|stop}"
    exit 1
    ;;
esac