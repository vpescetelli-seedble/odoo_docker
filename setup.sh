#!/bin/bash

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Funzione per modificare il docker-compose.yml
update_docker_compose() {
    local environment=$1
    local db_user=$2
    local db_password=$3
    local db_name=$4
    local env_lowercase=$(echo "$environment" | tr '[:upper:]' '[:lower:]')
    
    # Usa perl invece di sed per maggiore affidabilità
    perl -i -pe "s/POSTGRES_USER: odoo/POSTGRES_USER: ${db_user}/g" docker-compose.yml
    perl -i -pe "s/POSTGRES_PASSWORD: odoo_password/POSTGRES_PASSWORD: ${db_password}/g" docker-compose.yml
    perl -i -pe "s/POSTGRES_DB: postgres/POSTGRES_DB: ${db_name}/g" docker-compose.yml
    perl -i -pe "s/pg_isready -U odoo -d postgres/pg_isready -U ${db_user} -d ${db_name}/g" docker-compose.yml
}

# Funzione per modificare il Dockerfile di Odoo
update_odoo_dockerfile() {
    local dockerfile_path=$1
    local odoo_version=$2
    local github_token=$3
    
    if [ -f "$dockerfile_path" ]; then
        # Aggiorna la versione di Odoo
        perl -i -pe "s/FROM odoo:18.0/FROM odoo:${odoo_version}/g" "$dockerfile_path"
        
        # Aggiungi l'argomento GITHUB_TOKEN se non esiste
        if ! grep -q "ARG GITHUB_TOKEN" "$dockerfile_path"; then
            # Cerca la riga "FROM odoo" e inserisci l'ARG dopo
            perl -i -pe "s/(FROM odoo:.+\n)/# Usa l'immagine base Odoo\n\1\n# Aggiungi l'argomento per il token GitHub\nARG GITHUB_TOKEN=${github_token}\n\n/" "$dockerfile_path";
        else
            # Se ARG GITHUB_TOKEN esiste già, aggiorna il suo valore
            perl -i -pe "s/ARG GITHUB_TOKEN=.*/ARG GITHUB_TOKEN=${github_token}/" "$dockerfile_path";
        fi
        
        echo "Dockerfile aggiornato: $dockerfile_path"
    else
        echo -e "${RED}Errore: Dockerfile non trovato: $dockerfile_path${NC}"
        return 1
    fi
}

# Funzione per creare file .env e aggiornare le configurazioni correlate
create_env_file() {
    local env_path=$1
    local environment=$2
    local dockerfile_path=$3

    echo "Configurazione ambiente ${environment}..."
    
    # Input per le variabili
    read -p "Inserisci la versione di Odoo (default: 18.0): " odoo_version
    odoo_version=${odoo_version:-18.0}
    
    read -p "Inserisci il nome utente del database (default: odoo): " db_user
    db_user=${db_user:-odoo}
    
    read -s -p "Inserisci la password del database: " db_password
    echo
    db_password=${db_password:-odoo_password}
    
    read -p "Inserisci il nome del database (default: postgres): " db_name
    db_name=${db_name:-postgres}
    
    read -s -p "Inserisci il GitHub token (opzionale): " github_token
    echo

    # Assicurati che la directory esista
    mkdir -p $(dirname "$env_path")

    # Creazione file .env
    cat > "${env_path}" << EOF
ODOO_VERSION=$odoo_version
DB_USER=$db_user
DB_PASSWORD=$db_password
DB_NAME=$db_name
GITHUB_TOKEN=$github_token
EOF

    # Aggiorna il Dockerfile di Odoo
    if update_odoo_dockerfile "${dockerfile_path}" "${odoo_version}" "${github_token}"; then
        # Aggiorna il docker-compose.yml
        update_docker_compose "${environment}" "${db_user}" "${db_password}" "${db_name}"
        echo -e "${GREEN}File .env creato e configurazioni aggiornate per $environment${NC}"
    else
        echo -e "${RED}Errore durante l'aggiornamento delle configurazioni per $environment${NC}"
    fi
    
    # Esporta le variabili per uso successivo
    export DB_USER=$db_user
    export DB_PASSWORD=$db_password
    export DB_NAME=$db_name
}

# Funzione per configurare odoo.conf
configure_odoo() {
    local conf_path=$1
    local environment=$2
    local db_host=$3
    local http_port=$4
    local db_user=$5
    local db_password=$6
    local db_name=$7

    echo "Configurazione Odoo per ${environment}..."
    
    local default_workers
    if [ "$environment" = "Production" ]; then
        default_workers=10
    else
        default_workers=4
    fi
    
    read -p "Numero di workers (default: $default_workers): " workers
    workers=${workers:-$default_workers}

    local log_level
    if [ "$environment" = "Production" ]; then
        log_level="info"
    else
        log_level="debug"
    fi

    # Base della configurazione
    cat > "${conf_path}" << EOF
[options]
http_port = $http_port

db_host = $db_host
db_port = 5432
db_user = ${db_user}
db_password = ${db_password}

addons_path = /mnt/extra-addons,/usr/lib/python3/dist-packages/odoo/addons

data_dir = /var/lib/odoo
logfile = /var/log/odoo/odoo.log

workers = $workers
max_cron_threads = 2

log_level = $log_level
longpolling_port = False
gevent_port = 8072
EOF

    # Aggiungi proxy_mode = True solo per Production
    if [ "$environment" = "Production" ]; then
        echo "proxy_mode = True" >> "${conf_path}"
    fi

    echo -e "${GREEN}File odoo.conf configurato per $environment${NC}"
}

# ASCII Art
echo -e "${BLUE}"
cat << "EOF"
 ██████╗ ██████╗  ██████╗  ██████╗     ██████╗  ██████╗  ██████╗██╗  ██╗███████╗██████╗ 
██╔═══██╗██╔══██╗██╔═══██╗██╔═══██╗    ██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗
██║   ██║██║  ██║██║   ██║██║   ██║    ██║  ██║██║   ██║██║     █████╔╝ █████╗  ██████╔╝
██║   ██║██║  ██║██║   ██║██║   ██║    ██║  ██║██║   ██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗
╚██████╔╝██████╔╝╚██████╔╝╚██████╔╝    ██████╔╝╚██████╔╝╚██████╗██║  ██╗███████╗██║  ██║
 ╚═════╝ ╚═════╝  ╚═════╝  ╚═════╝     ╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
EOF
echo -e "${NC}"

echo -e "${RED}###############################################################################
#                               WARNING!                                        #
#                                                                             #
# To install Odoo Enterprise, you need to create an access token through      #
# GitHub.                                                                     #
#                                                                             #
# To generate the code, go to:                                               #
# Settings -> Developer Settings -> Access Tokens -> Generate token           #
###############################################################################${NC}"

# Main script
echo -e "${BLUE}Inizializzazione configurazione Odoo${NC}"

# Backup del docker-compose.yml originale
cp docker-compose.yml docker-compose.yml.backup

# Configurazione Staging
create_env_file "./srcs/staging/odoo/.env" "Staging" "./srcs/staging/odoo/Dockerfile"
configure_odoo "./srcs/staging/odoo/odoo.conf" "Staging" "db_staging" "8069" "$DB_USER" "$DB_PASSWORD" "$DB_NAME"

echo -e "${GREEN}Configurazione Staging completata${NC}"

# Configurazione Production
create_env_file "./srcs/prod/odoo/.env" "Production" "./srcs/prod/odoo/Dockerfile"
configure_odoo "./srcs/prod/odoo/odoo.conf" "Production" "db_production" "8070" "$DB_USER" "$DB_PASSWORD" "$DB_NAME"

echo -e "${GREEN}Configurazione Production completata${NC}"

echo -e "${BLUE}Configurazione completata${NC}"
echo -e "${GREEN}Backup del docker-compose.yml salvato come docker-compose.yml.backup${NC}"