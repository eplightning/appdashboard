# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :appdashboard,
  namespace: AppDashboard,
  ecto_repos: [AppDashboard.Repo]

# Configures the endpoint
config :appdashboard, AppDashboardWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "752g7rgSa5/v5l8JmAQc+19Ok0uPuccrsMeEX4yAPHKqD5v2kI5TwbKFBAk9rfH3",
  render_errors: [view: AppDashboardWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: AppDashboard.PubSub,
  live_view: [signing_salt: "PylImrh6"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :logger_json, :backend,
  metadata: :all

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure default HTTP pool
config :machine_gun,
  default: %{
    pool_size: 5,
    pool_max_overflow: 10,
    pool_timeout: 1000,
    request_timeout: 3000
  }

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
