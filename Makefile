# Nome del file docker-compose
docker_compose_file := docker-compose.yml

# Percorsi per i volumi
odoo_prod_data := ./data/odoo/prod
odoo_staging_data := ./data/odoo/staging
db_prod_data := ./data/db/prod
db_staging_data := ./data/db/staging

.PHONY: all up down clean create-folders start stop restart

# Target principale
all: install-requirements up

# Avvia i servizi definiti nel docker-compose
up:
	docker-compose -f $(docker_compose_file) up --build -d

# Ferma e rimuove i container, le reti e i volumi
# associati al docker-compose
down:
	docker-compose -f $(docker_compose_file) down

install-requirements:
	sudo apt-get install docker.io docker-compose wkhtmltopdf -y

# Crea le cartelle necessarie per i volumi se non esistono
create-folders:
	@mkdir -p $(odoo_prod_data)
	@mkdir -p $(odoo_staging_data)
	@mkdir -p $(db_prod_data)
	@mkdir -p $(db_staging_data)
	@echo "Cartelle per i volumi create (se non esistevano)."

# Rimuove tutte le cartelle di dati
clean:
	rm -rf $(odoo_prod_data) $(odoo_staging_data) $(db_prod_data) $(db_staging_data)
	@echo "Cartelle dei volumi rimosse."

# Avvia un singolo container
start:
	@if [ -z "$(container)" ]; then \
		echo "Specificare un container con 'make start container=<nome-container>'"; \
		exit 1; \
	fi
	docker-compose -f $(docker_compose_file) start $(container)

# Ferma un singolo container
stop:
	@if [ -z "$(container)" ]; then \
		echo "Specificare un container con 'make stop container=<nome-container>'"; \
		exit 1; \
	fi
	docker-compose -f $(docker_compose_file) stop $(container)

# Riavvia un singolo container
restart:
	@if [ -z "$(container)" ]; then \
		echo "Specificare un container con 'make restart container=<nome-container>'"; \
		exit 1; \
	fi
	docker-compose -f $(docker_compose_file) restart $(container)
