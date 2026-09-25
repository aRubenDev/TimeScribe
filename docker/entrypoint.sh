#!/bin/sh
# docker/entrypoint.sh
# Shared by the web, queue and scheduler containers.
set -eu

if [ -z "${APP_KEY:-}" ]; then
    echo "[timescribe] APP_KEY is not set. See docker/.env.example." >&2
    exit 1
fi

# SQLite file lives on the /data volume so it survives container rebuilds.
if [ ! -f "${DB_DATABASE}" ]; then
    touch "${DB_DATABASE}"
fi

# Only one container (web) runs migrations; queue/scheduler wait for it
# via depends_on + healthcheck, so they never see a half-migrated schema.
if [ "${RUN_MIGRATIONS:-false}" = "true" ]; then
    php artisan migrate --force --no-interaction
fi

exec "$@"