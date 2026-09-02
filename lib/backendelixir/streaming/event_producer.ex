defmodule Backendelixir.Streaming.EventProducer do
  @moduledoc """
  Unified event producer for streaming telemetry and audit logs.
  Ensures non-blocking, fault-tolerant execution using Downsampler throttling and Broadway pipelines.
  """

  alias Backendelixir.Streaming.{AuditConsumer, Downsampler, TelemetryConsumer}

  @redpanda_proxy_url "http://localhost:8082"

  def publish_telemetry(%{} = payload) do
    Task.start(fn ->
      bus_id = payload[:bus_id] || payload["bus_id"] || "BUS-DEFAULT"

      if Downsampler.should_persist?(bus_id) do
        TelemetryConsumer.push(payload)
        async_send_to_redpanda("transit.telemetry.v1", bus_id, payload)
      end
    end)

    :ok
  rescue
    _ -> :ok
  end

  def publish_audit_event(event_type, details \\ %{})
      when is_binary(event_type) or is_atom(event_type) do
    Task.start(fn ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      audit_payload =
        details
        |> Map.put_new(:event_type, to_string(event_type))
        |> Map.put_new(:recorded_at, now)

      AuditConsumer.push(audit_payload)
      async_send_to_redpanda("transit.audit.v1", to_string(event_type), audit_payload)
    end)

    :ok
  rescue
    _ -> :ok
  end

  defp async_send_to_redpanda(topic, key, payload) do
    url = System.get_env("REDPANDA_PROXY_URL") || @redpanda_proxy_url
    endpoint = "#{url}/topics/#{topic}"

    body = %{
      records: [
        %{
          key: to_string(key),
          value: payload
        }
      ]
    }

    _ = Req.post(endpoint, json: body, retry: false, receive_timeout: 500)
  rescue
    _ -> :ok
  end
end
