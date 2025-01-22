#!/bin/bash

# Crea directory per i certificati SSL
echo "Creazione directories SSL..."
mkdir -p /etc/nginx/ssl/
mkdir -p /var/www/html/.well-known/acme-challenge/

# Debug info
echo "Directory corrente: $(pwd)"
echo "Contenuto /etc/nginx: $(ls -la /etc/nginx)"
echo "Ambiente: ${ENVIRONMENT}"
echo "Dominio: ${DOMAIN_NAME}"

# Genera certificato self-signed iniziale
echo "Generazione certificato self-signed iniziale"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "/etc/nginx/ssl/${ENVIRONMENT}.key" \
        -out "/etc/nginx/ssl/${ENVIRONMENT}.crt" \
        -subj "/CN=${DOMAIN_NAME}" \
        -verbose

# Verifica che i certificati siano stati creati
echo "Verifica dei certificati generati:"
ls -la /etc/nginx/ssl/

# Genera la configurazione nginx
cat > /etc/nginx/conf.d/default.conf << EOF
upstream odoo {
    server odoo_${ENVIRONMENT}:8069;
}

upstream odoochat {
    server odoo_${ENVIRONMENT}:8072;
}

map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}

# Configurazione iniziale HTTP per tutti i casi
server {
    listen 80;
    server_name ${DOMAIN_NAME};

    # Configurazione per Let's Encrypt ACME challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

# Configurazione HTTPS
server {
    listen 443 ssl;
    server_name ${DOMAIN_NAME};

    # Usiamo i certificati con il nome corretto dell'ambiente
    ssl_certificate /etc/nginx/ssl/${ENVIRONMENT}.crt;
    ssl_certificate_key /etc/nginx/ssl/${ENVIRONMENT}.key;
    
    # Configurazione SSL
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;

    # Configurazione proxy moderna
    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;

    location / {
        proxy_pass http://odoo;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /websocket {
        proxy_pass http://odoochat;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header X-Forwarded-Host \$http_host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

# Verifica finale configurazione nginx
echo "Contenuto configurazione nginx:"
cat /etc/nginx/conf.d/default.conf

if [ "$USE_LETS_ENCRYPT" = "true" ]; then
    echo "Avvio nginx con certificato self-signed per validazione Let's Encrypt"
    nginx &
    
    # Attendi che nginx sia pronto
    sleep 5
    
    echo "Richiesta certificato Let's Encrypt per ${DOMAIN_NAME}"
    certbot certonly --webroot \
            --webroot-path=/var/www/html \
            --non-interactive \
            --agree-tos \
            --email ${LE_EMAIL} \
            --domains ${DOMAIN_NAME}
            
    CERTBOT_EXIT_CODE=$?
    
    if [ $CERTBOT_EXIT_CODE -eq 0 ]; then
        echo "Certificato Let's Encrypt ottenuto con successo"
        # Aggiorna la configurazione SSL in nginx
        sed -i "s|ssl_certificate .*|ssl_certificate /etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem;|" /etc/nginx/conf.d/default.conf
        sed -i "s|ssl_certificate_key .*|ssl_certificate_key /etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem;|" /etc/nginx/conf.d/default.conf
        
        # Riavvia nginx per applicare i nuovi certificati
        nginx -s stop
        sleep 2
    else
        echo "Errore nell'ottenimento del certificato Let's Encrypt. Mantengo il certificato self-signed"
    fi
fi

# Avvia/Riavvia nginx in foreground
echo "Avvio nginx in foreground"
exec nginx -g "daemon off;"