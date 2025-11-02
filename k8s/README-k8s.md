🧩 Stage 03 — Kubernetes local con Minikube
🎯 Objetivo

Desplegar la aplicación completa (frontend, backend y base de datos PostgreSQL) sobre Kubernetes local utilizando Minikube, asegurando comunicación entre servicios, persistencia de datos y migraciones automáticas.

🧱 Estructura del entorno
k8s/
 ├── base/
 │   ├── backend-deployment.yaml
 │   ├── backend-service.yaml
 │   ├── frontend-deployment.yaml
 │   ├── frontend-service.yaml
 │   ├── postgres-deployment.yaml
 │   ├── postgres-service.yaml
 │   ├── configmap.yaml
 │   └── secret.yaml
 └── jobs/
     └── migrate-job.yaml

⚙️ Preparación del entorno

Iniciar Minikube:

minikube start --driver=docker


Construir las imágenes dentro de Minikube:

minikube image build -t backend:stage03 -f backend/Dockerfile ./backend
minikube image build -t frontend:stage03 -f frontend/Dockerfile ./frontend


Crear namespace de desarrollo:

kubectl create ns dev


Aplicar configuración y secretos:

kubectl apply -n dev -f k8s/base/configmap.yaml
kubectl apply -n dev -f k8s/base/secret.yaml

🚀 Despliegue

Aplicar los despliegues y servicios:

kubectl apply -n dev -f k8s/base/


Verificar que los pods estén en estado Running:

kubectl get pods -n dev


Ejecutar las migraciones (solo la primera vez o ante cambios de modelo):

kubectl apply -n dev -f k8s/jobs/migrate-job.yaml
kubectl logs -n dev job/migrate-job

🌐 Acceso a la aplicación

Habilitar el túnel para acceder desde el host:

minikube service frontend -n dev


Esto abrirá el navegador automáticamente en la URL de tu frontend.

Verificar conexión del backend:

kubectl logs -n dev deploy/backend


Deberías ver:

Starting development server at http://0.0.0.0:8000/
[xx/xx/xxxx] "GET /health/ HTTP/1.1" 200 16

🧹 Limpieza

Para detener todo el entorno:

minikube stop


Para borrar completamente el entorno (solo si querés reiniciar):

minikube delete --all

✅ Estado final del Stage 03

 Backend desplegado correctamente sobre Kubernetes

 PostgreSQL con persistencia y conexión verificada

 Frontend accesible desde navegador local

 Migraciones aplicadas exitosamente mediante Job

 Preparado para transición a Stage 04 – Cloud (Terraform)