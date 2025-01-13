# Usa l'immagine base Odoo
FROM odoo:18.0

# Aggiungi l'argomento per il token GitHub
ARG GITHUB_TOKEN

# Passa all'utente root per installare dipendenze
USER root

# Installazione di dipendenze e configurazioni di sistema
RUN apt-get update && apt-get install -y \
    git \
    curl \
    python3-pip \
    fonts-dejavu \
    ttf-bitstream-vera \
    gsfonts \
    fontconfig \
    xfonts-75dpi \
    xfonts-base \
    && apt-get clean

# Passa all'utente odoo per configurazioni legate all'applicazione
USER odoo

# Clona il repository di Odoo Enterprise (se richiesto)
RUN if [ -n "$GITHUB_TOKEN" ]; then \
        git clone -b ${ODOO_VERSION} https://$GITHUB_TOKEN@github.com/odoo/enterprise.git /mnt/enterprise; \
    fi

# Copia file di configurazione
COPY ./odoo.conf /etc/odoo/odoo.conf

# Script per configurare i permessi
USER root
RUN mkdir -p /var/lib/odoo/addons/18.0 /var/lib/odoo/sessions /mnt/extra-addons && \
    chown -R odoo:odoo /var/lib/odoo /mnt/extra-addons && \
    chmod -R 700 /var/lib/odoo /mnt/extra-addons

# Passa all'utente Odoo e imposta la directory dei moduli personalizzati
USER odoo
VOLUME ["/mnt/extra-addons"]

# Comando di avvio predefinito
CMD ["odoo"]
