defmodule Backendelixir.StreamingTest do
  use Backendelixir.DataCase, async: false

  alias Backendelixir.{Audit, Repo}
  alias Backendelixir.Streaming.{Downsampler, EventProducer, TelemetryConsumer, AuditConsumer}
  alias Backendelixir.Transit.{BusLocationLog, Route}
  alias Backendelixir.Audit.AuditLog

  describe "Downsampler" do
    test "allows first telemetry ping, throttles within interval, and allows after interval" do
      bus_id = "BUS-TEST-DOWNSAMPLE-#{System.unique_integer([:positive])}"

      # Primer ping debe permitirse
      assert Downsampler.should_persist?(bus_id, 15) == true

      # Pings inmediatos deben descartarse para histórico (throttled)
      assert Downsampler.should_persist?(bus_id, 15) == false
      assert Downsampler.should_persist?(bus_id, 15) == false

      # Con intervalo 0 debe permitirse inmediatamente
      assert Downsampler.should_persist?(bus_id, 0) == true
    end
  end

  describe "Audit Context" do
    test "creates and lists audit logs" do
      {:ok, log} =
        Audit.create_audit_log(%{
          event_type: "ROUTE_STATUS_CHANGED",
          actor_role: "ADMIN",
          actor_email: "admin@transit.pe",
          resource_type: "Route",
          resource_id: "101",
          payload: %{status: "DEMORADA"}
        })

      assert log.id != nil
      assert log.event_type == "ROUTE_STATUS_CHANGED"

      logs = Audit.list_audit_logs(event_type: "ROUTE_STATUS_CHANGED")
      assert length(logs) >= 1
      assert Enum.any?(logs, fn l -> l.id == log.id end)
    end
  end

  describe "Broadway Telemetry Batch Ingestion" do
    test "TelemetryConsumer handles batch insertion of GPS telemetry" do
      {:ok, route} =
        Repo.insert(%Route{
          code: "RT-STREAM-01",
          name: "Ruta Streaming",
          origin: "Castilla",
          destination: "Catacaos",
          status: "ACTIVA"
        })

      message = %Broadway.Message{
        data: %{
          bus_id: "BUS-STREAM-01",
          route_id: route.id,
          route_code: route.code,
          latitude: -5.1974,
          longitude: -80.6268,
          speed: 45.0,
          timestamp: DateTime.utc_now()
        },
        acknowledger: {Backendelixir.Streaming.NoopAcknowledger, :ack_ref, :ack_data}
      }

      processed_message = TelemetryConsumer.handle_message(:default, message, %{})
      assert processed_message.status == :ok
      assert is_map(processed_message.data)

      # Ejecutar inserción en lote por Broadway
      TelemetryConsumer.handle_batch(:default, [processed_message], %{}, %{})

      persisted = Repo.get_by(BusLocationLog, bus_id: "BUS-STREAM-01")
      assert persisted != nil
      assert persisted.route_id == route.id
      assert persisted.speed == 45.0
    end
  end

  describe "Broadway Audit Batch Ingestion" do
    test "AuditConsumer handles batch insertion of audit events" do
      message = %Broadway.Message{
        data: %{
          event_type: "ALERT_CREATED",
          actor_role: "CONDUCTOR",
          resource_type: "RouteAlert",
          resource_id: "999",
          payload: %{severity: "CRITICAL", message: "Accidente en vía"},
          recorded_at: DateTime.utc_now()
        },
        acknowledger: {Backendelixir.Streaming.NoopAcknowledger, :ack_ref, :ack_data}
      }

      processed_message = AuditConsumer.handle_message(:default, message, %{})
      assert processed_message.status == :ok

      AuditConsumer.handle_batch(:default, [processed_message], %{}, %{})

      persisted = Repo.get_by(AuditLog, event_type: "ALERT_CREATED", resource_id: "999")
      assert persisted != nil
      assert persisted.actor_role == "CONDUCTOR"
    end
  end

  describe "EventProducer API" do
    test "safely publishes telemetry and audit events without crashing" do
      assert :ok ==
               EventProducer.publish_telemetry(%{
                 bus_id: "BUS-SAFE-#{System.unique_integer([:positive])}",
                 latitude: -5.1974,
                 longitude: -80.6268,
                 speed: 30.0
               })

      assert :ok ==
               EventProducer.publish_audit_event("TEST_EVENT", %{
                 actor_role: "TESTER",
                 payload: %{success: true}
               })
    end
  end
end
