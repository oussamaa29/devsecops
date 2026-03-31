# Rapport Synthétique — Projet DevSecOps
**Module :** 5DVSCOPS 2025/2026
**Auteur :** Oussama Chaghil
**Date :** Mars 2026

---

## 1. Présentation du projet

Ce projet consiste à mettre en place un pipeline DevSecOps complet sur GitHub Actions pour une API REST Flask. L'objectif est d'intégrer la sécurité à chaque étape du cycle de développement (CI/CD), en automatisant la détection de vulnérabilités avant tout déploiement.

**Stack technique :**
- Application : API REST en Flask (Python)
- Conteneurisation : Docker (`python:3.8-slim`)
- Orchestration : Kubernetes
- CI/CD : GitHub Actions
- Scan de vulnérabilités : Trivy
- Politique de sécurité : Conftest + Rego
- Lint YAML : yamllint

---

## 2. Architecture du pipeline

```
push/PR
  │
  ├── [Job 1] Lint YAML          → yamllint sur k8s/ et .github/workflows/
  │
  ├── [Job 2] Build Docker       → docker build + artifact upload
  │
  ├── [Job 3] Trivy FS Scan      → scan requirements.txt (CVEs Python)
  │
  ├── [Job 4] Trivy Image Scan   → scan image Docker (CVEs OS + libs)
  │
  ├── [Job 5] Conftest Policy    → vérification règles Rego K8s
  │
  └── [Job 6] Security Summary   → résumé global dans GitHub Actions
```

---

## 3. Vulnérabilités détectées

### 3.1 Scan des dépendances Python (Trivy FS)

Résultats réels obtenus par Trivy lors de l'exécution du pipeline (run #4) :

| Package | Version | CVE | Sévérité | Description |
|---------|---------|-----|----------|-------------|
| Jinja2 | 3.1.2 | CVE-2024-22195 | MEDIUM | HTML attribute injection via `xmlattr` filter |
| Jinja2 | 3.1.2 | CVE-2024-34064 | MEDIUM | Accepts keys with non-attribute characters |
| Jinja2 | 3.1.2 | CVE-2024-56201 | MEDIUM | Sandbox breakout via malicious filenames |
| Jinja2 | 3.1.2 | CVE-2024-56326 | MEDIUM | Sandbox breakout via indirect reference to format method |
| Jinja2 | 3.1.2 | CVE-2025-27516 | MEDIUM | Sandbox breakout via attr filter selecting format method |
| Werkzeug | 2.2.3 | CVE-2024-34069 | HIGH | Remote code execution on developer machine via debugger |
| Werkzeug | 2.2.3 | CVE-2023-46136 | MEDIUM | High resource consumption leading to denial of service |
| Werkzeug | 2.2.3 | CVE-2024-49766 | MEDIUM | `safe_join()` not safe on Windows |
| Werkzeug | 2.2.3 | CVE-2024-49767 | MEDIUM | Possible resource exhaustion when parsing file data in forms |
| Werkzeug | 2.2.3 | CVE-2025-66221 | MEDIUM | Denial of service via Windows device names in path segments |
| Werkzeug | 2.2.3 | CVE-2026-21860 | MEDIUM | `safe_join()` allows Windows special device names with compound extensions |
| Werkzeug | 2.2.3 | CVE-2026-27199 | MEDIUM | `safe_join()` allows Windows special device names |
| requests | 2.28.2 | CVE-2023-32681 | MEDIUM | Unintended leak of Proxy-Authorization header |
| requests | 2.28.2 | CVE-2024-35195 | MEDIUM | Subsequent requests ignore certificate verification |
| requests | 2.28.2 | CVE-2024-47081 | MEDIUM | Credentials leak via malicious URLs in `.netrc` |
| requests | 2.28.2 | CVE-2026-25645 | MEDIUM | Security bypass via predictable temporary file creation |

### 3.2 Scan de l'image Docker (Trivy image)

L'image `python:3.8-slim` expose des vulnérabilités au niveau OS (Debian/glibc) :

| Composant | CVE | Sévérité | Description |
|-----------|-----|----------|-------------|
| glibc | CVE-2021-33574 | CRITICAL | Use-after-free dans `mq_notify` |
| openssl | CVE-2022-0778 | HIGH | Boucle infinie dans `BN_mod_sqrt()` |
| libexpat | CVE-2022-25236 | HIGH | Injection de namespace XML |
| zlib | CVE-2022-37434 | HIGH | Heap buffer overflow dans `inflateGetHeader` |

> **Note :** Les vulnérabilités réelles varient selon la date d'exécution et la mise à jour de la base Trivy.

### 3.3 Violations de politique Conftest

Le fichier `k8s/deployment.yaml` viole 3 règles Rego :

```
FAIL - k8s/deployment.yaml - main - VIOLATION: Le conteneur 'flask-api' s'exécute en
       tant que root (runAsUser: 0). Utilisez un utilisateur non-root.

FAIL - k8s/deployment.yaml - main - VIOLATION: Le conteneur 'flask-api' n'a pas
       'runAsNonRoot: true'. Définissez cette propriété dans securityContext.

FAIL - k8s/deployment.yaml - main - VIOLATION: Le conteneur 'flask-api' n'a pas
       'allowPrivilegeEscalation: false'.
```

---

## 4. Recommandations

### 4.1 Dépendances

- **Mettre à jour toutes les dépendances** vers leurs dernières versions stables :
  ```
  Flask>=3.0.0
  Jinja2>=3.1.4
  Werkzeug>=3.0.3
  requests>=2.32.0
  ```
- Activer **GitHub Dependabot** pour des alertes automatiques sur les nouvelles CVEs.
- Intégrer un **lock file** (`pip-compile` / `poetry.lock`) pour figer les versions transitives.

### 4.2 Image Docker

- Utiliser une image de base récente : `python:3.12-slim` ou mieux `python:3.12-alpine`.
- Ne jamais utiliser `latest` en production — toujours épingler la version complète.
- Activer le scan d'image comme **gate de qualité** (`exit-code: 1` sur CRITICAL).

### 4.3 Configuration Kubernetes

Appliquer un `securityContext` sécurisé sur chaque conteneur :

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]
```

### 4.4 Pipeline CI/CD

- Passer `exit-code: "1"` dans Trivy pour **bloquer les merges** en cas de CVE CRITICAL.
- Ajouter **SAST** (ex : Semgrep) pour l'analyse statique du code source.
- Stocker les rapports SARIF dans l'onglet **Security > Code scanning** de GitHub.

---

## 5. Réflexion sécurité

L'intégration de la sécurité dans le pipeline CI/CD ("shift-left") permet de **détecter les vulnérabilités au plus tôt**, là où leur correction est la moins coûteuse. Sans ce pipeline, une image Docker construite avec des dépendances vulnérables pourrait être déployée en production sans que personne ne le sache.

Les trois couches de protection mises en place sont complémentaires :

1. **Trivy FS** : couvre les vulnérabilités applicatives (librairies Python)
2. **Trivy image** : couvre les vulnérabilités système (OS, glibc, openssl...)
3. **Conftest/Rego** : couvre les mauvaises configurations d'infrastructure

Ce projet illustre qu'un pipeline DevSecOps n'est pas une contrainte, mais un **filet de sécurité automatisé** qui renforce la posture de sécurité sans ralentir les développeurs. La prochaine étape naturelle serait d'ajouter du monitoring en production (Falco, Prometheus) pour compléter la boucle de rétroaction sécurité.

---

## 6. Fichiers livrés

| Fichier | Description |
|--------|-------------|
| `app.py` | API Flask (5 endpoints REST) |
| `requirements.txt` | Dépendances Python (versions vulnérables intentionnelles) |
| `Dockerfile` | Build de l'image Docker |
| `k8s/deployment.yaml` | Manifeste Kubernetes (avec défauts de sécurité intentionnels) |
| `policy/deny_root.rego` | Règles Conftest anti-root |
| `.github/workflows/ci.yml` | Pipeline GitHub Actions complet |
| `.yamllint.yml` | Configuration yamllint |
