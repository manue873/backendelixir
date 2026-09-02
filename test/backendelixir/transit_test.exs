defmodule Backendelixir.TransitTest do
  use Backendelixir.DataCase

  alias Backendelixir.Transit
  alias Backendelixir.Transit.Route

  describe "routes" do
    @valid_attrs %{
      code: "RT-101",
      name: "Ruta Norte - Sur",
      origin: "Terminal Norte",
      destination: "Terminal Sur",
      status: "ACTIVA"
    }
    @update_attrs %{
      name: "Ruta Norte - Sur Expreso",
      status: "DEMORADA"
    }
    @invalid_attrs %{code: nil, name: nil, origin: nil, destination: nil, status: nil}

    test "list_routes/0 returns all routes ordered by insertion" do
      {:ok, route} = Transit.create_route(@valid_attrs)
      routes = Transit.list_routes()
      assert Enum.any?(routes, fn r -> r.id == route.id end)
    end

    test "get_route!/1 returns the route with given id" do
      {:ok, route} = Transit.create_route(@valid_attrs)
      fetched = Transit.get_route!(route.id)
      assert fetched.id == route.id
      assert fetched.code == "RT-101"
    end

    test "get_route_by_code/1 returns the route with given code" do
      {:ok, route} = Transit.create_route(@valid_attrs)
      fetched = Transit.get_route_by_code("RT-101")
      assert fetched.id == route.id
    end

    test "create_route/1 with valid data creates a route and broadcasts event" do
      Transit.subscribe()

      assert {:ok, %Route{} = route} = Transit.create_route(@valid_attrs)
      assert route.code == "RT-101"
      assert route.name == "Ruta Norte - Sur"
      assert route.status == "ACTIVA"

      assert_receive {"route_created", received_route}
      assert received_route.id == route.id
    end

    test "create_route/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Transit.create_route(@invalid_attrs)
    end

    test "create_route/1 validates status enum inclusion" do
      invalid_status_attrs = Map.put(@valid_attrs, :status, "DESCONOCIDO")
      assert {:error, %Ecto.Changeset{} = changeset} = Transit.create_route(invalid_status_attrs)
      assert %{status: [_]} = errors_on(changeset)
    end

    test "get_route_by_name/1 returns the route with given name" do
      {:ok, route} = Transit.create_route(@valid_attrs)
      fetched = Transit.get_route_by_name("Ruta Norte - Sur")
      assert fetched.id == route.id
    end

    test "search_routes/1 finds routes by partial keyword matching" do
      {:ok, _r1} =
        Transit.create_route(%{@valid_attrs | code: "RT-SRCH-1", name: "Troncal Castilla"})

      {:ok, _r2} =
        Transit.create_route(%{@valid_attrs | code: "RT-SRCH-2", name: "Troncal Catacaos"})

      results = Transit.search_routes("castilla")
      assert length(results) == 1
      assert hd(results).code == "RT-SRCH-1"

      all_troncal = Transit.search_routes("Troncal")
      assert length(all_troncal) == 2
    end

    test "create_route/1 enforces unique code and unique name constraints" do
      {:ok, _route} = Transit.create_route(@valid_attrs)
      assert {:error, %Ecto.Changeset{} = changeset} = Transit.create_route(@valid_attrs)
      assert %{code: ["has already been taken"]} = errors_on(changeset)

      duplicate_name_attrs = Map.put(@valid_attrs, :code, "RT-DIFF")
      assert {:error, %Ecto.Changeset{} = changeset2} = Transit.create_route(duplicate_name_attrs)
      assert %{name: ["has already been taken"]} = errors_on(changeset2)
    end

    test "update_route/2 with valid data updates the route" do
      {:ok, route} = Transit.create_route(@valid_attrs)
      assert {:ok, %Route{} = updated} = Transit.update_route(route, @update_attrs)
      assert updated.name == "Ruta Norte - Sur Expreso"
      assert updated.status == "DEMORADA"
    end

    test "update_route_status/2 updates operational status and broadcasts status_changed" do
      {:ok, route} = Transit.create_route(@valid_attrs)
      Transit.subscribe()

      assert {:ok, %Route{} = updated} = Transit.update_route_status(route.id, "DEMORADA")
      assert updated.status == "DEMORADA"

      assert_receive {"status_changed", payload}
      assert payload.route_id == route.id
      assert payload.old_status == "ACTIVA"
      assert payload.new_status == "DEMORADA"
    end

    test "delete_route/1 deletes the route" do
      {:ok, route} = Transit.create_route(@valid_attrs)
      assert {:ok, %Route{}} = Transit.delete_route(route)
      assert is_nil(Transit.get_route(route.id))
    end
  end

  describe "stops and alerts" do
    test "create_stop/1 creates a stop for a route" do
      {:ok, route} =
        Transit.create_route(%{
          code: "RT-505",
          name: "Ruta Expreso",
          origin: "Punto A",
          destination: "Punto B",
          status: "ACTIVA"
        })

      assert {:ok, stop} =
               Transit.create_stop(%{
                 route_id: route.id,
                 name: "Parada 1 - Terminal Castilla",
                 sequence: 1,
                 latitude: -5.1989,
                 longitude: -80.6185
               })

      assert stop.name == "Parada 1 - Terminal Castilla"
      assert stop.sequence == 1
      assert length(Transit.list_stops(route.id)) == 1
    end

    test "create_stop/1 rejects coordinates outside Piura with controlled error" do
      {:ok, route} =
        Transit.create_route(%{
          code: "RT-PIU-99",
          name: "Ruta Prueba",
          origin: "A",
          destination: "B",
          status: "ACTIVA"
        })

      # Coordenadas de Lima (-12.0464, -77.0428) - Fuera de Piura
      assert {:error, %Ecto.Changeset{} = changeset} =
               Transit.create_stop(%{
                 route_id: route.id,
                 name: "Parada Lima Inválida",
                 sequence: 1,
                 latitude: -12.0464,
                 longitude: -77.0428
               })

      assert %{latitude: [lat_err], longitude: [lng_err]} = errors_on(changeset)
      assert lat_err =~ "fuera de la jurisdicción operativa de Piura"
      assert lng_err =~ "fuera de la jurisdicción operativa de Piura"
    end

    test "create_alert/1 creates alert and broadcasts alert_created" do
      {:ok, route} =
        Transit.create_route(%{
          code: "RT-707",
          name: "Ruta 707",
          origin: "Estación 1",
          destination: "Estación 2",
          status: "ACTIVA"
        })

      Transit.subscribe()

      assert {:ok, alert} =
               Transit.create_alert(%{
                 route_id: route.id,
                 message: "Retraso por congestión",
                 severity: "WARNING"
               })

      assert alert.message == "Retraso por congestión"
      assert alert.severity == "WARNING"

      assert_receive {"alert_created", received_alert}
      assert received_alert.id == alert.id
    end
  end
end
