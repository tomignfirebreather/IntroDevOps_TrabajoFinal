#!/usr/bin/env bash
# wait-for-db.sh host port -- cmd...
set -e

host="$1"
port="$2"
shift 2

# default timeout
timeout=60
elapsed=0
sleep_interval=2

until pg_isready -h "$host" -p "$port" -U "${SQL_USER:-devuser}" >/dev/null 2>&1; do
  elapsed=$((elapsed + sleep_interval))
  echo "Waiting for Postgres at ${host}:${port} (${elapsed}s)..."
  if [ "$elapsed" -ge "$timeout" ]; then
    echo "Timed out waiting for Postgres"
    exit 1
  fi
  sleep $sleep_interval
done

echo "Postgres ready — executing: $*"
exec "$@"
