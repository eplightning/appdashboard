defmodule AppDashboard.DataPlane.Instance do
  use GenServer

  require Logger
  alias AppDashboard.Config.Subset.Instance
  alias AppDashboard.Config.Instance.Provider, as: ProviderConfig
  alias AppDashboard.Config.Instance, as: InstanceConfig
  alias AppDashboard.Utils.JSONPath

  @provider_map %{"http" => AppDashboard.DataPlane.Provider.HTTP, "docker_image" => AppDashboard.DataPlane.Provider.DockerImage}
  @provider_types Map.keys(@provider_map)

  defmodule State do
    defstruct providers: [], extractors: %{}, initial_data: %{}, id: {}, leader: nil
  end

  @spec start_link({any, any}) :: :ignore | {:error, any} | {:ok, pid}
  def start_link({_instance, _leader} = initial_arg) do
    GenServer.start_link(__MODULE__, initial_arg)
  end

  @impl true
  def init({%Instance{config: %InstanceConfig{data: data} = config} = instance, leader}) do
    Process.send_after(self(), :refresh, 0)

    {:ok,
     %State{
       providers: prepare_providers(instance),
       extractors: prepare_extractors(instance),
       initial_data: data,
       leader: leader,
       id: {config.environment, config.application}
     }}
  end

  @impl true
  def handle_info(:refresh, state) do
    refresh(state)
  end

  @impl true
  def handle_cast(:refresh, state) do
    refresh(state)
  end

  defp refresh(%State{leader: leader, id: id} = state) do
    {data, wait_time} =
      {state.initial_data, :infinity}
      |> apply_providers(state.providers)
      |> apply_extractors(state.extractors)

    send(leader, {:data, id, data})
    if wait_time != :infinity, do: Process.send_after(self(), :refresh, wait_time)

    {:noreply, state}
  end

  defp apply_providers(data, providers) do
    providers
    |> Enum.reduce(data, fn {module, pid}, {data, wait_time} ->
      case apply(module, :update_data, [pid, data]) do
        {:ok, next_data, next_wait_time} -> {next_data, min(wait_time, next_wait_time)}
        {:error, _error} -> {data, wait_time}
      end
    end)
  end

  defp apply_extractors({data, wait_time}, extractors) do
    updated_data =
      extractors
      |> Enum.reduce(data, fn {name, path}, data ->
        case JSONPath.query(data, path) do
          {:ok, value} -> Map.put(data, name, value)
          _ -> Map.put(data, name, "")
        end
      end)

    {updated_data, wait_time}
  end

  defp prepare_extractors(%Instance{config: %InstanceConfig{extractors: extractors}}) do
    extractors
    |> Enum.filter(fn
      {_k, binary} when is_binary(binary) -> String.length(String.trim(binary)) > 0
      {_k, _val} -> false
    end)
    |> Enum.map(fn {k, jsonpath} ->
      case JSONPath.compile(jsonpath) do
        {:ok, compiled} ->
          {k, compiled}

        {:error, error} ->
          Logger.error("Error while parsing extractor #{k}: #{inspect(error)}")
          {k, nil}
      end
    end)
    |> Enum.filter(fn {_k, v} -> !is_nil(v) end)
    |> Enum.into(%{})
  end

  defp prepare_providers(%Instance{
         config: %InstanceConfig{providers: providers},
         sources: sources
       }) do
    providers
    |> Enum.filter(fn {_k, provider} -> supported?(provider) end)
    |> Enum.sort(fn {_k1, p1}, {_k2, p2} -> p1.order <= p2.order end)
    |> Enum.map(fn {_k, provider} ->
      source = provider_source(provider, sources)
      module = provider_module(provider)

      result = apply(module, :start_provider, [provider, source, self()])

      case result do
        {:ok, pid} ->
          {module, pid}

        {:error, error} ->
          Logger.error("Provider #{provider.id} failed to initialize: #{inspect(error)}")
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp supported?(%ProviderConfig{type: type}) when type in @provider_types, do: true

  defp supported?(%ProviderConfig{type: type}) do
    Logger.warn("Unsupported provider type: #{type}")
    false
  end

  defp provider_module(%ProviderConfig{type: type}), do: Map.fetch!(@provider_map, type)

  defp provider_source(%ProviderConfig{source: source}, sources)
       when is_binary(source) or source != "",
       do: Map.get(sources, source, :none)

  defp provider_source(_provider, _sources), do: :none
end
