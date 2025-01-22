#!/bin/bash

# Crea directory per i certificati SSL e Let's Encrypt
mkdir -p /etc/nginx/ssl
mkdir -p /etc/letsencrypt/live/${DOMAIN_NAME}

if [ "$USE_LETS_ENCRYPT" = "true" ]; then
    echo "Configurazione Let's Encrypt per ${DOMAIN_NAME}"
    
    # Avvia nginx temporaneamente senza SSL per la validazione ACME
    cat > /etc/nginx/conf.d/default.conf.tmp << EOF
server {
    listen 80;
    server_name ${DOMAIN_NAME};
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
}
EOF

    mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak
    mv /etc/nginx/conf.d/default.conf.tmp /etc/nginx/conf.d/default.conf
    
    # Avvia nginx in background
    nginx &
    
    # Attendi che nginx sia pronto
    sleep 5
    
    echo "Richiesta certificato Let's Encrypt"
    certbot certonly --webroot \
            --webroot-path=/var/www/html \
            --non-interactive \
            --agree-tos \
            --email ${LE_EMAIL} \
            --domains ${DOMAIN_NAME}
            
    CERTBOT_EXIT_CODE=$?
    
    # Ferma nginx temporaneo
    nginx -s stop
    sleep 2
    
    # Ripristina la configurazione originale
    mv /etc/nginx/conf.d/default.conf.bak /etc/nginx/conf.d/default.conf
    
    if [ $CERTBOT_EXIT_CODE -eq 0 ]; then
        echo "Certificato Let's Encrypt ottenuto con successo"
    else
        echo "Errore nell'ottenimento del certificato Let's Encrypt. Uso certificato self-signed come fallback"
        # Genera certificato self-signed come fallback
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout /etc/nginx/ssl/${ENVIRONMENT}.key \
                -out /etc/nginx/ssl/${ENVIRONMENT}.crt \
                -subj "/CN=${DOMAIN_NAME}"
    fi
else
    echo "Generazione certificato self-signed"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/nginx/ssl/${ENVIRONMENT}.key \
            -out /etc/nginx/ssl/${ENVIRONMENT}.crt \
            -subj "/CN=localhost"
fi

# Avvia nginx con la configurazione finale
exec nginx -g "daemon off;"