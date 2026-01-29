#!/bin/bash

# Script de Setup - Monokera

set -e

echo "Iniciando setup..."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker no está instalado.${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}Error: Docker Compose no está instalado.${NC}"
    exit 1
fi

echo -e "${GREEN}Docker y Docker Compose encontrados${NC}"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ ! -d "$SCRIPT_DIR/monokera_order_api" ]; then
    if [ -d "$SCRIPT_DIR/../monokera_order_api" ]; then
        echo -e "${YELLOW}Creando enlace simbólico para monokera_order_api...${NC}"
        ln -sf "$SCRIPT_DIR/../monokera_order_api" "$SCRIPT_DIR/monokera_order_api"
    else
        echo -e "${RED}Error: No se encontró monokera_order_api${NC}"
        exit 1
    fi
fi

if [ ! -d "$SCRIPT_DIR/monokera_customer_api" ]; then
    if [ -d "$SCRIPT_DIR/../monokera_customer_api" ]; then
        echo -e "${YELLOW}Creando enlace simbólico para monokera_customer_api...${NC}"
        ln -sf "$SCRIPT_DIR/../monokera_customer_api" "$SCRIPT_DIR/monokera_customer_api"
    else
        echo -e "${RED}Error: No se encontró monokera_customer_api${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Proyectos encontrados${NC}"

echo -e "${YELLOW}Construyendo imágenes Docker...${NC}"
docker-compose build

echo -e "${GREEN}Imágenes construidas${NC}"

echo -e "${YELLOW}Levantando servicios...${NC}"
docker-compose up -d postgres rabbitmq

echo -e "${YELLOW}Esperando a que PostgreSQL y RabbitMQ estén listos...${NC}"
sleep 10

docker-compose up -d order_service customer_service

echo -e "${YELLOW}Esperando a que las aplicaciones inicien...${NC}"
sleep 15

echo -e "${YELLOW}Ejecutando seeds...${NC}"
docker-compose exec customer_service bundle exec rails db:seed || true

echo -e "${YELLOW}Levantando worker...${NC}"
docker-compose up -d customer_worker

echo ""
echo -e "${GREEN}Setup completado${NC}"
echo ""
echo -e "Servicios disponibles:"
echo -e "   Order Service:    ${YELLOW}http://localhost:3000${NC}"
echo -e "   Customer Service: ${YELLOW}http://localhost:3001${NC}"
echo -e "   RabbitMQ UI:      ${YELLOW}http://localhost:15672${NC} (guest/guest)"
echo ""
echo -e "Para probar:"
echo -e "   curl http://localhost:3001/api/v1/customers/1"
echo -e "   curl -X POST http://localhost:3000/api/v1/orders -H 'Content-Type: application/json' -d '{\"order\":{\"customer_id\":1,\"product_name\":\"Test\",\"quantity\":1,\"price\":100}}'"
echo ""
echo -e "Comandos útiles:"
echo -e "   docker-compose logs -f          # Ver logs"
echo -e "   docker-compose ps               # Ver estado"
echo -e "   docker-compose down             # Detener"
echo -e "   docker-compose down -v          # Detener y eliminar volúmenes"
echo ""
