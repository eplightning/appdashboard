defmodule AppDashboard.Utils.Extractor do
  require Logger

  alias AppDashboard.Utils.Extractor
  alias AppDashboard.Utils.JSONPath

  defstruct jsonpath: %{}, template: %{}

  def create_config(config) do
    %Extractor{
      jsonpath: create_jsonpath_extractors(config),
      template: create_template_extractors(config)
    }
  end

  def extract(data, config, context) do
    %{}
    |> extract_jsonpath(data, config)
    |> extract_template(data, config, context)
  end

  defp extract_jsonpath(result, data, %Extractor{jsonpath: config}) do
    config
    |> Enum.reduce(result, fn {key, jsonpath}, acc ->
      case JSONPath.query(data, jsonpath) do
        {:ok, value} -> Map.put(acc, key, value)
        {:error, error} ->
          Logger.info("Error while extracting using JSONPath #{key}: #{inspect(error)}")
          acc
      end
    end)
  end

  defp extract_template(result, data, %Extractor{template: config}, extra_context) do
    context = Map.put(extra_context, "data", data)

    config
    |> Enum.reduce(result, fn {key, tpl}, acc ->
      Map.put(acc, key, to_string(Solid.render(tpl, Map.put(context, "extracted", acc))))
    end)
  end

  defp create_template_extractors(%{"template" => extractors}) when is_map(extractors) do
    extractors
    |> Enum.map(fn {key, template} -> {key, Solid.parse(template)} end)
    |> Enum.reject(fn
      {_key, {:ok, _parsed}} -> false
      {key, {:error, error}} ->
        Logger.warn("Could not parse #{key} template: #{inspect(error)}")
        true
    end)
    |> Enum.map(fn {key, {:ok, parsed}} -> {key, parsed} end)
    |> Enum.into(%{})
  end

  defp create_template_extractors(_config), do: %{}

  defp create_jsonpath_extractors(%{"jsonpath" => extractors}) when is_map(extractors) do
    extractors
    |> Enum.map(fn {key, jsonpath} -> {key, JSONPath.compile(jsonpath)} end)
    |> Enum.reject(fn
      {_key, {:ok, _parsed}} -> false
      {key, {:error, error}} ->
        Logger.warn("Could not parse #{key} JSONPath: #{inspect(error)}")
        true
    end)
    |> Enum.map(fn {key, {:ok, parsed}} -> {key, parsed} end)
    |> Enum.into(%{})
  end

  defp create_jsonpath_extractors(_config), do: %{}

end
