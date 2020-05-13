defmodule AppDashboardWeb.SnapshotLive do
  use AppDashboardWeb, :live_view

  alias AppDashboard.Schema.Snapshot

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _session, socket) do
    snapshot = AppDashboard.Repo.get(Snapshot, id)

    case snapshot do
      nil -> {:noreply, push_redirect(socket, to: Routes.snapshots_path(socket, :index))}
      snapshot -> {:noreply, assign(socket, snapshot: snapshot, dashboard: build_dashboard(snapshot))}
    end
  end

  defp build_dashboard(snapshot) do
    ui_config = AppDashboard.Config.Parser.parse_ui_config(snapshot.ui_config)
    data = snapshot.data

    AppDashboardWeb.Dashboard.Builder.build(ui_config, data)
  end

end
