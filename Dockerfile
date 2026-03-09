# Local development image.
#
# This image is intentionally simple: it is meant for running the app locally
# with docker compose, not for production deployment.
FROM elixir:1.15

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential git curl postgresql-client && \
    rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force && mix local.rebar --force

WORKDIR /app

# Copy the minimum dependency files first so Docker layer caching can help.
COPY mix.exs mix.lock ./
COPY config ./config

RUN mix deps.get

CMD ["bash", "-lc", "mix setup && mix phx.server"]
