## Stage 01 — De Código "Pelado" a Contenedores (Docker)

### 1. Resumen rápido

Punto de partida: el desarrollador ejecuta la app directamente en su máquina (por ejemplo `python manage.py runserver`), con entornos locales inconsistentes y configuración manual.

Evolución en esta etapa: hemos creado los Dockerfile para backend (Django) y frontend (React) y verificado que ambas aplicaciones pueden construirse y ejecutarse dentro de contenedores por separado. La orquestación con `docker-compose` se deja para la siguiente etapa.

Valor agregado principal:
- Consistencia de entornos: la app se ejecuta igual en cualquier máquina con Docker.
- Portabilidad: el contenedor empaqueta dependencias y código; puede ejecutarse en cualquier host con Docker.
- Aislamiento: las dependencias del proyecto quedan aisladas dentro del contenedor.
- Simplificación del onboarding: un desarrollador puede levantar cada servicio con 1-2 comandos.

> Nota: esta etapa está dividida en dos partes: (A) dockerización individual de cada servicio (esta documentación); (B) orquestación con `docker-compose` (stage/02). Aquí nos centramos en A.

---

### 2. Requisitos y supuestos

- Repositorio: la raíz contiene los directorios `backend/` y `frontend/`.
- Backend: hay un `Dockerfile` en `backend/dockerfile` que expone el puerto 8000 y ejecuta `python manage.py runserver 0.0.0.0:8000`.
- El backend usa `python manage.py runserver 0.0.0.0:8000` por defecto según el `Dockerfile`.
- `backend/env.example` contiene las variables necesarias para conectar con PostgreSQL, incluyendo credenciales y host (`SQL_HOST=pg-local`).
- `manage.py` requiere las variables de entorno definidas en `env.example`, especialmente `SQL_DATABASE`.
- Frontend: `frontend/Dockerfile` es multistage y produce una imagen que sirve el build estático vía nginx (expone 80). Los scripts de npm están en `frontend/package.json` (`build` y `start`).

---


### 3. Dockerización separada — usando Postgres

En este proyecto `backend/env.example` está preparado para usar PostgreSQL (variables `SQL_ENGINE=django.db.backends.postgresql`, `SQL_HOST=pg-local`, etc.). Por lo tanto, la guía de esta etapa usa Postgres corriendo en un contenedor independiente y el backend conectado a él.

Resumen técnico:
- Levantaremos un contenedor oficial de PostgreSQL con nombre `pg-local` y volúmenes para persistir datos.
- Crearemos una red Docker para que `pg-local` y `intro-backend` se resuelvan por nombre y se comuniquen entre sí.
- Usaremos `backend/env.example`como `--env-file` para el contenedor del backend. `manage.py` exige `SQL_DATABASE`, y `env.example`.

El backend ejecutará `python manage.py runserver 0.0.0.0:8000` según está definido en el `Dockerfile`.

---

### 4. Instructivo preciso — Backend (Django)

1) Sitúate en la raíz del repositorio:

```zsh
cd /ruta/a/tu/repositorio  # p. ej. ~/dev/IntroDevOps_TrabajoFinal
```


2) Construir la imagen del backend (desde la raíz del repo):

```zsh
docker build -t backend:local -f backend/dockerfile backend/
```

Explicación: usamos `-f backend/dockerfile` y el contexto `backend/` para que `COPY . .` en el Dockerfile copie el código del backend dentro de la imagen.

3) Ejecutar PostgreSQL en un contenedor (nombre `pg-local`) y crear una red Docker dedicada:

```zsh
# Creamos una red para que los contenedores se resuelvan por nombre
docker network create introdevops-network || true

# Levantamos Postgres (ajusta la versión si quieres)
docker run -d --name pg-local --network introdevops-network \
	-e POSTGRES_DB=devdb \
	-e POSTGRES_USER=devuser \
	-e POSTGRES_PASSWORD=secret \
	-v "$(pwd)/backend/pgdata:/var/lib/postgresql/data" \
	postgres:15-alpine
```

Notas:
- `env.example` del backend utiliza `SQL_HOST=pg-local`, por eso usamos ese nombre de contenedor.
- El volumen `backend/pgdata` persiste la base de datos en el host.

4) Esperar a que Postgres esté listo (opcional; útil para scripts automatizados):

```zsh
echo "Esperando a que Postgres acepte conexiones..."
until docker exec pg-local pg_isready -U devuser >/dev/null 2>&1; do
	sleep 1
done
echo "Postgres listo"
```

5) Ejecutar el backend usando `backend/env.example` como archivo de entorno:

```zsh
docker run --rm -it \
	-p 8000:8000 \
	--name backend-local \
	--network introdevops-network \
	--env-file backend/env.example \
	backend:local
```

5) Alicar migraciones

Si el contenedor está corriendo (por ejemplo --name backend-local), aplica las migraciones dentro del mismo:

dentro del host, usa el contenedor en ejecución:

```zsh
docker exec -it backend-local python manage.py migrate --noinput
```

Alternativa: ejecutar un contenedor one‑shot (si no quieres usar el que está en foreground):

```zsh
docker run --rm --network introdevops-network \
  --env-file backend/env.example \
  backend:local python manage.py migrate --noinput
```

6) Verificación backend:

- Ver logs: `docker logs -f backend-local` (o la salida en la terminal si no se ejecutó en background).
- Probar con curl:

```zsh
curl -sS http://localhost:8000/ | head -n 20
```

- Si la app está arriba deberías ver la respuesta del servidor Django (página de inicio, JSON, o redirect). Si tu proyecto expone `/api/health` u otra ruta, pruébala: `curl http://localhost:8000/api/health`.

---

### 5. Instructivo preciso — Frontend (React + nginx)

1) Construir la imagen del frontend:

```zsh
docker build -t frontend:local -f frontend/dockerfile frontend/
```

2) Ejecutar la imagen y mapear el puerto 80 del contenedor a 3000 en el host (para no colisionar con el backend):

```zsh
docker run --rm -it \
	-p 3000:80 \
	--name frontend-local \
	frontend:local
```

3) Verificación frontend:

- Abrir en el navegador: http://localhost:3000
- O usar curl:

```zsh
curl -sS http://localhost:3000/ | head -n 30
```

Nota: el Dockerfile del frontend es multi-stage y copia el build a `/usr/share/nginx/html`. Si quieres hacer development con `react-scripts start` (hot reload), usa `npm start` localmente o prepara una imagen distinta que ejecute `npm start` (no recomendado con la configuración actual de producción).

---

### 6. Comandos útiles de diagnóstico

- Listar contenedores en ejecución: `docker ps`
- Ver logs: `docker logs -f <container-name>`
- Ejecutar un shell dentro del contenedor: `docker exec -it <container-name> /bin/sh` (o `/bin/bash` si está disponible)
- Borrar imágenes antiguas: `docker image prune -a` (con cuidado)

---

### 7. Problemas comunes y soluciones verificadas

- Error: "Please create a proper .env file based on 'env.example' template"
	- Causa: `manage.py` confirmó ausencia de `SQL_DATABASE`. Solución: asegúrate de usar `--env-file backend/env.example` al ejecutar el contenedor.

- Migraciones fallan porque no hay Postgres accesible
	- Causa: `SQL_ENGINE` apunta a Postgres y `SQL_HOST` no existe. Solución: asegúrate de que el contenedor Postgres está arriba y que `intro-backend` está en la misma red Docker.

- Puerto en uso (8000/3000)
	- Solución: mapear a otro puerto en el host: `-p 8080:8000` u otro.

---

### 8. Resumen de archivos clave (artefactos de esta etapa)

- `backend/dockerfile` — Dockerfile del backend (Python/Django). Expone puerto 8000 y ejecuta runserver.
- `backend/env.example` — variables de entorno para conexión a Postgres.
- `frontend/dockerfile` — Dockerfile multi-stage que construye y sirve la app con nginx (expone 80).

---

### 9. Script de automatización (run-stage01.sh)

Para simplificar el despliegue, se proporciona un script que automatiza todos los pasos anteriores. El script se encuentra en `scripts/run-stage01.sh` y permite gestionar el ciclo completo de los contenedores.

#### Permisos de ejecución

Antes de usar el script por primera vez, asegúrate de darle permisos de ejecución:

```zsh
chmod +x scripts/run-stage01.sh
```

#### Comandos disponibles

1. Levantar todos los servicios:
```zsh
./scripts/run-stage01.sh up
```
Este comando:
- Crea la red Docker si no existe
- Construye las imágenes necesarias
- Inicia PostgreSQL y espera a que esté listo
- Levanta el backend y aplica las migraciones
- Inicia el frontend

2. Ver el estado de los contenedores:
```zsh
./scripts/run-stage01.sh status
```

3. Detener todos los servicios:
```zsh
./scripts/run-stage01.sh down
```
Este comando detiene y elimina todos los contenedores creados por el script.

#### Verificación

Después de ejecutar `up`, puedes verificar que todo funciona correctamente accediendo a:
- Backend: http://localhost:8000
- Frontend: http://localhost:3000

Los logs de los contenedores pueden consultarse con:
```zsh
docker logs -f backend-local  # para el backend
docker logs -f frontend-local # para el frontend
```
````