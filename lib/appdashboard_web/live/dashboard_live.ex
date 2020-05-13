defmodule AppDashboardWeb.DashboardLive do
  use AppDashboardWeb, :live_view

  alias AppDashboard.Schema.InstanceData

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(AppDashboard.PubSub, "config")
      Phoenix.PubSub.subscribe(AppDashboard.PubSub, "data")
    end

    dashboard = build_dashboard()

    {:ok, assign(socket, dashboard: dashboard)}
  end

  @impl true
  def handle_info(:config_changed, socket) do
    dashboard = build_dashboard()

    {:noreply, assign(socket, dashboard: dashboard)}
  end

  @impl true
  def handle_info(:data_snapshot_changed, socket) do
    dashboard = build_dashboard()

    {:noreply, assign(socket, dashboard: dashboard)}
  end

  @impl true
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp build_dashboard() do
    ui_config = AppDashboard.ConfigPlane.Snapshot.get_ui_config()

    data =
      AppDashboard.DataPlane.Snapshot.get()
      |> InstanceData.from_config_plane

    AppDashboardWeb.Dashboard.Builder.build(ui_config, data)
  end

end
