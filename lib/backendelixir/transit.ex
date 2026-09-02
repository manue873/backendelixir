defmodule Backendelixir.Transit do
  @moduledoc """
  The Transit context.
  Manages public transit routes, stops (paraderos), operational statuses, and alerts,
  along with real-time event broadcasting over Phoenix.PubSub.
  """

  import Ecto.Query, warn: false
  alias Backendelixir.Repo
  alias Backendelixir.Transit.{Route, Stop, RouteAlert}

  @pubsub_topic "transit:tracking"

  # Routes

  @doc """
  Returns the list of routes with optional preloading and sorting.
  """
  def list_routes(opts \\ []) do
    preload_assocs = Keyword.get(opts, :preload, [:stops, :alerts])

    Route
    |> order_by([r], desc: r.inserted_at)
    |> preload(^preload_assocs)
    |> Repo.all()
  end

  @doc """
  Gets a single route by ID. Raises Ecto.NoResultsError if not found.
  """
  def get_route!(id, opts \\ []) do
    preload_assocs = Keyword.get(opts, :preload, [:stops, :alerts])

    Route
    |> preload(^preload_assocs)
    |> Repo.get!(id)
  end

  @doc """
  Gets a single route by ID. Returns nil if not found.
  """
  def get_route(id, opts \\ []) do
    preload_assocs = Keyword.get(opts, :preload, [:stops, :alerts])

    Route
    |> preload(^preload_assocs)
    |> Repo.get(id)
  end

  @doc """
  Gets a single route by unique code.
  """
  def get_route_by_code(code, opts \\ []) do
    preload_assocs = Keyword.get(opts, :preload, [:stops, :alerts])

    Route
    |> where([r], r.code == ^code)
    |> preload(^preload_assocs)
    |> Repo.one()
  end

  @doc """
  Gets a single route by exact name.
  """
  def get_route_by_name(name, opts \\ []) do
    preload_assocs = Keyword.get(opts, :preload, [:stops, :alerts])

    Route
    |> where([r], r.name == ^name)
    |> preload(^preload_assocs)
    |> Repo.one()
  end

  @doc """
  Searches routes matching a query term in code, name, origin, or destination (case-insensitive).
  """
  def search_routes(query_term, opts \\ []) when is_binary(query_term) do
    term = "%" <> String.trim(query_term) <> "%"
    preload_assocs = Keyword.get(opts, :preload, [:stops, :alerts])

    Route
    |> where(
      [r],
      ilike(r.code, ^term) or ilike(r.name, ^term) or ilike(r.origin, ^term) or
        ilike(r.destination, ^term)
    )
    |> order_by([r], asc: r.code)
    |> preload(^preload_assocs)
    |> Repo.all()
  end

  @doc """
  Resolves a route by ID, code, or exact name. Returns %Route{} or nil.
  """
  def resolve_route(identifier) do
    cond do
      is_nil(identifier) ->
        nil

      is_integer(identifier) ->
        get_route(identifier)

      is_binary(identifier) ->
        get_route_by_code(identifier) ||
          get_route_by_name(identifier) ||
          case Integer.parse(identifier) do
            {id, ""} -> get_route(id)
            _ -> nil
          end

      true ->
        nil
    end
  end

  @doc """
  Creates a route and broadcasts the event.
  """
  def create_route(attrs \\ %{}) do
    result =
      %Route{}
      |> Route.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, route} ->
        route_with_assocs = Repo.preload(route, [:stops, :alerts])

        broadcast_event("route_created", %{
          id: route_with_assocs.id,
          code: route_with_assocs.code,
          name: route_with_assocs.name,
          origin: route_with_assocs.origin,
          destination: route_with_assocs.destination,
          status: route_with_assocs.status
        })

        {:ok, route_with_assocs}

      error ->
        error
    end
  end

  @doc """
  Updates a route and broadcasts the update event.
  """
  def update_route(%Route{} = route, attrs) do
    result =
      route
      |> Route.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated_route} ->
        route_with_assocs = Repo.preload(updated_route, [:stops, :alerts])

        broadcast_event("route_updated", %{
          id: route_with_assocs.id,
          code: route_with_assocs.code,
          name: route_with_assocs.name,
          origin: route_with_assocs.origin,
          destination: route_with_assocs.destination,
          status: route_with_assocs.status
        })

        {:ok, route_with_assocs}

      error ->
        error
    end
  end

  @doc """
  Updates specifically the operational status of a route.
  Accepts either a %Route{} struct or a route ID.
  """
  def update_route_status(%Route{} = route, status) do
    result =
      route
      |> Route.status_changeset(%{status: status})
      |> Repo.update()

    case result do
      {:ok, updated_route} ->
        route_with_assocs = Repo.preload(updated_route, [:stops, :alerts])

        broadcast_event("status_changed", %{
          route_id: route_with_assocs.id,
          code: route_with_assocs.code,
          name: route_with_assocs.name,
          old_status: route.status,
          new_status: updated_route.status
        })

        {:ok, route_with_assocs}

      error ->
        error
    end
  end

  def update_route_status(identifier, status)
      when is_integer(identifier) or is_binary(identifier) do
    case resolve_route(identifier) do
      nil -> {:error, :not_found}
      route -> update_route_status(route, status)
    end
  end

  @doc """
  Deletes a route.
  """
  def delete_route(%Route{} = route) do
    result = Repo.delete(route)

    case result do
      {:ok, deleted_route} ->
        broadcast_event("route_deleted", %{id: deleted_route.id, code: deleted_route.code})
        {:ok, deleted_route}

      error ->
        error
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking route changes.
  """
  def change_route(%Route{} = route, attrs \\ %{}) do
    Route.changeset(route, attrs)
  end

  # Stops (Paraderos)

  @doc """
  Returns the list of stops for a specific route, ordered by sequence.
  """
  def list_stops(route_id) do
    Stop
    |> where([s], s.route_id == ^route_id)
    |> order_by([s], asc: s.sequence)
    |> Repo.all()
  end

  @doc """
  Creates a stop associated with a route.
  """
  def create_stop(attrs \\ %{}) do
    %Stop{}
    |> Stop.changeset(attrs)
    |> Repo.insert()
  end

  # Route Alerts

  @doc """
  Returns alerts, optionally filtered by route_id.
  """
  def list_alerts(opts \\ []) do
    query = from(a in RouteAlert, order_by: [desc: a.inserted_at], preload: [:route])

    query =
      case Keyword.get(opts, :route_id) do
        nil -> query
        route_id -> where(query, [a], a.route_id == ^route_id)
      end

    Repo.all(query)
  end

  @doc """
  Creates an alert and broadcasts it to subscribers.
  Supports passing route_id, route_code, or route_name in attrs.
  """
  def create_alert(attrs \\ %{}) do
    normalized_attrs = resolve_alert_route(attrs)

    result =
      %RouteAlert{}
      |> RouteAlert.changeset(normalized_attrs)
      |> Repo.insert()

    case result do
      {:ok, alert} ->
        alert_with_route = Repo.preload(alert, :route)

        broadcast_event("alert_created", %{
          id: alert_with_route.id,
          route_id: alert_with_route.route_id,
          route_code: alert_with_route.route && alert_with_route.route.code,
          message: alert_with_route.message,
          severity: alert_with_route.severity,
          inserted_at: alert_with_route.inserted_at
        })

        {:ok, alert_with_route}

      error ->
        error
    end
  end

  defp resolve_alert_route(%{} = attrs) do
    route_identifier =
      Map.get(attrs, :route_code) ||
        Map.get(attrs, "route_code") ||
        Map.get(attrs, :route_name) ||
        Map.get(attrs, "route_name") ||
        Map.get(attrs, :route_id) ||
        Map.get(attrs, "route_id")

    case resolve_route(route_identifier) do
      %Route{} = route ->
        if Enum.any?(Map.keys(attrs), &is_binary/1) do
          attrs
          |> Map.delete(:route_id)
          |> Map.delete(:route_code)
          |> Map.delete(:route_name)
          |> Map.put("route_id", route.id)
        else
          attrs
          |> Map.delete("route_id")
          |> Map.delete("route_code")
          |> Map.delete("route_name")
          |> Map.put(:route_id, route.id)
        end

      nil ->
        attrs
    end
  end

  # Real-Time PubSub Event Dispatcher

  @doc """
  Broadcasts an event payload to both internal PubSub subscribers and WebSocket channel clients.
  """
  def broadcast_event(event, payload) do
    Phoenix.PubSub.broadcast(Backendelixir.PubSub, @pubsub_topic, {event, payload})
    BackendelixirWeb.Endpoint.broadcast(@pubsub_topic, event, payload)
  end

  @doc """
  Subscribes the calling process to the transit tracking topic.
  """
  def subscribe do
    Phoenix.PubSub.subscribe(Backendelixir.PubSub, @pubsub_topic)
  end

  @doc """
  Unsubscribes the calling process from the transit tracking topic.
  """
  def unsubscribe do
    Phoenix.PubSub.unsubscribe(Backendelixir.PubSub, @pubsub_topic)
  end
end
