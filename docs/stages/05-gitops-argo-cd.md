# Stage 05 — GitOps + CI/CD con ArgoCD

## 🎯 Objetivo
Implementar un flujo GitOps completo que automatice el despliegue de la aplicación en Kubernetes usando **ArgoCD** y **GitHub Actions**, desacoplando el código de la app del estado de despliegue.

---

## 🧠 Conceptos Clave

### 1. Repositorios separados
- **IntroDevOps_TrabajoFinal** → Código fuente (frontend, backend, tests, Dockerfiles, etc.)
- **IntroDevOps_GitOps** → Infraestructura declarativa (manifiestos de Kubernetes, overlays, kustomization, etc.)

### 2. GitOps Flow
Cada cambio en el repositorio de la aplicación:
1. Dispara un workflow de **GitHub Actions**.
2. Compila y publica imágenes en **Docker Hub** con tag SHA.
3. Actualiza automáticamente los manifiestos en el repositorio **GitOps** (`kustomization.yaml`).
4. **ArgoCD** detecta los cambios y sincroniza el clúster de Kubernetes.

---

## ⚙️ CI/CD: Pipeline en GitHub Actions

El workflow principal (`.github/workflows/gitops-ci.yml`):

1. **Build & Push**  
   - Construye imágenes del **backend** y **frontend**.
   - Las sube a Docker Hub usando el tag `SHA` de GitHub.

2. **Sync GitOps Repo**  
   - Hace checkout del repo de infraestructura.
   - Usa `kustomize edit set image` para actualizar los tags.
   - Hace commit y push automático.

3. **ArgoCD**  
   - Detecta los cambios en `IntroDevOps_GitOps` y actualiza los Deployments en el clúster.

---

## 🧰 Herramientas
- **Docker Hub** → Registro de imágenes.
- **GitHub Actions** → CI/CD automatizado.
- **Kustomize** → Manejo de configuraciones entre entornos.
- **ArgoCD** → Sincronización GitOps en Kubernetes.
- **Minikube** → Clúster local de pruebas.

---

## 🔐 Secrets configurados en GitHub
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`
- `GITOPS_TOKEN`

---

## 📂 Estructura del Repositorio GitOps

IntroDevOps_GitOps/
│
├── base/
│ ├── backend-deployment.yaml
│ ├── frontend-deployment.yaml
│ ├── postgres-deployment.yaml
│ ├── namespace.yaml
│
└── overlays/
└── dev/
├── kustomization.yaml
├── patches/


---

## 🧪 Cómo probar la integración

1. Realizar un cambio en el código fuente (por ejemplo, editar un comentario en `backend/views.py`).
2. Commit & push a `main`:
   ```bash
   git add .
   git commit -m "feat: update backend endpoint example"
   git push origin main

3. Verificar la ejecución del pipeline en GitHub Actions.
4. Confirmar en IntroDevOps_GitOps que el kustomization.yaml se actualizó.
5. Observar en ArgoCD que el despliegue se sincroniza automáticamente.

## 🏁 Resultado

Al finalizar este stage, se cuenta con:
✅ Pipeline CI/CD funcional
✅ Flujo GitOps completo
✅ Integración con Docker Hub
✅ Sincronización automática mediante ArgoCD