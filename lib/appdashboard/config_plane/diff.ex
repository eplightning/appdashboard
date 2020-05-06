defmodule AppDashboard.ConfigPlane.Diff do

  alias AppDashboard.Config

  require Logger

  def calculate_config_diff(%Config{instances: old_inst, sources: old_src} = old, %Config{instances: new_inst, sources: new_src} = new) do
    config_diff(old, new) ++ instances_diff(old_inst, old_src, new_inst, new_src)
  end

  def calculate_discovery_diff(old, new) do
    old_keys = MapSet.new(Map.keys(old))
    new_keys = MapSet.new(Map.keys(new))

    removed = MapSet.difference(old_keys, new_keys)
    |> MapSet.to_list
    |> Enum.map(fn id -> {:discovery_removed, id} end)

    added = MapSet.difference(new_keys, old_keys)
    |> MapSet.to_list
    |> Enum.map(fn id ->
      {:discovery_added, id}
    end)

    changed = MapSet.intersection(old_keys, new_keys)
    |> MapSet.to_list
    |> Enum.filter(fn id ->
      %Config.Subset.Discovery{discovery: old_disc, source: old_src} = Map.fetch!(old, id)
      %Config.Subset.Discovery{discovery: new_disc, source: new_src} = Map.fetch!(new, id)

      source_changed?(old_src, new_src) or discovery_changed?(old_disc, new_disc)
    end)
    |> Enum.map(fn id ->
      {:discovery_changed, id}
    end)

    removed ++ added ++ changed
  end

  defp config_diff(old, new) do
    if !Map.equal?(old, new), do: [:config_changed], else: []
  end

  defp instances_diff(old_instances, old_sources, new_instances, new_sources) do
    old_keys = MapSet.new(Map.keys(old_instances))
    new_keys = MapSet.new(Map.keys(new_instances))
    sources_changed = !Map.equal?(old_sources, new_sources)

    removed = MapSet.difference(old_keys, new_keys)
      |> MapSet.to_list
      |> Enum.map(fn id -> {:instance_removed, id} end)

    added = MapSet.difference(new_keys, old_keys)
      |> MapSet.to_list
      |> Enum.map(fn id ->
        {:instance_added, id}
      end)

    changed = MapSet.intersection(old_keys, new_keys)
      |> MapSet.to_list
      |> Enum.filter(fn id ->
        old_instance = Map.fetch!(old_instances, id)
        new_instance = Map.fetch!(new_instances, id)

        sources_changed or instance_changed?(old_instance, new_instance)
      end)
      |> Enum.map(fn id ->
        {:instance_changed, id}
      end)

    removed ++ added ++ changed
  end

  defp instance_changed?(old, new), do: !Map.equal?(old, new)

  defp discovery_changed?(old, new), do: !Map.equal?(old, new)

  defp source_changed?(old, new) when is_map(old) and is_map(new), do: !Map.equal?(old, new)
  defp source_changed?(nil, nil), do: false
  defp source_changed?(_, _), do: true

end
