#!/bin/bash

set -e

# Funzione per generare certificati SSL
generate_ssl_certificates() {
    local ENV=$1
    local CERT_DIR="./srcs/$ENV/nginx/ssl"
    
    echo "Generazione certificati SSL per l'ambiente: $ENV"
    mkdir -p "$CERT_DIR"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$CERT_DIR/$ENV.key" \
        -out "$CERT_DIR/$ENV.crt" \
        -subj "/CN=$ENV.odoo.local"
}

# Funzione per avviare Docker Compose
start_docker_compose() {
    echo "Avvio dei servizi Docker per $1"
    docker-compose up -d
}

# Controlla l'ambiente specificato
if [ -z "$1" ]; then
    echo "Uso: $0 [staging|production]"
    exit 1
fi

ENV=$1

if [[ "$ENV" != "staging" && "$ENV" != "production" ]]; then
    echo "Errore: Ambiente non valido. Usa 'staging' o 'production'."
    exit 1
fi

# Generazione certificati SSL
generate_ssl_certificates "$ENV"

# Avvio dei servizi Docker
start_docker_compose "$ENV"

echo "Setup completato per l'ambiente: $ENV"
