# In this file, we load production configuration and secrets
# from environment variables. You can also hardcode secrets,
# although such is generally not recommended and you have to
# remember to add this file to your .gitignore.
import Config

config_path = System.get_env("CONFIG_PATH") || "config.toml"
config_interval = String.to_integer(System.get_env("CONFIG_RELOAD_INTERVAL") || "600000")

config :appdashboard, AppDashboard.ConfigPlane,
  loaders: [
    {AppDashboard.ConfigPlane.File.Loader, path: config_path, reload_interval: config_interval}
  ]

database_url =
  System.get_env("DATABASE_URL") ||
    raise """
    environment variable DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

config :appdashboard, AppDashboard.Repo,
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

https_enabled = System.get_env("HTTPS", "false") == "true"
public_url = System.get_env("PUBLIC_URL", "localhost")

config :appdashboard, AppDashboardWeb.Endpoint,
  url: [host: public_url, port: if(https_enabled, do: 443, else: 80)],
  http: [
    port: String.to_integer(System.get_env("PORT") || "4000"),
    transport_options: [socket_opts: [:inet6]]
  ],
  secret_key_base: secret_key_base
