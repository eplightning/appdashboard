# WIP
defmodule AppDashboard.ConfigPlane.Discovery.Kubernetes do

  use GenServer

  alias AppDashboard.ConfigPlane.Processor.Discovery
  alias AppDashboard.Config.Instance
  alias AppDashboard.Config.Subset.Discovery, as: Config

  defmodule State do
    defstruct config: %Config{}, id: nil
  end

  def start_link({%Config{} = config, id}) do
    GenServer.start_link(__MODULE__, %State{config: config, id: id})
  end

  @impl true
  def init(state) do
    Process.send_after(self(), :discover, 5000)
    {:ok, state}
  end

  @impl true
  def handle_info(:discover, %State{id: id} = state) do
    Discovery.discover(id, %{
      {"discovered_env", "discovered_app"} => %Instance{application: "discovered_app", environment: "discovered_env", template: "template"}
    })
    {:noreply, state}
  end


end
