#!/usr/bin/env bash
#
# restore.sh - Restore a backup produced by backup.sh into a FRESH database.
#
# Usage:
#   ./scripts/restore.sh <path-to-backup-file> [target_db_name]
#
# Example:
#   ./scripts/restore.sh backups/hotel_bookings_20260726_101500.dump hotel_bookings_restore_test
#
# Env vars (all optional, defaults match docker-compose.yml):
#   DB_CONTAINER   - docker compose service/container name (default: hotel-bookings-db)
#   DB_USER        - postgres user (default: app_admin)
#   PGPASSWORD     - postgres password (default: app_password)

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <path-to-backup-file> [target_db_name]" >&2
  exit 1
fi

BACKUP_FILE="$1"
DB_CONTAINER="${DB_CONTAINER:-hotel-bookings-db}"
DB_USER="${DB_USER:-app_admin}"
TARGET_DB="${2:-hotel_bookings_restore_test}"
PGPASSWORD="${PGPASSWORD:-app_password}"

if [ ! -f "$BACKUP_FILE" ]; then
  echo "ERROR: backup file not found: ${BACKUP_FILE}" >&2
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
  echo "ERROR: container '${DB_CONTAINER}' is not running. Start it with: docker compose up -d" >&2
  exit 1
fi

echo "==> Creating fresh database '${TARGET_DB}' (dropping it first if it exists)..."
docker exec -e PGPASSWORD="$PGPASSWORD" "$DB_CONTAINER" \
  psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS ${TARGET_DB};"
docker exec -e PGPASSWORD="$PGPASSWORD" "$DB_CONTAINER" \
  psql -U "$DB_USER" -d postgres -c "CREATE DATABASE ${TARGET_DB};"

echo "==> Copying backup file into the container..."
BASENAME="$(basename "$BACKUP_FILE")"
docker cp "$BACKUP_FILE" "${DB_CONTAINER}:/tmp/${BASENAME}"

echo "==> Restoring into '${TARGET_DB}'..."
docker exec -e PGPASSWORD="$PGPASSWORD" "$DB_CONTAINER" \
  pg_restore -U "$DB_USER" -d "$TARGET_DB" --no-owner --no-privileges "/tmp/${BASENAME}"

docker exec "$DB_CONTAINER" rm -f "/tmp/${BASENAME}"

echo "==> Restore complete. Verifying row counts..."
docker exec -e PGPASSWORD="$PGPASSWORD" "$DB_CONTAINER" \
  psql -U "$DB_USER" -d "$TARGET_DB" -c \
  "SELECT 'hotel_bookings' AS table_name, COUNT(*) FROM hotel_bookings
   UNION ALL
   SELECT 'booking_events', COUNT(*) FROM booking_events;"

echo "==> Done. See README.md 'Backup & Restore' section for full verification steps."
