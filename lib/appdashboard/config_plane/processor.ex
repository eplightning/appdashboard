defmodule AppDashboard.ConfigPlane.Processor do
  use GenServer

  require Logger
  alias AppDashboard.Config
  alias AppDashboard.ConfigPlane.File.Parser
  alias AppDashboard.ConfigPlane.Snapshot
  alias AppDashboard.ConfigPlane.Processor.Discovery

  defmodule State do
    defstruct snapshot: AppDashboard.ConfigPlane.Snapshot,
              raw_config: %Config{},
              discovery: %Discovery.State{},
              templates: %{}
  end

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    snapshot = Keyword.get(opts, :snapshot, AppDashboard.ConfigPlane.Snapshot)

    GenServer.start_link(__MODULE__, %State{snapshot: snapshot}, name: name)
  end

  @impl true
  def init(state) do
    {:ok, _, discovery} = Discovery.start_link()

    {:ok, %State{state | discovery: discovery}}
  end

  @impl true
  def handle_info(
        {:config, %Config{templates: templates} = config},
        %{discovery: discovery} = state
      ) do
    new_state = %State{
      state
      | templates: compile_templates(templates),
        raw_config: config,
        discovery: Discovery.update_config(config, discovery)
    }

    process(new_state)
  end

  @impl true
  def handle_info({:discovery, {_id, _instances} = msg}, %{discovery: discovery} = state) do
    new_state = %State{state | discovery: Discovery.handle_discovery(msg, discovery)}

    process(new_state)
  end

  defp process(
         %State{
           raw_config: %Config{instances: instances} = config,
           templates: templates,
           discovery: discovery,
           snapshot: snapshot
         } = state
       ) do
    processed_instances =
      Discovery.get_instances(discovery)
      |> Enum.concat(instances)
      |> Enum.map(fn {id, instance} -> {id, process_instance(instance, config, templates)} end)
      |> Enum.into(%{})

    processed_config =
      %Config{config | instances: processed_instances}
      |> add_missing_apps_and_envs()

    Snapshot.update(processed_config, name: snapshot)

    {:noreply, state}
  end

  defp add_missing_apps_and_envs(%Config{instances: instances} = config) do
    instances
    |> Enum.reduce(config, fn {{env, app}, _v}, acc ->
      %Config{
        acc
        | applications:
            if(!Map.has_key?(acc.applications, app),
              do: Map.put(acc.applications, app, skeleton_app(app)),
              else: acc.applications
            ),
          environments:
            if(!Map.has_key?(acc.environments, env),
              do: Map.put(acc.environments, env, skeleton_env(env)),
              else: acc.environments
            )
      }
    end)
  end

  defp skeleton_app(id), do: %Config.Application{id: id, name: id}
  defp skeleton_env(id), do: %Config.Environment{id: id, name: id, order: 99999}

  defp compile_templates(templates) do
    Enum.reduce(templates, %{}, fn {id, %Config.Template{template: template}}, acc ->
      case Solid.parse(template) do
        {:ok, parsed} ->
          Map.put(acc, id, parsed)

        {:error, error} ->
          Logger.error("Error while parsing template #{inspect(error)}")
          acc
      end
    end)
  end

  defp process_instance(%Config.Instance{template: template} = instance, _config, _state)
       when template == "",
       do: instance

  defp process_instance(%Config.Instance{template: template} = instance, config, templates) do
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
      {:ok, decoded} ->
        Parser.parse_instance(decoded)

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
