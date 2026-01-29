# Monokera Customer Service (Servicio de Clientes)

API REST para gestión de clientes.

## Descripción del Proyecto

El **Servicio de Clientes** es responsable de:
- Exponer información de clientes (`customer_name`, `address`, `orders_count`)
- Permitir que el Servicio de Pedidos valide la existencia de clientes
- Consumir eventos de RabbitMQ para actualizar el contador de pedidos

## Requisitos del Sistema

- Ruby 3.4.5
- Rails 8.0.4
- PostgreSQL 14+
- RabbitMQ 3.x (para consumir eventos)
- Bundler 2.x

## Instrucciones de Instalación

### 1. Clonar el repositorio

```bash
git clone <repository-url>
cd monokera_customer_api
```

### 2. Instalar dependencias

```bash
bundle install
```

### 3. Configurar base de datos

```bash
# Crear y migrar la base de datos
rails db:create db:migrate

# Cargar clientes predefinidos
rails db:seed
```

### 4. Configurar variables de entorno (opcional)

Crear archivo `.env` en la raíz del proyecto:

```bash
# Base de datos
DATABASE_URL=postgresql://localhost/customers_development

# RabbitMQ
RABBITMQ_URL=amqp://guest:guest@localhost:5672/
```

## Cómo Ejecutar el Servicio

### Sin Docker

```bash
# Servidor API (puerto 3001)
rails server -p 3001

# Worker de Sneakers (en otra terminal)
bundle exec rake sneakers:run
```

### Con Docker

```bash
# Construir imagen
docker build -t monokera-customer-api .

# Ejecutar contenedor
docker run -p 3001:3001 monokera-customer-api
```

### Con Docker Compose (ambos servicios)

```bash
# Desde el directorio padre que contiene docker-compose.yml
docker-compose up
```

## Cómo Ejecutar Tests

```bash
# Ejecutar todos los tests
bundle exec rspec

# Con formato detallado
bundle exec rspec --format documentation

# Solo tests de modelos
bundle exec rspec spec/models/

# Solo tests de controladores
bundle exec rspec spec/requests/

# Solo tests de workers
bundle exec rspec spec/workers/

# Con cobertura de código
COVERAGE=true bundle exec rspec
```

## Endpoints Disponibles

### Clientes

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/api/v1/customers/:id` | Obtener información de un cliente |
| `GET` | `/up` | Health check |

### Obtener Cliente

**Request:**
```bash
curl http://localhost:3001/api/v1/customers/1
```

**Response (200 OK):**
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

### Errores

**Cliente no encontrado (404):**
```json
{
  "error": "Cliente con ID 99999 no encontrado"
}
```

## Estructura del Proyecto

```
monokera_customer_api/
├── app/
│   ├── controllers/
│   │   └── api/v1/
│   │       └── customers_controller.rb
│   ├── models/
│   │   └── customer.rb
│   └── workers/
│       └── order_created_worker.rb
├── config/
│   ├── settings.yml
│   ├── initializers/
│   │   └── sneakers.rb
│   └── settings/
│       ├── development.yml
│       ├── test.yml
│       └── production.yml
├── spec/
│   ├── models/
│   ├── requests/
│   └── workers/
└── README.md
```

## Flujo de Comunicación

### 1. Validación de Cliente (HTTP)
1. Order Service envía `GET /api/v1/customers/:id`
2. Customer Service busca el cliente en la base de datos
3. Retorna información del cliente o error 404

### 2. Actualización de orders_count (Eventos)
1. Order Service publica evento `order.created` en RabbitMQ
2. `OrderCreatedWorker` consume el mensaje
3. Incrementa `orders_count` del cliente correspondiente

## Modelo de Datos

### Customer

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | integer | ID único del cliente |
| `customer_name` | string | Nombre del cliente |
| `email` | string | Email único |
| `address` | text | Dirección completa |
| `orders_count` | integer | Contador de pedidos (default: 0) |
| `created_at` | datetime | Fecha de creación |
| `updated_at` | datetime | Fecha de actualización |

## Consumer RabbitMQ

### OrderCreatedWorker

Consume eventos `order.created` y actualiza el contador de pedidos.

**Configuración:**
- Queue: `customer_order_events`
- Exchange: `monokera_events`
- Routing Key: `order.created`

**Mensaje esperado:**
```json
{
  "event": "order.created",
  "data": {
    "order_id": 1,
    "customer_id": 1,
    "total_amount": 3000.0,
    "status": "pending"
  },
  "timestamp": "2026-01-29T05:39:11Z"
}
```

## Clientes Predefinidos (Seeds)

El sistema incluye 10 clientes predefinidos:

| ID | Nombre | Email |
|----|--------|-------|
| 1 | Juan García | juan.garcia@example.com |
| 2 | María López | maria.lopez@example.com |
| 3 | Carlos Rodríguez | carlos.rodriguez@example.com |
| 4 | Ana Martínez | ana.martinez@example.com |
| 5 | Pedro Sánchez | pedro.sanchez@example.com |
| 6 | Laura Fernández | laura.fernandez@example.com |
| 7 | Miguel González | miguel.gonzalez@example.com |
| 8 | Carmen Ruiz | carmen.ruiz@example.com |
| 9 | David Hernández | david.hernandez@example.com |
| 10 | Isabel Torres | isabel.torres@example.com |

## Cobertura de Tests

| Componente | Tests |
|------------|-------|
| Customer Model | 18 |
| CustomersController | 11 |
| OrderCreatedWorker | 13 |
| **Total** | **42** |

## Autor

Desarrollado como parte de la prueba técnica para Backend Developer en Monokera.

## Licencia

Este proyecto es privado y confidencial.
