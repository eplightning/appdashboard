defmodule AppDashboard.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      AppDashboard.Repo,
      # Start the Telemetry supervisor
      AppDashboardWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: AppDashboard.PubSub},
      # Config/data plane
      {AppDashboard.ConfigPlane, Application.fetch_env!(:appdashboard, AppDashboard.ConfigPlane)},
      AppDashboard.DataPlane,
      # Start the Endpoint (http/https)
      AppDashboardWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AppDashboard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    AppDashboardWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
