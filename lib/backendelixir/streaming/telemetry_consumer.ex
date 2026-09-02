defmodule Backendelixir.Streaming.TelemetryConsumer do
  @moduledoc """
  Broadway consumer pipeline for real-time GPS telemetry downsampled batches.
  Consumes messages, validates structure, and performs atomic bulk inserts into PostgreSQL.
  """

  use Broadway
  alias Backendelixir.Repo
  alias Backendelixir.Transit.BusLocationLog

  def start_link(_opts \\ []) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {Broadway.DummyProducer, []},
        concurrency: 1
      ],
      processors: [
        default: [concurrency: 2]
      ],
      batchers: [
        default: [
          batch_size: 10,
          batch_timeout: 2000,
          concurrency: 2
        ]
      ]
    )
  end

  def push(payload) do
    if Process.whereis(__MODULE__) do
      message = %Broadway.Message{
        data: payload,
        acknowledger: {Backendelixir.Streaming.NoopAcknowledger, :ack_ref, :ack_data}
      }

      Broadway.push_messages(__MODULE__, [message])
    end
  rescue
    _ -> :ok
  end

  @impl true
  def handle_message(_processor, message, _context) do
    data = message.data

    case normalize_telemetry_payload(data) do
      {:ok, prepared_row} ->
        Broadway.Message.put_data(message, prepared_row)

      {:error, _reason} ->
        Broadway.Message.failed(message, "invalid_telemetry_payload")
    end
  end

  @impl true
  def handle_batch(:default, messages, _batch_info, _context) do
    rows = Enum.map(messages, & &1.data)

    if length(rows) > 0 do
      try do
        Repo.insert_all(BusLocationLog, rows)
      rescue
        _ ->
          try do
            safe_rows = Enum.map(rows, &Map.put(&1, :route_id, nil))
            Repo.insert_all(BusLocationLog, safe_rows)
          rescue
            _ -> :ok
          end
      end
    end

    messages
  end

  defp normalize_telemetry_payload(%{} = payload) do
    bus_id = payload[:bus_id] || payload["bus_id"]
    lat = payload[:latitude] || payload["latitude"]
    lng = payload[:longitude] || payload["longitude"]

    if bus_id && lat && lng do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      timestamp =
        case payload[:timestamp] || payload["timestamp"] do
          %DateTime{} = dt ->
            DateTime.truncate(dt, :second)

          iso when is_binary(iso) ->
            case DateTime.from_iso8601(iso) do
              {:ok, dt, _} -> DateTime.truncate(dt, :second)
              _ -> now
            end

          _ ->
            now
        end

      raw_route_id = payload[:route_id] || payload["route_id"]

      route_id =
        case raw_route_id do
          id when is_integer(id) and id > 0 ->
            id

          id when is_binary(id) ->
            case Integer.parse(id) do
              {int, _} -> int
              :error -> nil
            end

          _ ->
            nil
        end

      row = %{
        bus_id: to_string(bus_id),
        route_id: route_id,
        route_code: payload[:route_code] || payload["route_code"],
        latitude: to_float(lat),
        longitude: to_float(lng),
        speed: to_float(payload[:speed] || payload["speed"] || 0.0),
        recorded_at: timestamp,
        inserted_at: now
      }

      {:ok, row}
    else
      {:error, :missing_required_fields}
    end
  end

  defp normalize_telemetry_payload(_), do: {:error, :not_a_map}

  defp to_float(val) when is_float(val), do: val
  defp to_float(val) when is_integer(val), do: val * 1.0

  defp to_float(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> 0.0
    end
  end

  defp to_float(_), do: 0.0
end
