Build and deploy a Databricks AppKit application called "wanderbricks-ops".

You must complete every step without asking the user for input. Use the Databricks CLI
(already authenticated) for all workspace operations. When you're done, print the
deployed app URL — nothing else should require user action.

## 0. Install Databricks skills

```bash
databricks experimental aitools install
```

This gives your agent access to Databricks-aware tools for workspace operations.

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

Write `.env`:

```
DATABRICKS_HOST=<value>
DATABRICKS_WAREHOUSE_ID=<value>
DATABRICKS_GENIE_SPACE_ID=<value>
```

## 2. Scaffold the app

Run `databricks apps init`, selecting Analytics, Genie, and Lakebase plugins.
Then `cd wanderbricks-ops && npm install`.

## 3. Application code

**Dataset**: `samples.wanderbricks` (vacation rental marketplace — ships with every workspace)

**Architecture**: All reads go through the SQL Warehouse (analytics queries). Lakebase
is used only for app-owned writable state — booking flags and notes that the app creates.
No data syncing or copying required.

**Server** (`server/server.ts`):
- Plugins: `server({ autoStart: false })`, `analytics({})`, `genie({ spaces: { wanderbricks: process.env.DATABRICKS_GENIE_SPACE_ID } })`, `lakebase()`
- On first start, auto-create the Lakebase tables if they don't exist:
  ```sql
  CREATE TABLE IF NOT EXISTS booking_flags (
    flag_id      SERIAL PRIMARY KEY,
    booking_id   BIGINT NOT NULL UNIQUE,
    flag_reason  TEXT NOT NULL,
    flagged_by   TEXT NOT NULL DEFAULT 'app-user',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );
  CREATE TABLE IF NOT EXISTS booking_notes (
    note_id      SERIAL PRIMARY KEY,
    booking_id   BIGINT NOT NULL,
    agent_email  TEXT NOT NULL,
    note         TEXT NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );
  ```
- Custom routes via `appkit.server.extend()`:
  - `POST /api/bookings/:id/flag` — flag a booking for review (insert into booking_flags)
  - `DELETE /api/bookings/:id/flag` — unflag a booking
  - `GET /api/bookings/:id/flag` — check if a booking is flagged
  - `POST /api/bookings/:id/notes` — add a note to a booking
  - `GET /api/bookings/:id/notes` — list notes for a booking, ordered by created_at DESC
- Call `appkit.server.start()` after extend

**Analytics queries** (in `config/queries/`):

`revenue_by_destination.sql`:
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

`booking_detail.sql`:
```sql
-- @param bookingId NUMERIC
SELECT b.booking_id, b.status, b.check_in, b.check_out,
       b.guests_count, b.total_amount,
       u.name AS guest_name, u.email AS guest_email,
       p.title AS property_title, d.destination
FROM samples.wanderbricks.bookings b
JOIN samples.wanderbricks.users u ON b.user_id = u.user_id
JOIN samples.wanderbricks.properties p ON b.property_id = p.property_id
JOIN samples.wanderbricks.destinations d ON p.destination_id = d.destination_id
WHERE b.booking_id = :bookingId
```

**Frontend** (React, in `client/src/`):
- `RevenueByDestination.tsx` — table using `useAnalyticsQuery("revenue_by_destination", { limit: sql.number(10) })`
- `RevenueChart.tsx` — `<BarChart queryKey="revenue_by_destination" xKey="destination" yKey="total_revenue" />`
- `BookingManager.tsx` — looks up a booking via `useAnalyticsQuery("booking_detail", { bookingId })`,
  displays guest/property details, shows a "Flag for review" button and a notes panel.
  Flag and notes operations use `fetch()` against the Lakebase routes.
- `WanderbricksChat.tsx` — `<GenieChat alias="wanderbricks" />`
- `App.tsx` — two-column grid layout using AppKit UI Card components

Use `@databricks/appkit` for the server and `@databricks/appkit-ui/react` for the frontend.

## 4. Verify and deploy

1. Run `npm run dev` and confirm the app starts on `http://localhost:8000`
2. Run `databricks bundle deploy`
3. Get the deployed app URL from the deploy output

## 5. Done

Print a summary of what was created (warehouse, Genie space, app) and the URL
of the deployed app. Do not print any remaining TODO items or manual steps.
