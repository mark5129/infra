#!/bin/sh
# Daily PostgreSQL backup – runs inside a db-backup-* container.
# Requires in the container environment:
#   POSTGRES_USER, POSTGRES_DB, PGPASSWORD (= POSTGRES_PASSWORD), DB_HOST
#
# DB_HOST must be set explicitly by the consuming project's compose file
# (e.g. `environment: DB_HOST: db-prod`) — this script has no project-specific
# default, so two different projects can share it without silently backing up
# the wrong database.
set -e

: "${DB_HOST:?DB_HOST must be set (the Docker service name of the Postgres instance to back up)}"

BACKUP_DIR=/backups
RETENTION_DAYS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/backup_${TIMESTAMP}.sql.gz"

pg_dump -h "$DB_HOST" -U "$POSTGRES_USER" "$POSTGRES_DB" | gzip > "$BACKUP_FILE"

find "$BACKUP_DIR" -name 'backup_*.sql.gz' -mtime +"$RETENTION_DAYS" -delete

echo "Backup saved: $BACKUP_FILE"
