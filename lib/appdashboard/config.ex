defmodule AppDashboard.Config do

  defstruct environments: %{}, applications: %{}, templates: %{}, sources: %{}, autodiscovery: %{}, instances: %{}

  defmodule Environment do
    defstruct id: "", name: "", variables: %{}
  end

  defmodule Application do
    defstruct id: "", name: "", variables: %{}
  end

  defmodule Template do
    defstruct id: "", template: ""
  end

  defmodule Autodiscovery do
    defstruct id: "", name: "", type: "", source: "", config: %{}
  end

  defmodule Source do
    defstruct id: "", name: "", type: "", config: %{}
  end

  defmodule Instance do
    defstruct environment: "", application: "", template: "", variables: %{}, data: %{}, extractors: %{}, providers: %{}

    defmodule Provider do
      defstruct id: "", name: "", type: "", source: "", config: %{}
    end
  end

  defmodule Subset.Ui do
    defstruct environments: %{}, applications: %{}

    def create(%AppDashboard.Config{environments: environments, applications: applications}) do
      %AppDashboard.Config.Subset.Ui{environments: environments, applications: applications}
    end
  end

  defmodule Subset.Instance do
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

end
