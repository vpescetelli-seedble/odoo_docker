FROM nginx:latest

# Installa Certbot e le dipendenze necessarie
RUN apt-get update && \
    apt-get install -y certbot python3-certbot-nginx && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copia la configurazione di Nginx
COPY ./default.conf /etc/nginx/conf.d/default.conf

# Crea una directory per i certificati
RUN mkdir -p /etc/nginx/ssl

# Script di inizializzazione
COPY ./init-letsencrypt.sh /docker-entrypoint.d/
RUN chmod +x /docker-entrypoint.d/init-letsencrypt.sh

CMD ["nginx", "-g", "daemon off;"]