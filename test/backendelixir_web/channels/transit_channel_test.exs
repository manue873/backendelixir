defmodule BackendelixirWeb.TransitChannelTest do
  use BackendelixirWeb.ChannelCase

  alias Backendelixir.Accounts
  alias Backendelixir.Transit
  alias BackendelixirWeb.UserSocket

  setup do
    {:ok, driver} =
      Accounts.register_user(%{
        email: "driver.sock@piura.pe",
        name: "Chofer Socket",
        password: "Password123!",
        role: "CONDUCTOR"
      })

    {:ok, passenger} =
      Accounts.register_user(%{
        email: "passenger.sock@piura.pe",
        name: "Pasajero Socket",
        password: "Password123!",
        role: "PASAJERO"
      })

    driver_token = Accounts.generate_user_token(driver)
    # Socket autenticado como CONDUCTOR
    {:ok, _, driver_socket} =
      socket(UserSocket, "user_socket:#{driver.id}", %{
        current_user: driver,
        user_id: driver.id,
        role: "CONDUCTOR"
      })
      |> subscribe_and_join(BackendelixirWeb.TransitChannel, "transit:tracking")

    # Socket autenticado como PASAJERO
    {:ok, _, passenger_socket} =
      socket(UserSocket, "user_socket:#{passenger.id}", %{
        current_user: passenger,
        user_id: passenger.id,
        role: "PASAJERO"
      })
      |> subscribe_and_join(BackendelixirWeb.TransitChannel, "transit:tracking")

    %{
      driver: driver,
      driver_token: driver_token,
      driver_socket: driver_socket,
      passenger_socket: passenger_socket
    }
  end

  test "connects UserSocket with valid Phoenix.Token", %{driver_token: token, driver: driver} do
    assert {:ok, socket} = connect(UserSocket, %{"token" => token})
    assert socket.assigns.user_id == driver.id
    assert socket.assigns.role == "CONDUCTOR"
  end

  test "connects UserSocket without token as guest PASAJERO" do
    assert {:ok, socket} = connect(UserSocket, %{})
    assert socket.assigns.user_id == nil
    assert socket.assigns.role == "PASAJERO"
  end

  test "rejects UserSocket connection with invalid token" do
    assert :error = connect(UserSocket, %{"token" => "bad_token"})
  end

  test "joins transit:tracking topic successfully as CONDUCTOR", %{driver_socket: socket} do
    assert socket.topic == "transit:tracking"
    assert socket.assigns.role == "CONDUCTOR"
  end

  test "driver can send alerts and broadcast new_alert", %{driver_socket: socket} do
    {:ok, route} =
      Transit.create_route(%{
        code: "RT-333",
        name: "Ruta 333",
        origin: "Punto A",
        destination: "Punto B",
        status: "ACTIVA"
      })

    ref =
      push(socket, "send_alert", %{
        "route_id" => route.id,
        "message" => "Accidente en vía",
        "severity" => "CRITICAL"
      })

    assert_reply ref, :ok, %{alert_id: _alert_id}, 2000

    assert_broadcast "new_alert", %{
      message: "Accidente en vía",
      severity: "CRITICAL"
    }
  end

  test "passenger is rejected when attempting to send alert", %{passenger_socket: socket} do
    ref =
      push(socket, "send_alert", %{
        "route_id" => 1,
        "message" => "Alerta no autorizada",
        "severity" => "CRITICAL"
      })

    assert_reply ref, :error, %{reason: reason}, 2000
    assert reason =~ "No autorizado"
  end

  test "driver can send telemetry within Piura", %{driver_socket: socket} do
    {:ok, route} =
      Transit.create_route(%{
        code: "RT-PIU-TEL-1",
        name: "Ruta Piura Test 1",
        origin: "P1",
        destination: "P2",
        status: "ACTIVA"
      })

    route_id = route.id

    ref =
      push(socket, "send_telemetry", %{
        "route_id" => route_id,
        "bus_id" => "BUS-PIU-01",
        "latitude" => -5.1974,
        "longitude" => -80.6268,
        "speed" => 42.0
      })

    assert_reply ref,
                 :ok,
                 %{
                   status: "telemetry_broadcasted",
                   bus_id: "BUS-PIU-01",
                   route_id: ^route_id,
                   route_code: "RT-PIU-TEL-1"
                 },
                 2000

    assert_broadcast "bus_location_updated", %{
      route_id: ^route_id,
      bus_id: "BUS-PIU-01",
      latitude: -5.1974,
      longitude: -80.6268,
      speed: 42.0
    }
  end

  test "driver can send telemetry using route_code instead of route_id", %{driver_socket: socket} do
    {:ok, route} =
      Transit.create_route(%{
        code: "RT-CODE-TEL",
        name: "Ruta Telemetria Codigo",
        origin: "P1",
        destination: "P2",
        status: "ACTIVA"
      })

    route_id = route.id

    ref =
      push(socket, "send_telemetry", %{
        "route_code" => "RT-CODE-TEL",
        "bus_id" => "BUS-PIU-02",
        "latitude" => -5.1974,
        "longitude" => -80.6268,
        "speed" => 35.0
      })

    assert_reply ref,
                 :ok,
                 %{
                   status: "telemetry_broadcasted",
                   bus_id: "BUS-PIU-02",
                   route_code: "RT-CODE-TEL",
                   route_id: ^route_id
                 },
                 2000

    assert_broadcast "bus_location_updated", %{
      route_code: "RT-CODE-TEL",
      route_id: ^route_id,
      bus_id: "BUS-PIU-02"
    }
  end

  test "passenger is rejected when attempting to send telemetry", %{passenger_socket: socket} do
    ref =
      push(socket, "send_telemetry", %{
        "route_id" => 1,
        "bus_id" => "BUS-FAKE",
        "latitude" => -5.1974,
        "longitude" => -80.6268
      })

    assert_reply ref, :error, %{reason: reason}, 2000
    assert reason =~ "No autorizado"
  end

  test "broadcasts status_changed when route status is updated via Transit context", %{
    passenger_socket: _socket
  } do
    {:ok, route} =
      Transit.create_route(%{
        code: "RT-444",
        name: "Ruta 444",
        origin: "Punto A",
        destination: "Punto B",
        status: "ACTIVA"
      })

    Transit.update_route_status(route.id, "DEMORADA")

    assert_broadcast "status_changed", %{
      route_id: route_id,
      code: "RT-444",
      old_status: "ACTIVA",
      new_status: "DEMORADA"
    }

    assert route_id == route.id
  end
end
