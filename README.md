
# El Trabajo Final 

## Introducción

El desafío final es una invitación a poner en práctica y desafiar los conocimientos sobre las herramientas tecnológicas y conceptos teóricos aprendidos. Este proyecto simula un escenario real donde un cliente necesita no solo migrar su aplicación, sino también construir una plataforma resiliente, segura y automatizada en la nube.

Utilizaremos: `Docker`, `Kubernetes`, `Terraform`, `Helm`, `GitLab CI`, `Argo CD`, `Prometheus`, `Grafana`, `Loki` y herramientas de seguridad.

---

## Objetivos

* Aplicar las herramientas y conceptos del curso en un proyecto integral.
* Diseñar e implementar una solución completa, desde la infraestructura hasta el deployment.
* Simular el lifecycle completo de una aplicación bajo la cultura DevSecOps.
* Automatizar la entrega de software utilizando un enfoque moderno de GitOps.
* Implementar una plataforma de observabilidad que permita monitorear y entender el estado de la aplicación.

---

## Requerimiento Central

Un cliente nos pidió migrar su aplicación (frontend y backend) a un clúster de Kubernetes en una nube pública (AWS). El cliente exige:

* Una gestión de la infraestructura automatizada y versionada (IaC).
* Un proceso de deployment totalmente automatizado y transparente basado en Git.
* La incorporación de prácticas de seguridad en el pipeline de entrega.
* Una plataforma de observabilidad completa para los entornos.

### 1. Infraestructura como Código (Infrastructure as Code - IaC) con Terraform

El primer paso será provisionar la infraestructura necesaria en la nube.

* **Tarea** : Usando `Terraform`, crear/utilizar un código para desplegar un clúster de Kubernetes gestionado (EKS en AWS).
* **Entregable** : Un repositorio aparte con el código de `Terraform`, siguiendo las best practices (variables, modules si es necesario, y un backend remoto para el state).

### 2. Arquitectura del Clúster y GitOps con Argo CD

Dentro del clúster se gestionarán dos entornos (namespaces): `dev` y `prd`. La gestión de las aplicaciones en estos entornos se hará mediante GitOps.

* **Tarea** :

1. Instalar `Argo CD` en el clúster (namespace `argocd`).
2. Crear un nuevo repositorio de Git (ej. `app-config`) que contendrá los manifiestos de Kubernetes (o charts de `Helm`) para cada entorno.
3. Configurar `Argo CD` para que sincronice automáticamente el contenido de este repositorio con los namespaces correspondientes.

* **Helm** : Los servicios se administrarán con charts de `Helm`. El chart del backend debe incluir un `Job` para ejecutar las migraciones de la base de datos PostgreSQL.

### 3. Pipeline de CI/CD con GitLab y Argo CD

El objetivo es implementar un pipeline de Integración Continua para la aplicación. La estrategia de versionado será GitLab Flow.

**Flujo de Trabajo:**

* **CI con GitLab** :
* **Pipeline de CI (en cada Merge Request)** : Al abrir un Merge Request, se ejecutará un pipeline que:
  *  **Test Stage** : Ejecutará pruebas unitarias con `pytest`.
  *  **Build Stage** : Construirá una imagen de `Docker` de la aplicación.
* El pipeline no hará el despliegue, sino que preparará el artefacto (la imagen) para la siguiente fase.
* **Despliegue con Argo CD (GitOps)** :
* **Gatillo de despliegue** : Una vez que el pipeline de CI finalice con éxito, se hará un commit en el repositorio de configuración (ej. `argocd-repo`).
* **Despliegue** : Una vez hecho el commit, `Argo CD` detectará el cambio en el repositorio de configuración y desplegará automáticamente la nueva versión de la aplicación.

### 4. Observabilidad y Monitoreo

Se debe desplegar una plataforma de observabilidad completa.

* **Métricas** : Usar `kube-prometheus-stack` para Prometheus y Grafana.
* **Logs** : Usar `Loki` y `Grafana Alloy` para centralizar y visualizar los logs en Grafana.

### 5. Diseño de Arquitectura

* **Tarea** : Realizar un diagrama de la arquitectura final.

---

## Entregables Finales

* **Code Repositories** : Frontend y Backend (con `Dockerfile` y `.gitlab-ci.yml`).
* **IaC Repository** : Código de `Terraform`.
* **ArgoCD-Config Repository (GitOps)** : Charts de `Helm` y configuración de `Argo CD`.
* **Documentación** : `README.md` con el diagrama de arquitectura e instrucciones de deployment.

---

# a Evolución del Proyecto y el Valor Agregado

Comprender por qué usamos cada herramienta es tan importante como saber cómo usarla. Este proyecto, en conjunto con el avance del curso, simulará un viaje de madurez tecnológica.

### 1. De Código 'Pelado' a Contenedores con Docker

* **Punto de Partida** : El desarrollador ejecuta el código directamente en su máquina (ej. `python app.py`). El entorno es inconsistente, la configuración es manual y es muy común el problema de "en mi máquina funciona".
* **Evolución** : Creamos un `Dockerfile` para empaquetar la aplicación con todas sus dependencias y usamos `docker-compose` para orquestar los servicios localmente.
* **Valor Agregado** :
* **Consistencia de Entornos** : La aplicación se ejecuta de la misma manera en cualquier máquina que tenga `Docker`.
* **Portabilidad** : El contenedor es un elemento portable que puede ejecutarse en cualquier lugar.
* **Aislamiento** : Las dependencias de un proyecto no entran en conflicto con las de otro.
* **Simplificación del Onboarding** : Un nuevo desarrollador sólo necesita ejecutar `docker-compose up` para tener todo el sistema funcionando.

### 2. De `docker-compose` a Kubernetes Local

* **Punto de Partida** : `docker-compose` es ideal para desarrollo local en un solo host, pero no ofrece capacidades de orquestación avanzadas.
* **Evolución** : Migramos a Kubernetes (corriendo localmente en `Minikube`/`k3d`).
* **Valor Agregado** : Ganamos orquestación real, capacidad de Self-Healing, escalabilidad y empezamos a trabajar con un modelo declarativo.

### 3. De Kubernetes Local a la Nube

* **Punto de Partida** : `Minikube` es un entorno de aprendizaje, no de producción.
* **Evolución** : Provisionamos un clúster gestionado (`EKS`) con `Terraform`.
* **Valor Agregado** : Obtenemos alta disponibilidad, escalabilidad real (de nodos y pods) y un entorno production-ready. Además, gestionamos nuestra infraestructura como código versionable y reproducible (IaC).

### 4. De Despliegues Manuales a GitOps

* **Punto de Partida** : Desplegar con comandos manuales (`kubectl`, `helm`) es propenso a errores y difícil de auditar.
* **Evolución** : Implementamos GitOps con `Argo CD`.
* **Valor Agregado** : Git se convierte en la única fuente de verdad (Single Source of Truth). Ganamos trazabilidad total, seguridad mejorada y la capacidad de revertir cambios de forma segura con un `git revert`.

### 5. De Monitoreo Básico a Observabilidad Completa

* **Punto de Partida** : Revisar logs manualmente (`kubectl logs`) es reactivo e ineficiente.
* **Evolución** : Construimos una plataforma con los tres pilares: Métricas (`Prometheus`) y Logs (`Loki`).
* **Valor Agregado** : Pasamos de "saber que algo está roto" a "entender por qué está roto". La centralización de métricas y logs nos permite ser proactivos y correlacionar eventos para resolver incidentes complejos.
