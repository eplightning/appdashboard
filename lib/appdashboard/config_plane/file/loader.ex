defmodule AppDashboard.ConfigPlane.File.Loader do
  use GenServer

  require Logger
  alias AppDashboard.Config.Parser

  def start_link(opts) do
    {:ok, path} = Keyword.fetch(opts, :path)
    {:ok, interval} = Keyword.fetch(opts, :reload_interval)

    subscriber = Keyword.get(opts, :subscriber, AppDashboard.ConfigPlane.Processor)
    name = Keyword.get(opts, :name, __MODULE__)

    GenServer.start_link(__MODULE__, {path, subscriber, interval}, name: name)
  end

  def reload(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.cast(name, :reload)
  end

  @impl true
  def init({path, _, interval} = state) do
    Process.send_after(self(), :reload, 0)
    schedule_auto_reload(interval)

    {:ok, pid} = FileSystem.start_link(dirs: [path])

    FileSystem.subscribe(pid)

    {:ok, state}
  end

  @impl true
  def handle_cast(:reload, state) do
    handle_info(:reload, state)
  end

  @impl true
  def handle_info({:file_event, _watcher, {_path, events}}, state) do
    if Enum.member?(events, :modified) do
      handle_info(:reload, state)
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:file_event, _watcher, :stop}, state) do
    {:stop, "Worker stopped", state}
  end

  @impl true
  def handle_info(:auto_reload, {_, _, interval} = state) do
    schedule_auto_reload(interval)
    handle_info(:reload, state)
  end

  @impl true
  def handle_info(:reload, {path, pid, _} = state) do
    case load_config(path) do
      {:ok, parsed} -> send(pid, {:config, parsed})
      {:error, error} -> Logger.error("Error while parsing config #{inspect(error)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(_, state) do
    {:noreply, state}
  end

  defp load_config(path) do
    case Toml.decode_file(path) do
      {:ok, decoded} -> {:ok, Parser.parse_config(decoded)}
      {:error, error} -> {:error, error}
    end
  end

  defp schedule_auto_reload(0), do: {:ok}

  defp schedule_auto_reload(interval) when is_number(interval) do
    Process.send_after(self(), :auto_reload, interval)
    {:ok}
  end
end
