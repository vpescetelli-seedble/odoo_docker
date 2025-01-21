FROM nginx:latest

# Installa Certbot e dipendenze
RUN apt-get update && \
    apt-get install -y certbot python3-certbot-nginx && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copia la configurazione esistente
COPY ./default.conf /etc/nginx/conf.d/default.conf

# Crea certificati SSL auto-firmati (manteniamo quelli esistenti come backup)
RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/production.key \
    -out /etc/nginx/ssl/production.crt \
    -subj "/CN=dominio@dominio.com"

# Crea uno script per ottenere i certificati Let's Encrypt
COPY ./init-letsencrypt.sh /opt/
RUN chmod +x /opt/init-letsencrypt.sh

CMD ["/bin/bash", "-c", "/opt/init-letsencrypt.sh"]