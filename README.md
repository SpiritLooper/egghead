# 🪺 EggHead - HomeServer

Welcome to my personal **HomeServer**! This is a self-hosted infrastructure powered by Kubernetes, GitOps, and open source magic. ✨

## 🧰 Stack Overview

| Component     | Description                                      |
|---------------|--------------------------------------------------|
| 🐳 **K3s**     | Lightweight Kubernetes distro, perfect for home |
| 🔁 **FluxCD**  | GitOps continuous delivery to K8s               |
| 🧠 **Traefik** | Ingress controller + automatic TLS via ACME     |

## ⚙️ GitOps Workflow

All configuration is declarative and stored in a Git repository. Changes are pushed and **FluxCD** syncs them automatically into the cluster. 🚀

## 🌐 Access & Networking

- 🔐 All services are routed through **Traefik** with automatic HTTPS
- 🧩 Subdomain-based access under `.egghead.infrao.top` for each service

---

## 📦 Hosted Applications

A few of the self-hosted apps currently running:

> TODO: Add more apps ! 

---
🛠 Built with love, open source, and a lot of YAML.  
Questions? Ideas? Pull requests are welcome! 💌