import Config

# Configure your database for tests.
#
# The host/port/user/password can be overridden so tests can run either against
# a local Postgres instance or a Docker container.
config :destiny_recommender, DestinyRecommender.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  port: String.to_integer(System.get_env("POSTGRES_PORT") || "5432"),
  database:
    System.get_env("POSTGRES_TEST_DB") ||
      "destiny_recommender_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :destiny_recommender, DestinyRecommenderWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "i+nGXlKdPsD85maFIga8NkPXAo9G9RFF6z9lnp+Q0B1JYRzk7M+6ODbiIH12Ahly",
  server: false

config :destiny_recommender, Oban, testing: :manual

config :destiny_recommender, DestinyRecommender.Mailer, adapter: Swoosh.Adapters.Test
config :swoosh, :api_client, false
config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true
