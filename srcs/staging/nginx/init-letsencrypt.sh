#!/bin/bash

# Avvia nginx con i certificati esistenti
nginx

# Attendi che nginx sia avviato
sleep 5

# Prova a ottenere il certificato Let's Encrypt
certbot --nginx \
    --non-interactive \
    --agree-tos \
    --email tuo@email.com \
    --domains samir-staging.seedble.com \
    --keep-until-expiring \
    --staging || true  # Il || true permette di continuare anche se certbot fallisce

# Riavvia nginx in foreground
exec nginx -g 'daemon off;'