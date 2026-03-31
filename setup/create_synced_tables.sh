#!/usr/bin/env bash
# Create Lakebase synced tables from the copied catalog tables.
# Requires: databricks CLI configured, DATABRICKS_WAREHOUSE_ID set.
#
# Usage: bash setup/create_synced_tables.sh <lakebase-instance-id> <lakebase-database>

set -euo pipefail

INSTANCE_ID="${1:?Usage: $0 <lakebase-instance-id> <lakebase-database>}"
DATABASE="${2:?Usage: $0 <lakebase-instance-id> <lakebase-database>}"

declare -A TABLES=(
  ["main.wanderbricks.bookings"]="booking_id"
  ["main.wanderbricks.users"]="user_id"
  ["main.wanderbricks.properties"]="property_id"
  ["main.wanderbricks.destinations"]="destination_id"
)

for TABLE in "${!TABLES[@]}"; do
  PK="${TABLES[$TABLE]}"
  echo "Creating synced table for ${TABLE} (PK: ${PK})..."
  databricks api post /api/2.0/pipelines \
    --json "{
      \"name\": \"sync-${TABLE##*.}\",
      \"catalog\": \"main\",
      \"target\": \"wanderbricks\",
      \"channel\": \"CURRENT\",
      \"configuration\": {
        \"source_table\": \"${TABLE}\",
        \"destination_instance_id\": \"${INSTANCE_ID}\",
        \"destination_database\": \"${DATABASE}\",
        \"primary_key\": \"${PK}\",
        \"sync_mode\": \"SNAPSHOT\"
      }
    }"
done

echo "Synced table pipelines created. Check status with:"
echo "  databricks pipelines list --filter 'name LIKE \"sync-%\"'"
