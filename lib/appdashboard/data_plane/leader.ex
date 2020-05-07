defmodule AppDashboard.DataPlane.Leader do
  use GenServer

  require Logger
  alias Phoenix.PubSub

  defmodule State do
    defstruct pubsub: AppDashboard.PubSub,
              conf_snap: AppDashboard.ConfigPlane.Snapshot,
              data_snap: AppDashboard.DataPlane.Snapshot,
              instances: %{},
              supervisor: nil
  end

  def start_link(opts \\ []) do
    pubsub = Keyword.get(opts, :pubsub, AppDashboard.PubSub)
    conf_snap = Keyword.get(opts, :conf_snap, AppDashboard.ConfigPlane.Snapshot)
    data_snap = Keyword.get(opts, :data_snap, AppDashboard.DataPlane.Snapshot)
    name = Keyword.get(opts, :name, __MODULE__)

    GenServer.start_link(
      __MODULE__,
      %State{pubsub: pubsub, conf_snap: conf_snap, data_snap: data_snap},
      name: name
    )
  end

  @impl true
  def init(state) do
    {:ok, pid} = Supervisor.start_link([], strategy: :one_for_one)

    Process.send_after(self(), :init, 0)
    {:ok, %State{state | supervisor: pid}}
  end

  @impl true
  def handle_info(:init, %State{pubsub: pubsub, conf_snap: conf_snap} = state) do
    PubSub.subscribe(pubsub, "config")

    new_state =
      AppDashboard.ConfigPlane.Snapshot.get_instance_ids(name: conf_snap)
      |> Enum.reduce(state, fn id, state -> update_instance(id, state) end)

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:instance_added, id}, state) do
    {:noreply, update_instance(id, state)}
  end

  @impl true
  def handle_info({:instance_changed, id}, state) do
    {:noreply, update_instance(id, state)}
  end

  @impl true
  def handle_info({:instance_removed, id}, state) do
    {:noreply, update_instance(id, state)}
  end

  @impl true
  def handle_info(:config_changed, state), do: {:noreply, state}

  @impl true
  def handle_info({:data, id, data}, %State{data_snap: data_snap, instances: instances} = state) do
    new_instances = Map.put(instances, id, data)
    AppDashboard.DataPlane.Snapshot.update(new_instances, name: data_snap)

    {:noreply, %State{state | instances: new_instances}}
  end

  defp update_instance(id, %State{conf_snap: conf_snap, instances: instances} = state) do
    config = AppDashboard.ConfigPlane.Snapshot.get_instance(id, name: conf_snap)

    case {config, Map.has_key?(instances, id)} do
      {{:ok, instance}, true} -> recreate_instance(state, id, instance)
      {{:ok, instance}, false} -> create_instance(state, id, instance)
      {:error, true} -> delete_instance(state, id)
      {:error, false} -> state
    end
  end

  defp recreate_instance(state, id, config) do
    state
    |> delete_instance(id)
    |> create_instance(id, config)
  end

  defp create_instance(%State{instances: instances, supervisor: supervisor} = state, id, config) do
    case Supervisor.start_child(supervisor, instance_child_spec(id, config)) do
      {:ok, _pid} ->
        %State{state | instances: Map.put(instances, id, %{})}

      {:ok, _pid, _info} ->
        %State{state | instances: Map.put(instances, id, %{})}

      {:error, err} when err not in [:already_started, :already_present] ->
        Logger.error("Instance #{inspect(id)} failed to start, ignored: #{inspect(err)}")
        state
    end
  end

  defp delete_instance(%State{instances: instances, supervisor: supervisor} = state, id) do
    :ok = terminate_instance(supervisor, id)
    %State{state | instances: Map.delete(instances, id)}
  end

  defp terminate_instance(supervisor, child) do
    with :ok <- Supervisor.terminate_child(supervisor, child),
         :ok <- Supervisor.delete_child(supervisor, child) do
      :ok
    else
      {:error, :not_found} -> :ok
      {:error, err} -> {:error, err}
    end
  end

  defp instance_child_spec(id, config) do
    Supervisor.child_spec({AppDashboard.DataPlane.Instance, {config, self()}}, id: id)
  end
end
