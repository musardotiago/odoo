#!/bin/bash

# Nome do cliente (ex: cliente01)
read -p "Informe o nome do cliente (ex: cliente01): " CLIENT_NAME

# Caminhos base
BASE_DIR="/srv/odoo"
CLIENT_DIR="$BASE_DIR/clients/$CLIENT_NAME"
ENV_FILE="$CLIENT_DIR/.env"
ODOO_CONF="$CLIENT_DIR/odoo.conf"
NGINX_CONF="/srv/odoo/docker/nginx/conf.d/$CLIENT_NAME.conf"

# Porta interna do container (padrão Odoo)
ODOO_PORT="8069"

# Subdomínio
read -p "Informe o subdomínio (ex: cliente01.dominio.com): " SUBDOMAIN

# Cria diretórios
mkdir -p "$CLIENT_DIR"/{addons,filestore,logs}

# Gera .env
cat <<EOF > "$ENV_FILE"
CLIENT_NAME=$CLIENT_NAME
SUBDOMAIN=$SUBDOMAIN
ODOO_PORT=$ODOO_PORT
EOF

# Gera odoo.conf personalizado
cat <<EOF > "$ODOO_CONF"
[options]
admin_passwd = T13#s25#m33
db_host = db
db_port = 5432
db_user = odoo
db_password = odoo
addons_path = /mnt/extra-addons,/opt/odoo/odoo/addons
logfile = /var/log/odoo/odoo.log
proxy_mode = True
logrotate = True
workers = 2
limit_memory_soft = 536870912
limit_memory_hard = 805306368
limit_time_cpu = 60
limit_time_real = 120
limit_request = 8192
xmlrpc_port = 8069
EOF

# Gera arquivo NGINX para subdomínio
cat <<EOF > "$NGINX_CONF"
server {
    listen 80;
    server_name $SUBDOMAIN;

    location / {
        proxy_pass http://$CLIENT_NAME:8069;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

echo "✅ Estrutura criada para cliente '$CLIENT_NAME'"
echo "➡️ Subdomínio configurado: http://$SUBDOMAIN"

# Remove serviço systemd antigo do Odoo
if systemctl is-active --quiet odoo; then
    echo "⛔ Parando e removendo serviço systemd antigo (odoo.service)"
    sudo systemctl stop odoo
    sudo systemctl disable odoo
    sudo rm /etc/systemd/system/odoo.service
    sudo systemctl daemon-reload
    echo "✔️ Serviço systemd removido"
fi

# Reinicia NGINX reverse proxy com novo domínio
docker compose -f /srv/odoo/docker-compose.nginx.yml up -d
