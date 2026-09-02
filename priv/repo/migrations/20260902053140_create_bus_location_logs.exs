defmodule Backendelixir.Repo.Migrations.CreateBusLocationLogs do
  use Ecto.Migration

  def change do
    create table(:bus_location_logs) do
      add :bus_id, :string, null: false
      add :route_id, references(:routes, on_delete: :nilify_all)
      add :route_code, :string
      add :latitude, :float, null: false
      add :longitude, :float, null: false
      add :speed, :float, default: 0.0
      add :recorded_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:bus_location_logs, [:bus_id])
    create index(:bus_location_logs, [:route_id])
    create index(:bus_location_logs, [:recorded_at])
    create index(:bus_location_logs, [:bus_id, :recorded_at])
  end
end
