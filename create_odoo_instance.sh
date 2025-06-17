#!/bin/bash

set -e

CLIENT=$1
DOMAIN="$CLIENT.mitsd.com.br"
BASE_DIR="/srv/odoo/clients/$CLIENT"
PORT=$((RANDOM%1000+9000))  # Ex: porta interna do container
ODOO_CONF="$BASE_DIR/config/odoo.conf"

if [ -z "$CLIENT" ]; then
  echo "Usage: $0 <client-name>"
  exit 1
fi

# Criar estrutura de pastas
mkdir -p "$BASE_DIR"/{data,config,addons,logs}
cp /srv/odoo/base/odoo.conf "$ODOO_CONF"
sed -i "s/db_name = .*/db_name = $CLIENT/" "$ODOO_CONF"
sed -i "s|addons_path = .*|addons_path = /mnt/extra-addons,/usr/lib/python3/dist-packages/odoo/addons|" "$ODOO_CONF"
sed -i "s|logfile = .*|logfile = /var/log/odoo/odoo.log|" "$ODOO_CONF"

# Criar .env
cat > "$BASE_DIR/.env" <<EOF
ODOO_DB=$CLIENT
ODOO_PORT=$PORT
EOF

# Criar docker-compose.yml por cliente
cat > "$BASE_DIR/docker-compose.yml" <<EOF
version: "3.9"

services:
  odoo:
    image: odoo:17
    container_name: odoo_$CLIENT
    env_file:
      - .env
    volumes:
      - ./data:/var/lib/odoo
      - ./config/odoo.conf:/etc/odoo/odoo.conf
      - ./addons:/mnt/extra-addons
    restart: always
    expose:
      - "8069"
EOF

# Criar config NGINX para o subdomínio
NGINX_CONF="/srv/odoo/docker/nginx/sites-enabled/$CLIENT.conf"
cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://odoo_$CLIENT:8069;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /longpolling {
        proxy_pass http://odoo_$CLIENT:8072;
    }
}
EOF

echo "[INFO] Cliente '$CLIENT' configurado. Subdomínio: http://$DOMAIN"
echo "[INFO] Lembre-se de adicionar '$DOMAIN' ao DNS apontando para o IP do servidor."
