defmodule Backendelixir.Audit do
  @moduledoc """
  Audit context for managing immutable system and domain event logs.
  """

  import Ecto.Query, warn: false
  alias Backendelixir.Repo
  alias Backendelixir.Audit.AuditLog

  def list_audit_logs(opts \\ []) do
    query = from(a in AuditLog, order_by: [desc: a.recorded_at], preload: [:actor])

    query =
      case Keyword.get(opts, :event_type) do
        nil -> query
        event_type -> where(query, [a], a.event_type == ^event_type)
      end

    query =
      case Keyword.get(opts, :actor_id) do
        nil -> query
        actor_id -> where(query, [a], a.actor_id == ^actor_id)
      end

    query =
      case Keyword.get(opts, :resource_type) do
        nil -> query
        res_type -> where(query, [a], a.resource_type == ^res_type)
      end

    query =
      case Keyword.get(opts, :limit) do
        nil -> limit(query, 100)
        lim -> limit(query, ^lim)
      end

    Repo.all(query)
  end

  def create_audit_log(attrs \\ %{}) do
    attrs = Map.put_new(attrs, :recorded_at, DateTime.utc_now() |> DateTime.truncate(:second))

    %AuditLog{}
    |> AuditLog.changeset(attrs)
    |> Repo.insert()
  end

  def insert_all_audit_logs(entries) when is_list(entries) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    prepared =
      Enum.map(entries, fn entry ->
        entry
        |> Map.put_new(:recorded_at, now)
        |> Map.put(:inserted_at, now)
      end)

    Repo.insert_all(AuditLog, prepared)
  end
end
