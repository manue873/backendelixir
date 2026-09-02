defmodule BackendelixirWeb.TransitChannel do
  use Phoenix.Channel
  alias Backendelixir.Transit

  @doc """
  Clients join "transit:tracking" or specific "transit:route:<id>" topics.
  """
  def join("transit:tracking", _payload, socket) do
    {:ok,
     %{status: "connected", topic: "transit:tracking", role: socket.assigns[:role] || "PASAJERO"},
     socket}
  end

  def join("transit:route:" <> _route_id, _payload, socket) do
    {:ok, socket}
  end

  def join("transit:" <> _subtopic, _payload, socket) do
    {:ok, socket}
  end

  @doc """
  Handles incoming messages from clients over WebSockets with RBAC authorization checks.
  Supports identifying routes by ID, code (e.g. 'RT-PIU-01'), or name.
  """
  def handle_in(event, payload, socket)

  def handle_in("send_alert", %{"message" => message} = payload, socket) do
    if authorized_driver?(socket) do
      severity = Map.get(payload, "severity", "WARNING")

      alert_params =
        payload
        |> Map.put("message", message)
        |> Map.put("severity", severity)

      case Transit.create_alert(alert_params) do
        {:ok, alert} ->
          broadcast!(socket, "new_alert", %{
            id: alert.id,
            route_id: alert.route_id,
            route_code: (alert.route && alert.route.code) || payload["route_code"],
            message: alert.message,
            severity: alert.severity,
            inserted_at: alert.inserted_at
          })

          Backendelixir.Streaming.EventProducer.publish_audit_event("ALERT_CREATED", %{
            actor_id: socket.assigns[:user_id],
            actor_role: socket.assigns[:role],
            resource_type: "RouteAlert",
            resource_id: to_string(alert.id),
            payload: %{message: alert.message, severity: alert.severity, route_id: alert.route_id}
          })

          {:reply, {:ok, %{alert_id: alert.id}}, socket}

        {:error, changeset} ->
          {:reply, {:error, %{reason: "Invalid alert data", errors: inspect(changeset)}}, socket}
      end
    else
      {:reply,
       {:error,
        %{
          reason:
            "No autorizado: se requiere rol de Conductor o Administrador para emitir alertas"
        }}, socket}
    end
  end

  def handle_in("update_status", %{"status" => status} = payload, socket) do
    if authorized_driver?(socket) do
      identifier = payload["route_id"] || payload["route_code"] || payload["route_name"]

      case Transit.update_route_status(identifier, status) do
        {:ok, route} ->
          Backendelixir.Streaming.EventProducer.publish_audit_event("ROUTE_STATUS_CHANGED", %{
            actor_id: socket.assigns[:user_id],
            actor_role: socket.assigns[:role],
            resource_type: "Route",
            resource_id: to_string(route.id),
            payload: %{code: route.code, new_status: route.status}
          })

          {:reply, {:ok, %{route_id: route.id, route_code: route.code, status: route.status}},
           socket}

        {:error, reason} ->
          {:reply, {:error, %{reason: inspect(reason)}}, socket}
      end
    else
      {:reply,
       {:error,
        %{
          reason:
            "No autorizado: se requiere rol de Conductor o Administrador para cambiar estado"
        }}, socket}
    end
  end

  def handle_in(
        "send_telemetry",
        %{"latitude" => lat, "longitude" => lng} = payload,
        socket
      ) do
    if authorized_driver?(socket) do
      bus_id = Map.get(payload, "bus_id", "BUS-DEFAULT")
      speed = Map.get(payload, "speed", 0.0)
      bounds = Backendelixir.Transit.Stop.piura_bounds()

      identifier = payload["route_id"] || payload["route_code"] || payload["route_name"]
      route = Transit.resolve_route(identifier)

      route_id = if route, do: route.id, else: nil
      route_code = if route, do: route.code, else: payload["route_code"]
      route_name = if route, do: route.name, else: payload["route_name"]

      if lat >= bounds.min_latitude and lat <= bounds.max_latitude and
           lng >= bounds.min_longitude and lng <= bounds.max_longitude do
        telemetry_payload = %{
          route_id: route_id,
          route_code: route_code,
          route_name: route_name,
          bus_id: bus_id,
          latitude: lat,
          longitude: lng,
          speed: speed,
          timestamp: DateTime.utc_now()
        }

        Backendelixir.ValkeyCache.put_bus_location(bus_id, telemetry_payload)
        broadcast!(socket, "bus_location_updated", telemetry_payload)

        # Ingesta por streaming con downsampling (15s) y batching en Broadway
        Backendelixir.Streaming.EventProducer.publish_telemetry(telemetry_payload)

        {:reply,
         {:ok,
          %{
            status: "telemetry_broadcasted",
            bus_id: bus_id,
            route_id: route_id,
            route_code: route_code
          }}, socket}
      else
        {:reply,
         {:error, %{reason: "Coordenadas fuera de la jurisdicción operativa de Piura, Perú"}},
         socket}
      end
    else
      {:reply,
       {:error,
        %{
          reason:
            "No autorizado: se requiere rol de Conductor o Administrador para emitir telemetría"
        }}, socket}
    end
  end

  def handle_in("get_active_buses", payload, socket) do
    route_id = payload["route_id"]
    active_buses = Backendelixir.ValkeyCache.list_active_buses(route_id)
    {:reply, {:ok, %{active_buses: active_buses, count: length(active_buses)}}, socket}
  end

  def handle_in("ping", payload, socket) do
    {:reply, {:ok, Map.put(payload, "pong", true)}, socket}
  end

  defp authorized_driver?(socket) do
    socket.assigns[:role] in ["CONDUCTOR", "ADMIN"]
  end

  def handle_info(_other, socket) do
    {:noreply, socket}
  end
end
