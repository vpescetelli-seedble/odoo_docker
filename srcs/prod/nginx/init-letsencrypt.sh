#!/bin/bash

# Ottieni il certificato
certbot --nginx \
  --non-interactive \
  --agree-tos \
  --email valerio.pescetelli@seedble.com \
  --domains samir.seedble.com \
  --redirect

# Configura il rinnovo automatico in background
certbot renew --deploy-hook "nginx -s reload" &