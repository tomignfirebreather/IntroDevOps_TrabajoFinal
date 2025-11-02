# Stage 03 — cierre: manifests, deploy script y README

Este documento contiene todo lo necesario para **cerrar `stage/03-k8s-local`**: checklist, archivos a añadir al repo, el script `deploy_minikube.sh` listo para usar y los pasos Git exactos para commitear y taggear. Pega los archivos indicados en las rutas sugeridas y sigue los comandos de la sección *Git: commit & tag*.

---

## 1) Checklist final (para confirmar antes de cerrar)

* [ ] `k8s/base/` contiene:

  * `namespace.yaml`
  * `postgres-pvc.yaml`
  * `postgres-deployment.yaml`
  * `backend-deployment.yaml`
  * `backend-service.yaml` (si está separado)
  * `frontend-deployment.yaml`
  * `frontend-service.yaml` (si está separado)
  * `configmap.yaml` (valores no sensibles)
  * `secret.example.yaml` (ejemplo - NO con secretos reales)
  * `jobs/migrate-job.yaml` (opcional)
* [ ] `k8s/overlays/minikube/kustomization.yaml` (si usás kustomize)
* [ ] `deploy_minikube.sh` en `k8s/` (script de despliegue automatizado local)
* [ ] `README-k8s.md` documentando pasos para levantar localmente con Minikube
* [ ] `.gitignore` incluye archivos sensibles: `dev.env`, `docker-compose.override.yml` (si decidiste no commitearlo) y otros secretos
* [ ] Probar el script `deploy_minikube.sh` en una sesión limpia de Minikube (minikube delete && minikube start) — todo debe funcionar o dejar errores claros a corregir

---

## 2) Archivos a crear/normalizar (contenido listo en secciones siguientes)

* `k8s/base/namespace.yaml`
* `k8s/base/postgres-pvc.yaml`
* `k8s/base/postgres-deployment.yaml`
* `k8s/base/backend-deployment.yaml`
* `k8s/base/backend-service.yaml` (si no está embebido)
* `k8s/base/frontend-deployment.yaml`
* `k8s/base/frontend-service.yaml`
* `k8s/base/configmap.yaml`
* `k8s/base/secret.example.yaml` (ejemplo sin valores reales)
* `k8s/jobs/migrate-job.yaml` (opcional)
* `k8s/deploy_minikube.sh` (script)
* `README-k8s.md` (instrucciones)

> Nota: si ya tenés los YAMLs, compara con lo que hay en `k8s/base/` e incorpora `imagePullPolicy: Never` en los deployments locales y probes ajustadas.

---

## 3) Script: `k8s/deploy_minikube.sh`

> Guarda este archivo en `k8s/deploy_minikube.sh` y dale permisos `chmod +x k8s/deploy_minikube.sh`.

```bash
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=dev
BACKEND_IMAGE=backend:stage03
FRONTEND_IMAGE=frontend:stage03

echo "==> 1. Start minikube (if not running)"
minikube status >/dev/null 2>&1 || minikube start

echo "==> 2. Build images inside minikube"
minikube image build -t ${BACKEND_IMAGE} -f ../backend/Dockerfile ../backend
minikube image build -t ${FRONTEND_IMAGE} -f ../frontend/Dockerfile ../frontend

echo "==> 3. Create namespace (idempotent)"
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

echo "==> 4. Create configmap (idempotent)"
kubectl create configmap dev-config --namespace ${NAMESPACE} \
  --from-literal=SQL_ENGINE=django.db.backends.postgresql \
  --from-literal=SQL_DATABASE=devdb \
  --from-literal=SQL_HOST=postgres \
  --from-literal=SQL_PORT=5432 \
  --from-literal=DEBUG=0 \
  --from-literal=DJANGO_ALLOWED_HOSTS='*' \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> 5. Create secret (interactive)"
read -p "Enter SQL_USER (default devuser): " SQL_USER
SQL_USER=${SQL_USER:-devuser}
read -s -p "Enter SQL_PASSWORD: " SQL_PASSWORD
echo
read -s -p "Enter SECRET_KEY (or leave blank to generate): " SECRET_KEY
echo
if [ -z "$SECRET_KEY" ]; then
  SECRET_KEY=$(python -c "import secrets; print(secrets.token_urlsafe(48))")
  echo "Generated SECRET_KEY"
fi

kubectl create secret generic dev-secrets --namespace ${NAMESPACE} \
  --from-literal=SQL_USER=${SQL_USER} \
  --from-literal=SQL_PASSWORD=${SQL_PASSWORD} \
  --from-literal=SECRET_KEY=${SECRET_KEY} \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> 6. Apply k8s manifests"
# apply order: pvc -> postgres -> wait -> backend -> migrations -> frontend
kubectl apply -f base/postgres-pvc.yaml -n ${NAMESPACE}
kubectl apply -f base/postgres-deployment.yaml -n ${NAMESPACE}

echo "Waiting for postgres rollout..."
kubectl rollout status deployment/postgres -n ${NAMESPACE} --timeout=120s

kubectl apply -f base/configmap.yaml -n ${NAMESPACE} || true
kubectl apply -f base/backend-deployment.yaml -n ${NAMESPACE}

echo "==> 7. Run migrations (temporary pod)"
kubectl run migrate-temp -n ${NAMESPACE} --rm -it --image=${BACKEND_IMAGE} --image-pull-policy=Never --restart=Never -- \
  /bin/sh -c "python manage.py migrate --noinput && python manage.py showmigrations"

echo "==> 8. Apply frontend"
kubectl apply -f base/frontend-deployment.yaml -n ${NAMESPACE}

echo "==> 9. Done. Port-forward instructions:"
echo "  kubectl port-forward service/backend 8000:8000 -n ${NAMESPACE}"
echo "  kubectl port-forward service/frontend 8080:80 -n ${NAMESPACE}"

echo "All done. If something failed, check 'kubectl get pods -n ${NAMESPACE}' and logs."
```

---

## 4) README para `k8s/` (`k8s/README-k8s.md`)

Incluye pasos rápidos: build images, deploy script, cómo crear secrets manualmente, cómo probar (port-forward) y cómo resetear la DB (delete PVC). El archivo `README-k8s.md` está listo para pegar en la carpeta `k8s/`.

---

## 5) Git: commit & tag (comandos exactos)

```bash
# desde la rama stage/03-k8s-local
git add k8s/
git commit -m "feat(k8s): add manifests, deploy_minikube.sh and README for stage/03"
git push origin stage/03-k8s-local

git tag stage-03-done
git push origin stage-03-done
```

---

## 6) Notas finales y buenas prácticas

* No commitees secretos reales: mantén `k8s/secret.example.yaml` con placeholders y documenta `kubectl create secret`.
* Testea el script en una VM limpia: `minikube delete && minikube start`.
* Si en el futuro migrás a CI, extrae la parte de `minikube image build` a la pipeline y el resto como `kubectl apply` o usa GitOps.

---

Si querés, ahora puedo:

* 1. crear los archivos `k8s/deploy_minikube.sh` y `k8s/README-k8s.md` directamente en el canvas (listos para copiar),
* 2. generar los YAMLs base exactos usando los valores que ya confirmaste, o
* 3. devolverte solo los comandos git listos para ejecutar.

Decime 1, 2 o 3.
