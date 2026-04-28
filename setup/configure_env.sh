#!/usr/bin/env bash
# Configure .env with warehouse ID, host, and Genie space ID.
# Requires: databricks CLI configured and authenticated.
#
# Usage: bash setup/configure_env.sh
#
# If you hit a permission error, run setup/verify_prereqs.sh first to surface
# what's reachable. Per-step error guidance is printed inline below.

set -uo pipefail

ENV_FILE=".env"

# --- Databricks host ---
if ! HOST_OUT=$(databricks auth describe --output json 2>&1); then
  cat >&2 <<EOF
ERROR: Could not read Databricks auth config.

CLI output:
${HOST_OUT}

Common causes:
  - The Databricks CLI is not authenticated. Run: databricks auth login
  - You have multiple profiles and DATABRICKS_CONFIG_PROFILE is unset.
    List them with: databricks auth profiles
    Then: export DATABRICKS_CONFIG_PROFILE=<profile-name>
EOF
  exit 1
fi
HOST=$(echo "$HOST_OUT" | jq -r '.host')
echo "DATABRICKS_HOST=${HOST}" > "$ENV_FILE"
echo "Using host: ${HOST}"

# --- SQL Warehouse ---
WAREHOUSE_ID=$(databricks warehouses list --output json | jq -r '.[0].id // empty')

if [ -z "$WAREHOUSE_ID" ]; then
  echo "No warehouses found. Creating a serverless warehouse..."
  if ! WAREHOUSE_OUT=$(databricks warehouses create \
      --name "appkit-dev" \
      --cluster-size "2X-Small" \
      --warehouse-type PRO \
      --enable-serverless \
      --output json 2>&1); then
    cat >&2 <<EOF
ERROR: Failed to create SQL warehouse 'appkit-dev'.

CLI output:
${WAREHOUSE_OUT}

Common causes:
  - Your account lacks permission to create warehouses. You typically need
    'Allow cluster creation' entitlement or workspace admin rights.
  - Serverless SQL is not enabled in this workspace (or not in this region).
  - The workspace is over its compute / DBU quota.

What to try:
  - Ask a workspace admin to create a Pro serverless SQL warehouse, then
    set DATABRICKS_WAREHOUSE_ID in .env manually and skip this script.
EOF
    exit 1
  fi
  WAREHOUSE_ID=$(echo "$WAREHOUSE_OUT" | jq -r '.id')
  echo "Created warehouse: ${WAREHOUSE_ID}"
else
  echo "Using existing warehouse: ${WAREHOUSE_ID}"
fi

echo "DATABRICKS_WAREHOUSE_ID=${WAREHOUSE_ID}" >> "$ENV_FILE"

# --- Genie space ---
echo "Creating Genie space..."
if ! GENIE_OUT=$(databricks genie spaces create \
    --name "Wanderbricks" \
    --warehouse-id "$WAREHOUSE_ID" \
    --tables samples.wanderbricks.bookings \
    --tables samples.wanderbricks.properties \
    --tables samples.wanderbricks.destinations \
    --tables samples.wanderbricks.reviews \
    --output json 2>&1); then
  cat >&2 <<EOF
ERROR: Failed to create Genie space 'Wanderbricks'.

CLI output:
${GENIE_OUT}

Common causes:
  - Genie is not enabled in this workspace.
  - You don't have SELECT on samples.wanderbricks tables. Verify with:
      databricks tables get samples.wanderbricks.bookings
  - The selected warehouse is not Pro or doesn't support serverless. Genie
    typically requires a Pro serverless SQL warehouse. Current warehouse:
      ${WAREHOUSE_ID}
    Inspect with: databricks warehouses get ${WAREHOUSE_ID}
  - Your account lacks the 'Genie space creator' entitlement.

What to try:
  - Confirm Genie is enabled and you have an appropriate warehouse.
  - If you proceed manually, create the space in the UI and set
    DATABRICKS_GENIE_SPACE_ID in .env yourself.
EOF
  exit 1
fi
GENIE_SPACE_ID=$(echo "$GENIE_OUT" | jq -r '.id')

echo "DATABRICKS_GENIE_SPACE_ID=${GENIE_SPACE_ID}" >> "$ENV_FILE"
echo "Created Genie space: ${GENIE_SPACE_ID}"

echo ""
echo "Wrote ${ENV_FILE}:"
cat "$ENV_FILE"
