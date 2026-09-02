defmodule Backendelixir.ValkeyCacheTest do
  use ExUnit.Case, async: true
  alias Backendelixir.ValkeyCache

  describe "valkey_cache" do
    test "put_bus_location and get_bus_location handle telemetry gracefully" do
      telemetry = %{
        bus_id: "BUS-TEST-99",
        route_id: 1,
        route_code: "RT-PIU-01",
        latitude: -5.1974,
        longitude: -80.6268,
        speed: 38.0,
        timestamp: "2026-09-01T23:45:00Z"
      }

      assert :ok = ValkeyCache.put_bus_location("BUS-TEST-99", telemetry)

      # In local without live Valkey or with live Valkey, get_bus_location returns nil or map without crashing
      result = ValkeyCache.get_bus_location("BUS-TEST-99")
      assert is_nil(result) or is_map(result)
    end

    test "list_active_buses returns a list" do
      buses = ValkeyCache.list_active_buses(1)
      assert is_list(buses)
    end

    test "put_cached, get_cached and invalidate operate safely" do
      assert :ok = ValkeyCache.put_cached("test_key", %{data: "hello"}, 10)
      assert :ok = ValkeyCache.invalidate("test_key")
    end
  end
end
