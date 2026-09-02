defmodule Backendelixir.Transit.RouteAlert do
  use Ecto.Schema
  import Ecto.Changeset

  @severities ["INFO", "WARNING", "CRITICAL"]

  @derive {Jason.Encoder, only: [:id, :message, :severity, :route_id, :inserted_at, :updated_at]}
  schema "route_alerts" do
    field :message, :string
    field :severity, :string, default: "INFO"

    belongs_to :route, Backendelixir.Transit.Route

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(alert, attrs) do
    alert
    |> cast(attrs, [:message, :severity, :route_id])
    |> validate_required([:message, :severity, :route_id])
    |> validate_inclusion(:severity, @severities, message: "debe ser INFO, WARNING o CRITICAL")
    |> foreign_key_constraint(:route_id)
  end

  def valid_severities, do: @severities
end
