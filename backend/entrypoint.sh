#!/bin/sh
set -e

# Entrypoint robusto para Django (espera DB, migraciones, collectstatic opcional)
SQL_ENGINE=${SQL_ENGINE:-}
SQL_HOST=${SQL_HOST:-localhost}
SQL_PORT=${SQL_PORT:-5432}
SQL_USER=${SQL_USER:-devuser}
SQL_DATABASE=${SQL_DATABASE:-devdb}
FLUSH_DB=${FLUSH_DB:-false}
RUN_COLLECTSTATIC=${RUN_COLLECTSTATIC:-false}
TIMEOUT=${WAIT_FOR_DB_TIMEOUT:-60}

# Función wait for port usando nc/pg_isready fallback
wait_for_db() {
  host="$1"
  port="$2"
  timeout="$3"
  elapsed=0
  interval=1

  echo "Waiting for DB at ${host}:${port} (timeout ${timeout}s)..."

  while true; do
    # intentar pg_isready si está disponible
    if command -v pg_isready >/dev/null 2>&1; then
      if pg_isready -h "$host" -p "$port" -U "$SQL_USER" >/dev/null 2>&1; then
        break
      fi
    else
      # fallback a nc
      if nc -z "$host" "$port" >/dev/null 2>&1; then
        break
      fi
    fi

    elapsed=$((elapsed + interval))
    if [ "$elapsed" -ge "$timeout" ]; then
      echo "Timed out waiting for database at ${host}:${port}"
      return 1
    fi
    sleep "$interval"
  done

  echo "Database is ready at ${host}:${port}"
  return 0
}

# Si SQL_ENGINE indica PostgreSQL, hacemos wait y migraciones
case "$SQL_ENGINE" in
  *postgres*|*postgresql*)
    wait_for_db "$SQL_HOST" "$SQL_PORT" "$TIMEOUT" || exit 1
    ;;
  *)
    # Si no se usa postgres, omitimos wait_for_db
    ;;
esac

# Flux opcional (por seguridad, no por defecto)
if [ "$FLUSH_DB" = "true" ]; then
  echo "Flushing database (FLUSH_DB=true)"
  python manage.py flush --no-input
fi

# Migraciones
echo "Running migrations..."
python manage.py migrate --noinput

# collectstatic opcional
if [ "$RUN_COLLECTSTATIC" = "true" ]; then
  echo "Running collectstatic..."
  python manage.py collectstatic --noinput
fi

# Finalmente ejecutar el comando que pasaron al contenedor (CMD)
echo "Executing: $@"
exec "$@"

