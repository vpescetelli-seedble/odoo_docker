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
    
    # Usa perl per le sostituzioni
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
        
        # Gestione del token GitHub
        if ! grep -q "ARG GITHUB_TOKEN" "$dockerfile_path"; then
            # Cerca la riga "FROM odoo" e inserisci l'ARG dopo
            perl -i -pe "s/(FROM odoo:.+\n)/# Use Odoo base image\n\1\n# Add GitHub token argument\nARG GITHUB_TOKEN=${github_token}\n\n/" "$dockerfile_path"
        else
            # Se ARG GITHUB_TOKEN esiste già, aggiorna il suo valore
            perl -i -pe "s/ARG GITHUB_TOKEN=.*/ARG GITHUB_TOKEN=${github_token}/" "$dockerfile_path"
        fi
        
        echo "Dockerfile updated: $dockerfile_path"
    else
        echo -e "${RED}Error: Dockerfile not found: $dockerfile_path${NC}"
        return 1
    fi
}

# Funzione per inizializzare il database Odoo
initialize_odoo_db() {
    local environment=$1
    local internal_port=$2
    local max_retries=30
    local retries=0
    
    clear
    echo "Initializing Odoo database for ${environment}..."
    
    # Determina la porta esterna in base all'ambiente
    local external_port
    if [ "$environment" = "Production" ]; then
        external_port="80"
    else
        external_port="8080"
    fi
    
    # Converti environment in minuscolo
    local env_lower=$(to_lower "$environment")
    
    # Attendi che il servizio Odoo sia disponibile
    echo "Waiting for Odoo service to be ready..."
    while ! curl -s "http://localhost:${external_port}/web" > /dev/null; do
        sleep 5
        retries=$((retries + 1))
        if [ $retries -ge $max_retries ]; then
            echo -e "${RED}Timeout waiting for Odoo service${NC}"
            return 1
        fi
        echo "Waiting for Odoo (attempt $retries of $max_retries)..."
    done
    
    # Crea il database usando la porta esterna
    curl -X POST \
        -F "master_pwd=${ADMIN_PASSWORD}" \
        -F "name=${DB_NAME}_${env_lower}" \
        -F "login=admin" \
        -F "password=admin" \
        -F "email=${ADMIN_EMAIL}" \
        -F "phone=" \
        -F "lang=en_US" \
        -F "country_code=IT" \
        "http://localhost:${external_port}/web/database/create"
        
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Database initialization completed for $environment${NC}"
    else
        echo -e "${RED}Failed to initialize database for $environment${NC}"
        return 1
    fi
}

# Funzione per convertire in minuscolo (compatibile con sh)
to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Funzione per creare file .env e aggiornare le configurazioni
create_env_file() {
    local env_path=$1
    local environment=$2
    local dockerfile_path=$3
    
    echo "Environment configuration for ${environment}..."
    
    # Input per le variabili
    read -p "Enter Odoo version (default: 18.0): " odoo_version
    odoo_version=${odoo_version:-18.0}
    
    read -p "Enter database username (default: odoo): " db_user
    db_user=${db_user:-odoo}
    
    read -s -p "Enter database password (default: odoo_password): " db_password
    echo
    db_password=${db_password:-odoo_password}
    
    read -p "Enter database name (default: postgres): " db_name
    db_name=${db_name:-postgres}
    
    read -s -p "Enter GitHub token (optional): " github_token
    echo
    
    read -p "Enter admin email (default: admin@example.com): " admin_email
    admin_email=${admin_email:-admin@example.com}
    
    read -s -p "Enter admin password for database management (default: admin): " admin_password
    echo
    admin_password=${admin_password:-admin}
    
    # Converti environment in minuscolo usando la nuova funzione
    local env_lower=$(to_lower "$environment")
    
    # Creazione directory e file .env
    mkdir -p $(dirname "$env_path")
    cat > "${env_path}" << EOF
ODOO_VERSION=$odoo_version
DB_USER=$db_user
DB_PASSWORD=$db_password
DB_NAME=${db_name}_${env_lower}
GITHUB_TOKEN=$github_token
ADMIN_EMAIL=$admin_email
ADMIN_PASSWORD=$admin_password
EOF
    
    # Aggiorna le configurazioni
    if update_odoo_dockerfile "${dockerfile_path}" "${odoo_version}" "${github_token}"; then
        update_docker_compose "${environment}" "${db_user}" "${db_password}" "${db_name}"
        echo -e "${GREEN}Configuration updated for $environment${NC}"
    else
        echo -e "${RED}Error updating configurations for $environment${NC}"
        return 1
    fi
    
    # Esporta le variabili per uso successivo
    export DB_USER=$db_user
    export DB_PASSWORD=$db_password
    export DB_NAME=$db_name
    export ADMIN_EMAIL=$admin_email
    export ADMIN_PASSWORD=$admin_password
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
    
    # Imposta workers basati sull'ambiente
    local default_workers
    if [ "$environment" = "Production" ]; then
        default_workers=10
    else
        default_workers=4
    fi
    
    read -p "Number of workers (default: $default_workers): " workers
    workers=${workers:-$default_workers}
    
    local log_level
    if [ "$environment" = "Production" ]; then
        log_level="info"
    else
        log_level="debug"
    fi

    # Converti environment in minuscolo
    local env_lower=$(to_lower "$environment")
    
    # Crea odoo.conf
    mkdir -p $(dirname "$conf_path")
    cat > "${conf_path}" << EOF
[options]
http_port = $http_port

db_host = $db_host
db_port = 5432
db_user = ${db_user}
db_password = ${db_password}
db_name = ${db_name}_${env_lower}

addons_path = /mnt/extra-addons,/usr/lib/python3/dist-packages/odoo/addons

data_dir = /var/lib/odoo
logfile = /var/log/odoo/odoo.log

workers = $workers
max_cron_threads = 2

log_level = $log_level
longpolling_port = False
gevent_port = 8072
EOF
    
    if [ "$environment" = "Production" ]; then
        echo "proxy_mode = True" >> "${conf_path}"
    fi
    
    echo -e "${GREEN}odoo.conf configured for $environment${NC}"
}


# Funzione per il deployment degli ambienti
deploy_environments() {
    clear
    echo -e "${BLUE}Starting deployment process...${NC}"
    
    # Build e avvio dei container
    docker-compose up --build -d
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to start Docker containers${NC}"
        return 1
    fi
    
    # Attendi che i servizi siano pronti
    echo -e "${GREEN}Deployment completed successfully${NC}"
    echo -e "${BLUE}Waiting for services to be ready...${NC}"
    sleep 10
    
    return 0
}

# Aggiungi queste funzioni dopo le funzioni esistenti e prima del main script

# Funzione per la configurazione SSL
configure_ssl() {
    local environment=$1
    local env_lowercase=$(to_lower "$environment")
    
    echo -e "${BLUE}SSL Configuration for ${environment}${NC}"
    
    while true; do
        read -p "Do you want to use Let's Encrypt for SSL? (y/n): " use_lets_encrypt
        case $use_lets_encrypt in
            [Yy]* )
                read -p "Enter domain name (e.g., staging.yourdomain.com): " domain_name
                read -p "Enter email for Let's Encrypt notifications: " le_email
                
                # Aggiorna il file .env di nginx
                mkdir -p "./srcs/${env_lowercase}/nginx"
                cat > "./srcs/${env_lowercase}/nginx/.env" << EOF
USE_LETS_ENCRYPT=true
DOMAIN_NAME=$domain_name
LE_EMAIL=$le_email
ENVIRONMENT=$env_lowercase
EOF
                
                # Aggiorna nginx.conf
                update_nginx_conf "${env_lowercase}" "$domain_name" "lets_encrypt"
                break
                ;;
            [Nn]* )
                # Usa certificati self-signed
                cat > "./srcs/${env_lowercase}/nginx/.env" << EOF
USE_LETS_ENCRYPT=false
DOMAIN_NAME=localhost
ENVIRONMENT=$env_lowercase
EOF
                
                # Aggiorna nginx.conf
                update_nginx_conf "${env_lowercase}" "localhost" "self_signed"
                break
                ;;
            * ) echo "Please answer yes (y) or no (n).";;
        esac
    done
}

# Funzione per aggiornare la configurazione nginx
update_nginx_conf() {
    local env=$1
    local domain=$2
    local ssl_type=$3
    local conf_path="./srcs/${env}/nginx/default.conf"
    
    # Backup della configurazione esistente
    if [ -f "$conf_path" ]; then
        cp "$conf_path" "${conf_path}.backup"
    fi
    
    # Crea la nuova configurazione
    cat > "$conf_path" << EOF
upstream odoo {
    server odoo_${env}:8069;
}

upstream odoochat {
    server odoo_${env}:8072;
}

map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}

# Configurazione iniziale HTTP per tutti i casi
server {
    listen 80;
    server_name ${domain};

    # Configurazione per Let's Encrypt ACME challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

# Configurazione HTTPS
server {
    listen 443 ssl;
    server_name ${domain};

    # Usiamo sempre inizialmente i certificati self-signed
    ssl_certificate /etc/nginx/ssl/${env}.crt;
    ssl_certificate_key /etc/nginx/ssl/${env}.key;
    
    # Configurazione SSL
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;

    # Configurazione proxy moderna
    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;

    location / {
        proxy_pass http://odoo;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /websocket {
        proxy_pass http://odoochat;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header X-Forwarded-Host \$http_host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
}

# Main script
clear 
# ASCII Art e messaggio di benvenuto
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
#                               WARNING!                                      #
#                                                                             #
# To install Odoo Enterprise, you need to create an access token through      #
# GitHub.                                                                     #
#                                                                             #
# To generate the code, go to:                                                #
# Settings -> Developer Settings -> Access Tokens -> Generate token           #
###############################################################################${NC}"

# Main script
echo -e "${BLUE}Odoo configuration initialization${NC}"

# Richiedi conferma per procedere
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

# Configurazione Staging
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

create_env_file "./srcs/staging/odoo/.env" "Staging" "./srcs/staging/odoo/Dockerfile"
configure_odoo "./srcs/staging/odoo/odoo.conf" "Staging" "db_staging" "8069" "$DB_USER" "$DB_PASSWORD" "$DB_NAME"
configure_ssl "Staging"  # Aggiungi questa linea

echo -e "${GREEN}Staging configuration completed${NC}"

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

create_env_file "./srcs/production/odoo/.env" "Production" "./srcs/production/odoo/Dockerfile"
configure_odoo "./srcs/production/odoo/odoo.conf" "Production" "db_production" "8070" "$DB_USER" "$DB_PASSWORD" "$DB_NAME"
configure_ssl "Production"  # Aggiungi questa linea

# Deploy degli ambienti
if deploy_environments; then
    # Inizializza i database
    initialize_odoo_db "Staging" "8069"
    initialize_odoo_db "Production" "8070"
    
    # Messaggio finale
    clear
    echo -e "${GREEN}"
    cat << "EOF"
╔════════════════════════════════════════════════════════════════════════════╗
║                                                                            ║
║     ____                   _                 _ _                           ║
║    |  _ \    ___    ___  | |__    ___    __| | |                           ║
║    | |_) |  / _ \  / __| | '_ \  / _ \  / _` | |                           ║
║    |  _ <  | (_) | \__ \ | | | || (_) || (_| |_|                           ║
║    |_| \_\  \___/  |___/ |_| |_| \___/  \__,_(_)                           ║
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
    echo -e "\n   🚀 Your Odoo environments are ready!"
    
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                   STAGING ENVIRONMENT                          ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "   📌 Access Information:"
    echo -e "      • URL          : http://localhost:8080 | https://localhost:8443"
    echo -e "      • Database Name: ${DB_NAME}_staging"
    echo -e "\n   🔐 Database Credentials:"
    echo -e "      • Master Password : ${ADMIN_PASSWORD}"
    echo -e "      • Admin Email     : ${ADMIN_EMAIL}"
    echo -e "      • Admin Password  : admin"
    echo -e "      • Database User   : ${DB_USER}"
    
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                  PRODUCTION ENVIRONMENT                        ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "   📌 Access Information:"
    echo -e "      • URL          : http://localhost:80 | https://localhost:443"
    echo -e "      • Database Name: ${DB_NAME}_production"
    echo -e "\n   🔐 Database Credentials:"
    echo -e "      • Master Password : ${ADMIN_PASSWORD}"
    echo -e "      • Admin Email     : ${ADMIN_EMAIL}"
    echo -e "      • Admin Password  : admin"
    echo -e "      • Database User   : ${DB_USER}"
    
    echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                       NEXT STEPS                               ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "   1. Review your configuration files"
    echo -e "   2. Start your environment with: make up"
    echo -e "   3. Access Odoo through your browser using the URLs above"
    echo -e "   4. Log in with the admin credentials provided above"
    
    echo -e "\n${RED}⚠️  IMPORTANT: Please save these credentials in a secure location!${NC}"
    echo -e "${RED}   This information will not be shown again.${NC}\n"

else
    echo -e "${RED}Setup failed. Please check the logs above for details.${NC}"
    exit 1
fi