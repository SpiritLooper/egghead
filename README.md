# 🪺 EggHead - HomeServer

Welcome to my personal **HomeServer**! This is a self-hosted infrastructure powered by **Kubernetes**, **GitOps**, and open source magic. ✨

---

## 🧰 Stack Overview

| Component | Category | Main Role |
| :--- | :--- | :--- |
| 🐳 **K3s** | K8s Orchestration | Lightweight Kubernetes distribution, the foundation of the infra. |
| 🔁 **FluxCD** | GitOps / CI/CD | Synchronization of configurations from Git. |
| 🦦 **Traefik** | Ingress Controller | External traffic routing and reverse proxy management. |
| 📜 **cert-manager** | Security / TLS | Automatic SSL certificate management and renewal (via DNS challenge). |
| 💾 **k8up** | Backup | Persistent Volume Claims (PVC) backup operator via restic. |
| 🐘 **CloudNativePG (CNPG)** | Databases | Operator for deploying and managing PostgreSQL clusters. |
| 🧠 **Prometheus Stack** | Monitoring | Metrics collection and aggregation (kube-prometheus-stack + Pushgateway). |
| 🐻 **Uptime Kuma** | Monitoring / Status | Service availability monitoring dashboard. |
| 👤 **Pocket ID** | Authentication | Minimalist SSO provider with Passkey authentication. |

---

## ⚙️ GitOps Workflow

All configuration is declarative and stored in a Git repository. Changes are pushed and **FluxCD** syncs them automatically into the cluster. 🚀

---

## 🌐 Access & Networking

* 🔐 All services are routed through **Traefik** with automatic HTTPS.
* 🧩 Subdomain-based access under `.egghead.infrao.top` for each service.
* 🗣️ **Discord** is used for receiving notification alerts.

---

## 📦 Hosted Applications

A few of the self-hosted apps currently running:

### 🗂️ Document & Data Management

* 🍃 **[Paperless-ngx](https://docs.paperless-ngx.com/)** : Open-source Document Management System (DMS) to archive and manage your scanned documents.
* 📸 **[Immich](https://immich.app/)** : Self-hosted photo and video management solution.
* 🔑 **[Vaultwarden](https://github.com/dani-garcia/vaultwarden)** : Lightweight Bitwarden server alternative for password management.
* 🕹️ **[Romm (ROM Manager)](https://romm.app/)** : Video game ROM collection manager.

### 🎬 Media Stack (*arr)

* 🍿 **[Jellyfin](https://jellyfin.org/)** : The Free Software Media System.
* ⬇️ **[Deluge](https://deluge-torrent.org/)** : A lightweight, Free Software, cross-platform BitTorrent client.
* 🧭 **[Prowlarr](https://prowlarr.com/)** : Indexer manager/proxy for PVR integration.
* 📺 **[Sonarr](https://sonarr.tv/)** : Smart PVR for managing TV series.
* 🎥 **[Radarr](https://radarr.video/)** : Movie collection manager.
* 🐙 **[Jellyseerr](https://docs.seerr.dev/)** : Media request management tool for Jellyfin.

### 🖥️ Dashboards & Authentication

* 🥯 **[Homer](https://github.com/bastienwirtz/homer)** : Centralized static dashboard for all applications.
* 👤 **[Pocket ID](https://pocket-id.org/)** : Minimalist OIDC provider for passwordless SSO via **Passkey**.

---

## ⚙️ Infra & Cluster Management

### 📊 Supervision and Monitoring

* 💻 **[beszel](https://beszel.dev/)** : Lightweight monitoring tool for machine resources.
* 🪁 **[Kite](https://github.com/zxh326/kite/)** : Graphical visualization tool for Kube resources and their relationships.
* 📈 **[kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)** : Prometheus/Grafana bundle for K8s monitoring.
* ➡️ **[Prometheus Pushgateway](https://github.com/prometheus/pushgateway)** : Allows ephemeral jobs to push their metrics.
* 🐻 **[Uptime Kuma](https://uptimekuma.org/)** : Infrastructure availability monitoring dashboard.

### 🗃️ Cluster Services

* 💾 **[k8up](https://k8up.io/)** : Kubernetes backup operator for PVCs.
* 📜 **[cert-manager](https://cert-manager.io/)** : Certificate management via DNS challenge.
* 🦦 **[Traefik](https://traefik.io/traefik)** : Ingress Controller.
* 🐘 **[CloudNativePG (CNPG)](https://cloudnative-pg.io/)** : Operator for PostgreSQL databases.

---

## 🚀 Deploying the stack !

1. Get a GitHub token and set an env var:

    ```fish
    export GITHUB_TOKEN=xxx
    ```

2. Enter some commands
    ```fish
    # pre create the decryption key
    kubectl create ns flux-system
    kubectl create secret generic sops-age --namespace=flux-system --from-file=age.agekey

    # bootstrap flux
    flux bootstrap github \
                  --owner=SpiritLooper \
                  --repository=egghead \
                  --branch=main \
                  --path=./k8s/flux
    ```

3. Things should start to deploy! 🪄

---
*🛠 Built with love, open source, and a lot of YAML.*