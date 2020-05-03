defmodule AppDashboard.ConfigPlane.Snapshot do

  use GenServer

  alias AppDashboard.Config
  alias AppDashboard.ConfigPlane.Diff
  alias Phoenix.PubSub

  defmodule State do
    defstruct pubsub: AppDashboard.PubSub, delay: 10 * 1000, snapshot: %Config{}, pending: nil
  end

  def start_link(opts \\ []) do
    pubsub = Keyword.get(opts, :pubsub, AppDashboard.PubSub)
    name = Keyword.get(opts, :name, __MODULE__)
    delay = Keyword.get(opts, :delay, 10 * 1000)

    GenServer.start_link(__MODULE__, %State{pubsub: pubsub, delay: delay}, name: name)
  end

  def get(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.call(name, :get)
  end

  def update(%Config{} = config, opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.cast(name, {:update, config})
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call(:get, _from, %State{snapshot: snapshot} = state), do: {:reply, snapshot, state}

  @impl true
  def handle_cast({:update, new_config}, %State{pending: pending, delay: delay} = state) do
    if is_nil(pending), do: Process.send_after(self(), :update, delay)

    {:noreply, %State{state | pending: new_config}}
  end

  @impl true
  def handle_info(:update, %State{pending: pending, pubsub: pubsub, snapshot: snapshot} = state) do
    broadcast_diff(pubsub, snapshot, pending)

    {:noreply, %State{state | snapshot: pending}}
  end

  defp broadcast_diff(pubsub, snapshot, pending) do
    diff = Diff.calculate_diff(snapshot, pending)
    broadcast_single_diff(pubsub, diff)
  end

  defp broadcast_single_diff(pubsub, [message | t]) do
    PubSub.local_broadcast(pubsub, "config", message)
    broadcast_single_diff(pubsub, t)
  end

  defp broadcast_single_diff(_pubsub, _diffs), do: nil

end
