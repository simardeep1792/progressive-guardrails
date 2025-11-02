#!/bin/bash
set -e

GATEWAY_URL="http://webapp.local:8081"
DURATION="60s"
CONCURRENCY="10"

echo "Sending load to ${GATEWAY_URL} for ${DURATION}..."
echo "Make sure 'make open-gateway' is running in another terminal"

if command -v hey > /dev/null 2>&1; then
  hey -z ${DURATION} -c ${CONCURRENCY} -H "Host: webapp.local" http://localhost:8081/
elif command -v ab > /dev/null 2>&1; then
  ab -t 60 -c ${CONCURRENCY} -H "Host: webapp.local" http://localhost:8081/
else
  echo "Neither 'hey' nor 'ab' found. Install one:"
  echo "  brew install hey"
  echo "  brew install apache-bench"
  exit 1
fi