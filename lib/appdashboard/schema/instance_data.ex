defmodule AppDashboard.Schema.InstanceData do

  use Ecto.Schema

  embedded_schema do
    field :environment, :string
    field :application, :string
    field :data, :map
  end

  def from_config_plane(config) do
    config
    |> Enum.map(fn {{env, app}, instance} ->
      %AppDashboard.Schema.InstanceData{environment: env, application: app, data: instance}
    end)
  end

end
