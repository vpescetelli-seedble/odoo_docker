#!/bin/bash

# Avvia nginx in background con certificato temporaneo
nginx

# Attendi un po' per assicurarsi che nginx sia avviato
sleep 10

# Ottieni certificato Let's Encrypt
certbot --nginx \
    --non-interactive \
    --agree-tos \
    --email valerio.pescetelli@seedble.com \
    --domains samir.seedble.com \
    --staging  # Rimuovi questa riga quando sei pronto per il certificato reale

# Ferma nginx in background
nginx -s stop

# Riavvia nginx in foreground
exec nginx -g 'daemon off;'