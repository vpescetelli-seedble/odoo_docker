# Usa l'immagine ufficiale di Nginx
FROM nginx:latest

# Copia la configurazione di Nginx
COPY ./default.conf /etc/nginx/conf.d/default.conf

# Imposta il comando di avvio
CMD ["nginx", "-g", "daemon off;"]
