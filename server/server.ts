import { createApp, server, analytics, genie, lakebase } from "@databricks/appkit";

const appkit = await createApp({
  plugins: [
    server({ autoStart: false }),
    analytics({}),
    genie({
      spaces: {
        wanderbricks: process.env.DATABRICKS_GENIE_SPACE_ID ?? "",
      },
    }),
    lakebase(),
  ],
});

// Auto-create app tables on startup
await appkit.lakebase.pool.query(`
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
`);

appkit.server.extend((app) => {
  // Flag a booking for review
  app.post("/api/bookings/:id/flag", async (req, res) => {
    const { reason } = req.body;
    const { rows } = await appkit.lakebase.pool.query(
      `INSERT INTO booking_flags (booking_id, flag_reason)
       VALUES ($1, $2)
       ON CONFLICT (booking_id) DO UPDATE SET flag_reason = $2, created_at = NOW()
       RETURNING *`,
      [req.params.id, reason ?? "flagged for review"],
    );
    res.status(201).json(rows[0]);
  });

  // Unflag a booking
  app.delete("/api/bookings/:id/flag", async (req, res) => {
    await appkit.lakebase.pool.query(
      `DELETE FROM booking_flags WHERE booking_id = $1`,
      [req.params.id],
    );
    res.status(204).end();
  });

  // Check if a booking is flagged
  app.get("/api/bookings/:id/flag", async (req, res) => {
    const { rows } = await appkit.lakebase.pool.query(
      `SELECT * FROM booking_flags WHERE booking_id = $1`,
      [req.params.id],
    );
    res.json(rows[0] ?? null);
  });

  // Add a note to a booking
  app.post("/api/bookings/:id/notes", async (req, res) => {
    const { note } = req.body;
    const { rows } = await appkit.lakebase.pool.query(
      `INSERT INTO booking_notes (booking_id, agent_email, note)
       VALUES ($1, $2, $3) RETURNING *`,
      [req.params.id, "app-user@example.com", note],
    );
    res.status(201).json(rows[0]);
  });

  // Get notes for a booking
  app.get("/api/bookings/:id/notes", async (req, res) => {
    const { rows } = await appkit.lakebase.pool.query(
      `SELECT * FROM booking_notes WHERE booking_id = $1 ORDER BY created_at DESC`,
      [req.params.id],
    );
    res.json(rows);
  });
});

await appkit.server.start();
