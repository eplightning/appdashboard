defmodule AppDashboard.DataPlane.Snapshot do
  use GenServer

  alias AppDashboard.DataPlane.Diff
  alias Phoenix.PubSub

  defmodule State do
    defstruct pubsub: AppDashboard.PubSub, delay: 1000, snapshot: %{}, pending: nil
  end

  def start_link(opts \\ []) do
    pubsub = Keyword.get(opts, :pubsub, AppDashboard.PubSub)
    name = Keyword.get(opts, :name, __MODULE__)
    delay = Keyword.get(opts, :delay, 1000)

    GenServer.start_link(__MODULE__, %State{pubsub: pubsub, delay: delay}, name: name)
  end

  def get(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.call(name, :get)
  end

  def get_instance({app, env}, opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.call(name, {:get_instance, {app, env}})
  end

  def update(%{} = data, opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.cast(name, {:update, data})
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call(:get, _from, %State{snapshot: snapshot} = state), do: {:reply, snapshot, state}

  @impl true
  def handle_call({:get_instance, id}, _from, %State{snapshot: snapshot} = state) do
    {:reply, Map.fetch(snapshot, id), state}
  end

  @impl true
  def handle_cast({:update, new_data}, %State{pending: pending, delay: delay} = state) do
    if is_nil(pending), do: Process.send_after(self(), :update, delay)

    {:noreply, %State{state | pending: new_data}}
  end

  @impl true
  def handle_info(:update, %State{pending: pending, pubsub: pubsub, snapshot: snapshot} = state) do
    broadcast_diff(pubsub, snapshot, pending)

    {:noreply, %State{state | snapshot: pending, pending: nil}}
  end

  defp broadcast_diff(pubsub, snapshot, pending) do
    diff = Diff.calculate_data_diff(snapshot, pending)
    broadcast_single_diff(pubsub, diff)
  end

  defp broadcast_single_diff(pubsub, [message | t]) do
    PubSub.local_broadcast(pubsub, "data", message)
    broadcast_single_diff(pubsub, t)
  end

  defp broadcast_single_diff(_pubsub, _diffs), do: nil
end
