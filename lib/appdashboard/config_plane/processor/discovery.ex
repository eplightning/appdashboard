defmodule AppDashboard.ConfigPlane.Processor.Discovery do

  use Supervisor

  require Logger
  alias AppDashboard.Config
  alias AppDashboard.ConfigPlane.Diff

  defmodule State do
    defstruct discovered: %{}, active: %{}, supervisor: nil
  end

  @discovery_map %{"kubernetes" => AppDashboard.ConfigPlane.Discovery.Kubernetes}
  @discovery_types Map.keys(@discovery_map)

  def update_config(%Config{} = config, %State{} = state) do
    update_state(state, config)
  end

  def handle_discovery({id, %{} = instances}, %State{discovered: discovered} = state) do
    %State{state | discovered: Map.put(discovered, id, instances)}
  end

  def get_instances(%State{discovered: discovered}) do
    discovered
    |> Map.values
    |> Enum.concat
    |> Enum.into(%{})
  end

  def discover({pid, id}, discoveries) do
    send(pid, {:discovery, {id, discoveries}})
  end

  @spec start_link ::
          {:error, any} | {:ok, pid, AppDashboard.ConfigPlane.Processor.Discovery.State.t()}
  def start_link do
    case Supervisor.start_link(__MODULE__, nil) do
      {:ok, pid} -> {:ok, pid, %State{supervisor: pid}}
      {:error, error} -> {:error, error}
    end
  end

  @impl true
  def init(_args) do
    Supervisor.init([], strategy: :one_for_one)
  end

  defp update_state(%State{discovered: discovered, active: old, supervisor: supervisor} = state, config) do
    # calculate difference between configs
    new = discovery_map(config)
    diff = Diff.calculate_discovery_diff(old, new)

    # create all lists of children
    to_remove =
      diff
      |> Enum.filter(fn {action, _id} -> action == :discovery_removed end)
      |> Enum.map(fn {_action, id} -> id end)

    to_recreate =
      diff
      |> Enum.filter(fn {action, _id} -> action == :discovery_changed end)
      |> Enum.map(fn {_action, id} -> id end)

    to_create =
      diff
      |> Enum.filter(fn {action, _id} -> action == :discovery_added end)
      |> Enum.map(fn {_action, id} -> id end)

    to_terminate = to_remove ++ to_recreate
    to_start = to_recreate ++ to_create

    # update supervisor
    to_terminate
    |> Enum.each(fn id -> :ok = terminate_discovery(supervisor, id) end)

    to_start
    |> Enum.map(fn id -> Map.fetch!(new, id) end)
    |> Enum.each(fn discovery -> :ok = create_discovery(supervisor, discovery) end)

    %State{state | discovered: Map.drop(discovered, to_remove), active: new}
  end

  defp discovery_map(%Config{discovery: discovery_list} = config) do
    discovery_list
    |> Map.keys
    |> Enum.map(fn id ->
      {:ok, discovery} = Config.Subset.Discovery.create(config, id)
      {id, discovery}
    end)
    |> Enum.filter(fn {_id, discovery} -> supported?(discovery) end)
    |> Enum.into(%{})
  end

  defp supported?(%Config.Subset.Discovery{discovery: %Config.Discovery{type: type}}) when type in @discovery_types, do: true
  defp supported?(%Config.Subset.Discovery{discovery: %Config.Discovery{type: type}}) do
    Logger.warn("Unsupported discovery type: #{type}")
    false
  end

  defp terminate_discovery(supervisor, child) do
    with :ok <- Supervisor.terminate_child(supervisor, child),
         :ok <- Supervisor.delete_child(supervisor, child)
    do
      :ok
    else
      {:error, :not_found} -> :ok
      {:error, err} -> {:error, err}
    end
  end

  defp create_discovery(supervisor, %Config.Subset.Discovery{discovery: %Config.Discovery{id: id}} = discovery) do
    case Supervisor.start_child(supervisor, discovery_child_spec(discovery)) do
      {:ok, _pid} -> :ok
      {:ok, _pid, _info} -> :ok
      {:error, err} when err in [:already_started, :already_present] -> {:error, err}
      _ ->
        Logger.error("Discovery failed to start, ignored: #{id}")
        :ok
    end
  end

  defp discovery_child_spec(%Config.Subset.Discovery{discovery: %Config.Discovery{id: id, type: type}} = config) do
    discovery_module = Map.fetch!(@discovery_map, type)

    Supervisor.child_spec({discovery_module, {config, {self(), id}}}, id: id)
  end

end
