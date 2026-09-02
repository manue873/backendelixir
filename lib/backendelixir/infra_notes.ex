defmodule Backendelixir.InfraNotes do
  @moduledoc """
  # Arquitectura de Alta Concurrencia y Escalabilidad: Valkey + Redpanda

  Este módulo documenta formalmente la justificación técnica y el diseño de integración
  para escalar el sistema de monitoreo de transporte a nivel masivo (cientos de miles de
  buses y millones de pasajeros concurrentes).

  ---

  ## 1. Rol y Justificación de Valkey (Caché en Memoria y Presencia en Tiempo Real)

  ### Problema en Arquitecturas Tradicionales:
  Si cada bus emite telemetría GPS cada 2 a 5 segundos, escribir y consultar directamente
  contra PostgreSQL causaría saturación de conexiones (pool exhaustion), bloqueos de I/O
  en disco y degradación en las consultas relacionales del catálogo de rutas.

  ### Solución con Valkey:
  Valkey (bifurcación comunitaria de alto rendimiento de Redis) actúa como un almacén clave-valor
  en memoria con tiempos de respuesta sub-milisegundo.

  1. **Almacenamiento de Última Posición Conocida (Hot State):**
     - Estructura: Hash de Valkey con clave `bus:{bus_id}:state` o `route:{route_id}:live`
     - Campos: `latitude`, `longitude`, `speed`, `heading`, `last_ping`, `status`
     - TTL (Time To Live): 60 segundos con auto-expiración en caso de que una unidad pierda señal.
     - Operaciones O(1): `HSET`, `HGETALL`, `GEOADD`, `GEORADIUS` para búsquedas espaciales inmediatas
       (e.g., "¿Qué buses están a menos de 500m del paradero X?").

  2. **Pub/Sub Distribuido entre Nodos Phoenix:**
     - En despliegues multi-nodo (clúster horizontal detrás de un Load Balancer), se utiliza
       el adaptador `Phoenix.PubSub.Redis` / `Valkey` para asegurar que un evento emitido
       en el Nodo A se propague instantáneamente a los WebSockets conectados en el Nodo B y Nodo C.

  ---

  ## 2. Rol y Justificación de Redpanda (Streaming e Ingesta Masiva de Eventos)

  ### Problema en Arquitecturas Tradicionales:
  Las bases de datos relacionales no son óptimas como colas de mensajes de alta velocidad.
  La pérdida de eventos o la saturación del backend web durante picos de tráfico afectaría
  la consistencia operativa.

  ### Solución con Redpanda:
  Redpanda es una plataforma de streaming de eventos distribuida, compatible con el protocolo
  de Apache Kafka, escrita en C++ sin dependencias de JVM ni Garbage Collection, optimizada para
  baja latencia y rendimiento de hardware NVMe.

  1. **Ingesta Desacoplada e Inmutable (Event Sourcing Buffer):**
     - Topics principales:
       - `transit.telemetry.raw`: Ingesta directa de coordenadas de buses enviadas por dispositivos IoT/GPS.
       - `transit.route.status_changes`: Eventos de cambios operativos ("ACTIVA" -> "DEMORADA").
       - `transit.alerts.dispatched`: Alertas emitidas por despachadores y operadores de tráfico.
     - Particionado: Las particiones se distribuyen por `route_id` o `bus_id`, garantizando orden estricto
       por entidad sin comprometer el paralelismo global.

  2. **Consumo Asíncrono para Analítica y Machine Learning:**
     - **Consumer 1 (Live Sync):** Proceso supervisor Elixir (vía librería `brod` o `klife`)
       que actualiza el estado caliente en Valkey y dispara WebSockets.
     - **Consumer 2 (Batch Archival):** Worker que consolida métricas y escribe en almacenamiento
       en frío (Data Lake / ClickHouse / BigQuery / TimescaleDB) para auditorías históricas y
       cálculo de tiempos promedio de viaje (ETA predictivo).

  ---

  ## 3. Diagrama de Flujo de Datos

  ```text
  [ Dispositivos GPS / Buses ]
             │ (Telemetría UDP/HTTP/MQTT)
             ▼
      [ Redpanda Stream ] ─── (Topic: transit.telemetry.raw)
             │
             ├──► [ Consumers Analítica / Histórico / BigData ]
             │
             ▼
    [ Phoenix Cluster / Elixir OTP ]
       │                         │
       ▼                         ▼
  [ Valkey (In-Memory) ]    [ PostgreSQL (ACID) ]
  - Estado GPS en caliente  - Catálogo de Rutas
  - Presencia y TTLs        - Paraderos y Horarios
  - Cobertura Geoespacial   - Alertas persistidas
       │
       ▼ (Phoenix.PubSub)
  [ Phoenix Channels / WebSockets ] ───► [ Clientes Web / Apps Móviles ]
  ```
  """

  @doc false
  def architecture_summary do
    %{
      memory_layer: "Valkey 7.2+ (Sub-millisecond state cache & geospatial queries)",
      event_streaming: "Redpanda 24+ (Kafka-compatible zero-JVM event buffer)",
      relational_store: "PostgreSQL 16+ (Transactional consistency & catalog storage)",
      realtime_transport: "Phoenix Channels (Stateful WebSockets with PubSub broadcast)"
    }
  end
end
