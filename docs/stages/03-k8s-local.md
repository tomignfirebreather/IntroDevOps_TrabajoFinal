# Stage 03 — De Docker‑Compose a Kubernetes local

## 1. Resumen rápido

**Punto de partida:** en stage/02 tenemos la aplicación orquestada con `docker-compose` (Postgres, Backend, Frontend) funcionando en un único host.

**Evolución en esta etapa:** migramos la misma aplicación a Kubernetes corriendo localmente (Minikube). Definimos manifiestos declarativos (`Deployment`, `Service`, `PersistentVolumeClaim`, `ConfigMap`, `Secret`, `Job` para migraciones) y adoptamos prácticas básicas de Kubernetes (namespaces, readiness/liveness probes, volúmenes persistentes, acceso vía `Service`/Ingress).

**Valor agregado principal:** orquestación real, self‑healing, escalabilidad declarativa, acercamiento al modelo de despliegue que usaremos en la nube (stage/04).

---

## 2. Requisitos y supuestos

* Stage anteriores completados (stage/01 y stage/02).
* Repositorio con carpetas `backend/`, `frontend/`, y `k8s/` (estructura ejemplo más abajo).
* Docker instalado; para Minikube se usa el driver `docker`.
* minikube instalado.
* `kubectl` instalado y configurado (contexto apuntando al cluster local creado).
* `backend/env.example` presente (usado como referencia para variables de entorno).
* Los Dockerfiles pueden estar en `backend/dockerfile` o `backend/Dockerfile` (ver nota en pasos de build).

---

## 3. Estructura recomendada en el repo

```
k8s/
 ├── base/
 │   ├── backend-deployment.yaml
 │   ├── backend-service.yaml
 │   ├── frontend-deployment.yaml
 │   ├── frontend-service.yaml
 │   ├── postgres-deployment.yaml
 │   ├── postgres-pvc.yaml
 │   ├── ingress.yaml
 │   ├── namespace.yaml
 │   ├── configmap.yaml
 │   └── secret.yaml
 └── jobs/
     └── migrate-job.yaml

backend/
frontend/
README.md

```

> Nota: los archivos YAML incluidos en `k8s/` deben ser idempotentes y diseñados para `kubectl apply -f`.

---

## 4. Manifiestos clave (qué hace cada archivo)

* `backend-deployment.yaml` — `Deployment` del backend (replicas 1, image `backend:stage03`),Define envFrom: `ConfigMap` y `Secret`, `readinessProbe` y `livenessProbe`, volumenes si necesarios.
* `backend-service.yaml` — `Service` tipo `ClusterIP` exponiendo el puerto 8000 al cluster.
* `frontend-deployment.yaml` — `Deployment` del frontend (image `frontend:stage03`) y `Service` asociado (ClusterIP/NodePort según acceso).
* `frontend-service.yaml` — `Service` que puede ser `NodePort` o `ClusterIP` (acceso por `minikube service` o Ingress).
* `postgres-deployment.yaml` — Deployment/StatefulSet que monta `PersistentVolumeClaim` para la data de Postgres (o `StatefulSet` si se prefiere).
* `postgres-pvc.yaml` — `PersistentVolumeClaim` solicitando almacenamiento (ej: 1Gi) con storageClass local (Minikube ya instala `standard`/`local-path`).
* `ingress.yaml` — Ingress que define reglas de enrutamiento para el namespace dev usando el controlador NGINX. Configura dos hosts: frontend.local (ruta / al servicio frontend:80) y api.local (ruta /api al servicio backend:8000).
* `configmap.yaml` — Variables no secretas (por ejemplo: `DJANGO_SETTINGS_MODULE`, flags de debug, hostnames internos).
* `secret.yaml` — Secret para credenciales sensibles (POSTGRES_PASSWORD, SECRET_KEY de Django). Importante: usar `kubectl create secret` localmente para no almacenar secretos en texto plano en git si preferís.
* `jobs/migrate-job.yaml` — Job que ejecuta `python manage.py migrate` usando la imagen del backend o un `initContainer`/Job según preferencia.

---

## 5. Preparación del entorno — Minikube (recomendado para desarrollo)

### 5.1 Iniciar Minikube

```bash
minikube start --driver=docker --memory=4g --cpus=2
```

Ajustá `--memory` y `--cpus` según recursos locales.

### 5.2 Habilitar el addon de Ingress

```bash
minikube addons enable ingress
```

### 5.3 Registar IP Minikube

```bash
minikube ip # obtiene IP del cluster
sudo nano /etc/hosts # editar /etc/hosts 
# <MINIKUBE_IP> api.local frontend.local
```

### 5.4 Construir imágenes DENTRO del cluster (evita push a registries)

Minikube ofrece `minikube image build` (recomendado si tenés versión reciente):

```bash
# Ajustá la ruta al Dockerfile si fuera `backend/dockerfile` o `backend/Dockerfile`
minikube image build -t backend:stage03 -f backend/dockerfile ./backend
minikube image build -t frontend:stage03 -f frontend/dockerfile ./frontend
```

Si tu Dockerfile está en `backend/Dockerfile` usa `-f backend/Dockerfile`.

> Alternativa (antigua): `eval $(minikube docker-env)` y `docker build -t backend:stage03 -f backend/Dockerfile ./backend` para construir la imagen en el daemon de minikube.

### 5.5 Crear namespace

```bash 
kubectl create ns dev || true
kubectl config set-context --current --namespace=dev
```

### 5.6 Aplicar ConfigMap y Secret

1. Revisá `backend/env.example` y volcá variables no sensibles a `k8s/base/configmap.yaml`.
2. Revisá `backend/env.example` y volcá secretos (variables sensibles) en `k8s/base/secret.yaml` (pero **no** subir secretos reales a git).

```bash
kubectl apply -n dev -f k8s/base/configmap.yaml
kubectl apply -n dev -f k8s/base/secret.yaml
```
---

## 6. Despliegue (aplicar manifests)

```bash
# Desde la raíz del repo
kubectl apply -n dev -f k8s/base/
```

Verificá estado:

```bash
kubectl get all -n dev
kubectl get pvc -n dev
kubectl get jobs -n dev
```

### 6.1 Ejecutar migraciones

Opciones:

**A) Job dedicated (recomendado para replicable):**

```bash
kubectl apply -n dev -f k8s/jobs/migrate-job.yaml
kubectl wait --for=condition=complete job/migrate-job -n dev --timeout=120s
kubectl logs -n dev job/migrate-job
```

**B) Ejecutar comando dentro del Deployment (one‑off):**

```bash
# Crear pod temporal usando la imagen del backend
kubectl run --rm -n dev migrate --image=backend:stage03 --restart=Never -- bash -c "python manage.py migrate --noinput"
```

> Si las migraciones necesitan acceso a archivos estáticos o variables, asegurate de montar los mismos ConfigMaps/Secrets que el Deployment.

---

## 7. Acceso a la aplicación desde el host

Abrir en navegador:

Frontend: http://frontend.local

Backend: las peticiones del frontend deben ir a http://api.local/api/...


---

## 8. Scripts de ayuda (propuestos)

`./scripts/run-stage03-minikube.sh` (ejemplo básico):

```bash
#!/usr/bin/env bash
set -euo pipefail

# Start minikube if not started
minikube status >/dev/null 2>&1 || minikube start --driver=docker --memory=4g --cpus=2

# Build images inside minikube
minikube image build -t backend:stage03 -f backend/Dockerfile ./backend
minikube image build -t frontend:stage03 -f frontend/Dockerfile ./frontend

kubectl create ns dev || true
kubectl apply -n dev -f k8s/base/
kubectl apply -n dev -f k8s/jobs/migrate-job.yaml

kubectl wait --for=condition=ready pod -l app=backend -n dev --timeout=120s || true
minikube service frontend -n dev
```

Hacé `chmod +x scripts/run-stage03-minikube.sh` antes de usar.

---

## 9. Verificación y diagnósticos

Comandos útiles:

```bash
# Estado general
kubectl get all -n dev
kubectl get pods -n dev -o wide
kubectl get pvc -n dev

# Logs
kubectl logs -n dev deploy/backend -f
kubectl logs -n dev deploy/frontend -f
kubectl logs -n dev deploy/postgres -f

# Descripción para investigar eventos y condiciones
kubectl describe pod <pod-name> -n dev
kubectl describe pvc <pvc-name> -n dev

# Ejecutar shell en pod
kubectl exec -it -n dev deploy/backend -- bash
```

### Problemas comunes y soluciones

* **Pod CrashLoopBackOff (backend)**

  * Revisá `kubectl logs` y `kubectl describe pod`. Muy frecuentemente faltan variables de entorno, secret o la DB no está accesible.
  * Asegurate de que `postgres` tenga su PVC ligado y que el Deployment usa el mismo `Service`/host (ej: `POSTGRES_HOST=postgres`).

* **PVC no se liga (Pending)**

  * Minikube normalmente provee un `storageClass` por defecto (`standard` o `local-path`). Ejecutá `kubectl get storageclass` y adaptá `postgres-pvc.yaml` al `storageClassName` correcto.

* **Postgres no acepta conexiones**

  * Esperá a que el pod de Postgres esté `Running` y revisá logs; si hay errores de permisos en el hostPath, ajustá owner/permissions.

---

## 10. Limpieza

```bash
# Minikube
minikube stop
# si querés borrar todo
minikube delete --all
```

En el cluster:

```bash
kubectl delete -n dev -f k8s/base/
kubectl delete -n dev -f k8s/jobs/migrate-job.yaml
kubectl delete ns dev
```

---

## 11. Archivos clave para seguimiento

* `k8s/base/*` — manifests fuente para Deployments/Services/ConfigMap/Secret/PVC
* `k8s/jobs/migrate-job.yaml` — Job para migraciones (idempotente)
* `backend/Dockerfile` o `backend/dockerfile` — Dockerfile del backend
* `frontend/Dockerfile` o `frontend/dockerfile` — Dockerfile del frontend
* `scripts/run-stage03-minikube.sh` — script de ayuda propuesto

---

