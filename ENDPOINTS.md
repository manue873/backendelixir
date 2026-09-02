# 📖 Catálogo de Endpoints, Entradas y Salidas (API GraphQL y WebSockets)

Documentación completa de todos los contratos de comunicación del backend **ElixirPro - Sistema de Tránsito de Piura, Perú**.

---

## 🌐 1. Puntos de Entrada Generales

| Protocolo | URL / Ruta | Método | Descripción |
|---|---|---|---|
| **GraphQL API** | `http://localhost:4000/api/graphql` | `POST` | Punto único para todas las consultas (`queries`) y mutaciones (`mutations`). |
| **GraphiQL Playground** | `http://localhost:4000/api/graphiql` | `GET` | Explorador interactivo para pruebas desde el navegador. |
| **Phoenix WebSockets** | `ws://localhost:4000/socket/websocket` | `WS` | Conexión bidireccional en tiempo real para GPS, alertas y estados de ruta. |

---

## 👥 2. Matriz de Roles y Permisos (RBAC)

| Rol | Identificador | Permisos |
|---|---|---|
| **Público / Pasajero** | `PASAJERO` / Anónimo | Consultar rutas, paraderos, alertas y suscribirse a telemetría GPS en vivo. |
| **Conductor** | `CONDUCTOR` | Todo lo de Pasajero + Emitir telemetría GPS (`send_telemetry`), reportar alertas (`createAlert` / `send_alert`), cambiar estado operativo (`updateRouteStatus`). |
| **Administrador** | `ADMIN` | Control total del sistema + Crear rutas (`createRoute`) y agregar paraderos (`createStop`). |

### 🔑 Cuentas de Prueba Pre-sembradas en Base de Datos:
- **Conductor:** `conductor@piura.pe` | Contraseña: `Password123!`
- **Pasajero:** `pasajero@piura.pe` | Contraseña: `Password123!`
- **Administrador:** `admin@piura.pe` | Contraseña: `Password123!`

---

## 📡 3. Catálogo de Operaciones GraphQL (`POST /api/graphql`)

---

### 3.1. `mutation register` (Registro de Usuario)
Crea una cuenta en la plataforma y retorna su token de sesión.

* **Rol requerido:** Público (Cualquiera).
* **Header:** `Content-Type: application/json`

#### 📥 Datos de Entrada (Request):
```graphql
mutation RegistrarUsuario($input: RegisterInput!) {
  register(input: $input) {
    token
    user {
      id
      email
      name
      role
      insertedAt
    }
  }
}
```
**Variables:**
```json
{
  "input": {
    "email": "nuevo.conductor@piura.pe",
    "name": "Pedro Castillo Chofer",
    "password": "Password123!",
    "role": "CONDUCTOR"
  }
}
```
*(Valores válidos para `role`: `CONDUCTOR`, `PASAJERO`, `ADMIN`. Si se omite, toma `PASAJERO`).*

#### 📤 Datos de Salida (Response - HTTP 200):
```json
{
  "data": {
    "register": {
      "token": "SFMyNTY.g2gDbQAAAAh1c2VyX2lkbAAAAAFtAAAADGNvbmR1Y3Rvcl9waXVyYW0AAAAJY29uZHVjdG9ybgYA...",
      "user": {
        "id": "4",
        "email": "nuevo.conductor@piura.pe",
        "name": "Pedro Castillo Chofer",
        "role": "CONDUCTOR",
        "insertedAt": "2026-09-01T21:30:00Z"
      }
    }
  }
}
```

---

### 3.2. `mutation login` (Inicio de Sesión)
Autentica con correo y contraseña, retornando el usuario y su Bearer Token nativo.

* **Rol requerido:** Público.
* **Header:** `Content-Type: application/json`

#### 📥 Datos de Entrada (Request):
```graphql
mutation IniciarSesion($input: LoginInput!) {
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
```
**Variables:**
```json
{
  "input": {
    "email": "conductor@piura.pe",
    "password": "Password123!"
  }
}
```

#### 📤 Datos de Salida (Response Exitosa):
```json
{
  "data": {
    "login": {
      "token": "SFMyNTY.g2gDbQAAAAh1c2VyX2lkbAAAAAFtAAAAEGNvbmR1Y3RvckBwaXVyYS5wZW0AAAAJQ09ORFVDVE9SbgYA...",
      "user": {
        "id": "1",
        "email": "conductor@piura.pe",
        "name": "Juan Chofer Castilla",
        "role": "CONDUCTOR"
      }
    }
  }
}
```

#### ❌ Error por Credenciales Incorrectas:
```json
{
  "errors": [
    {
      "message": "Credenciales inválidas: correo o contraseña incorrectos"
    }
  ],
  "data": {
    "login": null
  }
}
```

---

### 3.3. `query me` (Perfil del Usuario Autenticado)
Obtiene el perfil del usuario a partir de su Bearer Token.

* **Rol requerido:** Cualquier usuario autenticado (`CONDUCTOR`, `PASAJERO`, `ADMIN`).
* **Header requerido:** `Authorization: Bearer <TOKEN>`

#### 📥 Datos de Entrada (Request):
```graphql
query VerMiPerfil {
  me {
    id
    email
    name
    role
    insertedAt
  }
}
```

#### 📤 Datos de Salida (Response):
```json
{
  "data": {
    "me": {
      "id": "1",
      "email": "conductor@piura.pe",
      "name": "Juan Chofer Castilla",
      "role": "CONDUCTOR",
      "insertedAt": "2026-09-01T21:27:17Z"
    }
  }
}
```

---

### 3.4. `query routes` (Catálogo de Rutas de Piura)
Obtiene todas las rutas activas, sus paraderos con coordenadas GPS y alertas activas.

* **Rol requerido:** Público / Todos los roles.
* **Header:** Opcional.

#### 📥 Datos de Entrada (Request):
```graphql
query ObtenerRutas {
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

#### 📤 Datos de Salida (Response):
```json
{
  "data": {
    "routes": [
      {
        "id": "1",
        "code": "RT-PIU-01",
        "name": "Línea 01: Castilla - Plaza de Armas - UDEP",
        "origin": "Terminal Terrestre de Castilla (Av. Progreso)",
        "destination": "Campus Universidad de Piura (UDEP - San Ramón)",
        "status": "ACTIVA",
        "stops": [
          {
            "id": "1",
            "name": "Paradero 1 - Terminal Castilla (Av. Progreso)",
            "sequence": 1,
            "latitude": -5.1989,
            "longitude": -80.6185
          },
          {
            "id": "2",
            "name": "Paradero 2 - Puente Sánchez Cerro / Open Plaza",
            "sequence": 2,
            "latitude": -5.1932,
            "longitude": -80.6234
          }
        ],
        "alerts": [
          {
            "id": "1",
            "message": "Flujo vehicular continuo en Av. Progreso y Puente Sánchez Cerro.",
            "severity": "INFO",
            "insertedAt": "2026-09-01T21:27:18Z"
          }
        ]
      }
    ]
  }
}
```

---

### 3.5. `query searchRoutes` (Búsqueda Inteligente por Término)
Busca rutas por coincidencia parcial en nombre, código, origen o destino (insensible a mayúsculas y acentos).

* **Rol requerido:** Público / Todos.

#### 📥 Datos de Entrada (Request):
```graphql
query BuscarRutasPorPalabraClave($query: String!) {
  searchRoutes(query: $query) {
    id
    code
    name
    origin
    destination
    status
  }
}
```
**Variables:**
```json
{
  "query": "Catacaos"
}
```

---

### 3.6. `query activeBuses` (Buses Activos en Caché Valkey)
Consulta instantánea (sub-milisegundo) a la base de datos en memoria **Valkey** de todos los buses que están transmitiendo telemetría en Piura (opcionalmente filtrados por ruta).

* **Origen de datos:** Caché en memoria **Valkey (Redis-compatible)** vía `Redix`.

#### 📥 Datos de Entrada (Request):
```graphql
query ObtenerBusesEnVivo($route_id: ID) {
  activeBuses(routeId: $route_id) {
    busId
    routeId
    routeCode
    routeName
    latitude
    longitude
    speed
    timestamp
  }
}
```
**Variables (Opcionales):**
```json
{
  "route_id": "1"
}
```

#### 📤 Datos de Salida (Response):
```json
{
  "data": {
    "activeBuses": [
      {
        "busId": "BUS-PIU-01",
        "routeId": "1",
        "routeCode": "RT-PIU-01",
        "routeName": "Línea 01: Castilla - Plaza de Armas - UDEP",
        "latitude": -5.1974,
        "longitude": -80.6268,
        "speed": 38.5,
        "timestamp": "2026-09-01T23:45:10Z"
      }
    ]
  }
}
```

---

### 3.7. `query busLocation` (Última Posición de un Bus en Valkey)
Obtiene la posición en tiempo real de una unidad específica almacenada en el caché de Valkey.

#### 📥 Datos de Entrada (Request):
```graphql
query PosicionDeBus($busId: String!) {
  busLocation(busId: $busId) {
    busId
    routeCode
    latitude
    longitude
    speed
    timestamp
  }
}
```
**Variables:**
```json
{
  "busId": "BUS-PIU-01"
}
```

---

### 3.8. `query auditLogs` (Historial Inmutable de Auditoría)
Consulta los registros de auditoría generados por eventos de dominio (inicios de sesión, cambios de estado operativo de rutas, creación de alertas).

* **Origen de datos:** Tabla inmutable `audit_logs` alimentada por el stream de **Redpanda + Broadway**.

#### 📥 Datos de Entrada (Request):
```graphql
query VerAuditoria($eventType: String, $limit: Int) {
  auditLogs(eventType: $eventType, limit: $limit) {
    id
    eventType
    actorRole
    actorEmail
    resourceType
    resourceId
    payload
    recordedAt
  }
}
```
**Variables:**
```json
{
  "eventType": "ROUTE_STATUS_CHANGED",
  "limit": 20
}
```

#### 📤 Datos de Salida (Response):
```json
{
  "data": {
    "auditLogs": [
      {
        "id": "1",
        "eventType": "ROUTE_STATUS_CHANGED",
        "actorRole": "CONDUCTOR",
        "actorEmail": "conductor@piura.pe",
        "resourceType": "Route",
        "resourceId": "1",
        "payload": "{\"code\":\"RT-PIU-01\",\"new_status\":\"DEMORADA\"}",
        "recordedAt": "2026-09-02T01:15:30Z"
      }
    ]
  }
}
```

---

### 3.9. `query historicalBusLocations` (Trazabilidad GPS por Lotes)
Permite consultar el histórico de recorridos y telemetría persistido por lotes mediante el diezmado temporal de 15 segundos.

* **Origen de datos:** Tabla `bus_location_logs` persistida por el consumidor **Broadway** desde el topic `transit.telemetry.v1`.

#### 📥 Datos de Entrada (Request):
```graphql
query HistorialGPS($busId: String, $limit: Int) {
  historicalBusLocations(busId: $busId, limit: $limit) {
    id
    busId
    routeCode
    latitude
    longitude
    speed
    recordedAt
  }
}
```
**Variables:**
```json
{
  "busId": "BUS-PIU-01",
  "limit": 50
}
```

---

### 3.10. `query routeByName` (Búsqueda Exacta por Nombre)
Obtiene una ruta a partir de su nombre único.

#### 📥 Datos de Entrada (Request):
```graphql
query BuscarPorNombre($name: String!) {
  routeByName(name: $name) {
    id
    code
    name
    status
    stops { name sequence }
  }
}
```
**Variables:**
```json
{
  "name": "Línea 01: Castilla - Plaza de Armas - UDEP"
}
```

---

### 3.7. `query route` & `query route_by_code` (Buscar Ruta Individual)

#### 📥 Datos de Entrada (Request):
```graphql
query BuscarPorId($id: ID!) {
  route(id: $id) {
    id
    code
    name
    status
  }
}

# O por código único de Piura:
query BuscarPorCodigo($code: String!) {
  routeByCode(code: $code) {
    id
    code
    name
    status
  }
}
```
**Variables:**
```json
{ "id": "1", "code": "RT-PIU-01" }
```

---

### 3.8. `mutation createAlert` (Emitir Alerta por ID o por Código de Ruta)
Publica una alerta en la ruta especificada identificándola por `route_id`, `route_code` o `route_name`.

* **Rol requerido:** `CONDUCTOR` o `ADMIN`.
* **Header requerido:** `Authorization: Bearer <TOKEN>`
* **Valores válidos para `severity`:** `INFO`, `WARNING`, `CRITICAL`.

#### 📥 Datos de Entrada con Código de Ruta (Recomendado):
```graphql
mutation CrearAlertaPorCodigo($input: CreateAlertInput!) {
  createAlert(input: $input) {
    id
    message
    severity
    insertedAt
  }
}
```
**Variables:**
```json
{
  "input": {
    "route_code": "RT-PIU-01",
    "message": "Congestión por trabajos en Av. Sánchez Cerro frente a Real Plaza",
    "severity": "WARNING"
  }
}
```

#### 📤 Datos de Salida (Response):
```json
{
  "data": {
    "createAlert": {
      "id": "4",
      "message": "Congestión por trabajos en Av. Sánchez Cerro frente a Real Plaza",
      "severity": "WARNING",
      "insertedAt": "2026-09-01T21:45:00Z"
    }
  }
}
```

---

### 3.8. `mutation createRoute` (Crear Nueva Ruta)
Registra una nueva ruta de transporte en Piura.

* **Rol requerido:** `ADMIN`.
* **Header requerido:** `Authorization: Bearer <TOKEN_ADMIN>`

#### 📥 Datos de Entrada (Request):
```graphql
mutation RegistrarRuta($input: CreateRouteInput!) {
  createRoute(input: $input) {
    id
    code
    name
    origin
    destination
    status
  }
}
```
**Variables:**
```json
{
  "input": {
    "code": "RT-PIU-04",
    "name": "Línea 04: San Martín - Santa Ana - UPAO",
    "origin": "Urb. San Martín (Veintiséis de Octubre)",
    "destination": "Campus UPAO Piura",
    "status": "ACTIVA"
  }
}
```

#### 📤 Datos de Salida (Response):
```json
{
  "data": {
    "createRoute": {
      "id": "4",
      "code": "RT-PIU-04",
      "name": "Línea 04: San Martín - Santa Ana - UPAO",
      "origin": "Urb. San Martín (Veintiséis de Octubre)",
      "destination": "Campus UPAO Piura",
      "status": "ACTIVA"
    }
  }
}
```

---

### 3.9. `mutation createStop` (Crear Paradero en Piura)
Agrega un paradero georreferenciado con validación de límites de Piura.

* **Rol requerido:** `ADMIN`.
* **Header requerido:** `Authorization: Bearer <TOKEN_ADMIN>`
* **Límites geográficos obligatorios:**
  - Latitud: entre `-5.6000` y `-4.8000`
  - Longitud: entre `-81.3500` y `-80.0000`

#### 📥 Datos de Entrada (Request):
```graphql
mutation RegistrarParadero($input: CreateStopInput!) {
  createStop(input: $input) {
    id
    name
    sequence
    latitude
    longitude
  }
}
```
**Variables (Válidas en Piura):**
```json
{
  "input": {
    "route_id": "1",
    "name": "Paradero Hospital Regional José Cayetano Heredia",
    "sequence": 6,
    "latitude": -5.1890,
    "longitude": -80.6210
  }
}
```

#### 📤 Datos de Salida (Response):
```json
{
  "data": {
    "createStop": {
      "id": "15",
      "name": "Paradero Hospital Regional José Cayetano Heredia",
      "sequence": 6,
      "latitude": -5.1890,
      "longitude": -80.6210
    }
  }
}
```

#### ❌ Error si las coordenadas están fuera de Piura:
```json
{
  "errors": [
    {
      "message": "latitude: la latitud -12.0464 está fuera de la jurisdicción operativa de Piura, Perú (rango permitido: -5.6 a -4.8), longitude: la longitud -77.0428 está fuera de la jurisdicción operativa de Piura, Perú (rango permitido: -81.35 a -80.0)"
    }
  ]
}
```

---

## ⚡ 4. WebSockets en Tiempo Real (Phoenix Channels)

* **URL:** `ws://localhost:4000/socket/websocket`
* **Tópico principal:** `"transit:tracking"`

---

### 4.1. Conexión Inicial (`connect`)
Al establecer la conexión WebSocket:
- **Conductor:** Envía `params: { "token": "<TOKEN_CONDUCTOR>" }` ➔ El socket le asigna `role: "CONDUCTOR"`.
- **Pasajero:** Puede conectarse anónimo `params: {}` o con su token ➔ El socket le asigna `role: "PASAJERO"`.

---

### 4.2. Eventos Entrantes (Emitidos por el Cliente ➔ Servidor)

#### A. Emitir Telemetría GPS (`send_telemetry`)
* **Autorizado para:** Solo `CONDUCTOR` o `ADMIN`.
* **Validación:** Verifica que las coordenadas pertenezcan a Piura.

**Payload que envía el Conductor:**
```json
{
  "topic": "transit:tracking",
  "event": "send_telemetry",
  "payload": {
    "route_id": 1,
    "bus_id": "BUS-PIU-01",
    "latitude": -5.1974,
    "longitude": -80.6268,
    "speed": 38.5
  },
  "ref": "1"
}
```

**Respuesta recibida por el Conductor:**
```json
{
  "status": "ok",
  "response": {
    "status": "telemetry_broadcasted",
    "bus_id": "BUS-PIU-01"
  }
}
```

---

#### B. Emitir Alerta Rápida (`send_alert`)
* **Autorizado para:** Solo `CONDUCTOR` o `ADMIN`.

**Payload que envía el Conductor:**
```json
{
  "topic": "transit:tracking",
  "event": "send_alert",
  "payload": {
    "route_id": 1,
    "message": "Tráfico detenido por accidente menor",
    "severity": "CRITICAL"
  },
  "ref": "2"
}
```

---

#### C. Cambiar Estado Operativo (`update_status`)
* **Autorizado para:** Solo `CONDUCTOR` o `ADMIN`.

**Payload que envía el Conductor:**
```json
{
  "topic": "transit:tracking",
  "event": "update_status",
  "payload": {
    "route_id": 1,
    "status": "DEMORADA"
  },
  "ref": "3"
}
```

---

### 4.3. Eventos Salientes (Recibidos en Tiempo Real por los Pasajeros)

Todos los clientes conectados y suscritos a `"transit:tracking"` reciben automáticamente estos eventos:

#### 📡 1. Posición del Bus en Vivo (`bus_location_updated`):
```json
{
  "topic": "transit:tracking",
  "event": "bus_location_updated",
  "payload": {
    "route_id": 1,
    "bus_id": "BUS-PIU-01",
    "latitude": -5.1974,
    "longitude": -80.6268,
    "speed": 38.5,
    "timestamp": "2026-09-01T21:50:00.000Z"
  }
}
```

#### 🚨 2. Nueva Alerta en Ruta (`new_alert` / `route_alert`):
```json
{
  "topic": "transit:tracking",
  "event": "new_alert",
  "payload": {
    "id": 5,
    "route_id": 1,
    "message": "Tráfico detenido por accidente menor",
    "severity": "CRITICAL",
    "inserted_at": "2026-09-01T21:51:00Z"
  }
}
```

#### 🔄 3. Cambio de Estado de Ruta (`route_status_changed`):
```json
{
  "topic": "transit:tracking",
  "event": "route_status_changed",
  "payload": {
    "route_id": 1,
    "code": "RT-PIU-01",
    "name": "Línea 01: Castilla - Plaza de Armas - UDEP",
    "old_status": "ACTIVA",
    "new_status": "DEMORADA"
  }
}
```

---

## 💻 5. Ejemplos de Consumo desde el Frontend (JavaScript)

### Consumir GraphQL con `fetch`:
```javascript
async function loginAndGetProfile() {
  // 1. Iniciar Sesión
  const loginRes = await fetch("http://localhost:4000/api/graphql", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      query: `
        mutation {
          login(input: { email: "conductor@piura.pe", password: "Password123!" }) {
            token
          }
        }
      `
    })
  });
  const { data } = await loginRes.json();
  const token = data.login.token;

  // 2. Usar el Bearer Token en peticiones protegidas
  const profileRes = await fetch("http://localhost:4000/api/graphql", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${token}`
    },
    body: JSON.stringify({
      query: `query { me { id name email role } }`
    })
  });

  const profileData = await profileRes.json();
  console.log("Usuario autenticado:", profileData.data.me);
}
```

### Escuchar WebSockets con `phoenix` (npm package):
```javascript
import { Socket } from "phoenix";

// Conectar al socket
const socket = new Socket("ws://localhost:4000/socket", {
  params: { token: userToken } // Opcional para pasajeros
});
socket.connect();

// Unirse al canal de tránsito de Piura
const channel = socket.channel("transit:tracking", {});

// Escuchar actualización de GPS de buses en tiempo real
channel.on("bus_location_updated", (payload) => {
  console.log(`🚌 Bus ${payload.bus_id} en (${payload.latitude}, ${payload.longitude}) a ${payload.speed} km/h`);
});

// Escuchar nuevas alertas
channel.on("new_alert", (alert) => {
  console.warn(`🚨 Alerta en ruta ${alert.route_id}: ${alert.message} [${alert.severity}]`);
});

channel.join()
  .receive("ok", resp => console.log("Conectado al canal de tránsito de Piura", resp))
  .receive("error", resp => console.error("Error al unirse al canal", resp));
```
