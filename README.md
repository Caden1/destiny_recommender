# Destiny 2 Solo Exotic Recommender

A Phoenix + LiveView web app that recommends exactly **one exotic weapon** and **one exotic armor** for a Destiny 2 player based on:

- **Class**: Warlock, Titan, or Hunter
- **Activity**: Crucible or Strike

The app always assumes the player is **solo**.

For **Crucible**, the goal is to recommend gear that helps the player get the **most kills**.
For **Strike**, the goal is to recommend gear that helps the player finish the activity **as quickly and safely as possible** while solo.

---

## What the project does

This project is intentionally **not** a general Destiny 2 chatbot.

Instead, it uses a **candidate-first recommendation pipeline**:

1. The server gathers a small, valid list of exotic weapon candidates.
2. The server gathers a small, valid list of exotic armor candidates.
3. Optional short RAG notes are retrieved from the local database.
4. The model chooses **one** weapon and **one** armor from those server-approved candidates.
5. The server validates the model output before anything is rendered.

That design keeps the app fast, predictable, and much harder to break with hallucinated item names.

---

## Product goals

The app has three layers of functionality:

### MVP
- Player selects class and activity.
- The app builds a small candidate set.
- The model chooses exactly one weapon and one armor.
- The UI renders the recommendation and short playstyle tips.

### v2
- The app retrieves short build-note bullets using embeddings + pgvector.
- Those notes improve the explanation and playstyle guidance.
- The notes are kept short so the model does not get distracted by too much context.

### v3
- The app can ingest the Destiny 2 manifest from Bungie.
- Imported exotics go into a review queue.
- An admin reviews items, adds tags and activity suitability, and marks them ready.
- Offline curator jobs generate ranking proposals.
- An admin approves a proposal before it becomes live.

---

## How it works

### Online recommendation flow

1. A player selects a class and activity.
2. `RecommenderLive` starts an async recommendation task.
3. `AIRecommender` builds a **Context Pack**.
4. The Context Pack includes:
   - request data
   - constraints
   - weapon candidates
   - armor candidates
   - short build-note bullets
   - output limits
5. The model receives only that bounded context.
6. The model returns strict JSON.
7. The server validates the response with an embedded Ecto schema.
8. The UI renders the final recommendation.

### Offline curation flow

1. A manifest sync imports canonical item data.
2. Imported exotics are stored in `catalog_items` with `review_state = needs_review`.
3. Admin reviews each item and adds:
   - tags
   - activity suitability
   - meta notes
4. After review, the admin manually enqueues curator jobs.
5. Curator jobs rank reviewed candidates for each class/activity pair.
6. The app stores pending proposals.
7. Admin approves a proposal.
8. The approved rankings are used by the online recommender.

---

## How this app uses Context Engineering

This project uses **Context Engineering** in a practical, narrow way.

### What that means here

The model is **not** asked to “know Destiny 2 from memory.”
Instead, the server assembles the exact context the model needs for one decision.

### The Context Pack contains
- the player request
- the solo-play constraint
- a small list of valid candidates
- short note bullets
- strict output requirements

### Why this matters
- The model does not invent item names.
- The model cannot choose invalid armor for the wrong class.
- Long prompt history is avoided.
- Recommendation behavior is easier to test.
- Context can be cached and retried deterministically.

### Candidate-first design

The most important prompt design choice in this project is:

> The model chooses from a list. It does not invent from memory.

That is the core context-engineering decision in the app.

---

## How this app uses Agentic AI

This project uses **bounded Agentic AI**, not open-ended agent behavior.

### Online micro-agent

The online path behaves like a tiny agent:
- gather candidates
- retrieve note bullets
- choose one weapon and one armor
- return structured output

It is “agentic” because the AI is part of a tool-backed pipeline, but it is still tightly constrained.

### Offline curator agent

The offline curation path is more agent-like:
- reviewed candidates are gathered
- note bullets are retrieved
- the curator model ranks items
- the result becomes an approval proposal

This is slower, token-heavier, and intentionally separated from the user-facing path.

### What the app does **not** do
- no open web browsing from the model
- no infinite thought loops
- no free-form build invention
- no direct publishing of unreviewed AI output

---

## Architecture overview

### Main modules

- `DestinyRecommender.Recommendations.AIRecommender`
  - builds the online recommendation context pack
  - calls the model
  - validates structured output
  - retries once with a smaller context if needed

- `DestinyRecommender.Recommendations.ContextPack`
  - explicit struct for model context
  - supports caching and retries

- `DestinyRecommender.Recommendations.Recommendation`
  - embedded schema for validating model output

- `DestinyRecommender.Recommendations.Notes`
  - retrieves short build-note bullets using pgvector similarity search

- `DestinyRecommender.Recommendations.Catalog`
  - returns candidate pools from either DB rankings or hardcoded fallback data

- `DestinyRecommender.Recommendations.ManifestImporter`
  - imports canonical exotic items from Bungie manifest data

- `DestinyRecommender.Workers.ManifestPollWorker`
  - checks whether a new manifest version exists

- `DestinyRecommender.Workers.ManifestSyncWorker`
  - imports the manifest item definitions

- `DestinyRecommender.Workers.CuratorProposalWorker`
  - builds offline ranking proposals from reviewed items

- `DestinyRecommenderWeb.RecommenderLive`
  - player-facing UI

- `DestinyRecommenderWeb.Admin.CatalogLive`
  - admin UI for review and proposal approval

---

## Dependencies and why they are used

### App framework
- **phoenix**
  - main web framework
- **phoenix_live_view**
  - interactive server-rendered UI for the recommender and admin pages
- **phoenix_html**
  - HTML helpers for forms and rendering
- **phoenix_ecto**
  - Phoenix/Ecto integration
- **bandit**
  - HTTP server adapter

### Database and persistence
- **ecto_sql**
  - SQL-backed Ecto support
- **postgrex**
  - PostgreSQL driver
- **pgvector**
  - vector column + Ecto helpers for embeddings and similarity search

### Jobs and background work
- **oban**
  - background job processing for manifest polling, syncing, and curator jobs

### HTTP and API integration
- **req**
  - HTTP client used for the OpenAI and Bungie integrations
- **jason**
  - JSON encoding/decoding

### UI and assets
- **tailwind**
  - CSS pipeline
- **esbuild**
  - JavaScript bundling
- **heroicons**
  - icons for UI components

### Observability and system support
- **telemetry_metrics**
  - telemetry metrics support
- **telemetry_poller**
  - periodic telemetry collection
- **dns_cluster**
  - cluster support when needed

### Miscellaneous Phoenix defaults
- **gettext**
  - localization framework
- **swoosh**
  - mailer abstraction; mostly placeholder in this app
- **lazy_html**
  - HTML parsing/testing support in test environment

---

## External services used

- **OpenAI**
  - used for the online recommender, embeddings, and offline curator proposals
- **Bungie API**
  - used to retrieve the Destiny 2 manifest metadata

---

## Requirements

### Local requirements
- Elixir `~> 1.15`
- Erlang/OTP compatible with your Elixir version
- PostgreSQL
- pgvector extension installed in PostgreSQL
- OpenAI API key for AI features
- Bungie API key for manifest sync features

### Recommended environment variables
Copy `.env.example` and set the values you need.

Important ones:
- `OPENAI_API_KEY`
- `BUNGIE_API_KEY`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_HOST`
- `POSTGRES_PORT`
- `POSTGRES_DB`
- `POSTGRES_TEST_DB`

---

## Local setup

### 1. Fetch dependencies and set up the database

```bash
mix setup
```

What that does:
- fetches deps
- creates the database
- runs migrations
- runs seeds
- builds assets

### 2. Start the server

```bash
iex -S mix phx.server
```

Then open:

```text
http://localhost:4000
```

### 3. Admin UI

```text
http://localhost:4000/admin/catalog
```

---

## Seed commands

### Seed the fallback catalog only

```bash
mix seed.catalog
```

### Seed build notes

This requires `OPENAI_API_KEY` because embeddings are generated during seeding.

```bash
mix seed.notes
```

### Full default seed path

```bash
mix run priv/repo/seeds.exs
```

---

## Common Mix commands

### Start the app

```bash
mix phx.server
```

### Start the app with IEx

```bash
iex -S mix phx.server
```

### Run tests

```bash
mix test
```

### Reset the database

```bash
mix ecto.reset
```

### Create and migrate the database

```bash
mix ecto.create
mix ecto.migrate
```

### Format code

```bash
mix format
```

### Run the precommit alias

```bash
mix precommit
```

---

## Common Make commands

A `Makefile` is included for convenience.

### Setup

```bash
make setup
```

### Start server

```bash
make server
```

### Run tests

```bash
make test
```

### Seed fallback catalog

```bash
make seed-catalog
```

### Seed build notes

```bash
make seed-notes
```

### Reset DB

```bash
make reset
```

### Open psql

```bash
make db-shell
```

### Query recent catalog items

```bash
make db-items
```

---

## Docker support

This repo includes local Docker support for development.

### Files added
- `Dockerfile`
- `docker-compose.yml`
- `.dockerignore`
- `.env.example`

### Start Docker services

```bash
docker compose up --build
```

### Stop Docker services

```bash
docker compose down
```

### Follow app logs

```bash
docker compose logs -f web
```

### Open a shell in the web container

```bash
docker compose exec web bash
```

### Open a psql shell in the DB container

```bash
docker compose exec db psql -U postgres -d destiny_recommender_dev
```

### Docker login

```bash
docker login
```

### Docker build only

```bash
docker compose build
```

### Makefile wrappers for Docker

```bash
make docker-build
make docker-up
make docker-down
make docker-logs
make docker-shell
make docker-db-shell
```

---

## Viewing table entries locally

### Using local `psql`

```bash
psql -h localhost -U postgres -d destiny_recommender_dev
```

### Useful queries

#### Catalog items

```sql
SELECT id, slug, name, slot, class, review_state, recommended_activities, source, manifest_version
FROM catalog_items
ORDER BY id DESC
LIMIT 20;
```

#### Build notes

```sql
SELECT id, slug, class, activity, tags, inserted_at
FROM build_notes
ORDER BY id DESC
LIMIT 20;
```

#### Manifest snapshots

```sql
SELECT id, version, locale, status, checked_at, synced_at
FROM manifest_snapshots
ORDER BY id DESC
LIMIT 20;
```

#### Pending proposals

```sql
SELECT id, class, activity, status, manifest_version, inserted_at
FROM catalog_proposals
ORDER BY id DESC
LIMIT 20;
```

#### Published rankings

```sql
SELECT id, class, activity, slot, rank, catalog_item_id, proposal_id
FROM catalog_rankings
ORDER BY class, activity, slot, rank;
```

### Using Dockerized Postgres

```bash
docker compose exec db psql -U postgres -d destiny_recommender_dev -c "SELECT id, slug, name, slot, class, review_state FROM catalog_items ORDER BY id DESC LIMIT 20;"
```

---

## Running background jobs locally

Oban is configured for local background processing, but you can also trigger specific jobs manually.

### Open IEx

```bash
iex -S mix
```

### Enqueue a manifest poll

```elixir
Oban.insert!(DestinyRecommender.Workers.ManifestPollWorker.new(%{}))
```

### Enqueue curator proposals manually

```elixir
DestinyRecommender.Recommendations.Curation.enqueue_curator_proposals()
```

### Drain jobs in the current process

Useful in tests or local debugging:

```elixir
Oban.drain_queue(queue: :manifest)
Oban.drain_queue(queue: :curator)
```

---

## Local testing checklist

### MVP testing
- open `/`
- test all 6 class/activity combinations
- verify each result returns exactly one weapon and one armor
- verify armor matches the selected class
- verify the page does not crash on repeated submissions

### v2 testing
- seed build notes
- verify recommendations still work
- verify note-driven explanations look more grounded
- verify the app still works when there are zero notes

### v3 testing
- set `BUNGIE_API_KEY`
- trigger manifest sync
- verify imported items land in `catalog_items`
- review items in `/admin/catalog`
- mark a subset ready
- enqueue proposal generation
- approve a proposal
- verify the approved ranking affects the online recommendation path

---

## Test suite

The project now includes tests for:
- recommendation schema validation and normalization
- catalog candidate ID behavior
- manifest import merge behavior
- curator proposal candidate scoping
- player-facing LiveView submission flow
- admin LiveView review/edit flow
- admin proposal approval error handling

Run all tests with:

```bash
mix test
```

---

## Important implementation details

### Candidate IDs

The app now prefers **Bungie hashes** as the model-facing item ID when a manifest-backed item has a hash.

For fallback catalog rows that do not yet have a canonical Bungie hash, the app falls back to the local slug.

This gives the project a safe migration path toward canonical Bungie IDs without breaking local-only MVP development.

### Validation

Model output is validated with an embedded Ecto schema before rendering.

That validation checks:
- required fields exist
- IDs are from the server-approved candidate lists
- the output fits the expected structure
- text lengths stay within limits

### Retry strategy

If the model returns invalid JSON or an invalid candidate choice, the app retries once with:
- a smaller candidate pool
- no extra notes
- stricter instructions

### Caching

Recommendations are cached by the **assembled context pack**, not just class/activity.

This means a cache entry changes automatically when:
- candidates change
- note bullets change
- output limits change

---

## Admin workflow

### Review imported items
At `/admin/catalog`, admins can:
- edit tags
- edit short meta notes
- set recommended activities
- mark items ready
- archive items

### Generate proposals
The admin page has a button that enqueues curator proposal jobs.
This is manual on purpose so proposal generation happens **after** human review.

### Approve proposals
Approving a proposal publishes rankings to `catalog_rankings`.
Once published, those DB rankings are used by the player-facing recommendation flow.

---

## Notes about local-only development

This project is set up to work locally in two modes:

### Local fallback mode
- uses hardcoded fallback catalog data
- useful for MVP work and UI iteration
- does not require Bungie manifest sync

### Manifest-backed mode
- imports exotic items from Bungie manifest data
- adds human review and offline curation
- better matches the full v3 design

---

## Troubleshooting

### `Missing OPENAI_API_KEY`
Set your key and restart the server.

```bash
export OPENAI_API_KEY=your_key_here
```

### `CREATE EXTENSION vector` fails
Your PostgreSQL instance does not have pgvector installed.
Use a pgvector-enabled Postgres instance or the included Docker Compose setup.

### No proposals are generated
Check that:
- reviewed items exist
- items are marked `ready`
- items have `recommended_activities` set
- manifest-backed runs have a synced manifest version

### Recommendations do not change after admin approval
Check:
- rankings were inserted into `catalog_rankings`
- the proposal was approved
- the approved items are still `ready`
