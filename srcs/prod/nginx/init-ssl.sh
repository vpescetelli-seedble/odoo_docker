#!/bin/bash
# ./srcs/staging/nginx/init-ssl.sh e ./srcs/prod/nginx/init-ssl.sh

if [ "$USE_LETS_ENCRYPT" = "true" ] && [ ! -f "/etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem" ]; then
    # Genera certificato temporaneo
    mkdir -p /etc/nginx/ssl
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/nginx/ssl/temp.key \
            -out /etc/nginx/ssl/temp.crt \
            -subj "/CN=localhost"

    # Avvia nginx temporaneamente con il certificato self-signed
    cp /etc/nginx/ssl/temp.key /etc/nginx/ssl/${ENVIRONMENT}.key
    cp /etc/nginx/ssl/temp.crt /etc/nginx/ssl/${ENVIRONMENT}.crt
    nginx -g "daemon off;" &
    
    # Attendi che nginx sia avviato
    sleep 5
    
    # Ottieni il certificato Let's Encrypt
    certbot --nginx \
            --non-interactive \
            --agree-tos \
            --email ${LE_EMAIL} \
            --domains ${DOMAIN_NAME} \
            --redirect
    
    # Riavvia nginx con il nuovo certificato
    nginx -s reload
else
    # Usa certificati self-signed esistenti o generane di nuovi
    if [ ! -f "/etc/nginx/ssl/${ENVIRONMENT}.crt" ]; then
        mkdir -p /etc/nginx/ssl
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout /etc/nginx/ssl/${ENVIRONMENT}.key \
                -out /etc/nginx/ssl/${ENVIRONMENT}.crt \
                -subj "/CN=localhost"
    fi
    
    # Avvia nginx
    nginx -g "daemon off;"
fi