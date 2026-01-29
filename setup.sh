#!/bin/bash

# ===========================================
# Script de Setup - Monokera Microservicios
# ===========================================

set -e

echo "🚀 Iniciando setup de Monokera..."

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker no está instalado. Por favor instálalo primero.${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Docker Compose no está instalado. Por favor instálalo primero.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker y Docker Compose encontrados${NC}"

# Crear enlaces simbólicos si los proyectos no están en el directorio
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ ! -d "$SCRIPT_DIR/monokera_order_api" ]; then
    if [ -d "$SCRIPT_DIR/../monokera_order_api" ]; then
        echo -e "${YELLOW}📁 Creando enlace simbólico para monokera_order_api...${NC}"
        ln -sf "$SCRIPT_DIR/../monokera_order_api" "$SCRIPT_DIR/monokera_order_api"
    else
        echo -e "${RED}❌ No se encontró monokera_order_api${NC}"
        exit 1
    fi
fi

if [ ! -d "$SCRIPT_DIR/monokera_customer_api" ]; then
    if [ -d "$SCRIPT_DIR/../monokera_customer_api" ]; then
        echo -e "${YELLOW}📁 Creando enlace simbólico para monokera_customer_api...${NC}"
        ln -sf "$SCRIPT_DIR/../monokera_customer_api" "$SCRIPT_DIR/monokera_customer_api"
    else
        echo -e "${RED}❌ No se encontró monokera_customer_api${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✅ Proyectos encontrados${NC}"

# Construir imágenes
echo -e "${YELLOW}🔨 Construyendo imágenes Docker...${NC}"
docker-compose build

echo -e "${GREEN}✅ Imágenes construidas${NC}"

# Levantar servicios
echo -e "${YELLOW}🚀 Levantando servicios...${NC}"
docker-compose up -d postgres rabbitmq

# Esperar a que los servicios estén listos
echo -e "${YELLOW}⏳ Esperando a que PostgreSQL y RabbitMQ estén listos...${NC}"
sleep 10

# Levantar aplicaciones
docker-compose up -d order_service customer_service

# Esperar a que las apps estén listas
echo -e "${YELLOW}⏳ Esperando a que las aplicaciones inicien...${NC}"
sleep 15

# Ejecutar seeds
echo -e "${YELLOW}🌱 Ejecutando seeds en Customer Service...${NC}"
docker-compose exec customer_service bundle exec rails db:seed || true

# Levantar worker
echo -e "${YELLOW}👷 Levantando worker de Sneakers...${NC}"
docker-compose up -d customer_worker

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}✅ ¡Setup completado!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "📡 Servicios disponibles:"
echo -e "   • Order Service:    ${YELLOW}http://localhost:3000${NC}"
echo -e "   • Customer Service: ${YELLOW}http://localhost:3001${NC}"
echo -e "   • RabbitMQ UI:      ${YELLOW}http://localhost:15672${NC} (guest/guest)"
echo ""
echo -e "🧪 Para probar:"
echo -e "   curl http://localhost:3001/api/v1/customers/1"
echo -e "   curl -X POST http://localhost:3000/api/v1/orders -H 'Content-Type: application/json' -d '{\"order\":{\"customer_id\":1,\"product_name\":\"Test\",\"quantity\":1,\"price\":100}}'"
echo ""
echo -e "📋 Comandos útiles:"
echo -e "   docker-compose logs -f          # Ver logs en tiempo real"
echo -e "   docker-compose ps               # Ver estado de servicios"
echo -e "   docker-compose down             # Detener todo"
echo -e "   docker-compose down -v          # Detener y eliminar volúmenes"
echo ""
