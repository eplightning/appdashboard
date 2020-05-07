defmodule AppDashboard.DataPlane.Provider.Kubernetes do
  use GenServer

  alias AppDashboard.DataPlane.Provider

  @behaviour Provider

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  @impl GenServer
  def init(_) do
    {:ok, nil}
  end

  @impl Provider
  def start_provider(_provider_config, _source_config, _instance_pid) do
    start_link(nil)
  end

  @impl Provider
  def update_data(_provider_pid, data) do
    {:ok, Map.put(data, "wow", "hehe"), 2000}
  end
end
