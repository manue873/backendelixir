defmodule BackendelixirWeb.Resolvers.AuditResolver do
  @moduledoc """
  GraphQL Resolvers for querying immutable audit logs and historical GPS telemetry.
  """

  import Ecto.Query
  alias Backendelixir.{Audit, Repo}
  alias Backendelixir.Transit.BusLocationLog

  def list_audit_logs(_parent, args, _resolution) do
    opts =
      []
      |> maybe_put(:event_type, args[:event_type])
      |> maybe_put(:resource_type, args[:resource_type])
      |> maybe_put(:limit, args[:limit])

    logs = Audit.list_audit_logs(opts)
    {:ok, logs}
  end

  def list_bus_location_logs(_parent, args, _resolution) do
    query = from(b in BusLocationLog, order_by: [desc: b.recorded_at])

    query =
      case args[:bus_id] do
        nil -> query
        bus_id -> where(query, [b], b.bus_id == ^bus_id)
      end

    query =
      case args[:route_id] do
        nil -> query
        route_id -> where(query, [b], b.route_id == ^route_id)
      end

    limit = args[:limit] || 100
    query = limit(query, ^limit)

    {:ok, Repo.all(query)}
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, val), do: Keyword.put(opts, key, val)
end
