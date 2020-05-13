defmodule AppDashboard.ConfigPlane do

  use Supervisor

  alias AppDashboard.ConfigPlane

  def start_link(config_path) do
    Supervisor.start_link(__MODULE__, config_path, name: __MODULE__)
  end

  @impl true
  def init(config_path) do
    children = [
      ConfigPlane.Snapshot,
      ConfigPlane.Processor,
      {ConfigPlane.File.Loader, path: config_path}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

end
