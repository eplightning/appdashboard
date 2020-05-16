defmodule AppDashboard.ConfigPlane do

  use Supervisor

  alias AppDashboard.ConfigPlane

  def start_link(config) do
    Supervisor.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl true
  def init(config) do
    children = [
      ConfigPlane.Snapshot,
      ConfigPlane.Processor
    ]

    Supervisor.init(children ++ config[:loaders], strategy: :rest_for_one)
  end

end
