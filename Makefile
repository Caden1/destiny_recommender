APP_NAME=destiny_recommender
DB_NAME?=destiny_recommender_dev
DB_USER?=postgres
DB_HOST?=localhost
DB_PORT?=5432

.PHONY: setup server test seed-catalog seed-notes reset db-shell db-items docker-build docker-up docker-down docker-logs docker-shell docker-db-shell

# Full local setup: fetch deps, migrate, seed, and build assets.
setup:
	mix setup

# Start the Phoenix server with IEx attached.
server:
	iex -S mix phx.server

# Run the full test suite.
test:
	mix test

# Seed only the fallback catalog rows.
seed-catalog:
	mix seed.catalog

# Seed build notes (requires OPENAI_API_KEY for embeddings).
seed-notes:
	mix seed.notes

# Reset the local database from scratch.
reset:
	mix ecto.reset

# Open a psql shell against the local database.
db-shell:
	psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d $(DB_NAME)

# Quick query for recently inserted catalog items.
db-items:
	psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d $(DB_NAME) -c "SELECT id, slug, name, slot, class, review_state, recommended_activities, source, manifest_version FROM catalog_items ORDER BY id DESC LIMIT 20;"

# Build the local Docker images.
docker-build:
	docker compose build

# Start the app and Postgres in Docker.
docker-up:
	docker compose up --build

# Stop Docker services.
docker-down:
	docker compose down

# Follow Docker logs.
docker-logs:
	docker compose logs -f web

# Get a shell inside the web container.
docker-shell:
	docker compose exec web bash

# Open a psql shell inside the Postgres container.
docker-db-shell:
	docker compose exec db sh -lc 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'
