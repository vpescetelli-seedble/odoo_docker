# Usa l'immagine ufficiale di Nginx
FROM nginx:latest

# Copia la configurazione di Nginx
COPY ./default.conf /etc/nginx/conf.d/default.conf

# Crea certificati SSL auto-firmati
RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/production.key \
    -out /etc/nginx/ssl/production.crt \
    -subj "/CN=localhost"

# Imposta il comando di avvio
CMD ["nginx", "-g", "daemon off;"]
