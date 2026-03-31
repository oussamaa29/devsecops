# Rapport de projet — DevSecOps Pipeline
**Module :** 5DVSCOPS 2025/2026
**Auteur :** Oussama Chaghil
**Date :** Mars 2026

---

## 1. Présentation du projet

Pour ce projet j'ai mis en place un pipeline DevSecOps sur GitHub Actions à partir d'une petite API en Flask. L'idée c'est d'automatiser les vérifications de sécurité directement dans le pipeline, donc à chaque push on lance des scans de vulnérabilités, un lint des fichiers YAML, et une vérification des manifestes Kubernetes.

Ce que j'ai utilisé :
- Flask (Python) pour l'API
- Docker pour la conteneurisation (image `python:3.8-slim`)
- Kubernetes pour le déploiement
- GitHub Actions pour le pipeline CI/CD
- Trivy pour les scans de vulnérabilités
- Conftest + Rego pour les politiques de sécurité K8s
- yamllint pour la validation YAML

---

## 2. Structure du pipeline

Le pipeline se découpe en 6 jobs qui s'enchaînent :

```
push
  │
  ├── [Job 1] Lint YAML        → vérifie la syntaxe des fichiers k8s/
  ├── [Job 2] Build Docker     → construit l'image et la sauvegarde en artifact
  ├── [Job 3] Trivy FS         → scan des dépendances Python (requirements.txt)
  ├── [Job 4] Trivy image      → scan de l'image Docker construite
  ├── [Job 5] Conftest         → vérifie les règles de sécurité Kubernetes
  └── [Job 6] Résumé           → affiche le statut global dans GitHub Actions
```

---

## 3. Vulnérabilités détectées

### 3.1 Dépendances Python (Trivy FS)

Voici les CVEs trouvées sur les dépendances du projet (résultats réels du pipeline run #4) :

| Package | Version | CVE | Sévérité | Description |
|---------|---------|-----|----------|-------------|
| Jinja2 | 3.1.2 | CVE-2024-22195 | MEDIUM | Injection d'attributs HTML via le filtre `xmlattr` |
| Jinja2 | 3.1.2 | CVE-2024-34064 | MEDIUM | Accepte des clés avec des caractères non valides |
| Jinja2 | 3.1.2 | CVE-2024-56201 | MEDIUM | Sortie de sandbox via des noms de fichiers malveillants |
| Jinja2 | 3.1.2 | CVE-2024-56326 | MEDIUM | Sortie de sandbox via référence indirecte à `format` |
| Jinja2 | 3.1.2 | CVE-2025-27516 | MEDIUM | Sortie de sandbox via le filtre `attr` |
| Werkzeug | 2.2.3 | CVE-2024-34069 | HIGH | Exécution de code à distance via le debugger |
| Werkzeug | 2.2.3 | CVE-2023-46136 | MEDIUM | Consommation excessive de ressources (DoS) |
| Werkzeug | 2.2.3 | CVE-2024-49766 | MEDIUM | `safe_join()` non sécurisé sur Windows |
| Werkzeug | 2.2.3 | CVE-2024-49767 | MEDIUM | Épuisement des ressources lors du parsing de formulaires |
| Werkzeug | 2.2.3 | CVE-2025-66221 | MEDIUM | DoS via noms de devices Windows dans les chemins |
| Werkzeug | 2.2.3 | CVE-2026-21860 | MEDIUM | `safe_join()` contournable avec extensions composées |
| Werkzeug | 2.2.3 | CVE-2026-27199 | MEDIUM | `safe_join()` contournable avec noms spéciaux Windows |
| requests | 2.28.2 | CVE-2023-32681 | MEDIUM | Fuite du header `Proxy-Authorization` sur redirection |
| requests | 2.28.2 | CVE-2024-35195 | MEDIUM | Vérification du certificat ignorée sur requêtes suivantes |
| requests | 2.28.2 | CVE-2024-47081 | MEDIUM | Fuite de credentials via `.netrc` et URLs malveillantes |
| requests | 2.28.2 | CVE-2026-25645 | MEDIUM | Contournement de sécurité via fichiers temporaires prévisibles |

### 3.2 Image Docker (Trivy image)

L'image `python:3.8-slim` (Debian) contient aussi des CVEs au niveau OS :

| Composant | CVE | Sévérité | Description |
|-----------|-----|----------|-------------|
| glibc | CVE-2021-33574 | CRITICAL | Use-after-free dans `mq_notify` |
| openssl | CVE-2022-0778 | HIGH | Boucle infinie dans `BN_mod_sqrt()` |
| libexpat | CVE-2022-25236 | HIGH | Injection de namespace XML |
| zlib | CVE-2022-37434 | HIGH | Heap buffer overflow dans `inflateGetHeader` |

### 3.3 Violations Conftest

Le manifeste `k8s/deployment.yaml` a été volontairement configuré avec des failles pour tester les règles Rego. Résultat du pipeline :

```
FAIL - Le conteneur 'flask-api' s'exécute en tant que root (runAsUser: 0)
FAIL - Le conteneur 'flask-api' n'a pas runAsNonRoot: true
FAIL - Le conteneur 'flask-api' n'a pas allowPrivilegeEscalation: false
```

---

## 4. Recommandations

**Côté dépendances** — la première chose à faire serait de mettre à jour les versions. Jinja2, Werkzeug et requests ont tous des versions corrigées disponibles. Activer Dependabot sur le repo permettrait d'être alerté automatiquement.

**Côté image Docker** — passer sur `python:3.12-slim` ou `python:3.12-alpine` réduirait considérablement la surface d'attaque au niveau OS. L'image 3.8 est en fin de vie et n'est plus patchée.

**Côté Kubernetes** — le pod ne devrait jamais tourner en root. Le `securityContext` devrait ressembler à ça :

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]
```

**Côté pipeline** — pour l'instant Trivy est configuré avec `exit-code: 0` donc le pipeline ne bloque pas même si des CVEs critiques sont trouvées. En production il faudrait passer à `exit-code: 1` pour bloquer les merges sur les CVEs HIGH/CRITICAL.

---

## 5. Réflexion personnelle

Ce projet m'a permis de voir concrètement pourquoi on parle de "shift-left" en sécurité. Avant de faire ce pipeline, j'aurais probablement installé ces dépendances sans me douter qu'elles contiennent autant de CVEs, dont une HIGH sur Werkzeug qui permet une exécution de code à distance.

Ce qui m'a le plus surpris c'est la quantité de vulnérabilités sur l'image Docker de base — même une image "slim" Python 3.8 contient des CVEs critiques au niveau OS, ce qui montre que le choix de l'image de base est tout aussi important que les dépendances applicatives.

Conftest m'a aussi semblé utile pour "coder" des règles de sécurité qui s'appliquent automatiquement, plutôt que de compter sur des reviews manuelles. Si quelqu'un pousse un manifest Kubernetes avec un pod en root, le pipeline le détecte immédiatement.

---

## 6. Fichiers rendus

| Fichier | Description |
|--------|-------------|
| `app.py` | API Flask avec 5 endpoints |
| `requirements.txt` | Dépendances Python |
| `Dockerfile` | Image Docker basée sur python:3.8-slim |
| `k8s/deployment.yaml` | Manifeste Kubernetes (avec failles intentionnelles pour démo Conftest) |
| `policy/deny_root.rego` | 3 règles Rego anti-root |
| `.github/workflows/ci.yml` | Pipeline GitHub Actions (6 jobs) |
| `.yamllint.yml` | Config yamllint |
