defmodule Backendelixir.Transit.BusLocationLog do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :bus_id,
             :route_id,
             :route_code,
             :latitude,
             :longitude,
             :speed,
             :recorded_at,
             :inserted_at
           ]}
  schema "bus_location_logs" do
    field :bus_id, :string
    field :route_code, :string
    field :latitude, :float
    field :longitude, :float
    field :speed, :float, default: 0.0
    field :recorded_at, :utc_datetime

    belongs_to :route, Backendelixir.Transit.Route

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:bus_id, :route_id, :route_code, :latitude, :longitude, :speed, :recorded_at])
    |> validate_required([:bus_id, :latitude, :longitude, :recorded_at])
    |> foreign_key_constraint(:route_id)
  end
end
