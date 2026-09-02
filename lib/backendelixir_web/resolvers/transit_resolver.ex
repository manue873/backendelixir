defmodule BackendelixirWeb.Resolvers.TransitResolver do
  @moduledoc """
  Absinthe GraphQL resolvers for the Transit domain with Role-Based Access Control (RBAC).
  """

  alias Backendelixir.Transit

  def list_routes(_parent, _args, _resolution) do
    {:ok, Transit.list_routes()}
  end

  def get_route(_parent, %{id: id}, _resolution) do
    case Transit.get_route(id) do
      nil -> {:error, "Ruta con id #{id} no encontrada"}
      route -> {:ok, route}
    end
  end

  def get_route_by_code(_parent, %{code: code}, _resolution) do
    case Transit.get_route_by_code(code) do
      nil -> {:error, "Ruta con código #{code} no encontrada"}
      route -> {:ok, route}
    end
  end

  def get_route_by_name(_parent, %{name: name}, _resolution) do
    case Transit.get_route_by_name(name) do
      nil -> {:error, "Ruta con nombre #{name} no encontrada"}
      route -> {:ok, route}
    end
  end

  def search_routes(_parent, %{query: query}, _resolution) do
    {:ok, Transit.search_routes(query)}
  end

  def list_alerts(_parent, args, _resolution) do
    opts =
      cond do
        route_id = args[:route_id] ->
          [route_id: route_id]

        code = args[:route_code] ->
          case Transit.get_route_by_code(code) do
            nil -> [route_id: -1]
            route -> [route_id: route.id]
          end

        true ->
          []
      end

    {:ok, Transit.list_alerts(opts)}
  end

  def list_active_buses(_parent, args, _resolution) do
    route_id = args[:route_id]
    buses = Backendelixir.ValkeyCache.list_active_buses(route_id)
    {:ok, buses}
  end

  def get_bus_location(_parent, %{bus_id: bus_id}, _resolution) do
    case Backendelixir.ValkeyCache.get_bus_location(bus_id) do
      nil -> {:error, "No hay telemetría activa en caché para el bus #{bus_id}"}
      location -> {:ok, location}
    end
  end

  def create_route(_parent, %{input: input}, %{context: %{current_role: "ADMIN"}}) do
    case Transit.create_route(input) do
      {:ok, route} -> {:ok, route}
      {:error, %Ecto.Changeset{} = changeset} -> {:error, format_errors(changeset)}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

  def create_route(_parent, _args, _resolution) do
    {:error, "No autorizado: se requiere rol de Administrador para registrar nuevas rutas"}
  end

  def update_route_status(_parent, %{id: id, status: status}, %{context: %{current_role: role}})
      when role in ["CONDUCTOR", "ADMIN"] do
    case Transit.update_route_status(id, status) do
      {:ok, route} -> {:ok, route}
      {:error, :not_found} -> {:error, "Ruta con id o código '#{id}' no encontrada"}
      {:error, %Ecto.Changeset{} = changeset} -> {:error, format_errors(changeset)}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

  def update_route_status(_parent, _args, _resolution) do
    {:error,
     "No autorizado: se requiere rol de Conductor o Administrador para actualizar el estado operativo"}
  end

  def create_stop(_parent, %{input: input}, %{context: %{current_role: "ADMIN"}}) do
    case Transit.create_stop(input) do
      {:ok, stop} -> {:ok, stop}
      {:error, %Ecto.Changeset{} = changeset} -> {:error, format_errors(changeset)}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

  def create_stop(_parent, _args, _resolution) do
    {:error, "No autorizado: se requiere rol de Administrador para registrar paraderos"}
  end

  def create_alert(_parent, %{input: input}, %{context: %{current_role: role}})
      when role in ["CONDUCTOR", "ADMIN"] do
    case Transit.create_alert(input) do
      {:ok, alert} -> {:ok, alert}
      {:error, %Ecto.Changeset{} = changeset} -> {:error, format_errors(changeset)}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

  def create_alert(_parent, _args, _resolution) do
    {:error,
     "No autorizado: se requiere rol de Conductor o Administrador para emitir alertas de tránsito"}
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join(", ", fn {field, errors} ->
      "#{field}: #{Enum.join(errors, "; ")}"
    end)
  end
end
