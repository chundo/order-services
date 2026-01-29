# Monokera Order Service (Servicio de Pedidos)

API REST para gestión de pedidos.

## Descripción del Proyecto

El **Servicio de Pedidos** es responsable de:
- Crear pedidos validando el cliente contra el Servicio de Clientes
- Consultar pedidos por cliente (`customer_id`)
- Emitir eventos a RabbitMQ cuando se crea un pedido

## Requisitos del Sistema

- Ruby 3.4.5
- Rails 8.0.4
- PostgreSQL 14+
- RabbitMQ 3.x (opcional para eventos)
- Bundler 2.x

## Instrucciones de Instalación

### 1. Clonar el repositorio

```bash
git clone <repository-url>
cd monokera_order_api
```

### 2. Instalar dependencias

```bash
bundle install
```

### 3. Configurar base de datos

```bash
# Crear y migrar la base de datos
rails db:create db:migrate

# Cargar datos de prueba (opcional)
rails db:seed
```

### 4. Configurar variables de entorno (opcional)

Crear archivo `.env` en la raíz del proyecto:

```bash
# Base de datos
DATABASE_URL=postgresql://localhost/orders_development

# Customer Service
CUSTOMER_SERVICE_URL=http://localhost:3001

# RabbitMQ
RABBITMQ_URL=amqp://guest:guest@localhost:5672/
```

## Cómo Ejecutar el Servicio

### Sin Docker

```bash
# Desarrollo
rails server -p 3000

# O con binding específico
rails server -b 0.0.0.0 -p 3000
```

### Con Docker

```bash
# Construir imagen
docker build -t monokera-order-api .

# Ejecutar contenedor
docker run -p 3000:3000 monokera-order-api
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

# Solo tests de servicios
bundle exec rspec spec/services/

# Con cobertura de código
COVERAGE=true bundle exec rspec
```

## Endpoints Disponibles

### Pedidos

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `POST` | `/api/v1/orders` | Crear un nuevo pedido |
| `GET` | `/api/v1/orders?customer_id=X` | Listar pedidos por cliente |
| `GET` | `/api/v1/orders/:id` | Obtener un pedido específico |
| `GET` | `/up` | Health check |

### Crear Pedido

**Request:**
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

**Response (201 Created):**
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

### Listar Pedidos por Cliente

**Request:**
```bash
curl "http://localhost:3000/api/v1/orders?customer_id=1"
```

**Response (200 OK):**
```json
{
  "orders": [
    {
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
  ],
  "meta": {
    "total": 1,
    "filters": {
      "customer_id": "1"
    }
  }
}
```

### Errores

**Cliente no encontrado (422):**
```json
{
  "error": "Cliente con ID 99999 no encontrado",
  "details": ["Cliente con ID 99999 no encontrado"]
}
```

## Estructura del Proyecto

```
monokera_order_api/
├── app/
│   ├── controllers/
│   │   └── api/v1/
│   │       └── orders_controller.rb
│   ├── models/
│   │   └── order.rb
│   └── services/
│       ├── customer_service_client.rb
│       ├── event_publisher.rb
│       └── orders/
│           └── create_service.rb
├── config/
│   ├── settings.yml
│   └── settings/
│       ├── development.yml
│       ├── test.yml
│       └── production.yml
├── spec/
│   ├── models/
│   ├── requests/
│   └── services/
└── README.md
```

## Flujo de Creación de Pedido

1. Cliente envía `POST /api/v1/orders` con datos del pedido
2. `OrdersController` recibe la petición
3. `Orders::CreateService` orquesta la creación:
   - Valida el `customer_id` llamando a Customer Service via HTTP
   - Si el cliente existe, crea el pedido en la base de datos
   - Publica evento `order.created` a RabbitMQ
4. Retorna el pedido creado o error de validación

## Modelo de Datos

### Order

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | integer | ID único del pedido |
| `customer_id` | integer | ID del cliente (FK externa) |
| `product_name` | string | Nombre del producto |
| `quantity` | integer | Cantidad (mínimo 1) |
| `price` | decimal | Precio unitario |
| `status` | enum | pending, processing, completed, cancelled |
| `created_at` | datetime | Fecha de creación |
| `updated_at` | datetime | Fecha de actualización |

## Eventos RabbitMQ

### order.created

Publicado cuando se crea un nuevo pedido exitosamente.

```json
{
  "event": "order.created",
  "data": {
    "order_id": 1,
    "customer_id": 1,
    "product_name": "Laptop Dell",
    "quantity": 2,
    "price": 1500.0,
    "total_amount": 3000.0,
    "status": "pending"
  },
  "timestamp": "2026-01-29T05:39:11Z"
}
```

## Cobertura de Tests

| Componente | Tests |
|------------|-------|
| Order Model | 24 |
| OrdersController | 45 |
| CustomerServiceClient | 22 |
| EventPublisher | 18 |
| Orders::CreateService | 22 |
| **Total** | **131** |

## Autor

Desarrollado como parte de la prueba técnica para Backend Developer en Monokera.

## Licencia

Este proyecto es privado y confidencial.
