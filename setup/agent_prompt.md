Build a Databricks AppKit application called "wanderbricks-ops" with these requirements:

**Dataset**: `samples.wanderbricks` (vacation rental marketplace — ships with every workspace)

**Plugins**: server, analytics, genie, lakebase

**Data layer setup** (run these first):
  - Copy bookings, users, properties, destinations from `samples.wanderbricks`
    to `main.wanderbricks` (so we can sync them)
  - Create synced tables in Lakebase for each (Snapshot mode):
    bookings (PK: booking_id), users (PK: user_id),
    properties (PK: property_id), destinations (PK: destination_id)
  - Create a writable `booking_notes` table directly in Lakebase:
    note_id SERIAL PK, booking_id BIGINT, agent_email TEXT,
    note TEXT, action_taken TEXT DEFAULT 'no_action',
    created_at TIMESTAMPTZ DEFAULT NOW()
  - Create a Genie space with the bookings, properties, destinations,
    and reviews tables from `samples.wanderbricks`

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
