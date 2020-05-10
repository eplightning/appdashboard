defmodule AppDashboardWeb.DashboardLive do
  use AppDashboardWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(AppDashboard.PubSub, "config")
      Phoenix.PubSub.subscribe(AppDashboard.PubSub, "data")
    end

    dashboard = build_dashboard()

    {:ok, assign(socket, dashboard: dashboard, filtered: dashboard, query: "")}
  end

  @impl true
  def handle_info(:config_changed, socket) do
    dashboard = build_dashboard()

    {:noreply, assign(socket, dashboard: dashboard, filtered: filter_dashboard(dashboard, socket.assigns.query))}
  end

  @impl true
  def handle_info(:data_snapshot_changed, socket) do
    dashboard = build_dashboard()

    {:noreply, assign(socket, dashboard: dashboard, filtered: filter_dashboard(dashboard, socket.assigns.query))}
  end

  @impl true
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, assign(socket, query: query, filtered: filter_dashboard(socket.assigns.dashboard, query))}
  end

  defp build_dashboard() do
    ui_config = AppDashboard.ConfigPlane.Snapshot.get_ui_config()
    data = AppDashboard.DataPlane.Snapshot.get()

    AppDashboardWeb.Dashboard.Builder.build(ui_config, data)
  end

  defp filter_dashboard(dashboard, query) when query == "", do: dashboard

  defp filter_dashboard(dashboard, query) do
    dashboard
    |> Enum.filter(fn %{name: name} -> String.starts_with?(name, query) end)
  end

end
