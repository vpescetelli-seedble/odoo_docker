# Nome del file docker-compose
docker_compose_file := docker-compose.yml

# Nome dello script di setup
setup_script := setup.sh

# Percorsi per i volumi
odoo_prod_data := ./addons/production/extra-addons
odoo_staging_data := ./addons/staging/extra-addons
db_prod_data := ./data/db/prod
db_staging_data := ./data/db/staging

.PHONY: all up down clean create-folders start stop restart init setup install-requirements

# Target principale
init: create-folders install-requirements setup

# Target per il setup
setup:
	@chmod +x $(setup_script)
	@./$(setup_script)

# Avvia i servizi definiti nel docker-compose
up:
	docker-compose -f $(docker_compose_file) up --build -d

# Avvia i servizi in modalità detached con build
deploy:
	docker-compose -f $(docker_compose_file) up --build -d

# Ferma e rimuove i container, le reti e i volumi
down:
	docker-compose -f $(docker_compose_file) down

# Installa i requisiti necessari
install-requirements:
	@echo "Installing Docker and Docker Compose..."
	@if ! command -v docker &> /dev/null; then \
		sudo apt-get update; \
		sudo apt-get install docker.io docker-compose -y; \
	fi
	@echo "Requirements installed successfully."

# Crea le cartelle necessarie per i volumi
create-folders:
	@mkdir -p $(odoo_prod_data)
	@mkdir -p $(odoo_staging_data)
	@mkdir -p $(db_prod_data)
	@mkdir -p $(db_staging_data)
	@echo "Volume folders created successfully."

# Pulisce completamente l'ambiente
clean:
	@echo "Cleaning up the environment..."
	@docker-compose -f $(docker_compose_file) down -v
	@rm -rf $(odoo_prod_data)/* $(odoo_staging_data)/* $(db_prod_data)/* $(db_staging_data)/*
	@echo "Environment cleaned successfully."

# Avvia un singolo container
start:
	@if [ -z "$(container)" ]; then \
		echo "Please specify a container with 'make start container=<container-name>'"; \
		exit 1; \
	fi
	docker-compose -f $(docker_compose_file) start $(container)

# Ferma un singolo container
stop:
	@if [ -z "$(container)" ]; then \
		echo "Please specify a container with 'make stop container=<container-name>'"; \
		exit 1; \
	fi
	docker-compose -f $(docker_compose_file) stop $(container)

# Riavvia un singolo container
restart:
	@if [ -z "$(container)" ]; then \
		echo "Please specify a container with 'make restart container=<container-name>'"; \
		exit 1; \
	fi
	docker-compose -f $(docker_compose_file) restart $(container)

# Mostra i log dei container
logs:
	@if [ -z "$(container)" ]; then \
		docker-compose -f $(docker_compose_file) logs -f; \
	else \
		docker-compose -f $(docker_compose_file) logs -f $(container); \
	fi

# Rebuild e restart dei container
rebuild:
	@docker-compose -f $(docker_compose_file) up --build -d --force-recreate


# Abilita Let's Encrypt per staging
enable-ssl-staging:
	@docker-compose exec -e USE_LETS_ENCRYPT=true nginx_staging /init-ssl.sh

# Abilita Let's Encrypt per production
enable-ssl-prod:
	@docker-compose exec -e USE_LETS_ENCRYPT=true nginx_production /init-ssl.sh

# Rinnova certificati Let's Encrypt
renew-ssl:
	@docker-compose exec nginx_staging certbot renew
	@docker-compose exec nginx_production certbot renew