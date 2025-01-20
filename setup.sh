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
        
        echo "Dockerfile update: $dockerfile_path"
    else
        echo -e "${RED}Error: Dockerfile not found: $dockerfile_path${NC}"
        return 1
    fi
}

# Funzione per creare file .env e aggiornare le configurazioni correlate
create_env_file() {
    local env_path=$1
    local environment=$2
    local dockerfile_path=$3

    echo "Environment configuration ${environment}..."
    
    # Input per le variabili
    read -p "Enter the Odoo version (default: 18.0): " odoo_version
    odoo_version=${odoo_version:-18.0}
    
    read -p "Enter the database username (default: odoo): " db_user
    db_user=${db_user:-odoo}
    
    read -s -p "Enter the database password: " db_password
    echo
    db_password=${db_password:-odoo_password}
    
    read -p "Enter the database host name (default: postgres): " db_name
    db_name=${db_name:-postgres}
    
    read -s -p "Enter the GitHub token (optional): " github_token
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
        echo -e "${GREEN}.env file created and configurations updated for $environment${NC}"
    else
        echo -e "${RED}Error while updating configurations for $environment${NC}"
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

    echo "Odoo configuration for ${environment}..."
    
    local default_workers
    if [ "$environment" = "Production" ]; then
        default_workers=10
    else
        default_workers=4
    fi
    
    read -p "Numbers of workers (default: $default_workers): " workers
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

    echo -e "${GREEN}odoo.conf file configured for $environment${NC}"
}

clear 
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
echo -e "${BLUE}Odoo configuration initialization

${NC}"

# Richiedi conferma per proseguire
while true; do
    read -p "Do you want to proceed with the configuration? [Y/n] " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) echo "Configuration aborted."; exit;;
        * ) echo "Please answer yes (Y) or no (n).";;
    esac
done

# Backup del docker-compose.yml originale
cp docker-compose.yml docker-compose.yml.backup

# Configurazione Production
clear
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════════╗
║                   STAGING ENVIRONMENT CONFIGURATION                       ║
║                                                                           ║
║               Preparation of the development environment                  ║
╚═══════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"


# Configurazione Staging
create_env_file "./srcs/staging/odoo/.env" "Staging" "./srcs/staging/odoo/Dockerfile"
configure_odoo "./srcs/staging/odoo/odoo.conf" "Staging" "db_staging" "8069" "$DB_USER" "$DB_PASSWORD" "$DB_NAME"

echo -e "${GREEN}Configurazione Staging completata${NC}"

# Configurazione Production
clear
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════════╗
║                   PRODUCTION ENVIRONMENT CONFIGURATION                    ║
║                                                                           ║
║                Preparation of the production environment                  ║
╚═══════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

create_env_file "./srcs/prod/odoo/.env" "Production" "./srcs/prod/odoo/Dockerfile"
configure_odoo "./srcs/prod/odoo/odoo.conf" "Production" "db_production" "8070" "$DB_USER" "$DB_PASSWORD" "$DB_NAME"

echo -e "${GREEN}Configuration Production completed${NC}"

echo -e "${BLUE}Configuration completed${NC}"
echo -e "${GREEN}Backup of docker-compose.yml saved as docker-compose.yml.backup${NC}"

sleep 2
clear 
# New completion message with ASCII art
echo -e "${GREEN}"
cat << "EOF"

╔════════════════════════════════════════════════════════════════════════════╗
║                                                                            ║
║             ____                   _                 _ _                   ║
║            |  _ \    ___    ___  | |__    ___    __| | |                   ║
║            | |_) |  / _ \  / __| | '_ \  / _ \  / _` | |                   ║
║            |  _ <  | (_) | \__ \ | | | || (_) || (_| |_|                   ║
║            |_| \_\  \___/  |___/ |_| |_| \___/  \__,_(_)                   ║
║                                                                            ║
║                Configuration completed successfully!                       ║
║                                                                            ║
╚════════════════════════════════════════════════════════════════════════════╝

   🚀 Your Odoo environments are ready to launch!

   ✓ Staging Environment  : http | Port 8080  --- https | Port 8443
   ✓ Production Environment: http | Port 80 --- https | Port 443
   ✓ Configuration files created and updated
   ✓ Docker Compose backup saved

   📝 Next steps:
   1. Review your configuration files
   2. Start your environment with make up
   3. Access Odoo through your browser

EOF
echo -e "${NC}"