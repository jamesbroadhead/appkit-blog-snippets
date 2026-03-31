#!/usr/bin/env bash
# Configure .env with warehouse ID, host, and Genie space ID.
# Requires: databricks CLI configured and authenticated.
#
# Usage: bash setup/configure_env.sh

set -euo pipefail

ENV_FILE=".env"

# --- Databricks host ---
HOST=$(databricks auth describe --output json | jq -r '.host')
echo "DATABRICKS_HOST=${HOST}" > "$ENV_FILE"
echo "Using host: ${HOST}"

# --- SQL Warehouse ---
WAREHOUSE_ID=$(databricks warehouses list --output json | jq -r '.[0].id // empty')

if [ -z "$WAREHOUSE_ID" ]; then
  echo "No warehouses found. Creating a serverless warehouse..."
  WAREHOUSE_ID=$(databricks warehouses create \
    --name "appkit-dev" \
    --cluster-size "2X-Small" \
    --warehouse-type PRO \
    --enable-serverless \
    --output json | jq -r '.id')
  echo "Created warehouse: ${WAREHOUSE_ID}"
else
  echo "Using existing warehouse: ${WAREHOUSE_ID}"
fi

echo "DATABRICKS_WAREHOUSE_ID=${WAREHOUSE_ID}" >> "$ENV_FILE"

# --- Genie space ---
echo "Creating Genie space..."
GENIE_SPACE_ID=$(databricks genie spaces create \
  --name "Wanderbricks" \
  --warehouse-id "$WAREHOUSE_ID" \
  --tables samples.wanderbricks.bookings \
  --tables samples.wanderbricks.properties \
  --tables samples.wanderbricks.destinations \
  --tables samples.wanderbricks.reviews \
  --output json | jq -r '.id')

echo "DATABRICKS_GENIE_SPACE_ID=${GENIE_SPACE_ID}" >> "$ENV_FILE"
echo "Created Genie space: ${GENIE_SPACE_ID}"

echo ""
echo "Wrote ${ENV_FILE}:"
cat "$ENV_FILE"
