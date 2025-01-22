# Nome del file docker-compose
docker_compose_file := docker-compose.yml

# Nome dello script di setup
setup_script := setup.sh

# Percorsi per i volumi
odoo_prod_data := ./addons/production/extra-addons
odoo_staging_data := ./addons/staging/extra-addons
db_prod_data := ./data/db/production
db_staging_data := ./data/db/staging

.PHONY: all up down clean create-folders start stop restart init setup install-requirements

# Target principale
init: create-folders setup

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
enable-ssl-production:
	@docker-compose exec -e USE_LETS_ENCRYPT=true nginx_production /init-ssl.sh

# Rinnova certificati Let's Encrypt
renew-ssl:
	@docker-compose exec nginx_staging certbot renew
	@docker-compose exec nginx_production certbot renew

# Reset delle configurazioni
reset:
	@echo "Resetting configuration files..."
	@if [ -f "$(docker_compose_file).backup" ]; then \
		mv $(docker_compose_file).backup $(docker_compose_file); \
		echo "✓ Docker Compose file restored"; \
	else \
		echo "✗ No Docker Compose backup file found"; \
	fi
	@if [ -f "./srcs/staging/nginx/default.conf.backup" ]; then \
		mv ./srcs/staging/nginx/default.conf.backup ./srcs/staging/nginx/default.conf; \
		echo "✓ Staging Nginx configuration restored"; \
	fi
	@if [ -f "./srcs/prod/nginx/default.conf.backup" ]; then \
		mv ./srcs/prod/nginx/default.conf.backup ./srcs/prod/nginx/default.conf; \
		echo "✓ Production Nginx configuration restored"; \
	fi
	@if [ -f "./srcs/staging/odoo/odoo.conf.backup" ]; then \
		mv ./srcs/staging/odoo/odoo.conf.backup ./srcs/staging/odoo/odoo.conf; \
		echo "✓ Staging Odoo configuration restored"; \
	fi
	@if [ -f "./srcs/prod/odoo/odoo.conf.backup" ]; then \
		mv ./srcs/prod/odoo/odoo.conf.backup ./srcs/prod/odoo/odoo.conf; \
		echo "✓ Production Odoo configuration restored"; \
	fi
	@echo "Reset completed!"

# Backup delle configurazioni
backup:
	@echo "Creating backup of configuration files..."
	@if [ -f "$(docker_compose_file)" ]; then \
		cp $(docker_compose_file) $(docker_compose_file).backup; \
		echo "✓ Docker Compose file backup created"; \
	fi
	@if [ -f "./srcs/staging/nginx/default.conf" ]; then \
		cp ./srcs/staging/nginx/default.conf ./srcs/staging/nginx/default.conf.backup; \
		echo "✓ Staging Nginx configuration backup created"; \
	fi
	@if [ -f "./srcs/prod/nginx/default.conf" ]; then \
		cp ./srcs/prod/nginx/default.conf ./srcs/prod/nginx/default.conf.backup; \
		echo "✓ Production Nginx configuration backup created"; \
	fi
	@if [ -f "./srcs/staging/odoo/odoo.conf" ]; then \
		cp ./srcs/staging/odoo/odoo.conf ./srcs/staging/odoo/odoo.conf.backup; \
		echo "✓ Staging Odoo configuration backup created"; \
	fi
	@if [ -f "./srcs/prod/odoo/odoo.conf" ]; then \
		cp ./srcs/prod/odoo/odoo.conf ./srcs/prod/odoo/odoo.conf.backup; \
		echo "✓ Production Odoo configuration backup created"; \
	fi
	@echo "Backup completed!"