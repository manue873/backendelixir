defmodule BackendelixirWeb.Schema do
  use Absinthe.Schema
  import_types(BackendelixirWeb.Schema.TransitTypes)
  import_types(BackendelixirWeb.Schema.AccountTypes)
  import_types(BackendelixirWeb.Schema.AuditTypes)

  alias BackendelixirWeb.Resolvers.TransitResolver
  alias BackendelixirWeb.Resolvers.AccountResolver
  alias BackendelixirWeb.Resolvers.AuditResolver

  query do
    @desc "Obtiene el perfil del usuario autenticado actual a partir de su Bearer Token"
    field :me, :user do
      resolve(&AccountResolver.me/3)
    end

    @desc "Obtiene el listado general de todas las rutas de tránsito"
    field :routes, list_of(:route) do
      resolve(&TransitResolver.list_routes/3)
    end

    @desc "Busca una ruta específica por su identificador único numérico"
    field :route, :route do
      arg(:id, non_null(:id))
      resolve(&TransitResolver.get_route/3)
    end

    @desc "Busca una ruta por su código alfanumérico único (e.g., 'RT-PIU-01')"
    field :route_by_code, :route do
      arg(:code, non_null(:string))
      resolve(&TransitResolver.get_route_by_code/3)
    end

    @desc "Busca rutas por coincidencia parcial en nombre, código, origen o destino (e.g., 'Catacaos', 'Castilla', 'RT-PIU')"
    field :search_routes, list_of(:route) do
      arg(:query, non_null(:string))
      resolve(&TransitResolver.search_routes/3)
    end

    @desc "Busca una ruta por su nombre exacto (e.g., 'Línea 01: Castilla - Plaza de Armas - UDEP')"
    field :route_by_name, :route do
      arg(:name, non_null(:string))
      resolve(&TransitResolver.get_route_by_name/3)
    end

    @desc "Lista las alertas activas del sistema, con filtro opcional por ruta"
    field :alerts, list_of(:route_alert) do
      arg(:route_id, :id)
      arg(:route_code, :string)
      resolve(&TransitResolver.list_alerts/3)
    end

    @desc "Obtiene la lista de buses activos transmitiendo en vivo en Piura desde el caché en memoria Valkey"
    field :active_buses, list_of(:bus_telemetry) do
      arg(:route_id, :id)
      resolve(&TransitResolver.list_active_buses/3)
    end

    @desc "Obtiene la última posición conocida de un bus específico desde el caché Valkey"
    field :bus_location, :bus_telemetry do
      arg(:bus_id, non_null(:string))
      resolve(&TransitResolver.get_bus_location/3)
    end

    @desc "Consulta el historial de auditoría inmutable del sistema (eventos, logins, alertas)"
    field :audit_logs, list_of(:audit_log) do
      arg(:event_type, :string)
      arg(:resource_type, :string)
      arg(:limit, :integer)
      resolve(&AuditResolver.list_audit_logs/3)
    end

    @desc "Consulta el historial de telemetría GPS persistido por lotes para trazabilidad de un bus o ruta"
    field :historical_bus_locations, list_of(:bus_location_log) do
      arg(:bus_id, :string)
      arg(:route_id, :id)
      arg(:limit, :integer)
      resolve(&AuditResolver.list_bus_location_logs/3)
    end
  end

  mutation do
    @desc "Registra un nuevo usuario en la plataforma y retorna su token de sesión"
    field :register, :session_payload do
      arg(:input, non_null(:register_input))
      resolve(&AccountResolver.register/3)
    end

    @desc "Inicia sesión con correo y contraseña, retornando el usuario y su token de autenticación"
    field :login, :session_payload do
      arg(:input, non_null(:login_input))
      resolve(&AccountResolver.login/3)
    end

    @desc "Crea una nueva ruta en el catálogo de transporte (Requiere rol ADMIN)"
    field :create_route, :route do
      arg(:input, non_null(:create_route_input))
      resolve(&TransitResolver.create_route/3)
    end

    @desc "Actualiza el estado operativo de una ruta (Requiere rol CONDUCTOR o ADMIN)"
    field :update_route_status, :route do
      arg(:id, non_null(:id))
      arg(:status, non_null(:route_status))
      resolve(&TransitResolver.update_route_status/3)
    end

    @desc "Registra un paradero en una ruta existente en Piura (Requiere rol ADMIN)"
    field :create_stop, :stop do
      arg(:input, non_null(:create_stop_input))
      resolve(&TransitResolver.create_stop/3)
    end

    @desc "Emite y persiste una alerta operativa para una ruta (Requiere rol CONDUCTOR o ADMIN)"
    field :create_alert, :route_alert do
      arg(:input, non_null(:create_alert_input))
      resolve(&TransitResolver.create_alert/3)
    end
  end
end
