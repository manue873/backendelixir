defmodule BackendelixirWeb.Schema.TransitTypes do
  use Absinthe.Schema.Notation

  enum :route_status do
    value(:activa, as: "ACTIVA", description: "Ruta operando con normalidad")
    value(:demorada, as: "DEMORADA", description: "Ruta con retrasos o congestión")
    value(:mantenimiento, as: "MANTENIMIENTO", description: "Ruta en mantenimiento operativo")
    value(:cancelada, as: "CANCELADA", description: "Ruta suspendida o cancelada")
  end

  enum :alert_severity do
    value(:info, as: "INFO", description: "Alerta informativa")
    value(:warning, as: "WARNING", description: "Alerta de advertencia o congestión moderada")
    value(:critical, as: "CRITICAL", description: "Alerta crítica o corte de vía")
  end

  object :stop do
    field :id, non_null(:id)
    field :name, non_null(:string)
    field :sequence, non_null(:integer)
    field :latitude, :float
    field :longitude, :float
    field :inserted_at, non_null(:string)
  end

  object :route_alert do
    field :id, non_null(:id)
    field :message, non_null(:string)
    field :severity, non_null(:alert_severity)
    field :inserted_at, non_null(:string)
    field :route, :route
  end

  object :route do
    field :id, non_null(:id)
    field :code, non_null(:string)
    field :name, non_null(:string)
    field :origin, non_null(:string)
    field :destination, non_null(:string)
    field :status, non_null(:route_status)
    field :stops, list_of(:stop)
    field :alerts, list_of(:route_alert)
    field :inserted_at, non_null(:string)
    field :updated_at, non_null(:string)
  end

  object :bus_telemetry do
    field :bus_id, non_null(:string)
    field :route_id, :id
    field :route_code, :string
    field :route_name, :string
    field :latitude, non_null(:float)
    field :longitude, non_null(:float)
    field :speed, :float
    field :timestamp, :string
  end

  input_object :create_route_input do
    field :code, non_null(:string)
    field :name, non_null(:string)
    field :origin, non_null(:string)
    field :destination, non_null(:string)
    field :status, :route_status
  end

  input_object :create_stop_input do
    field :route_id, non_null(:id)
    field :name, non_null(:string)
    field :sequence, non_null(:integer)
    field :latitude, :float
    field :longitude, :float
  end

  input_object :create_alert_input do
    field :route_id, :id
    field :route_code, :string, description: "Código de la ruta (e.g., 'RT-PIU-01')"
    field :route_name, :string, description: "Nombre de la ruta"
    field :message, non_null(:string)
    field :severity, :alert_severity
  end
end
