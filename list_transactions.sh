#!/bin/bash
# Retrieve all transactions from the API Gateway.
set -euo pipefail

API_URL="https://p6kcw3gkqc.execute-api.eu-west-1.amazonaws.com/dev"

curl -s "${API_URL}/transactions" | jq
