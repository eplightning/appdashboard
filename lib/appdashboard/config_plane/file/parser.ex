defmodule AppDashboard.ConfigPlane.File.Parser do

  alias AppDashboard.Config

  def parse_config(%{} = input) do
    %Config{}
    |> parse_hashmap(input, "environments", &(parse_env(&1, &2)))
    |> parse_hashmap(input, "applications", &(parse_app(&1, &2)))
    |> parse_hashmap(input, "templates", &(parse_template(&1, &2)))
    |> parse_hashmap(input, "autodiscovery", &(parse_autodiscovery(&1, &2)))
    |> parse_hashmap(input, "sources", &(parse_source(&1, &2)))
    |> parse_list(input, "instances", &(parse_instance(&1)))
  end

  defp parse_hashmap(output, %{} = input, key, func) do
    parsed_map = case Map.get(input, key) do
      value when is_map(value) -> for {k, v} <- value, is_binary(k), k != "", into: %{}, do: {k, func.(k, v)}
      _ -> %{}
    end

    Map.put(output, String.to_atom(key), parsed_map)
  end

  defp parse_list(output, %{} = input, key, func) do
    parsed_list = case Map.get(input, key) do
      value when is_list(value) -> Enum.map(value, func)
      _ -> []
    end

    Map.put(output, String.to_atom(key), parsed_list)
  end

  defp parse_env(id, input), do: %Config.Environment{id: id} |> to_struct(input, ["name", "variables"])
  defp parse_app(id, input), do: %Config.Application{id: id} |> to_struct(input, ["name", "variables"])
  defp parse_template(id, input), do: %Config.Template{id: id} |> to_struct(input, ["template"])
  defp parse_autodiscovery(id, input), do: %Config.Autodiscovery{id: id} |> to_struct(input, ["name", "type", "source", "config"])
  defp parse_source(id, input), do: %Config.Source{id: id} |> to_struct(input, ["name", "type", "config"])
  defp parse_provider(id, input), do: %Config.Instance.Provider{id: id} |> to_struct(input, ["name", "type", "source", "config"])

  defp parse_instance(input) do
    %Config.Instance{}
    |> to_struct(input, ["environment", "application", "template", "variables", "data", "extractors"])
    |> parse_hashmap(input, "providers", &(parse_provider(&1, &2)))
  end

  defp to_struct(output, input, keys) do
    Enum.reduce(keys, output, fn key, acc ->
      case Map.fetch(input, key) do
        {:ok, value} -> Map.put(acc, String.to_atom(key), value)
        _ -> acc
      end
    end)
  end

end
