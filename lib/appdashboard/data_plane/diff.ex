defmodule AppDashboard.DataPlane.Diff do
  require Logger

  def calculate_data_diff(%{} = old, %{} = new) do
    snapshot = if !Map.equal?(old, new), do: [:data_snapshot_changed], else: []

    old_keys = MapSet.new(Map.keys(old))
    new_keys = MapSet.new(Map.keys(new))

    removed =
      MapSet.difference(old_keys, new_keys)
      |> MapSet.to_list()
      |> Enum.map(fn id -> {:data_removed, id} end)

    added =
      MapSet.difference(new_keys, old_keys)
      |> MapSet.to_list()
      |> Enum.map(fn id ->
        {:data_added, id}
      end)

    changed =
      MapSet.intersection(old_keys, new_keys)
      |> MapSet.to_list()
      |> Enum.filter(fn id ->
        old_instance = Map.fetch!(old, id)
        new_instance = Map.fetch!(new, id)

        data_changed?(old_instance, new_instance)
      end)
      |> Enum.map(fn id ->
        {:data_changed, id}
      end)

    snapshot ++ removed ++ added ++ changed
  end

  defp data_changed?(old, new), do: !Map.equal?(old, new)
end
