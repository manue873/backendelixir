defmodule BackendelixirWeb.SchemaTest do
  use BackendelixirWeb.ConnCase

  alias Backendelixir.Accounts
  alias Backendelixir.Transit

  @register_mutation """
  mutation Register($input: RegisterInput!) {
    register(input: $input) {
      token
      user {
        id
        email
        name
        role
      }
    }
  }
  """

  @login_mutation """
  mutation Login($input: LoginInput!) {
    login(input: $input) {
      token
      user {
        id
        email
        name
        role
      }
    }
  }
  """

  @me_query """
  query Me {
    me {
      id
      email
      name
      role
    }
  }
  """

  @create_route_mutation """
  mutation CreateRoute($input: CreateRouteInput!) {
    createRoute(input: $input) {
      id
      code
      name
      origin
      destination
      status
    }
  }
  """

  @update_status_mutation """
  mutation UpdateStatus($id: ID!, $status: RouteStatus!) {
    updateRouteStatus(id: $id, status: $status) {
      id
      code
      status
    }
  }
  """

  @routes_query """
  query GetRoutes {
    routes {
      id
      code
      name
      status
      stops {
        id
        name
        sequence
      }
    }
  }
  """

  @route_by_id_query """
  query GetRoute($id: ID!) {
    route(id: $id) {
      id
      code
      name
      status
    }
  }
  """

  describe "authentication mutations and me query" do
    test "mutation register creates a user and returns token", %{conn: conn} do
      variables = %{
        "input" => %{
          "email" => "nuevo.pasajero@piura.pe",
          "name" => "Carlos Pasajero",
          "password" => "Password123!",
          "role" => "PASAJERO"
        }
      }

      conn =
        post(conn, "/api/graphql", %{"query" => @register_mutation, "variables" => variables})

      assert %{
               "data" => %{
                 "register" => %{
                   "token" => token,
                   "user" => %{
                     "email" => "nuevo.pasajero@piura.pe",
                     "name" => "Carlos Pasajero",
                     "role" => "PASAJERO"
                   }
                 }
               }
             } = json_response(conn, 200)

      assert is_binary(token)
    end

    test "mutation login authenticates valid credentials and returns token", %{conn: conn} do
      {:ok, _user} =
        Accounts.register_user(%{
          email: "login.chofer@piura.pe",
          name: "Chofer Login",
          password: "Password123!",
          role: "CONDUCTOR"
        })

      variables = %{
        "input" => %{
          "email" => "login.chofer@piura.pe",
          "password" => "Password123!"
        }
      }

      conn = post(conn, "/api/graphql", %{"query" => @login_mutation, "variables" => variables})

      assert %{
               "data" => %{
                 "login" => %{
                   "token" => token,
                   "user" => %{
                     "email" => "login.chofer@piura.pe",
                     "role" => "CONDUCTOR"
                   }
                 }
               }
             } = json_response(conn, 200)

      assert is_binary(token)
    end

    test "query me returns authenticated user profile when token is provided", %{conn: conn} do
      {:ok, user} =
        Accounts.register_user(%{
          email: "perfil@piura.pe",
          name: "Perfil Usuario",
          password: "Password123!",
          role: "PASAJERO"
        })

      token = Accounts.generate_user_token(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post("/api/graphql", %{"query" => @me_query})

      assert %{
               "data" => %{
                 "me" => %{
                   "email" => "perfil@piura.pe",
                   "name" => "Perfil Usuario",
                   "role" => "PASAJERO"
                 }
               }
             } = json_response(conn, 200)
    end

    test "query me returns error when not authenticated", %{conn: conn} do
      conn = post(conn, "/api/graphql", %{"query" => @me_query})
      assert %{"errors" => [error | _]} = json_response(conn, 200)
      assert error["message"] =~ "No autenticado"
    end
  end

  describe "RBAC authorization on transit operations" do
    setup do
      {:ok, admin} =
        Accounts.register_user(%{
          email: "admin.rbac@piura.pe",
          name: "Admin",
          password: "Password123!",
          role: "ADMIN"
        })

      {:ok, driver} =
        Accounts.register_user(%{
          email: "driver.rbac@piura.pe",
          name: "Driver",
          password: "Password123!",
          role: "CONDUCTOR"
        })

      {:ok, passenger} =
        Accounts.register_user(%{
          email: "passenger.rbac@piura.pe",
          name: "Passenger",
          password: "Password123!",
          role: "PASAJERO"
        })

      admin_token = Accounts.generate_user_token(admin)
      driver_token = Accounts.generate_user_token(driver)
      passenger_token = Accounts.generate_user_token(passenger)

      %{
        admin_token: admin_token,
        driver_token: driver_token,
        passenger_token: passenger_token
      }
    end

    test "mutation createRoute succeeds for ADMIN", %{conn: conn, admin_token: token} do
      variables = %{
        "input" => %{
          "code" => "RT-ADM-01",
          "name" => "Ruta Admin",
          "origin" => "Centro",
          "destination" => "Castilla",
          "status" => "ACTIVA"
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post("/api/graphql", %{"query" => @create_route_mutation, "variables" => variables})

      assert %{"data" => %{"createRoute" => %{"code" => "RT-ADM-01"}}} = json_response(conn, 200)
    end

    test "mutation createRoute is rejected for PASSENGER or unauthenticated", %{
      conn: conn,
      passenger_token: token
    } do
      variables = %{
        "input" => %{
          "code" => "RT-PAS-01",
          "name" => "Ruta Ilegal",
          "origin" => "A",
          "destination" => "B",
          "status" => "ACTIVA"
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post("/api/graphql", %{"query" => @create_route_mutation, "variables" => variables})

      assert %{"errors" => [error | _]} = json_response(conn, 200)
      assert error["message"] =~ "No autorizado: se requiere rol de Administrador"
    end

    test "mutation updateRouteStatus succeeds for CONDUCTOR", %{
      conn: conn,
      driver_token: token
    } do
      {:ok, route} =
        Transit.create_route(%{
          code: "RT-DRV-01",
          name: "Ruta Chofer",
          origin: "Norte",
          destination: "Sur",
          status: "ACTIVA"
        })

      variables = %{
        "id" => to_string(route.id),
        "status" => "DEMORADA"
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post("/api/graphql", %{"query" => @update_status_mutation, "variables" => variables})

      assert %{"data" => %{"updateRouteStatus" => %{"status" => "DEMORADA"}}} =
               json_response(conn, 200)
    end

    test "mutation updateRouteStatus is rejected for PASSENGER", %{
      conn: conn,
      passenger_token: token
    } do
      {:ok, route} =
        Transit.create_route(%{
          code: "RT-BLOCKED-01",
          name: "Ruta",
          origin: "A",
          destination: "B",
          status: "ACTIVA"
        })

      variables = %{
        "id" => to_string(route.id),
        "status" => "DEMORADA"
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post("/api/graphql", %{"query" => @update_status_mutation, "variables" => variables})

      assert %{"errors" => [error | _]} = json_response(conn, 200)
      assert error["message"] =~ "No autorizado: se requiere rol de Conductor"
    end
  end

  describe "public catalog queries" do
    test "query routes returns list of routes without authentication", %{conn: conn} do
      {:ok, _route} =
        Transit.create_route(%{
          code: "RT-PUB-01",
          name: "Ruta Publica",
          origin: "P1",
          destination: "P2",
          status: "ACTIVA"
        })

      conn = post(conn, "/api/graphql", %{"query" => @routes_query})

      assert %{"data" => %{"routes" => routes}} = json_response(conn, 200)
      assert Enum.any?(routes, fn r -> r["code"] == "RT-PUB-01" end)
    end

    test "query route by id returns the exact route", %{conn: conn} do
      {:ok, route} =
        Transit.create_route(%{
          code: "RT-PUB-02",
          name: "Ruta Oriente",
          origin: "Estación A",
          destination: "Estación B",
          status: "MANTENIMIENTO"
        })

      conn =
        post(conn, "/api/graphql", %{
          "query" => @route_by_id_query,
          "variables" => %{"id" => to_string(route.id)}
        })

      assert %{
               "data" => %{
                 "route" => %{
                   "code" => "RT-PUB-02",
                   "status" => "MANTENIMIENTO"
                 }
               }
             } = json_response(conn, 200)
    end

    test "query searchRoutes returns matching routes by term", %{conn: conn} do
      {:ok, _} =
        Transit.create_route(%{
          code: "RT-SRCH-A",
          name: "Línea Castilla Express",
          origin: "Terminal Castilla",
          destination: "UDEP",
          status: "ACTIVA"
        })

      query = """
      query Search($query: String!) {
        searchRoutes(query: $query) {
          code
          name
        }
      }
      """

      conn =
        post(conn, "/api/graphql", %{"query" => query, "variables" => %{"query" => "castilla"}})

      assert %{"data" => %{"searchRoutes" => results}} = json_response(conn, 200)
      assert length(results) >= 1
      assert Enum.any?(results, fn r -> r["code"] == "RT-SRCH-A" end)
    end

    test "mutation createAlert resolves route by route_code", %{conn: conn} do
      {:ok, driver} =
        Accounts.register_user(%{
          email: "alert.driver@piura.pe",
          name: "Alert Driver",
          password: "Password123!",
          role: "CONDUCTOR"
        })

      token = Accounts.generate_user_token(driver)

      {:ok, _route} =
        Transit.create_route(%{
          code: "RT-CODE-ALERT",
          name: "Ruta Code Alert",
          origin: "Orig",
          destination: "Dest",
          status: "ACTIVA"
        })

      mutation = """
      mutation CreateAlertByCode($input: CreateAlertInput!) {
        createAlert(input: $input) {
          id
          message
          severity
        }
      }
      """

      variables = %{
        "input" => %{
          "route_code" => "RT-CODE-ALERT",
          "message" => "Alerta por código exitosa",
          "severity" => "WARNING"
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post("/api/graphql", %{"query" => mutation, "variables" => variables})

      assert %{
               "data" => %{
                 "createAlert" => %{
                   "message" => "Alerta por código exitosa",
                   "severity" => "WARNING"
                 }
               }
             } = json_response(conn, 200)
    end
  end
end
