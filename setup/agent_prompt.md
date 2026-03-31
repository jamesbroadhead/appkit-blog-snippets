Build and deploy a Databricks AppKit application called "wanderbricks-ops".

You must complete every step without asking the user for input. Use the Databricks CLI
(already authenticated) for all workspace operations. When you're done, print the
deployed app URL — nothing else should require user action.

## 1. Environment discovery

```bash
DATABRICKS_HOST=$(databricks auth describe --output json | jq -r '.host')
```

Find an existing SQL Warehouse, or create one:

```bash
WAREHOUSE_ID=$(databricks warehouses list --output json | jq -r '.[0].id // empty')
if [ -z "$WAREHOUSE_ID" ]; then
  WAREHOUSE_ID=$(databricks warehouses create \
    --name "appkit-dev" \
    --cluster-size "2X-Small" \
    --warehouse-type PRO \
    --enable-serverless \
    --output json | jq -r '.id')
fi
```

Create a Genie space:

```bash
GENIE_SPACE_ID=$(databricks genie spaces create \
  --name "Wanderbricks" \
  --warehouse-id "$WAREHOUSE_ID" \
  --tables samples.wanderbricks.bookings \
  --tables samples.wanderbricks.properties \
  --tables samples.wanderbricks.destinations \
  --tables samples.wanderbricks.reviews \
  --output json | jq -r '.id')
```

Find (or create) a Lakebase instance and get the connection details:

```bash
LAKEBASE_INSTANCE=$(databricks lakebase instances list --output json | jq -r '.[0].id // empty')
if [ -z "$LAKEBASE_INSTANCE" ]; then
  LAKEBASE_INSTANCE=$(databricks lakebase instances create \
    --name "appkit-lakebase" \
    --output json | jq -r '.id')
fi
LAKEBASE_DATABASE=$(databricks lakebase databases list \
  --instance-id "$LAKEBASE_INSTANCE" --output json | jq -r '.[0].name // empty')
if [ -z "$LAKEBASE_DATABASE" ]; then
  LAKEBASE_DATABASE=$(databricks lakebase databases create \
    --instance-id "$LAKEBASE_INSTANCE" \
    --name "wanderbricks" \
    --output json | jq -r '.name')
fi
```

Write `.env`:

```
DATABRICKS_HOST=<value>
DATABRICKS_WAREHOUSE_ID=<value>
DATABRICKS_GENIE_SPACE_ID=<value>
```

## 2. Data layer

Copy sample tables so we can sync them:

```sql
CREATE SCHEMA IF NOT EXISTS main.wanderbricks;
CREATE TABLE IF NOT EXISTS main.wanderbricks.bookings     AS SELECT * FROM samples.wanderbricks.bookings;
CREATE TABLE IF NOT EXISTS main.wanderbricks.users        AS SELECT * FROM samples.wanderbricks.users;
CREATE TABLE IF NOT EXISTS main.wanderbricks.properties   AS SELECT * FROM samples.wanderbricks.properties;
CREATE TABLE IF NOT EXISTS main.wanderbricks.destinations AS SELECT * FROM samples.wanderbricks.destinations;
```

Run each via `databricks sql execute --warehouse-id $WAREHOUSE_ID --statement "..."`.

Create synced tables in Lakebase (Snapshot mode) using the pipelines API:

| Source table | Primary key |
|---|---|
| `main.wanderbricks.bookings` | `booking_id` |
| `main.wanderbricks.users` | `user_id` |
| `main.wanderbricks.properties` | `property_id` |
| `main.wanderbricks.destinations` | `destination_id` |

Wait for all pipelines to reach RUNNING/ONLINE state before continuing.

Create the writable app table directly in Lakebase (use `databricks lakebase sql execute` or the Lakebase connection):

```sql
CREATE TABLE IF NOT EXISTS booking_notes (
  note_id      SERIAL PRIMARY KEY,
  booking_id   BIGINT NOT NULL,
  agent_email  TEXT NOT NULL,
  note         TEXT NOT NULL,
  action_taken TEXT NOT NULL DEFAULT 'no_action',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_booking_notes_booking_id ON booking_notes (booking_id);
```

## 3. Scaffold the app

Run `databricks apps init`, selecting Analytics, Genie, and Lakebase plugins.
Then `cd wanderbricks-ops && npm install`.

## 4. Application code

**Dataset**: `samples.wanderbricks` (vacation rental marketplace)

**Server** (`server/server.ts`):
- Plugins: `server({ autoStart: false })`, `analytics({})`, `genie({ spaces: { wanderbricks: process.env.DATABRICKS_GENIE_SPACE_ID } })`, `lakebase()`
- Custom routes via `appkit.server.extend()`:
  - `GET /api/bookings/:id` — join bookings, users, properties, destinations by booking_id
  - `POST /api/bookings/:id/notes` — insert into booking_notes
  - `GET /api/bookings/:id/notes` — list notes for a booking, ordered by created_at DESC
- Call `appkit.server.start()` after extend

**Analytics query** (`config/queries/revenue_by_destination.sql`):
```sql
-- @param limit NUMERIC
SELECT d.destination, d.country,
       COUNT(DISTINCT b.booking_id) AS total_bookings,
       ROUND(SUM(b.total_amount), 2) AS total_revenue,
       ROUND(AVG(r.rating), 1) AS avg_rating
FROM samples.wanderbricks.bookings b
JOIN samples.wanderbricks.properties p ON b.property_id = p.property_id
JOIN samples.wanderbricks.destinations d ON p.destination_id = d.destination_id
LEFT JOIN samples.wanderbricks.reviews r ON b.booking_id = r.booking_id
GROUP BY d.destination, d.country
ORDER BY total_revenue DESC
LIMIT :limit
```

**Frontend** (React, in `client/src/`):
- `RevenueByDestination.tsx` — table using `useAnalyticsQuery("revenue_by_destination", { limit: sql.number(10) })`
- `RevenueChart.tsx` — `<BarChart queryKey="revenue_by_destination" xKey="destination" yKey="total_revenue" />`
- `BookingManager.tsx` — booking lookup by ID with note-adding, fetches from the Lakebase routes
- `WanderbricksChat.tsx` — `<GenieChat alias="wanderbricks" />`
- `App.tsx` — two-column grid layout using AppKit UI Card components

Use `@databricks/appkit` for the server and `@databricks/appkit-ui/react` for the frontend.

## 5. Verify and deploy

1. Run `npm run dev` and confirm the app starts on `http://localhost:8000`
2. Run `databricks bundle deploy`
3. Get the deployed app URL from the deploy output

## 6. Done

Print a summary of what was created (warehouse, Genie space, synced tables, app)
and the URL of the deployed app. Do not print any remaining TODO items or manual steps.
