defmodule AppDashboardWeb.SnapshotsLive do
  use AppDashboardWeb, :live_view

  alias AppDashboard.Schema.Snapshot

  @per_page 20

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(AppDashboard.PubSub, "snapshots")
    end

    {:ok, assign(socket, query: "", page: 1, changeset: Snapshot.changeset(%Snapshot{}))}
  end

  @impl true
  def handle_params(%{"page" => page}, _session, socket) do
    socket = case Integer.parse(page) do
      {page, ""} when page >= 1 -> assign(socket, page: page)
      _ -> socket
    end

    {:noreply, assign(socket, snapshot_list_assigns(socket))}
  end

  @impl true
  def handle_params(_params, _session, socket) do
    {:noreply, assign(socket, snapshot_list_assigns(socket))}
  end

  @impl true
  def handle_info(:snapshot_added, socket) do
    {:noreply, assign(socket, snapshot_list_assigns(socket))}
  end

  @impl true
  def handle_event("open_snapshot", %{"id" => id}, socket) do
    {:noreply, push_redirect(socket, to: Routes.snapshot_path(socket, :view, id))}
  end

  @impl true
  def handle_event("filter", %{"filter" => %{"name" => name}}, socket) do
    socket = assign(socket, query: name, page: 1)

    {:noreply, assign(socket, snapshot_list_assigns(socket))}
  end

  @impl true
  def handle_event("create", %{"snapshot" => input}, socket) do
    changeset =
      Snapshot.changeset(%Snapshot{}, input)
      |> Snapshot.with_current_data()

    case Snapshot.insert(changeset) do
      {:ok, snapshot} -> {:noreply, push_redirect(socket, to: Routes.snapshot_path(socket, :view, snapshot.id))}
      {:error, _error} -> {:noreply, socket}
    end
  end

  defp snapshot_list_assigns(%{assigns: %{page: page} = assigns}) do
    query =
      snapshot_query(assigns)

    count = AppDashboard.Repo.aggregate(query, :count)

    snapshots =
      query
      |> Snapshot.limited(@per_page, (page - 1) * @per_page)

    [snapshots: AppDashboard.Repo.all(snapshots), pages: ceil(count / @per_page)]
  end

  defp snapshot_query(%{query: query}) when query == "" do
    Snapshot.all()
  end

  defp snapshot_query(%{query: query}) do
    Snapshot.filtered(query)
  end

end
