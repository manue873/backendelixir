defmodule Backendelixir.ValkeyCache do
  @moduledoc """
  Valkey / Redis cache layer via Redix.
  """

  require Logger

  @default_valkey_url "redis://localhost:6379"
  @bus_ttl_seconds 60
  @route_ttl_seconds 300

  def child_spec(_opts) do
    url = valkey_url()

    %{
      id: :valkey_redix,
      start: {Redix, :start_link, [url, [name: :redix, sync_connect: false]]},
      type: :worker,
      restart: :permanent
    }
  end

  def valkey_url do
    System.get_env("VALKEY_URL") ||
      System.get_env("REDIS_URL") ||
      Application.get_env(:backendelixir, :valkey_url, @default_valkey_url)
  end

  def put_bus_location(bus_id, %{} = telemetry, ttl \\ @bus_ttl_seconds) do
    key = "valkey:bus:#{bus_id}"
    route_id = Map.get(telemetry, :route_id) || Map.get(telemetry, "route_id", "default")
    route_set = "valkey:active_buses:route:#{route_id}"
    global_set = "valkey:active_buses:all"

    case Jason.encode(telemetry) do
      {:ok, json} ->
        commands = [
          ["SET", key, json, "EX", to_string(ttl)],
          ["SADD", route_set, bus_id],
          ["EXPIRE", route_set, to_string(ttl + 30)],
          ["SADD", global_set, bus_id],
          ["EXPIRE", global_set, to_string(ttl + 30)]
        ]

        case Redix.pipeline(:redix, commands) do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            Logger.debug("ValkeyCache put_bus_location unavailable: #{inspect(reason)}")
            :ok
        end

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e ->
      Logger.debug("ValkeyCache exception in put_bus_location: #{inspect(e)}")
      :ok
  end

  def get_bus_location(bus_id) do
    key = "valkey:bus:#{bus_id}"

    case Redix.command(:redix, ["GET", key]) do
      {:ok, nil} ->
        nil

      {:ok, json} ->
        decode_json(json)

      {:error, reason} ->
        Logger.debug("ValkeyCache get_bus_location unavailable: #{inspect(reason)}")
        nil
    end
  rescue
    _ -> nil
  end

  def list_active_buses(route_id \\ nil) do
    set_key =
      if route_id,
        do: "valkey:active_buses:route:#{route_id}",
        else: "valkey:active_buses:all"

    case Redix.command(:redix, ["SMEMBERS", set_key]) do
      {:ok, bus_ids} when is_list(bus_ids) and length(bus_ids) > 0 ->
        keys = Enum.map(bus_ids, fn id -> "valkey:bus:#{id}" end)

        case Redix.command(:redix, ["MGET" | keys]) do
          {:ok, json_list} ->
            json_list
            |> Enum.reject(&is_nil/1)
            |> Enum.map(&decode_json/1)
            |> Enum.reject(&is_nil/1)

          _ ->
            []
        end

      _ ->
        []
    end
  rescue
    _ -> []
  end

  def put_cached(key, value, ttl \\ @route_ttl_seconds) do
    valkey_key = "valkey:cache:#{key}"

    case Jason.encode(value) do
      {:ok, json} ->
        case Redix.command(:redix, ["SET", valkey_key, json, "EX", to_string(ttl)]) do
          {:ok, "OK"} -> :ok
          _ -> :ok
        end

      _ ->
        :ok
    end
  rescue
    _ -> :ok
  end

  def get_cached(key) do
    valkey_key = "valkey:cache:#{key}"

    case Redix.command(:redix, ["GET", valkey_key]) do
      {:ok, nil} -> nil
      {:ok, json} -> decode_json(json)
      _ -> nil
    end
  rescue
    _ -> nil
  end

  def invalidate(key) do
    valkey_key = "valkey:cache:#{key}"
    Redix.command(:redix, ["DEL", valkey_key])
    :ok
  rescue
    _ -> :ok
  end

  def ping do
    case Redix.command(:redix, ["PING"]) do
      {:ok, "PONG"} -> {:ok, :pong}
      {:error, reason} -> {:error, reason}
    end
  rescue
    e -> {:error, e}
  end

  defp decode_json(json) do
    case Jason.decode(json) do
      {:ok, map} -> map
      _ -> nil
    end
  end
end
