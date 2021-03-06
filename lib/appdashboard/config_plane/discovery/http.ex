defmodule AppDashboard.ConfigPlane.Discovery.HTTP do
  use GenServer

  require Logger
  alias AppDashboard.ConfigPlane.Processor.Discovery
  alias AppDashboard.Config.Instance
  alias AppDashboard.Config.Source
  alias AppDashboard.Config.Subset.Discovery, as: Subset
  alias AppDashboard.Config.Discovery, as: Config
  alias AppDashboard.Utils.HTTPConfig
  alias AppDashboard.Utils.JSONPath

  defmodule State do
    defstruct id: nil,
              http_config: %HTTPConfig{},
              pool: :default,
              uri: nil,
              interval: 60 * 1000,
              instance: nil,
              environment: nil,
              application: nil,
              template: nil
  end

  def start_link({%Subset{} = config, id}) do
    case populate_state(id, config) do
      {:ok, state} -> GenServer.start_link(__MODULE__, state)
      {:error, error} -> {:error, error}
    end
  end

  @impl true
  def init(state) do
    Process.send_after(self(), :discover, 0)
    {:ok, state}
  end

  @impl true
  def handle_info(:discover, state) do
    objects = fetch_objects(state)
    :ok = discover(objects, state)
    Process.send_after(self(), :discover, state.interval)

    {:noreply, state}
  end

  @impl true
  def handle_info(_, state) do
    {:noreply, state}
  end

  defp fetch_objects(state) do
    with {:ok, request} <- MachineGun.get(state.uri, HTTPConfig.headers(state.http_config), %{pool_group: state.pool}),
         {:ok, data} <- response_to_data(request),
         {:ok, list} <- eval_list(data, state.instance) do
      {:ok, list}
    else
      {:error, error} -> {:error, error}
    end
  end

  defp discover({:ok, objects}, %State{id: id} = state) do
    discoveries =
      objects
      |> Enum.reduce(%{}, fn data, result ->
        with {:ok, environment} <- eval_single(data, state.environment),
             {:ok, application} <- eval_single(data, state.application),
             {:ok, template} <- eval_single(data, state.template) do
          Map.put(result, {environment, application}, %Instance{
            application: application,
            environment: environment,
            template: template,
            variables: %{"discovery" => data}
          })
        else
          {:error, error} ->
            Logger.warn("Could not fetch all required variables: #{inspect(error)}")
            result
        end
      end)

    Discovery.discover(id, discoveries)
    :ok
  end

  defp discover({:error, error}, _state) do
    Logger.warn("Could not fetch list of objects: #{inspect(error)}")
  end

  defp eval_single(_data, path) when is_binary(path), do: {:ok, path}

  defp eval_single(data, path) do
    case JSONPath.query(data, path) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, result} -> {:ok, result}
      {:error, error} -> {:error, error}
    end
  end

  defp eval_list(data, path) do
    case JSONPath.query(data, path) do
      {:ok, result} when is_list(result) -> {:ok, result}
      {:ok, nil} -> {:ok, []}
      {:ok, result} -> {:ok, [result]}
      {:error, error} -> {:error, error}
    end
  end

  defp response_to_data(%MachineGun.Response{body: body, status_code: code})
       when code in [200, 201, 202, 203] do
    # TODO: this shouldn't assume json
    body |> Jason.decode()
  end

  defp response_to_data(_) do
    {:error, "Unable to parse body"}
  end

  defp populate_state(id, %Subset{discovery: %Config{config: config}, source: source}) do
    initial_state = %State{id: id}

    with {:ok, state} <- populate_instance(initial_state, config),
         {:ok, state} <- populate_environment(state, config),
         {:ok, state} <- populate_application(state, config),
         {:ok, state} <- populate_template(state, config),
         {:ok, state} <- populate_http_config(state, config, source),
         {:ok, state} <- populate_misc(state, config) do
      {:ok, state}
    else
      {:error, error} -> {:error, error}
    end
  end

  defp populate_instance(state, %{"instance_path" => instance_path})
       when is_binary(instance_path) and instance_path != "" do
    case JSONPath.compile(instance_path) do
      {:ok, compiled} -> {:ok, %State{state | instance: compiled}}
      {:error, error} -> {:error, error}
    end
  end

  defp populate_instance(_, _), do: {:error, "Instance path is required"}

  defp populate_environment(state, %{"environment" => environment})
       when is_binary(environment) and environment != "" do
    {:ok, %State{state | environment: environment}}
  end

  defp populate_environment(state, %{"environment_path" => environment})
       when is_binary(environment) and environment != "" do
    case JSONPath.compile(environment) do
      {:ok, compiled} -> {:ok, %State{state | environment: compiled}}
      {:error, error} -> {:error, error}
    end
  end

  defp populate_environment(_, _), do: {:error, "Environment or environment path is required"}

  defp populate_template(state, %{"template" => template})
       when is_binary(template) and template != "" do
    {:ok, %State{state | template: template}}
  end

  defp populate_template(state, %{"template_path" => template})
       when is_binary(template) and template != "" do
    case JSONPath.compile(template) do
      {:ok, compiled} -> {:ok, %State{state | template: compiled}}
      {:error, error} -> {:error, error}
    end
  end

  defp populate_template(_, _), do: {:error, "Template or template path is required"}

  defp populate_application(state, %{"application" => application})
       when is_binary(application) and application != "" do
    {:ok, %State{state | application: application}}
  end

  defp populate_application(state, %{"application_path" => application})
       when is_binary(application) and application != "" do
    case JSONPath.compile(application) do
      {:ok, compiled} -> {:ok, %State{state | application: compiled}}
      {:error, error} -> {:error, error}
    end
  end

  defp populate_application(_, _), do: {:error, "Application or application path is required"}

  defp populate_http_config(state, _, %Source{id: id, type: "http", config: config})
       when is_map(config) do
    {:ok, %State{state | pool: "src_" <> id, http_config: HTTPConfig.create_config(config)}}
  end

  defp populate_http_config(state, _, _), do: {:ok, state}

  defp populate_misc(state, %{"uri" => uri} = config) when is_binary(uri) and uri != "" do
    {
      :ok,
      %State{state | uri: uri, interval: parse_interval(config)}
    }
  end

  defp populate_misc(_state, _conf) do
    {:error, "URI is required"}
  end

  defp parse_interval(%{"interval" => interval}) when is_number(interval), do: interval
  defp parse_interval(_), do: 60 * 1000
end
