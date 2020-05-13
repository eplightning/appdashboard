defmodule AppDashboardWeb.Components.DashboardComponent do

  use AppDashboardWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, assign(socket, query: "")}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, title: assigns.title, dashboard: assigns.dashboard, filtered: filter_dashboard(assigns.dashboard, socket.assigns.query))}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, assign(socket, query: query, filtered: filter_dashboard(socket.assigns.dashboard, query))}
  end

  defp filter_dashboard(dashboard, query) when query == "", do: dashboard

  defp filter_dashboard(dashboard, query) do
    dashboard
    |> Enum.filter(fn %{name: name} -> String.contains?(name, query) end)
  end

end
