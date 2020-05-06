defmodule AppDashboard.ConfigPlane do

  use Supervisor

  alias AppDashboard.ConfigPlane

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      ConfigPlane.Snapshot,
      ConfigPlane.Processor,
      {ConfigPlane.File.Loader, path: "examples/config.toml"}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

end
