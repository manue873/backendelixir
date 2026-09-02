defmodule Backendelixir.Transit.Route do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ["ACTIVA", "DEMORADA", "MANTENIMIENTO", "CANCELADA", "DESVIO"]

  @derive {Jason.Encoder,
           only: [:id, :code, :name, :origin, :destination, :status, :inserted_at, :updated_at]}
  schema "routes" do
    field :code, :string
    field :name, :string
    field :origin, :string
    field :destination, :string
    field :status, :string, default: "ACTIVA"

    has_many :stops, Backendelixir.Transit.Stop, on_delete: :delete_all
    has_many :alerts, Backendelixir.Transit.RouteAlert, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(route, attrs) do
    route
    |> cast(attrs, [:code, :name, :origin, :destination, :status])
    |> validate_required([:code, :name, :origin, :destination, :status])
    |> validate_inclusion(:status, @statuses,
      message: "debe ser ACTIVA, DEMORADA, MANTENIMIENTO o CANCELADA"
    )
    |> validate_format(:code, ~r/^[A-Za-z0-9\-_]{2,20}$/,
      message: "debe contener entre 2 y 20 caracteres alfanuméricos"
    )
    |> unique_constraint(:code)
    |> unique_constraint(:name)
  end

  @doc false
  def status_changeset(route, attrs) do
    route
    |> cast(attrs, [:status])
    |> validate_required([:status])
    |> validate_inclusion(:status, @statuses,
      message: "debe ser ACTIVA, DEMORADA, MANTENIMIENTO o CANCELADA"
    )
  end

  def valid_statuses, do: @statuses
end
