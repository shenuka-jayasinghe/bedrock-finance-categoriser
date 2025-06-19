#!/bin/bash
# Retrieve a transaction from the API Gateway.
set -euo pipefail

API_URL="https://p6kcw3gkqc.execute-api.eu-west-1.amazonaws.com/dev"

if [ $# -ne 1 ]; then
  echo "Usage: $0 <transaction_id>" >&2
  exit 1
fi

TRANSACTION_ID="$1"

curl -s "${API_URL}/transaction?transaction_id=${TRANSACTION_ID}" | jq

