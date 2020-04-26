defmodule AppDashboard.Repo do
  use Ecto.Repo,
    otp_app: :appdashboard,
    adapter: Ecto.Adapters.Postgres
end
