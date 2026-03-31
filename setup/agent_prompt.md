Build a Databricks AppKit application called "wanderbricks-ops" with these requirements:

**Dataset**: `samples.wanderbricks` (vacation rental marketplace — ships with every workspace)

**Plugins**: server, analytics, genie, lakebase

**Environment setup** (do this first):
  - Use `databricks auth describe --output json | jq -r '.host'` to get DATABRICKS_HOST
  - List warehouses with `databricks warehouses list --output json`.
    If none exist, create a serverless one:
    `databricks warehouses create --name "appkit-dev" --cluster-size "2X-Small" --warehouse-type PRO --enable-serverless --output json`
  - Create a Genie space:
    `databricks genie spaces create --name "Wanderbricks" --warehouse-id $WAREHOUSE_ID --tables samples.wanderbricks.bookings --tables samples.wanderbricks.properties --tables samples.wanderbricks.destinations --tables samples.wanderbricks.reviews --output json`
  - Write all three values (DATABRICKS_HOST, DATABRICKS_WAREHOUSE_ID,
    DATABRICKS_GENIE_SPACE_ID) to `.env`

**Data layer setup**:
  - Copy bookings, users, properties, destinations from `samples.wanderbricks`
    to `main.wanderbricks` using `databricks sql execute` (so we can sync them)
  - Create synced tables in Lakebase for each (Snapshot mode):
    bookings (PK: booking_id), users (PK: user_id),
    properties (PK: property_id), destinations (PK: destination_id)
  - Create a writable `booking_notes` table directly in Lakebase:
    note_id SERIAL PK, booking_id BIGINT, agent_email TEXT,
    note TEXT, action_taken TEXT DEFAULT 'no_action',
    created_at TIMESTAMPTZ DEFAULT NOW()

**Analytics query** (`config/queries/revenue_by_destination.sql`):
  Query `samples.wanderbricks` for destination, country, booking count,
  total revenue, and average rating — grouped by destination,
  limited to top N results (parameterized)

**Lakebase custom routes** (in server.ts):
  - `GET /api/bookings/:id` — look up booking with guest and property details
    (join synced bookings, users, properties, destinations tables)
  - `POST /api/bookings/:id/notes` — add a note to a booking
  - `GET /api/bookings/:id/notes` — list notes for a booking

**Genie**: One space aliased as "wanderbricks"

**Frontend** (React):
  - Revenue table and bar chart using `useAnalyticsQuery`
  - Booking manager with lookup, guest details, and inline note-adding
  - `<GenieChat>` component for conversational data exploration
  - Use AppKit UI components (Card, Skeleton, etc.)

Use `@databricks/appkit` for the server and `@databricks/appkit-ui` for the frontend.

**After scaffolding**: Run `npm run dev` to verify the app starts, then deploy
with `databricks bundle deploy`.
