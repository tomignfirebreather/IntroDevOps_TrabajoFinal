#!/usr/bin/env bash
set -euo pipefail

# Script para levantar stage/01: postgres + backend + frontend (builds + migraciones)
# USO: ./scripts/run-stage01.sh [up|down|status]
# Notas: No cambia nombres de imagenes/containers (usa los de la doc)

NETWORK=introdevops-network
PG_CONTAINER=pg-local
PG_IMAGE=postgres:15-alpine
PG_VOLUME="$(pwd)/backend/pgdata"
PG_DB=devdb
PG_USER=devuser
PG_PASSWORD=secret

BACKEND_IMAGE=backend:local
BACKEND_CONTAINER=backend-local
BACKEND_ENV=backend/env.example
BACKEND_PORT=8000

FRONTEND_IMAGE=introdevops-frontend:stage1
FRONTEND_CONTAINER=intro-frontend
FRONTEND_PORT_HOST=3000
FRONTEND_PORT_CONTAINER=80
FRONTEND_DOCKERFILE=frontend/dockerfile
FRONTEND_CONTEXT=frontend

MIGRATE_TIMEOUT=120   # segundos máximo esperando a pg_isready

function ensure_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker no está instalado o no está en PATH"
    exit 1
  fi
}

function create_network() {
  if ! docker network ls --format '{{.Name}}' | grep -q "^${NETWORK}$"; then
    echo "Creando red ${NETWORK}"
    docker network create "${NETWORK}"
  else
    echo "Red ${NETWORK} ya existe"
  fi
}

function stop_container_if_exists() {
  local name=$1
  if docker ps -a --format '{{.Names}}' | grep -q "^${name}$"; then
    echo "Deteniendo y removiendo contenedor existente: ${name}"
    docker rm -f "${name}" >/dev/null 2>&1 || true
  fi
}

function up_postgres() {
  mkdir -p "${PG_VOLUME}"
  stop_container_if_exists "${PG_CONTAINER}"
  echo "Arrancando Postgres (${PG_IMAGE}) en contenedor ${PG_CONTAINER}..."
  docker run -d --name "${PG_CONTAINER}" --network "${NETWORK}" \
    -e POSTGRES_DB="${PG_DB}" \
    -e POSTGRES_USER="${PG_USER}" \
    -e POSTGRES_PASSWORD="${PG_PASSWORD}" \
    -v "${PG_VOLUME}:/var/lib/postgresql/data" \
    "${PG_IMAGE}"
}

function wait_for_postgres() {
  echo "Esperando a que Postgres acepte conexiones (timeout ${MIGRATE_TIMEOUT}s)..."
  local waited=0
  until docker exec "${PG_CONTAINER}" pg_isready -U "${PG_USER}" >/dev/null 2>&1; do
    sleep 1
    waited=$((waited+1))
    if [ "${waited}" -ge "${MIGRATE_TIMEOUT}" ]; then
      echo "ERROR: Timeout esperando a Postgres (${MIGRATE_TIMEOUT}s). Revisa logs: docker logs ${PG_CONTAINER}"
      exit 2
    fi
  done
  echo "Postgres listo"
}

function build_backend() {
  echo "Preparando .dockerignore para backend..."
  DOCKERIGNORE=backend/.dockerignore
  if [ -f "${DOCKERIGNORE}" ]; then
    if ! grep -qxF 'pgdata' "${DOCKERIGNORE}"; then
      echo 'pgdata' >> "${DOCKERIGNORE}"
      echo "Agregado 'pgdata' a ${DOCKERIGNORE}"
    fi
  else
    echo 'pgdata' > "${DOCKERIGNORE}"
    echo "Creado ${DOCKERIGNORE} con 'pgdata'"
  fi

  echo "Construyendo imagen backend: ${BACKEND_IMAGE}"
  docker build -t "${BACKEND_IMAGE}" -f backend/dockerfile backend/
}

function build_frontend() {
  echo "Construyendo imagen frontend: ${FRONTEND_IMAGE}"
  docker build -t "${FRONTEND_IMAGE}" -f "${FRONTEND_DOCKERFILE}" "${FRONTEND_CONTEXT}"
}

function migrate() {
  echo "Aplicando migrations (one-shot) usando imagen ${BACKEND_IMAGE}..."
  docker run --rm --network "${NETWORK}" --env-file "${BACKEND_ENV}" "${BACKEND_IMAGE}" \
    python manage.py migrate --noinput
  echo "Migraciones aplicadas."
}

function up_backend() {
  stop_container_if_exists "${BACKEND_CONTAINER}"
  echo "Arrancando backend (${BACKEND_IMAGE}) en contenedor ${BACKEND_CONTAINER}..."
  docker run -d --name "${BACKEND_CONTAINER}" --network "${NETWORK}" \
    -p "${BACKEND_PORT}:8000" \
    --env-file "${BACKEND_ENV}" \
    "${BACKEND_IMAGE}"
}

function up_frontend() {
  stop_container_if_exists "${FRONTEND_CONTAINER}"
  echo "Arrancando frontend (${FRONTEND_IMAGE}) en contenedor ${FRONTEND_CONTAINER}..."
  docker run -d --name "${FRONTEND_CONTAINER}" --network "${NETWORK}" \
    -p "${FRONTEND_PORT_HOST}:${FRONTEND_PORT_CONTAINER}" \
    "${FRONTEND_IMAGE}"
}

function status() {
  echo "Containers running (filter):"
  docker ps --filter "name=${PG_CONTAINER}" --filter "name=${BACKEND_CONTAINER}" --filter "name=${FRONTEND_CONTAINER}" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
}

function down() {
  echo "Deteniendo y removiendo contenedores..."
  docker rm -f "${FRONTEND_CONTAINER}" "${BACKEND_CONTAINER}" "${PG_CONTAINER}" >/dev/null 2>&1 || true
  echo "Opcional: eliminar network ${NETWORK}? (y/n)"
  read -r resp
  if [ "${resp}" = "y" ]; then
    docker network rm "${NETWORK}" || true
  fi
}

function usage() {
  cat <<EOF
Usage: $0 up|down|status
  up     - build & start postgres, backend, frontend and run migrations
  down   - stop and remove containers (asks about removing network)
  status - show brief status of relevant containers
EOF
  exit 1
}

# MAIN
if [ $# -lt 1 ]; then
  usage
fi

COMMAND=$1

ensure_docker

case "${COMMAND}" in
  up)
    create_network
    up_postgres
    wait_for_postgres
    build_backend
    migrate
    up_backend
    build_frontend
    up_frontend
    echo "Aplicación levantada: backend -> http://localhost:${BACKEND_PORT} , frontend -> http://localhost:${FRONTEND_PORT_HOST}"
    ;;
  down)
    down
    ;;
  status)
    status
    ;;
  *)
    usage
    ;;
esac
