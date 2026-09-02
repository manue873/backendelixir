defmodule Backendelixir.Streaming.AuditConsumer do
  @moduledoc """
  Broadway consumer pipeline for domain and system audit events.
  Consumes audit events, normalizes payloads, and batches writes to PostgreSQL.
  """

  use Broadway
  alias Backendelixir.Repo
  alias Backendelixir.Audit.AuditLog

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

    case normalize_audit_payload(data) do
      {:ok, prepared_row} ->
        Broadway.Message.put_data(message, prepared_row)

      {:error, _reason} ->
        Broadway.Message.failed(message, "invalid_audit_payload")
    end
  end

  @impl true
  def handle_batch(:default, messages, _batch_info, _context) do
    rows = Enum.map(messages, & &1.data)

    if length(rows) > 0 do
      try do
        Repo.insert_all(AuditLog, rows)
      rescue
        _ ->
          try do
            safe_rows = Enum.map(rows, &Map.put(&1, :actor_id, nil))
            Repo.insert_all(AuditLog, safe_rows)
          rescue
            _ -> :ok
          end
      end
    end

    messages
  end

  defp normalize_audit_payload(%{} = payload) do
    event_type = payload[:event_type] || payload["event_type"]

    if event_type do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      timestamp =
        case payload[:recorded_at] || payload["recorded_at"] do
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

      raw_actor_id = payload[:actor_id] || payload["actor_id"]

      actor_id =
        case raw_actor_id do
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

      raw_payload = payload[:payload] || payload["payload"] || %{}

      row = %{
        actor_id: actor_id,
        actor_role: payload[:actor_role] || payload["actor_role"],
        actor_email: payload[:actor_email] || payload["actor_email"],
        event_type: to_string(event_type),
        resource_type: payload[:resource_type] || payload["resource_type"],
        resource_id: to_string(payload[:resource_id] || payload["resource_id"] || ""),
        payload: raw_payload,
        ip_address: payload[:ip_address] || payload["ip_address"],
        recorded_at: timestamp,
        inserted_at: now
      }

      {:ok, row}
    else
      {:error, :missing_event_type}
    end
  end

  defp normalize_audit_payload(_), do: {:error, :not_a_map}
end
