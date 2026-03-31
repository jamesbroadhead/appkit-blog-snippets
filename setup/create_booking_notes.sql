-- Create the writable app table in Lakebase (Postgres).
-- This table is NOT synced from the lakehouse -- it's app-owned state.
-- Run against your Lakebase Postgres endpoint with psql, or via the Lakebase SQL editor.

CREATE TABLE IF NOT EXISTS booking_notes (
  note_id      SERIAL PRIMARY KEY,
  booking_id   BIGINT NOT NULL,
  agent_email  TEXT NOT NULL,
  note         TEXT NOT NULL,
  action_taken TEXT NOT NULL DEFAULT 'no_action',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_booking_notes_booking_id ON booking_notes (booking_id);
