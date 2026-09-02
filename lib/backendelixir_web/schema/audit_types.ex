defmodule BackendelixirWeb.Schema.AuditTypes do
  use Absinthe.Schema.Notation

  @desc "Registro inmutable de auditoría del sistema"
  object :audit_log do
    field :id, :id
    field :actor_id, :id
    field :actor_role, :string
    field :actor_email, :string
    field :event_type, :string
    field :resource_type, :string
    field :resource_id, :string

    field :payload, :string do
      resolve(fn log, _, _ ->
        case log.payload do
          %{} = map -> {:ok, Jason.encode!(map)}
          other -> {:ok, to_string(other)}
        end
      end)
    end

    field :ip_address, :string

    field :recorded_at, :string do
      resolve(fn log, _, _ -> {:ok, DateTime.to_iso8601(log.recorded_at)} end)
    end
  end

  @desc "Registro histórico de ubicación de bus por lote"
  object :bus_location_log do
    field :id, :id
    field :bus_id, :string
    field :route_id, :id
    field :route_code, :string
    field :latitude, :float
    field :longitude, :float
    field :speed, :float

    field :recorded_at, :string do
      resolve(fn log, _, _ -> {:ok, DateTime.to_iso8601(log.recorded_at)} end)
    end
  end
end
