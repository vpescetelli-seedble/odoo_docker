# Usa l'immagine base Odoo
ARG ODOO_VERSION
FROM odoo:${ODOO_VERSION}

# Aggiungi l'argomento per il token GitHub
ARG GITHUB_TOKEN

# Installazione di dipendenze e clonazione di Odoo Enterprise (se richiesto)
RUN apt-get update && apt-get install -y \
    git \
    curl \
    python3-pip && \
    apt-get clean

# Clona il repository di Odoo Enterprise
RUN if [ -n "$GITHUB_TOKEN" ]; then \
        git clone -b ${ODOO_VERSION} https://$GITHUB_TOKEN@github.com/odoo/enterprise.git /mnt/enterprise; \
    fi

# Copia file di configurazione (opzionale)
COPY ./odoo.conf /etc/odoo/odoo.conf

# Imposta la directory dei moduli personalizzati
VOLUME ["/mnt/extra-addons"]

# Comando di avvio predefinito
CMD ["odoo"]
