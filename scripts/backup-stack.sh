#!/bin/bash
# Nightly backup of ServerChan stack: app configs, compose files, NPM db, Mealie data
set -euo pipefail

BACKUP_ROOT="/home/maezstro/backups"
DATE=$(date +%F_%H-%M)
DEST="$BACKUP_ROOT/$DATE"
RETENTION_DAYS=14

mkdir -p "$DEST"

# --- 1. All *arr / media app configs (excludes Jellyfin's regenerable cache/transcodes) ---
tar -czf "$DEST/arr-configs.tar.gz" \
  --exclude='arr/jellyfin/config/cache' \
  --exclude='arr/jellyfin/config/data/subtitles' \
  --exclude='arr/jellyfin/config/data/attachments' \
  --exclude='arr/jellyfin/config/data/introskipper' \
  --exclude='arr/qbittorrent/config/qBittorrent/ipc-socket' \
  -C /media arr || [ $? -eq 1 ]

# --- 2. Compose files and .env files ---
mkdir -p "$DEST/compose"
cp /home/maezstro/docker-compose.yml "$DEST/compose/docker-compose.yml"
cp /home/maezstro/glance/docker-compose.yml "$DEST/compose/glance-docker-compose.yml"
cp /home/maezstro/glance/.env "$DEST/compose/glance.env"
cp /home/maezstro/docker/mealie/docker-compose.yaml "$DEST/compose/mealie-docker-compose.yaml"

# --- 3. Nginx Proxy Manager: consistent sqlite snapshot + keys + certs ---
NPM_DATA="/var/lib/docker/volumes/maezstro_npm_data/_data"
NPM_LE="/var/lib/docker/volumes/maezstro_npm_letsencrypt/_data"
mkdir -p "$DEST/npm"
sqlite3 "$NPM_DATA/database.sqlite" ".backup '$DEST/npm/database.sqlite'"
cp "$NPM_DATA/keys.json" "$DEST/npm/keys.json"
tar -czf "$DEST/npm/letsencrypt.tar.gz" -C "$NPM_LE" .

# --- 4. Mealie data (named volume) ---
tar -czf "$DEST/mealie-data.tar.gz" -C /var/lib/docker/volumes/mealie_mealie-data/_data .

# --- Prune backups older than RETENTION_DAYS ---
find "$BACKUP_ROOT" -maxdepth 1 -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \;

echo "$(date): Full stack backup completed -> $DEST" >> "$BACKUP_ROOT/backup.log"
