# Monokera - Microservicios de Pedidos y Clientes

Prueba técnica para Backend Developer en Monokera.

## Descripción

Sistema compuesto por dos microservicios que demuestran:
- Desarrollo de **APIs REST** en Rails
- Comunicación entre **microservicios** via HTTP
- Arquitectura **event-driven** con RabbitMQ
- **PostgreSQL** para persistencia de datos
- **Pruebas unitarias e integración** con RSpec

## Arquitectura

```
┌─────────────────┐   HTTP    ┌───────────────────┐
│  Order Service  │ ────────► │  Customer Service │
│    :3000        │           │      :3001        │
└────────┬────────┘           └─────────┬─────────┘
         │                              │
         │ publish                      │ consume
         ▼                              ▼
┌─────────────────────────────────────────────────┐
│                   RabbitMQ                      │
│            (order.created events)               │
└─────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
┌─────────────────┐           ┌─────────────────┐
│   PostgreSQL    │           │   PostgreSQL    │
│   orders_db     │           │  customers_db   │
└─────────────────┘           └─────────────────┘
```

## Flujo de Comunicación

1. **Crear Pedido**: Cliente envía `POST /api/v1/orders` al Order Service
2. **Validar Cliente**: Order Service llama a Customer Service via HTTP
3. **Guardar Pedido**: Si el cliente existe, se crea el pedido en PostgreSQL
4. **Emitir Evento**: Order Service publica `order.created` en RabbitMQ
5. **Consumir Evento**: Customer Service escucha el evento y actualiza `orders_count`

## Requisitos del Sistema

- Docker y Docker Compose
- Git

**O para desarrollo local:**
- Ruby 3.4.5
- Rails 8.0.4
- PostgreSQL 14+
- RabbitMQ 3.x

## Inicio Rápido con Docker

```bash
# 1. Clonar el repositorio
git clone <repository-url>
cd monokera

# 2. Ejecutar setup (primera vez)
./setup.sh

# 3. ¡Listo! Servicios disponibles:
#    - Order Service:    http://localhost:3000
#    - Customer Service: http://localhost:3001
#    - RabbitMQ UI:      http://localhost:15672 (guest/guest)
```

### Comandos Docker

```bash
# Iniciar servicios
./start.sh

# Detener servicios
./stop.sh

# Ver logs en tiempo real
docker-compose logs -f

# Ver logs de un servicio específico
docker-compose logs -f order_service
docker-compose logs -f customer_worker

# Detener y eliminar volúmenes (reset completo)
docker-compose down -v
```

## Instalación Local (sin Docker)

### 1. Configurar PostgreSQL

```bash
# Crear bases de datos
createdb orders_development
createdb customers_development
```

### 2. Instalar RabbitMQ

```bash
# macOS
brew install rabbitmq
brew services start rabbitmq

# Ubuntu/Debian
sudo apt-get install rabbitmq-server
sudo systemctl start rabbitmq-server
```

### 3. Configurar Order Service

```bash
cd monokera_order_api
bundle install
rails server -p 3000
```

### 4. Configurar Customer Service

```bash
# Terminal 1 - API
cd monokera_customer_api
bundle install
rails db:migrate db:seed
rails server -p 3001

# Terminal 2 - Worker
cd monokera_customer_api
bundle exec rake sneakers:run
```

## Ejecutar Tests

```bash
# Order Service (131 tests)
cd monokera_order_api
bundle exec rspec

# Customer Service (42 tests)
cd monokera_customer_api
bundle exec rspec

# Con formato detallado
bundle exec rspec --format documentation
```

## Endpoints Disponibles

### Order Service (Puerto 3000)

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `POST` | `/api/v1/orders` | Crear un nuevo pedido |
| `GET` | `/api/v1/orders?customer_id=X` | Listar pedidos por cliente |
| `GET` | `/api/v1/orders/:id` | Obtener un pedido específico |
| `GET` | `/up` | Health check |

### Customer Service (Puerto 3001)

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/api/v1/customers/:id` | Obtener información de un cliente |
| `GET` | `/up` | Health check |

## Ejemplos de Uso

### Consultar un cliente

```bash
curl http://localhost:3001/api/v1/customers/1
```

```json
{
  "customer": {
    "id": 1,
    "customer_name": "Juan García",
    "address": "Calle Principal 123, Madrid",
    "orders_count": 5
  }
}
```

### Crear un pedido

```bash
curl -X POST http://localhost:3000/api/v1/orders \
  -H "Content-Type: application/json" \
  -d '{
    "order": {
      "customer_id": 1,
      "product_name": "Laptop Dell",
      "quantity": 2,
      "price": 1500.00
    }
  }'
```

```json
{
  "message": "Recurso creado exitosamente",
  "order": {
    "id": 1,
    "customer_id": 1,
    "product_name": "Laptop Dell",
    "quantity": 2,
    "price": 1500.0,
    "total_amount": 3000.0,
    "status": "pending",
    "status_label": "Pendiente",
    "created_at": "2026-01-29T05:39:11Z",
    "updated_at": "2026-01-29T05:39:11Z"
  }
}
```

### Listar pedidos por cliente

```bash
curl "http://localhost:3000/api/v1/orders?customer_id=1"
```

## Estructura del Proyecto

```
monokera/
├── docker-compose.yml          # Orquestación de servicios
├── init-databases.sql          # Script de inicialización de BD
├── setup.sh                    # Script de configuración inicial
├── start.sh                    # Script de inicio
├── stop.sh                     # Script de parada
├── README.md                   # Este archivo
│
├── monokera_order_api/         # Servicio de Pedidos
│   ├── app/
│   │   ├── controllers/api/v1/
│   │   ├── models/
│   │   └── services/
│   ├── spec/
│   └── README.md
│
└── monokera_customer_api/      # Servicio de Clientes
    ├── app/
    │   ├── controllers/api/v1/
    │   ├── models/
    │   └── workers/
    ├── spec/
    └── README.md
```

## Tecnologías Utilizadas

- **Ruby** 3.4.5
- **Rails** 8.0.4
- **PostgreSQL** 15
- **RabbitMQ** 3.x
- **Bunny** - Cliente RabbitMQ para Ruby
- **Sneakers** - Worker para consumir mensajes
- **Faraday** - Cliente HTTP
- **RSpec** - Framework de testing
- **FactoryBot** - Fixtures para tests
- **Docker** - Containerización

## Guía de Ejecución con Docker

### Requisitos Previos

- Docker Desktop instalado y corriendo
- Docker Compose v2+
- Puertos disponibles: 3000, 3001, 5432, 5672, 15672

### Pasos para Ejecutar

```bash
# 1. Clonar el repositorio
git clone <repository-url>
cd monokera

# 2. Iniciar todos los servicios
docker-compose up -d

# 3. Esperar ~30 segundos a que todos los servicios estén listos
docker-compose ps

# 4. Ejecutar seeds (datos de prueba - solo primera vez)
docker-compose exec order_service bin/rails db:seed
docker-compose exec customer_service bin/rails db:seed
```

### Verificar que Funciona

```bash
# Ver clientes disponibles
curl http://localhost:3001/api/v1/customers/1

# Crear una orden
curl -X POST http://localhost:3000/api/v1/orders \
  -H "Content-Type: application/json" \
  -d '{"order": {"customer_id": 1, "product_name": "Producto Test", "quantity": 2, "price": 25.50}}'

# Verificar que orders_count aumentó (esperar 2-3 segundos)
curl http://localhost:3001/api/v1/customers/1
```

### URLs de los Servicios

| Servicio | URL | Descripción |
|----------|-----|-------------|
| Order Service | http://localhost:3000 | API de pedidos |
| Customer Service | http://localhost:3001 | API de clientes |
| RabbitMQ Management | http://localhost:15672 | UI de RabbitMQ (guest/guest) |

### Comandos Útiles

```bash
# Ver logs de todos los servicios
docker-compose logs -f

# Ver logs de un servicio específico
docker-compose logs -f order_service
docker-compose logs -f customer_worker

# Reiniciar un servicio
docker-compose restart order_service

# Detener todos los servicios
docker-compose down

# Detener y eliminar datos (reset completo)
docker-compose down -v
```

### Solución de Problemas

#### El evento no llega al Customer Service

1. Verificar que el worker está corriendo:
   ```bash
   docker-compose ps | grep customer_worker
   ```

2. Verificar la cola en RabbitMQ:
   ```bash
   curl -s -u guest:guest http://localhost:15672/api/queues/%2F/customer_order_events | jq '{messages, consumers}'
   ```

3. Ver logs del worker:
   ```bash
   docker-compose exec customer_worker cat log/development.log | tail -50
   ```

#### Error de conexión a RabbitMQ

1. Verificar que RabbitMQ está healthy:
   ```bash
   docker-compose ps | grep rabbitmq
   ```

2. Reiniciar los servicios:
   ```bash
   docker-compose restart order_service customer_worker
   ```

### Variables de Entorno Importantes

Las variables están configuradas en `docker-compose.yml`:

| Variable | Valor | Descripción |
|----------|-------|-------------|
| `RAILS_ENV` | development | Entorno de Rails |
| `DATABASE_URL` | postgresql://... | Conexión a PostgreSQL |
| `RABBITMQ_URL` | amqp://guest:guest@rabbitmq:5672 | Conexión a RabbitMQ |
| `CUSTOMER_SERVICE_URL` | http://customer_service:3001 | URL del Customer Service |

> **Nota**: El archivo `.env` local se elimina automáticamente al iniciar los contenedores para evitar conflictos con las variables de Docker.

