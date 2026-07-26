#!/usr/bin/env bash
#
# backup.sh - Create a timestamped backup of the local hotel_bookings database.
#
# Usage:
#   ./scripts/backup.sh
#
# Env vars (all optional, defaults match docker-compose.yml):
#   DB_CONTAINER   - docker compose service/container name (default: hotel-bookings-db)
#   DB_USER        - postgres user (default: app_admin)
#   DB_NAME        - database name (default: hotel_bookings)
#   BACKUP_DIR     - where to store the dump (default: ./backups)

set -euo pipefail

DB_CONTAINER="${DB_CONTAINER:-hotel-bookings-db}"
DB_USER="${DB_USER:-app_admin}"
DB_NAME="${DB_NAME:-hotel_bookings}"
BACKUP_DIR="${BACKUP_DIR:-$(dirname "$0")/../backups}"

mkdir -p "$BACKUP_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.dump"

echo "==> Checking that the database container is running..."
if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
  echo "ERROR: container '${DB_CONTAINER}' is not running. Start it with: docker compose up -d" >&2
  exit 1
fi

echo "==> Backing up '${DB_NAME}' from container '${DB_CONTAINER}'..."
# -F c = custom format: compressed, and restorable with pg_restore
# (also supports selective restore of individual tables if ever needed).
docker exec -e PGPASSWORD="${PGPASSWORD:-app_password}" "$DB_CONTAINER" \
  pg_dump -U "$DB_USER" -d "$DB_NAME" -F c -f "/tmp/${DB_NAME}_${TIMESTAMP}.dump"

docker cp "${DB_CONTAINER}:/tmp/${DB_NAME}_${TIMESTAMP}.dump" "$BACKUP_FILE"
docker exec "$DB_CONTAINER" rm -f "/tmp/${DB_NAME}_${TIMESTAMP}.dump"

echo "==> Backup complete: ${BACKUP_FILE}"
echo "$(du -h "$BACKUP_FILE" | cut -f1) written."
