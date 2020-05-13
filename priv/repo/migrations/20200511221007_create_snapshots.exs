defmodule AppDashboard.Repo.Migrations.CreateSnapshots do
  use Ecto.Migration

  def change do
    create table(:snapshots) do
      add :name, :string
      add :ui_config, :map
      add :data, :map

      timestamps(type: :utc_datetime)
    end

  end
end
