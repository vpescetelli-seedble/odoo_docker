#!/bin/bash

# Funzione per fermare nginx in modo sicuro
stop_nginx() {
    if [ -f /var/run/nginx.pid ]; then
        kill $(cat /var/run/nginx.pid)
        rm -f /var/run/nginx.pid
        sleep 2
    fi
}

# Avvia nginx inizialmente
nginx -g 'daemon off;' &
NGINX_PID=$!

# Attendi che nginx sia avviato
sleep 5

# Prova a ottenere il certificato Let's Encrypt
certbot --nginx \
    --non-interactive \
    --agree-tos \
    --email valerio.pescetelli@seedble.com \
    --domains samir-staging.seedble.com \

# Ferma nginx
stop_nginx

# Riavvia nginx con la nuova configurazione
exec nginx -g 'daemon off;'