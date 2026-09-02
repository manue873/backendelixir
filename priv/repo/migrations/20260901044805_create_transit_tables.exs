defmodule Backendelixir.Repo.Migrations.CreateTransitTables do
  use Ecto.Migration

  def change do
    create table(:routes) do
      add :code, :string, null: false
      add :name, :string, null: false
      add :origin, :string, null: false
      add :destination, :string, null: false
      add :status, :string, default: "ACTIVA", null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:routes, [:code])
    create index(:routes, [:status])

    create table(:stops) do
      add :route_id, references(:routes, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :sequence, :integer, null: false
      add :latitude, :float
      add :longitude, :float

      timestamps(type: :utc_datetime)
    end

    create index(:stops, [:route_id])
    create index(:stops, [:route_id, :sequence])

    create table(:route_alerts) do
      add :route_id, references(:routes, on_delete: :delete_all), null: false
      add :message, :string, null: false
      add :severity, :string, default: "INFO", null: false

      timestamps(type: :utc_datetime)
    end

    create index(:route_alerts, [:route_id])
  end
end
