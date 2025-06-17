#!/bin/bash

# Parâmetros obrigatórios
CLIENT_NAME=$1
SUBDOMAIN=$2
DB_PASSWORD=$3
ADMIN_PASSWD=$4

if [[ -z "$CLIENT_NAME" || -z "$SUBDOMAIN" || -z "$DB_PASSWORD" || -z "$ADMIN_PASSWD" ]]; then
  echo "Uso: $0 <nome_cliente> <subdominio> <db_password> <admin_password>"
  exit 1
fi

# Caminhos
BASE_DIR="/srv/odoo"
CLIENT_DIR="$BASE_DIR/clients/$CLIENT_NAME"
TEMPLATE_CONF="$BASE_DIR/base/odoo.conf.template"
CLIENT_CONF="$CLIENT_DIR/odoo.conf"

# 1. Criar estrutura
mkdir -p "$CLIENT_DIR/custom-addons" "$CLIENT_DIR/filestore" "$CLIENT_DIR/log"
chown -R ubuntu:ubuntu "$CLIENT_DIR"

# 2. Gerar .env
cat <<EOF > "$CLIENT_DIR/.env"
CLIENT_NAME=$CLIENT_NAME
SUBDOMAIN=$SUBDOMAIN
DB_NAME=$CLIENT_NAME
DB_USER=odoo
DB_PASSWORD=$DB_PASSWORD
ADMIN_PASSWD=$ADMIN_PASSWD
EOF

# 3. Gerar odoo.conf
cp "$TEMPLATE_CONF" "$CLIENT_CONF"
sed -i "s|\${DB_PASSWORD}|$DB_PASSWORD|g" "$CLIENT_CONF"
sed -i "s|\${ADMIN_PASSWD}|$ADMIN_PASSWD|g" "$CLIENT_CONF"

# 4. docker-compose.yml (com env_file)
cat <<EOF > "$CLIENT_DIR/docker-compose.yml"
version: '3.1'

services:
  db:
    image: postgres:13
    env_file:
      - .env
    environment:
      POSTGRES_DB=\${DB_NAME}
      POSTGRES_USER=\${DB_USER}
      POSTGRES_PASSWORD=\${DB_PASSWORD}
    volumes:
      - ./filestore:/var/lib/postgresql/data
    restart: always

  odoo:
    image: odoo:17
    env_file:
      - .env
    depends_on:
      - db
    volumes:
      - ./custom-addons:/opt/odoo/custom-addons
      - ./odoo.conf:/etc/odoo/odoo.conf
      - ./log:/var/log/odoo
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.\${CLIENT_NAME}.rule=Host(\`\${SUBDOMAIN}\`)"
      - "traefik.http.services.\${CLIENT_NAME}.loadbalancer.server.port=8069"
    restart: always
EOF

chown -R ubuntu:ubuntu "$CLIENT_DIR"

echo "Instância '$CLIENT_NAME' criada com sucesso."
echo "Subdomínio: $SUBDOMAIN"
echo "Para subir: cd $CLIENT_DIR && docker compose up -d"
