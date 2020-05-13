defmodule AppDashboardWeb.Dashboard.Builder do

  alias AppDashboard.Config.Subset.Ui
  alias AppDashboard.Schema.InstanceData

  def build(%Ui{applications: apps, environments: envs}, instances) do
    instances
    |> Enum.group_by(fn %InstanceData{application: app} -> app end, fn %InstanceData{environment: env, data: data} -> {env, data} end)
    |> Enum.map(fn {app, instances} ->
      app_data = Map.fetch!(apps, app)

      %{id: app_data.id, name: app_data.name, instances: build_instances(envs, instances)}
    end)
  end

  defp build_instances(envs, instances) do
    instances
    |> Enum.map(fn {env, instance} ->
      env_data = Map.fetch!(envs, env)

      %{name: env_data.name, order: env_data.order, properties: build_properties(instance)}
    end)
    |> Enum.sort(fn i1, i2 -> i1.order <= i2.order end)
  end

  defp build_properties(%{"dashboard_config" => %{"properties" => properties}} = data) when is_list(properties) do
    properties
    |> Enum.map(fn property -> build_property(property, data) end)
    |> Enum.reject(fn
      {:ok, _value} -> false
      {:error, _error} -> true
    end)
    |> Enum.map(fn {:ok, value} -> value end)
  end

  defp build_properties(_data), do: []

  defp build_property(%{"key" => key, "name" => name, "link_key" => link_key}, data) do
    {:ok, {name, Map.get(data, key, ""), Map.get(data, link_key, "")}}
  end

  defp build_property(%{"key" => key, "name" => name}, data) do
    {:ok, {name, Map.get(data, key, ""), ""}}
  end

  defp build_property(_, _data), do: {:error, :invalid_config}

end
