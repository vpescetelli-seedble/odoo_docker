FROM nginx:latest

ARG ENVIRONMENT=production
ARG DOMAIN_NAME=localhost
ARG USE_LETS_ENCRYPT=false
ARG LE_EMAIL=""

ENV ENVIRONMENT=${ENVIRONMENT}
ENV DOMAIN_NAME=${DOMAIN_NAME}
ENV USE_LETS_ENCRYPT=${USE_LETS_ENCRYPT}
ENV LE_EMAIL=${LE_EMAIL}

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