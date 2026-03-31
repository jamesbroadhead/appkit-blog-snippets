import { useState } from "react";
import { Card, CardHeader, CardTitle, CardContent } from "@databricks/appkit-ui";

export function BookingManager() {
  const [bookingId, setBookingId] = useState("");
  const [booking, setBooking] = useState<any>(null);
  const [notes, setNotes] = useState<any[]>([]);
  const [newNote, setNewNote] = useState("");

  const handleLookup = async () => {
    const [bookingRes, notesRes] = await Promise.all([
      fetch(`/api/bookings/${bookingId}`),
      fetch(`/api/bookings/${bookingId}/notes`),
    ]);
    setBooking(await bookingRes.json());
    setNotes(await notesRes.json());
  };

  const handleAddNote = async () => {
    const res = await fetch(`/api/bookings/${bookingId}/notes`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ note: newNote, action_taken: "note_added" }),
    });
    const created = await res.json();
    setNotes([created, ...notes]);
    setNewNote("");
  };

  return (
    <div className="space-y-4">
      <div className="flex gap-2">
        <input
          className="border rounded px-3 py-1.5 text-sm"
          placeholder="Booking ID"
          value={bookingId}
          onChange={(e) => setBookingId(e.target.value)}
        />
        <button
          className="bg-primary text-primary-foreground px-4 py-1.5 rounded text-sm"
          onClick={handleLookup}
        >
          Look up
        </button>
      </div>

      {booking && (
        <Card>
          <CardHeader>
            <CardTitle>{booking.property_title}</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-sm text-muted-foreground space-y-1">
              <p>{booking.guest_name} · {booking.guest_email}</p>
              <p>{booking.destination} · {booking.guests_count} guests</p>
              <p>{booking.check_in} → {booking.check_out} · {booking.status}</p>
              <p className="font-medium">${booking.total_amount}</p>
            </div>

            <div className="mt-4 space-y-2">
              <h4 className="text-sm font-medium">Notes</h4>
              <div className="flex gap-2">
                <input
                  className="border rounded px-3 py-1.5 text-sm flex-1"
                  placeholder="Add a note..."
                  value={newNote}
                  onChange={(e) => setNewNote(e.target.value)}
                />
                <button
                  className="bg-primary text-primary-foreground px-4 py-1.5 rounded text-sm"
                  onClick={handleAddNote}
                >
                  Add
                </button>
              </div>
              {notes.map((n) => (
                <div key={n.note_id} className="text-sm border-l-2 pl-3 py-1">
                  <p>{n.note}</p>
                  <p className="text-muted-foreground text-xs">
                    {n.agent_email} · {n.action_taken} · {new Date(n.created_at).toLocaleString()}
                  </p>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
