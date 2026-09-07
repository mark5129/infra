#!/bin/sh
# Daily PostgreSQL backup — runs inside a db-backup-* container.
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

# pg_dump | gzip masks pg_dump's exit status (a pipeline's status is its last
# command's, i.e. gzip's) — `set -e` alone won't catch pg_dump failing (wrong
# client/server version, auth failure, etc.), so a broken dump would still
# "succeed" and silently overwrite good history with garbage. Dump to a plain
# file first and check pg_dump's own exit code before compressing.
pg_dump -h "$DB_HOST" -U "$POSTGRES_USER" "$POSTGRES_DB" > "${BACKUP_FILE%.gz}"
gzip -f "${BACKUP_FILE%.gz}"

find "$BACKUP_DIR" -name 'backup_*.sql.gz' -mtime +"$RETENTION_DAYS" -delete

echo "Backup saved: $BACKUP_FILE"
