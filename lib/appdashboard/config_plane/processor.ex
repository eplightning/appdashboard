defmodule AppDashboard.ConfigPlane.Processor do

  use GenServer

  require Logger
  alias AppDashboard.Config
  alias AppDashboard.ConfigPlane.File.Parser
  alias AppDashboard.ConfigPlane.Snapshot

  defmodule State do
    defstruct snapshot: AppDashboard.ConfigPlane.Snapshot,
              discoveries: %{},
              discovered: %{},
              templates: %{}
  end

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    snapshot = Keyword.get(opts, :snapshot, AppDashboard.ConfigPlane.Snapshot)

    GenServer.start_link(__MODULE__, %State{snapshot: snapshot}, name: name)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_info({:config, %Config{templates: templates, instances: instances} = config}, %{snapshot: snapshot} = state) do
    new_state = %State{state | templates: compile_templates(templates)}

    # TODO: update discoveries
    # TODO: merge instances with discovered instances

    processed_instances =
      instances
      |> Enum.map(fn {id, instance} -> {id, process_instance(instance, config, new_state)} end)
      |> Enum.into(%{})

    processed_config = %Config{config | instances: processed_instances}

    Snapshot.update(processed_config, name: snapshot)

    {:noreply, new_state}
  end

  defp compile_templates(templates) do
    Enum.reduce(templates, %{}, fn {id, %Config.Template{template: template}}, acc ->
      case Solid.parse(template) do
        {:ok, parsed} -> Map.put(acc, id, parsed)
        {:error, error} ->
          Logger.error("Error while parsing template #{inspect(error)}")
          acc
      end
    end)
  end

  defp process_instance(%Config.Instance{template: template} = instance, _config, _state) when template == "", do: instance
  defp process_instance(%Config.Instance{template: template} = instance, config, %State{templates: templates}) do
    case Map.fetch(templates, template) do
      {:ok, parsed_template} ->
        apply_template(instance, parsed_template, instance_context(instance, config))
      _ ->
        Logger.error("Template '#{template}' could not be found")
        instance
    end
  end

  defp apply_template(instance, template, context) do
    rendered = render_instance(template, context)

    # TODO: Really need to rethink that, need some changes in Parser module to make this look sane
    Map.merge(instance, rendered, fn _k, inst_val, tpl_val ->
      case tpl_val do
        %{} = map when map_size(map) == 0 -> inst_val
        [] -> inst_val
        "" -> inst_val
        nil -> inst_val
        _ -> tpl_val
      end
    end)
  end

  defp render_instance(template, context) do
    toml = Solid.render(template, context) |> to_string

    case Toml.decode(toml) do
      {:ok, decoded} -> Parser.parse_instance(decoded)
      {:error, error} ->
        Logger.error("Error while parsing template config #{inspect(error)}")
        %AppDashboard.Config.Instance{}
    end
  end

  defp instance_context(instance, %Config{applications: apps, environments: envs}) do
    app_vars =
      case Map.fetch(apps, instance.application) do
        {:ok, application} -> application.variables
        _ -> %{}
      end

    env_vars =
      case Map.fetch(envs, instance.environment) do
        {:ok, environment} -> environment.variables
        _ -> %{}
      end

    instance_vars = instance.variables

    app_vars
    |> Map.merge(env_vars)
    |> Map.merge(instance_vars)
  end

end
