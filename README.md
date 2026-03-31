# AppKit Blog Snippets

Code snippets for the "Building a Vacation Rental Operations App with AppKit" blog post.

These files are referenced directly from the blog via raw GitHub URLs. You don't need to clone this repo — use `curl` and the Databricks CLI to pull what you need.

## Quick start (with a coding agent)

Copy the prompt from [`setup/agent_prompt.md`](setup/agent_prompt.md) into your preferred coding agent and let it scaffold the full project.

## Manual walkthrough

See the blog post for step-by-step instructions. Key files:

| File | Purpose |
|------|---------|
| `setup/copy_to_catalog.sql` | Copy wanderbricks sample data to your catalog |
| `setup/create_synced_tables.sh` | Create Lakebase synced tables via CLI |
| `setup/create_booking_notes.sql` | Create the writable app table in Lakebase |
| `setup/agent_prompt.md` | Full prompt for AI coding agents |
| `config/queries/revenue_by_destination.sql` | Analytics query |
| `server/server.ts` | AppKit server with Lakebase routes |
| `client/src/*.tsx` | React components |
