FROM nginx:latest

# Installa certbot e le sue dipendenze
RUN apt-get update && \
    apt-get install -y certbot python3-certbot-nginx && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copia la configurazione di Nginx
COPY ./default.conf /etc/nginx/conf.d/default.conf

# Crea directory per Let's Encrypt
RUN mkdir -p /etc/letsencrypt

# Copia lo script di init per SSL
COPY ./init-ssl.sh /init-ssl.sh
RUN chmod +x /init-ssl.sh

# Imposta il comando di avvio
CMD ["/init-ssl.sh"]