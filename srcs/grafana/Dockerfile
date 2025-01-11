FROM grafana/grafana:latest

# Install plugins (replace "PLUGIN_ID" with actual plugin IDs)
RUN grafana-cli plugins install PLUGIN_ID

# Set permissions (if necessary)
USER root
RUN chmod -R 777 /var/lib/grafana

USER grafana
