# Stage 01 — Docker
## Objetivo
Breve: empaquetar app en un contenedor y demostrar portabilidad.

## Punto de partida
Ej: se ejecutaba con `python app.py` en entorno local.

## Pasos realizados
1. Dockerfile creado (línea clave: `FROM python:3.11-slim` ...).
2. Build y run local: `docker build -t mi-app:stage1 .` / `docker run --rm -p 8000:8000 mi-app:stage1`
3. Pruebas básicas: curl a /health

## Comandos clave
docker build -t mi-app:stage1 .
docker run --rm -p 8000:8000 mi-app:stage1

## Artefactos generados
- `Dockerfile`
- `docker-compose.yml` (si aplica)
- `evidence/docker-run.log`
- imagen: `mi-app:stage1` (digest: ...)

## Valor agregado
Lista de puntos: consistencia, aislamiento, onboarding rápido.

## Capturas / outputs
(links a archivos en /evidence)