defmodule AppDashboard.Schema.Snapshot do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  alias AppDashboard.Schema.InstanceData

  schema "snapshots" do
    field :name, :string
    field :ui_config, :map
    embeds_many :data, InstanceData

    timestamps(type: :utc_datetime)
  end

  def all() do
    from snap in AppDashboard.Schema.Snapshot,
      order_by: [desc: snap.inserted_at]
  end

  def filtered(name) do
    from snap in AppDashboard.Schema.Snapshot,
      where: like(snap.name, ^("%#{name}%")),
      order_by: [desc: snap.inserted_at]
  end

  def insert(snapshot) do
    case AppDashboard.Repo.insert(snapshot) do
      {:ok, snapshot} ->
        Phoenix.PubSub.broadcast(AppDashboard.PubSub, "snapshots", :snapshot_added)
        {:ok, snapshot}

      {:error, err} ->
        {:error, err}
    end
  end

  def limited(query, limit \\ 100, offset \\ 0) do
    from snap in query,
      offset: ^offset,
      limit: ^limit
  end

  @doc false
  def changeset(snapshot, attrs \\ %{}) do
    snapshot
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end

  def with_current_data(snapshot) do
    data =
      AppDashboard.DataPlane.Snapshot.get()
      |> InstanceData.from_config_plane

    ui_config =
      AppDashboard.ConfigPlane.Snapshot.get_ui_config()

    snapshot
    |> change(data: data, ui_config: ui_config)
  end

end
