import Config

# Configure your database.
#
# Environment variables are respected in development so the same project can run
# locally on the host machine or inside Docker without changing source files.
config :destiny_recommender, DestinyRecommender.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  port: String.to_integer(System.get_env("POSTGRES_PORT") || "5432"),
  database: System.get_env("POSTGRES_DB") || "destiny_recommender_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
bind_ip =
  case System.get_env("PHX_HOST_IP") do
    "0.0.0.0" -> {0, 0, 0, 0}
    _ -> {127, 0, 0, 1}
  end

config :destiny_recommender, DestinyRecommenderWeb.Endpoint,
  http: [ip: bind_ip, port: String.to_integer(System.get_env("PORT") || "4000")],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "w88ZAAImjGFufuNc7XmoJ+yRcD5IsslvZmOFEqZZU1j7QP7CN1iZ6KMqOgwmZjOE",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:destiny_recommender, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:destiny_recommender, ~w(--watch)]}
  ]

# Watch static and templates for browser reloading.
config :destiny_recommender, DestinyRecommenderWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/destiny_recommender_web/(?:controllers|live|components|router)/?.*\.(ex|heex)$"
    ]
  ]

config :destiny_recommender, dev_routes: true

config :logger, :default_formatter, format: "[$level] $message\n"
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true

config :swoosh, :api_client, false
