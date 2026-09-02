defmodule Backendelixir.Streaming.Downsampler do
  @moduledoc """
  Controls the sampling frequency of real-time GPS telemetry sent to historical storage.
  Enforces a 15-second window per bus so that high-frequency WebSocket updates (every 3s)
  do not saturate the persistent database, achieving up to an 80-85% reduction in disk writes.
  Uses ValkeyCache with an ETS fallback for high-throughput memory-speed throttling.
  """

  alias Backendelixir.ValkeyCache

  @default_interval_seconds 15
  @ets_table :downsampler_ets_cache

  def init_table do
    if :ets.whereis(@ets_table) == :undefined do
      :ets.new(@ets_table, [
        :set,
        :public,
        :named_table,
        {:read_concurrency, true},
        {:write_concurrency, true}
      ])
    end

    :ok
  rescue
    _ -> :ok
  end

  def should_persist?(bus_id, interval_seconds \\ @default_interval_seconds) do
    now = System.system_time(:second)
    cache_key = "throttle:telemetry:#{bus_id}"

    last_time = get_last_timestamp(cache_key)

    if last_time && now - last_time < interval_seconds do
      false
    else
      put_last_timestamp(cache_key, now, interval_seconds)
      true
    end
  end

  defp get_last_timestamp(cache_key) do
    case ValkeyCache.get_cached(cache_key) do
      %{"timestamp" => time} when is_integer(time) ->
        time

      _ ->
        init_table()

        case :ets.lookup(@ets_table, cache_key) do
          [{^cache_key, time}] -> time
          _ -> nil
        end
    end
  rescue
    _ -> nil
  end

  defp put_last_timestamp(cache_key, now, interval_seconds) do
    ValkeyCache.put_cached(cache_key, %{timestamp: now}, interval_seconds)
    init_table()
    :ets.insert(@ets_table, {cache_key, now})
    :ok
  rescue
    _ -> :ok
  end
end
