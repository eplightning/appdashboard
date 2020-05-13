defmodule AppDashboard.Config.Subset do

  defmodule Ui do
    @derive Jason.Encoder
    defstruct environments: %{}, applications: %{}

    def create(%AppDashboard.Config{environments: environments, applications: applications}) do
      %AppDashboard.Config.Subset.Ui{environments: environments, applications: applications}
    end
  end

  defmodule Instance do
    defstruct config: %AppDashboard.Config.Instance{}, sources: %{}

    def create(%AppDashboard.Config{instances: instances, sources: sources}, id) do
      case Map.fetch(instances, id) do
        {:ok, instance} -> {:ok, %AppDashboard.Config.Subset.Instance{config: instance, sources: sources_for_instance(sources, instance)}}
        _ -> :error

      end
    end

    defp sources_for_instance(sources, %AppDashboard.Config.Instance{providers: providers}) do
      used_sources =
        providers
        |> Enum.map(fn {_k, provider} -> provider.source end)
        |> Enum.reject(fn source -> is_nil(source) or source == "" end)

      sources
      |> Enum.filter(fn {k, _} -> k in used_sources end)
      |> Enum.into(%{})
    end
  end

  defmodule Discovery do
    defstruct discovery: %AppDashboard.Config.Discovery{}, source: nil

    def create(%AppDashboard.Config{discovery: discovery_list, sources: sources}, id) do
      case Map.fetch(discovery_list, id) do
        {:ok, discovery} -> {:ok, %AppDashboard.Config.Subset.Discovery{discovery: discovery, source: source_for_discovery(sources, discovery)}}
        _ -> :error
      end
    end

    defp source_for_discovery(sources, %AppDashboard.Config.Discovery{source: source}) when is_binary(source) and source != "" do
      Map.get(sources, source, nil)
    end
    defp source_for_discovery(_sources, _discovery), do: nil
  end

end
