defmodule AppDashboard.DataPlane.Provider.DockerImage do
  use GenServer

  require Logger
  alias AppDashboard.DataPlane.Provider
  alias AppDashboard.Config.Source
  alias AppDashboard.Config.Instance.Provider, as: ProviderConfig
  alias AppDashboard.Utils.HTTPConfig
  alias AppDashboard.Utils.Extractor
  alias AppDashboard.Utils.DockerRegistry

  defmodule State do
    defstruct id: "",
              http_config: %HTTPConfig{},
              pool: :default,
              image: nil,
              default_registry: nil,
              extractor: %Extractor{},
              last_success: %{},
              interval: 60 * 1000
  end

  @behaviour Provider

  @impl Provider
  def start_provider(provider, source, _instance_pid) do
    start_link({provider, source})
  end

  @impl Provider
  def update_data(pid, data) do
    GenServer.call(pid, {:update_data, data})
  end

  def start_link({provider, source}) do
    case populate_state(provider, source) do
      {:ok, state} -> GenServer.start_link(__MODULE__, state)
      {:error, error} -> {:error, error}
    end
  end

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:update_data, data}, _from, state) do
    {extracted_data, new_state} =
      with {:ok, image_spec} <- eval_template(state.image, %{"prev" => data}),
           {:ok, image} <- DockerRegistry.parse_image(image_spec, state.default_registry),
           {:ok, raw_manifest} <- manifest_request(image, state),
           {:ok, response} <- blob_request(image, raw_manifest, state),
           {:ok, parsed_data} <- response_to_data(response),
           extracted_data = extract_data(parsed_data, data, state) do
        {extracted_data, %State{state | last_success: extracted_data}}
      else
        {:error, error} ->
          Logger.warn("Provider #{state.id} could not fetch data: #{inspect(error)}")
          {state.last_success, state}
      end

    merged_data = Map.merge(data, extracted_data)

    {:reply, {:ok, merged_data, next_interval(state.interval)}, new_state}
  end

  @impl true
  def handle_info(_, state) do
    # TODO: remove when Mojito stops leaking messages
    {:noreply, state}
  end

  defp manifest_request(image, state) do
    uri = DockerRegistry.manifest_url(image)

    headers = [{"accept", "application/vnd.docker.distribution.manifest.v2+json"} | HTTPConfig.headers(state.http_config)]

    MachineGun.get(uri, headers, %{
      pool_group: state.pool
    })
  end

  defp blob_request(image, raw_response, state) do
    with {:ok, manifest_response} <- response_to_data(raw_response),
         {:ok, digest} <- DockerRegistry.extract_config_digest(manifest_response),
         uri = DockerRegistry.blob_url(image, digest) do
      MachineGun.get(uri, HTTPConfig.headers(state.http_config), %{
        pool_group: state.pool
      })
    else
      {:error, error} -> {:error, error}
    end
  end

  defp next_interval({min, max}) do
    min + :rand.uniform(max(max - min, 1))
  end

  defp next_interval(const), do: const

  defp extract_data(fetched, original, %State{extractor: config}) do
    fetched
    |> Extractor.extract(config, %{"prev" => original})
  end

  defp eval_template(tpl, data) do
    {:ok, Solid.render(tpl, data) |> to_string}
  end

  defp response_to_data(%MachineGun.Response{body: body, status_code: code})
       when code in [200, 201, 202, 203] do
    # TODO: this shouldn't assume json
    body |> Jason.decode()
  end

  defp response_to_data(_) do
    {:error, "Unable to parse body"}
  end

  defp populate_state(%ProviderConfig{id: id, config: config}, source) do
    initial_state = %State{id: id}

    with {:ok, state} <- populate_image(initial_state, config, source),
         {:ok, state} <- populate_http_config(state, config, source),
         {:ok, state} <- populate_misc(state, config, source),
         {:ok, state} <- populate_extractors(state, config, source) do
      {:ok, state}
    else
      {:error, error} -> {:error, error}
    end
  end

  defp populate_image(state, %{"image" => tpl}, _source) when is_binary(tpl) and tpl != "" do
    case Solid.parse(tpl) do
      {:ok, parsed} -> {:ok, %State{state | image: parsed}}
      {:error, error} -> {:error, error}
    end
  end

  defp populate_image(_state, _config, _source) do
    {:error, "Image is required"}
  end

  defp populate_http_config(state, _config, %Source{id: id, type: "http", config: config})
       when is_map(config) do
    {:ok, %State{state | pool: "src_" <> id, http_config: HTTPConfig.create_config(config)}}
  end

  defp populate_http_config(state, _, _), do: {:ok, state}

  defp populate_misc(state, config, _source) do
    {
      :ok,
      %State{state | interval: parse_interval(config), default_registry: parse_default_registry(config)}
    }
  end

  defp parse_default_registry(%{"default_registry" => registry}) when is_binary(registry) and registry != "", do: registry
  defp parse_default_registry(_), do: "registry-1.docker.io"

  defp parse_interval(%{"interval_min" => min, "interval_max" => max}) when is_number(min) and is_number(max), do: {min, max}
  defp parse_interval(%{"interval" => interval}) when is_number(interval), do: interval
  defp parse_interval(_), do: 60 * 1000

  defp populate_extractors(state, %{"extractors" => extractors}, _source) when is_map(extractors) do
    {:ok, %State{state | extractor: Extractor.create_config(extractors)}}
  end

  defp populate_extractors(%State{id: id} = state, _config, _source) do
    populate_extractors(state, %{"extractors" => %{"jsonpath" => %{id => "$"}}}, %{})
  end
end
