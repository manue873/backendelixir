# Backend ElixirPro – Plataforma de Monitoreo de Tránsito en Tiempo Real

Backend reactivo de alto rendimiento desarrollado en **Elixir / Phoenix Framework**, con persistencia transaccional en **PostgreSQL**, capa de consulta estructurada con **GraphQL (Absinthe)**, transmisión de eventos en tiempo real mediante **Phoenix Channels (WebSockets)**, y diseño de arquitectura distribuida para alta escalabilidad con **Valkey** y **Redpanda**.

---

## 1. Arquitectura General y Capas del Sistema

```text
┌──────────────────────────────────────────────────────────────────────────┐
│                             CAPA WEB / ENTRADA                           │
│  - Endpoint GraphQL (Absinthe): Consultas y mutaciones de catálogo       │
│  - Phoenix Channels: Canal WebSockets "transit:tracking" para eventos    │
│  - GraphiQL: Playground interactivo para pruebas y demostración visual   │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     │
┌────────────────────────────────────▼─────────────────────────────────────┐
│                          NÚCLEO DE NEGOCIO (CONTEXTO)                    │
│  - Contexto Transit: API pública interna del dominio de transporte       │
│  - Reglas de Integridad: Validación de códigos únicos, estados y tiempos │
│  - Emisor de Eventos: Publicación reactiva a Phoenix.PubSub              │
└───────────────────────┬───────────────────────────────┬──────────────────┘
                        │                               │
┌───────────────────────▼──────┐            ┌───────────▼──────────────────┐
│      PERSISTENCIA PRIMARIA   │            │     STREAMING & MEMORIA      │
│  - PostgreSQL: Tablas routes │            │  - Valkey: Caché y Presencia │
│    y route_alerts            │            │  - Redpanda: Ingesta Eventos │
└──────────────────────────────┘            └──────────────────────────────┘
```

---

## 2. Pila Tecnológica

| Componente | Tecnología | Propósito |
|---|---|---|
| **Lenguaje / Runtime** | Elixir 1.17+ / BEAM OTP | Concurrencia masiva, tolerancia a fallos y baja latencia. |
| **Framework Web** | Phoenix 1.8 | API HTTP, Enrutamiento y Supervisor OTP. |
| **Capa de Consulta** | Absinthe GraphQL 1.7+ | Consultas y mutaciones tipadas y desacopladas. |
| **Tiempo Real** | Phoenix Channels + Phoenix.PubSub | WebSockets bidireccionales con topic broadcast. |
| **Persistencia ACID** | PostgreSQL + Ecto SQL | Modelo relacional, llaves foráneas, índices e integridad. |
| **Caché en Caliente** | Valkey (Redis-compatible) | Estado efímero de buses y presencia geoespacial O(1). |
| **Streaming de Eventos**| Redpanda (Kafka-compatible) | Ingesta masiva y procesamiento asíncrono desacoplado. |

---

## 3. Instalación y Ejecución Local

### Prerrequisitos
- Elixir 1.17+ y Erlang/OTP 26+
- PostgreSQL corriendo localmente

### Pasos de inicialización
```bash
# 1. Instalar dependencias
mix deps.get

# 2. Crear y migrar la base de datos con semillas
mix ecto.setup

# 3. Iniciar el servidor Phoenix
mix phx.server
# O en modo interactivo IEx:
iex -S mix phx.server
```

El servidor estará disponible en `http://localhost:4000`.

---

## 4. Autenticación y Control de Acceso por Roles (RBAC con Phoenix.Token)

El sistema cuenta con autenticación nativa y control de acceso basado en roles (**RBAC**):

| Rol | Identificador | Permisos Principales |
|---|---|---|
| **Conductor** | `CONDUCTOR` | Emitir telemetría GPS (`send_telemetry`), reportar alertas (`send_alert`), cambiar estado de ruta (`updateRouteStatus`). |
| **Pasajero** | `PASAJERO` | Consultar catálogo de rutas (`routes`), ver paraderos y escuchar eventos en vivo (`bus_location_updated`, `route_alert`). |
| **Administrador**| `ADMIN` | Crear nuevas rutas (`createRoute`), registrar paraderos (`createStop`), gestionar el sistema completo. |

### Cuentas de Prueba Pre-configuradas (Semillas):
- **Conductor:** `conductor@piura.pe` / `Password123!` (Rol: `CONDUCTOR`)
- **Pasajero:** `pasajero@piura.pe` / `Password123!` (Rol: `PASAJERO`)
- **Administrador:** `admin@piura.pe` / `Password123!` (Rol: `ADMIN`)

---

## 5. Pruebas y Explorador GraphQL (GraphiQL)

Visita el playground interactivo en:
👉 **`http://localhost:4000/api/graphiql`**

### Autenticación en GraphQL:

#### Iniciar Sesión (Login):
```graphql
mutation Login {
  login(input: {
    email: "conductor@piura.pe"
    password: "Password123!"
  }) {
    token
    user {
      id
      email
      name
      role
    }
  }
}
```

> **Para autenticar tus peticiones en GraphiQL:**
> En la sección inferior **"Headers"** de GraphiQL, agrega:
> ```json
> {
>   "Authorization": "Bearer PEGA_AQUI_TU_TOKEN"
> }
> ```

#### Consultar mi perfil (`me`):
```graphql
query GetMyProfile {
  me {
    id
    email
    name
    role
  }
}
```

#### Listado general de rutas con paraderos y alertas:
```graphql
query GetRoutes {
  routes {
    id
    code
    name
    origin
    destination
    status
    stops {
      id
      name
      sequence
      latitude
      longitude
    }
    alerts {
      id
      message
      severity
      insertedAt
    }
  }
}
```

#### Consulta de ruta puntual por identificador único:
```graphql
query GetRouteById {
  route(id: "1") {
    id
    code
    name
    status
    stops {
      name
      sequence
    }
  }
}
```

#### Búsqueda por código de ruta:
```graphql
query GetRouteByCode {
  routeByCode(code: "RT-101") {
    id
    code
    name
    status
  }
}
```

### Mutaciones (Mutations) de ejemplo:

#### Crear una nueva ruta:
```graphql
mutation CreateRoute {
  createRoute(input: {
    code: "RT-404"
    name: "Expreso Sur - Aeropuerto"
    origin: "Portal Sur"
    destination: "Terminal Aérea"
    status: ACTIVA
  }) {
    id
    code
    name
    status
    insertedAt
  }
}
```

#### Actualizar estado operativo (dispara evento WebSocket en tiempo real):
```graphql
mutation UpdateRouteStatus {
  updateRouteStatus(id: "1", status: DEMORADA) {
    id
    code
    name
    status
    updatedAt
  }
}
```

#### Crear alerta para una ruta:
```graphql
mutation CreateAlert {
  createAlert(input: {
    route_id: "1"
    message: "Congestión por manifestación en carril central"
    severity: WARNING
  }) {
    id
    message
    severity
    insertedAt
  }
}
```

---

## 5. WebSockets en Tiempo Real (Phoenix Channels)

- **Punto de conexión (Endpoint):** `ws://localhost:4000/socket/websocket`
- **Tópico principal:** `"transit:tracking"`

### Eventos emitidos automáticamente por el servidor:
- `route_status_changed`: Notifica a los clientes cuando una ruta cambia su estado operativo (e.g. `ACTIVA` -> `DEMORADA`).
- `route_created`: Notifica cuando se añade una nueva ruta al sistema.
- `route_alert`: Notifica la creación de una nueva alerta de tráfico/incidente.

### Eventos entrantes (enviados por operadores/despachadores):
- `send_alert`: Envía un objeto `%{"route_id" => "1", "message" => "Vía bloqueada", "severity" => "CRITICAL"}` que se persiste en BD y se retransmite a todos los clientes.
- `update_status`: Envía `%{"route_id" => "1", "status" => "MANTENIMIENTO"}`.

### Ejemplo de conexión con Phoenix JS Client:
```javascript
import { Socket } from "phoenix";

const socket = new Socket("ws://localhost:4000/socket");
socket.connect();

const channel = socket.channel("transit:tracking", {});

channel.join()
  .receive("ok", resp => console.log("Conectado al canal de tránsito:", resp))
  .receive("error", resp => console.error("Error al conectar:", resp));

channel.on("route_status_changed", payload => {
  console.log("🔔 Cambio de estado de ruta:", payload);
});

channel.on("route_alert", payload => {
  console.log("⚠️ Alerta operativa:", payload);
});
```

---

## 6. Sustentación de Arquitectura de Alta Escalabilidad (Valkey + Redpanda)

Para escenarios de alta concurrencia masiva (miles de buses enviando GPS por segundo y millones de usuarios consultando tiempos de llegada):

### Rol de Valkey (Caché en Memoria y Presencia en Vivo):
1. **Almacenamiento de Estado Caliente (Hot State):** Almacena la última coordenada geográfica de cada unidad activa mediante estructuras Hash (`bus:{id}:state`) con TTL de 60 segundos. Permite consultas geoespaciales `GEORADIUS` en O(1) con latencia < 1ms sin sobrecargar PostgreSQL.
2. **Pub/Sub Distribuido:** En clústeres horizontales de múltiples servidores Phoenix, Valkey sincroniza la distribución de eventos entre todos los nodos interconectados.

### Rol de Redpanda (Streaming de Eventos Kafka-Compatible):
1. **Buffer Inmutable y Desacoplado:** Ingesta directa de telemetría IoT mediante el topic `transit.telemetry.raw`. Garantiza tolerancia a fallos y elimina la contención de conexiones en la base de datos relacional.
2. **Procesamiento Asíncrono:** Permite que consumidores independientes (microservicios de analítica, modelos de Machine Learning para estimación de ETA predictivo y archivadores históricos) procesen los datos en paralelo sin bloquear el ciclo de petición/respuesta de los usuarios.

---

## 7. Ejecución de la Suite de Pruebas

```bash
# Ejecutar pruebas unitarias e integración
mix test

# Ejecutar verificación estricta pre-commit (formato, advertencias como error, pruebas)
mix precommit
```
