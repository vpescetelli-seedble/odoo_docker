FROM nginx:latest

# Installa Certbot e dipendenze
RUN apt-get update && \
    apt-get install -y certbot python3-certbot-nginx && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Genera certificati temporanei
RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/staging.key \
    -out /etc/nginx/ssl/staging.crt \
    -subj "/CN=samir-staging.seedble.com"

# Copia configurazione
COPY ./default.conf /etc/nginx/conf.d/default.conf

# Script per Let's Encrypt
COPY ./obtain-cert.sh /opt/
RUN chmod +x /opt/obtain-cert.sh

CMD ["/bin/bash", "-c", "/opt/obtain-cert.sh"]