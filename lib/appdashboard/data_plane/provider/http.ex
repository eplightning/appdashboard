defmodule AppDashboard.DataPlane.Provider.HTTP do
  use GenServer

  require Logger
  alias AppDashboard.DataPlane.Provider
  alias AppDashboard.Config.Source
  alias AppDashboard.Config.Instance.Provider, as: ProviderConfig
  alias AppDashboard.Utils.HTTPConfig
  alias AppDashboard.Utils.Extractor

  defmodule State do
    defstruct id: "",
              http_config: %HTTPConfig{},
              uri: nil,
              extractor: %Extractor{},
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
    fetched_data =
      with {:ok, uri} <- eval_template(state.uri, %{"prev" => data}),
           {:ok, response} <-
             Mojito.request(:get, uri, HTTPConfig.headers(state.http_config), "",
               transport_opts: HTTPConfig.transport_opts(state.http_config)
             ),
           {:ok, parsed_data} <- response_to_data(response) do
        parsed_data
      else
        {:error, error} ->
          Logger.warn("Provider #{state.id} could not fetch data: #{inspect(error)}")
          %{}
      end

    extracted_data = extract_data(fetched_data, data, state)

    {:reply, {:ok, extracted_data, state.interval}, state}
  end

  defp extract_data(fetched, original, %State{extractor: config}) do
    fetched
    |> Extractor.extract(config, %{"prev" => original})
  end

  defp eval_template(tpl, data) do
    {:ok, Solid.render(tpl, data) |> to_string}
  end

  defp response_to_data(%Mojito.Response{body: body, status_code: code})
       when code in [200, 201, 202, 203] do
    # TODO: this shouldn't assume json
    body |> Jason.decode()
  end

  defp response_to_data(_) do
    {:error, "Unable to parse body"}
  end

  defp populate_state(%ProviderConfig{id: id, config: config}, source) do
    initial_state = %State{id: id}

    with {:ok, state} <- populate_uri(initial_state, config, source),
         {:ok, state} <- populate_http_config(state, config, source),
         {:ok, state} <- populate_misc(state, config, source),
         {:ok, state} <- populate_extractors(state, config, source) do
      {:ok, state}
    else
      {:error, error} -> {:error, error}
    end
  end

  defp populate_uri(state, %{"uri" => tpl}, _source) when is_binary(tpl) and tpl != "" do
    case Solid.parse(tpl) do
      {:ok, parsed} -> {:ok, %State{state | uri: parsed}}
      {:error, error} -> {:error, error}
    end
  end

  defp populate_uri(_state, _config, _source) do
    {:error, "URI is required"}
  end

  defp populate_http_config(state, _config, %Source{type: "http", config: config})
       when is_map(config) do
    {:ok, %State{state | http_config: HTTPConfig.create_config(config)}}
  end

  defp populate_http_config(state, _, _), do: {:ok, state}

  defp populate_misc(state, config, _source) do
    {
      :ok,
      %State{state | interval: parse_interval(config)}
    }
  end

  defp parse_interval(%{"interval" => interval}) when is_number(interval), do: interval
  defp parse_interval(_), do: 60 * 1000

  defp populate_extractors(state, %{"extractors" => extractors}, _source) when is_map(extractors) do
    {:ok, %State{state | extractor: Extractor.create_config(extractors)}}
  end

  defp populate_extractors(%State{id: id} = state, _config, _source) do
    populate_extractors(state, %{"extractors" => %{"jsonpath" => %{id => "$"}}}, %{})
  end
end