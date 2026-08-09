#!/bin/bash
# Nightly backup of homelab stack: app configs, compose files, NPM db, Mealie data
set -euo pipefail

# --- Configuration (override via environment or edit defaults below) ---
BACKUP_ROOT="${BACKUP_ROOT:-/home/maezstro/backups}"
COMPOSE_DIR="${COMPOSE_DIR:-/home/maezstro}"
ARR_CONFIG_ROOT="${ARR_CONFIG_ROOT:-/media}"
NPM_VOLUME_PREFIX="${NPM_VOLUME_PREFIX:-maezstro}"
MEALIE_VOLUME="${MEALIE_VOLUME:-mealie_mealie-data}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"

DATE=$(date +%F_%H-%M)
DEST="$BACKUP_ROOT/$DATE"
mkdir -p "$DEST"

# --- 1. All *arr / media app configs (excludes Jellyfin's regenerable cache/transcodes) ---
tar -czf "$DEST/arr-configs.tar.gz" \
  --exclude='arr/jellyfin/config/cache' \
  --exclude='arr/jellyfin/config/data/subtitles' \
  --exclude='arr/jellyfin/config/data/attachments' \
  --exclude='arr/jellyfin/config/data/introskipper' \
  --exclude='arr/qbittorrent/config/qBittorrent/ipc-socket' \
  -C "$ARR_CONFIG_ROOT" arr || [ $? -eq 1 ]

# --- 2. Compose files and .env files ---
mkdir -p "$DEST/compose"
cp "$COMPOSE_DIR/docker-compose.yml" "$DEST/compose/docker-compose.yml"
cp "$COMPOSE_DIR/docker/mealie/docker-compose.yaml" "$DEST/compose/mealie-docker-compose.yaml"

# --- 3. Nginx Proxy Manager: consistent sqlite snapshot + keys + certs ---
NPM_DATA="/var/lib/docker/volumes/${NPM_VOLUME_PREFIX}_npm_data/_data"
NPM_LE="/var/lib/docker/volumes/${NPM_VOLUME_PREFIX}_npm_letsencrypt/_data"
mkdir -p "$DEST/npm"
sqlite3 "$NPM_DATA/database.sqlite" ".backup '$DEST/npm/database.sqlite'"
cp "$NPM_DATA/keys.json" "$DEST/npm/keys.json"
tar -czf "$DEST/npm/letsencrypt.tar.gz" -C "$NPM_LE" .

# --- 4. Mealie data (named volume) ---
tar -czf "$DEST/mealie-data.tar.gz" -C "/var/lib/docker/volumes/$MEALIE_VOLUME/_data" .

# --- Prune backups older than RETENTION_DAYS ---
find "$BACKUP_ROOT" -maxdepth 1 -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \;

echo "$(date): Full stack backup completed -> $DEST" >> "$BACKUP_ROOT/backup.log"
