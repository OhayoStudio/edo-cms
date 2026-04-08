#!/bin/bash
# Droplet bootstrap script — run as root on a fresh Ubuntu 24.04 server.
# Usage: bash script/setup_droplet.sh
#
# Before running:
#   1. Replace REPLACE_WITH_EDO_DATABASE_PASSWORD with the value from .env.staging
#   2. Replace REPLACE_WITH_YOUR_PUBLIC_KEY with your public key (cat ~/.ssh/id_ed25519.pub)

set -e

DB_PASS="REPLACE_WITH_EDO_DATABASE_PASSWORD"

# ── Deploy user ────────────────────────────────────────────────────────────────
adduser deploy --disabled-password --gecos ""
usermod -aG sudo deploy
mkdir -p /home/deploy/.ssh
echo "REPLACE_WITH_YOUR_PUBLIC_KEY" >> /home/deploy/.ssh/authorized_keys
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys
chown -R deploy:deploy /home/deploy/.ssh

# ── Postgres ───────────────────────────────────────────────────────────────────
apt update && apt install -y postgresql

sudo -u postgres psql <<SQL
CREATE USER edo WITH PASSWORD '$DB_PASS';
CREATE DATABASE edo_production OWNER edo;
CREATE DATABASE edo_production_cache OWNER edo;
CREATE DATABASE edo_production_queue OWNER edo;
CREATE DATABASE edo_production_cable OWNER edo;
SQL

# Allow Docker containers (172.17.0.0/16) to reach host Postgres
echo "host all edo 172.17.0.0/16 md5" >> /etc/postgresql/*/main/pg_hba.conf
sed -i "s/#listen_addresses.*/listen_addresses = '*'/" /etc/postgresql/*/main/postgresql.conf
systemctl restart postgresql

# ── Storage dir ────────────────────────────────────────────────────────────────
mkdir -p /var/www/edo/storage
chown deploy:deploy /var/www/edo/storage

echo "Droplet ready. Run: bin/kamal setup"
