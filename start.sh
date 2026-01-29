#!/bin/bash

# Script de Inicio - Monokera

set -e

echo "Iniciando servicios..."

if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
    echo "Error: Docker Compose no encontrado"
    exit 1
fi

docker-compose up -d

echo ""
echo "Servicios iniciados"
echo ""
echo "URLs:"
echo "   Order Service:    http://localhost:3000"
echo "   Customer Service: http://localhost:3001"
echo "   RabbitMQ UI:      http://localhost:15672"
echo ""
echo "Ver logs: docker-compose logs -f"
echo ""
