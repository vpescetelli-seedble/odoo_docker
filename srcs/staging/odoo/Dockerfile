# Usa l'immagine base Odoo
FROM odoo:18.0

# Aggiungi l'argomento per il token GitHub
ARG GITHUB_TOKEN

USER root

# Installazione di dipendenze aggiuntive
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
    wkhtmltopdf \
    && apt-get clean


USER odoo
# Crea le directory necessarie con i permessi corretti
RUN mkdir -p /var/lib/odoo/sessions /var/lib/odoo/addons/18.0 /mnt/extra-addons && \
    chown -R odoo:odoo /var/lib/odoo /mnt/extra-addons && \
    chmod -R 755 /var/lib/odoo /mnt/extra-addons

# Copia file di configurazione
COPY ./odoo.conf /etc/odoo/odoo.conf

RUN if [ -n "$GITHUB_TOKEN" ]; then \
        git clone -b ${ODOO_VERSION} https://$GITHUB_TOKEN@github.com/odoo/enterprise.git /mnt/enterprise; \
    fi

# Imposta la directory dei moduli personalizzati
VOLUME ["/mnt/extra-addons"]

# Comando di avvio predefinito
CMD ["odoo"]