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

appkit.server.extend((app) => {
  // Look up a booking by ID (joins synced tables in Lakebase)
  app.get("/api/bookings/:id", async (req, res) => {
    const { rows } = await appkit.lakebase.pool.query(
      `SELECT b.booking_id, b.status, b.check_in, b.check_out,
              b.guests_count, b.total_amount,
              u.name AS guest_name, u.email AS guest_email,
              p.title AS property_title, d.destination
       FROM bookings b
       JOIN users u ON b.user_id = u.user_id
       JOIN properties p ON b.property_id = p.property_id
       JOIN destinations d ON p.destination_id = d.destination_id
       WHERE b.booking_id = $1`,
      [req.params.id],
    );
    if (!rows.length) return res.status(404).json({ error: "Booking not found" });
    res.json(rows[0]);
  });

  // Add a note to a booking
  app.post("/api/bookings/:id/notes", async (req, res) => {
    const { note, action_taken } = req.body;
    const { rows } = await appkit.lakebase.pool.query(
      `INSERT INTO booking_notes (booking_id, agent_email, note, action_taken)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [req.params.id, "app-user@example.com", note, action_taken ?? "no_action"],
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
