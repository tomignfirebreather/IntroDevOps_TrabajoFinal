## Stage 02 — Orquestación con Docker Compose

### 1. Resumen rápido

Punto de partida: servicios dockerizados individualmente (etapa anterior) que requieren múltiples comandos para su gestión.

Evolución en esta etapa: implementación de Docker Compose para orquestar todos los servicios (PostgreSQL, Backend, Frontend) de manera unificada y simplificada.

Valor agregado principal:
- Orquestación centralizada: todos los servicios se gestionan desde un único archivo.
- Configuración declarativa: la infraestructura se define como código en `docker-compose.yml`.
- Gestión de red automática: Docker Compose maneja la red interna automáticamente.
- Simplicidad operativa: un solo comando `docker compose up` levanta todo el sistema.

> Nota: esta etapa es la continuación de stage/01-docker donde dockerizamos los servicios individualmente. Ahora los orquestaremos de manera unificada con Docker Compose.

---

### 2. Requisitos y supuestos

- Etapa anterior (stage/01-docker) completada exitosamente.
- Imágenes Docker construidas y funcionales:
  - Backend: `backend:local`
  - Frontend: `frontend:local`
- Archivos de configuración existentes:
  - `backend/env.example` para variables de entorno del backend
  - `backend/dockerfile` y `frontend/dockerfile` validados
- Docker Compose instalado en el sistema

---

### 3. Estructura del docker-compose.yml

El archivo `docker-compose.yml` define tres servicios principales:

1. **postgres**: Base de datos PostgreSQL
   - Imagen: `postgres:15-alpine`
   - Persistencia de datos en `./backend/pgdata`
   - Variables de entorno para configuración inicial

2. **backend**: Aplicación Django
   - Imagen: construida desde `./backend/dockerfile`
   - Depende de postgres
   - Variables de entorno desde `./backend/env.example`
   - Puerto: 8000

3. **frontend**: Aplicación React
   - Imagen: construida desde `./frontend/dockerfile`
   - Puerto: 3000:80
   - Servido con nginx en producción

---

### 4. Instructivo preciso — Levantamiento del sistema

1) Sitúate en la raíz del repositorio:

```zsh
cd /ruta/a/tu/repositorio  # p. ej. ~/dev/IntroDevOps_TrabajoFinal
```

2) Construir las imágenes:

```zsh
docker compose build
```

3) Levantar todos los servicios:

```zsh
docker compose up -d
```

El flag `-d` ejecuta los contenedores en segundo plano. Omítelo si quieres ver los logs en tiempo real.

4) Aplicar migraciones (después de que los servicios estén arriba):

```zsh
docker compose exec backend python manage.py migrate --noinput
```

5) Verificar que todos los servicios están corriendo:

```zsh
docker compose ps
```

---

### 5. Verificación del sistema

1) Backend:
- API: http://localhost:8000/
```zsh
curl -sS http://localhost:8000/ | head -n 20
```

2) Frontend:
- Interfaz web: http://localhost:3000   

3) Logs de los servicios:
```zsh
# Ver logs de un servicio específico
docker compose logs -f backend
docker compose logs -f frontend

# Ver logs de todos los servicios
docker compose logs -f
```

---

### 6. Gestión de servicios

**Comandos básicos:**

1) Detener los servicios (preservando contenedores):
```zsh
docker compose stop
```

2) Iniciar servicios detenidos:
```zsh
docker compose start
```

3) Detener y eliminar contenedores:
```zsh
docker compose down
```

4) Detener y eliminar contenedores, volúmenes y redes:
```zsh
docker compose down -v
```

5) Ver estado de los servicios:
```zsh
docker compose ps
```

---

### 7. Problemas comunes y soluciones

1) **Error de conexión a postgres**
   - Causa: Postgres aún no está listo cuando el backend intenta conectar
   - Solución: Docker Compose reintentará automáticamente. Si persiste, reinicia los servicios:
   ```zsh
   docker-compose restart backend
   ```

2) **Puertos en uso**
   - Causa: Puertos 8000 o 3000 ya están siendo utilizados
   - Solución: Modifica los puertos en `docker-compose.yml` o libera los puertos en uso

3) **Problemas de permisos en pgdata**
   - Causa: Directorio pgdata con permisos incorrectos
   - Solución: 
   ```zsh
   sudo chown -R 5432:5432 backend/pgdata
   ```

---

### 8. Resumen de archivos clave

- `docker-compose.yml` — Archivo principal de orquestación
- `backend/env.example` — Variables de entorno para el backend
- `backend/dockerfile` — Dockerfile del backend
- `frontend/dockerfile` — Dockerfile del frontend

---

### 9. Diferencias clave con la etapa anterior

1) **Gestión de red**
   - Antes: Red Docker creada manualmente
   - Ahora: Docker Compose crea y gestiona la red automáticamente

2) **Levantamiento de servicios**
   - Antes: Múltiples comandos `docker run` con parámetros extensos
   - Ahora: Un solo comando `docker compose up`

3) **Configuración**
   - Antes: Parámetros en línea de comandos
   - Ahora: Configuración declarativa en `docker-compose.yml`

4) **Gestión de dependencias**
   - Antes: Manual, esperando que los servicios estén listos
   - Ahora: Automática con `depends_on`
