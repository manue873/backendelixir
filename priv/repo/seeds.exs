alias Backendelixir.Repo
alias Backendelixir.Transit.{Route, Stop, RouteAlert}
alias Backendelixir.Accounts

# Limpieza inicial y reseteo de secuencias de IDs (para que Route 1 sea ID 1, Route 2 sea ID 2, etc.)
Ecto.Adapters.SQL.query!(
  Repo,
  "TRUNCATE TABLE route_alerts, stops, routes, users RESTART IDENTITY CASCADE;"
)

# ==============================================================================
# USUARIOS DEL SISTEMA (ROLES: CONDUCTOR, PASAJERO, ADMIN)
# ==============================================================================
{:ok, driver_user} =
  Accounts.register_user(%{
    email: "conductor@piura.pe",
    name: "Juan Chofer Castilla",
    password: "Password123!",
    role: "CONDUCTOR"
  })

{:ok, _passenger_user} =
  Accounts.register_user(%{
    email: "pasajero@piura.pe",
    name: "María Pasajera UDEP",
    password: "Password123!",
    role: "PASAJERO"
  })

{:ok, _admin_user} =
  Accounts.register_user(%{
    email: "admin@piura.pe",
    name: "Admin Transporte Piura",
    password: "Password123!",
    role: "ADMIN"
  })

driver_token = Accounts.generate_user_token(driver_user)

IO.puts("👤 Usuarios sembrados:")
IO.puts("   - Conductor: conductor@piura.pe (Password123!)")
IO.puts("   - Pasajero:  pasajero@piura.pe  (Password123!)")
IO.puts("   - Admin:     admin@piura.pe     (Password123!)")
IO.puts("   🔑 Token de prueba para Conductor: #{driver_token}")

# ==============================================================================
# RUTA 1: Troncal Castilla - Centro - Universidad de Piura (UDEP)
# ==============================================================================
route1 =
  Repo.insert!(%Route{
    code: "RT-PIU-01",
    name: "Línea 01: Castilla - Plaza de Armas - UDEP",
    origin: "Terminal Terrestre de Castilla (Av. Progreso)",
    destination: "Campus Universidad de Piura (UDEP - San Ramón)",
    status: "ACTIVA"
  })

Repo.insert!(%Stop{
  route_id: route1.id,
  name: "Paradero 1 - Terminal Castilla (Av. Progreso)",
  sequence: 1,
  latitude: -5.1989,
  longitude: -80.6185
})

Repo.insert!(%Stop{
  route_id: route1.id,
  name: "Paradero 2 - Puente Sánchez Cerro / Open Plaza",
  sequence: 2,
  latitude: -5.1932,
  longitude: -80.6234
})

Repo.insert!(%Stop{
  route_id: route1.id,
  name: "Paradero 3 - Plaza de Armas de Piura (Catedral)",
  sequence: 3,
  latitude: -5.1974,
  longitude: -80.6268
})

Repo.insert!(%Stop{
  route_id: route1.id,
  name: "Paradero 4 - Óvalo Grau / Av. Loreto",
  sequence: 4,
  latitude: -5.1945,
  longitude: -80.6321
})

Repo.insert!(%Stop{
  route_id: route1.id,
  name: "Paradero 5 - Campus Principal Universidad de Piura (UDEP)",
  sequence: 5,
  latitude: -5.1742,
  longitude: -80.6358
})

Repo.insert!(%RouteAlert{
  route_id: route1.id,
  message: "Flujo vehicular continuo en Av. Progreso y Puente Sánchez Cerro.",
  severity: "INFO"
})

# ==============================================================================
# RUTA 2: Corredor Av. Sánchez Cerro - Mercado Modelo - Real Plaza
# ==============================================================================
route2 =
  Repo.insert!(%Route{
    code: "RT-PIU-02",
    name: "Línea 02: Los Algarrobos - Av. Sánchez Cerro - Real Plaza",
    origin: "Sector Los Algarrobos (Sector Oeste)",
    destination: "Centro Comercial Real Plaza Piura",
    status: "DEMORADA"
  })

Repo.insert!(%Stop{
  route_id: route2.id,
  name: "Paradero 1 - Terminal Los Algarrobos",
  sequence: 1,
  latitude: -5.1820,
  longitude: -80.6550
})

Repo.insert!(%Stop{
  route_id: route2.id,
  name: "Paradero 2 - Óvalo Cáceres / Av. Sánchez Cerro",
  sequence: 2,
  latitude: -5.1870,
  longitude: -80.6410
})

Repo.insert!(%Stop{
  route_id: route2.id,
  name: "Paradero 3 - Mercado Modelo de Piura",
  sequence: 3,
  latitude: -5.1925,
  longitude: -80.6285
})

Repo.insert!(%Stop{
  route_id: route2.id,
  name: "Paradero 4 - Terminal Terrestre Gechisa",
  sequence: 4,
  latitude: -5.1950,
  longitude: -80.6380
})

Repo.insert!(%Stop{
  route_id: route2.id,
  name: "Paradero 5 - Centro Comercial Real Plaza (Av. Sánchez Cerro)",
  sequence: 5,
  latitude: -5.1910,
  longitude: -80.6480
})

Repo.insert!(%RouteAlert{
  route_id: route2.id,
  message:
    "Congestión vehicular severa en inmediaciones del Mercado Modelo por comercio y obras viales. Retraso aprox: 15-20 min.",
  severity: "WARNING"
})

# ==============================================================================
# RUTA 3: Interurbana Piura Centro - Catacaos (Capital Artesanal)
# ==============================================================================
route3 =
  Repo.insert!(%Route{
    code: "RT-PIU-03",
    name: "Línea 03: Piura Centro - UNP - Catacaos",
    origin: "Óvalo Bolognesi (Piura Centro)",
    destination: "Plaza de Armas de Catacaos (Calle Comercio)",
    status: "MANTENIMIENTO"
  })

Repo.insert!(%Stop{
  route_id: route3.id,
  name: "Paradero 1 - Óvalo Bolognesi",
  sequence: 1,
  latitude: -5.1990,
  longitude: -80.6310
})

Repo.insert!(%Stop{
  route_id: route3.id,
  name: "Paradero 2 - Universidad Nacional de Piura (UNP - Campus Miraflores)",
  sequence: 2,
  latitude: -5.1840,
  longitude: -80.6150
})

Repo.insert!(%Stop{
  route_id: route3.id,
  name: "Paradero 3 - Entrada a Catacaos / Cruce Simbilá",
  sequence: 3,
  latitude: -5.2520,
  longitude: -80.6690
})

Repo.insert!(%Stop{
  route_id: route3.id,
  name: "Paradero 4 - Plaza de Armas de Catacaos / Calle Comercio",
  sequence: 4,
  latitude: -5.2670,
  longitude: -80.6750
})

Repo.insert!(%RouteAlert{
  route_id: route3.id,
  message: "Mantenimiento preventivo de flota interurbana. Salidas cada 30 minutos.",
  severity: "CRITICAL"
})

IO.puts(
  "✅ Semillas de Piura cargadas exitosamente (3 usuarios con roles, 3 rutas principales de Piura, 14 paraderos con coordenadas GPS y 3 alertas)."
)
