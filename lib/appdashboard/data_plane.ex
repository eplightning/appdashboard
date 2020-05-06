defmodule AppDashboard.DataPlane do

  use Supervisor

  alias AppDashboard.DataPlane

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      DataPlane.Snapshot
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

end
