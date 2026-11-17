# Pipeline DevSecOps : Trivy, Conftest et GitHub Actions

| Branche | Contenu | Pipeline |
|---|---|---|
| `main` | Version corrigée | [![main](https://github.com/oussamaa29/devsecops/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/oussamaa29/devsecops/actions/workflows/ci.yml?query=branch%3Amain) |
| `vulnerable` | Version volontairement vulnérable | [![vulnerable](https://github.com/oussamaa29/devsecops/actions/workflows/ci.yml/badge.svg?branch=vulnerable)](https://github.com/oussamaa29/devsecops/actions/workflows/ci.yml?query=branch%3Avulnerable) |

Ce pipeline intègre la sécurité à chaque push : scan des dépendances, de l'image Docker et des secrets avec Trivy, et vérification des manifestes Kubernetes par des politiques écrites en Rego (Conftest).

Le projet montre les deux côtés :
- **`vulnerable`** contient une API avec des dépendances aux CVE connues, une image Python 3.8 (fin de vie) et un conteneur qui tourne en root. **Son pipeline échoue, et c'est voulu** : les barrières font leur travail.
- **`main`** contient la même API corrigée, et son pipeline passe.

Le diff entre les deux branches tient en quatre fichiers : `git diff vulnerable main -- Dockerfile requirements.txt k8s/ app.py`.

## Ce que le pipeline bloque

| Job | Outil | Bloque si… |
|---|---|---|
| `lint-yaml` | yamllint | un manifeste ou le workflow est mal formé |
| `tests` | pytest | un test de l'API échoue |
| `trivy-fs` | Trivy | une faille CRITICAL/HIGH corrigible dans les dépendances, un secret commité, ou une mauvaise configuration (Dockerfile, Kubernetes) |
| `trivy-image` | Trivy | une faille CRITICAL/HIGH corrigible dans l'image construite |
| `conftest` | Conftest | un test de politique échoue (`conftest verify`), ou un manifeste viole une règle |

Les résultats Trivy sont aussi envoyés au format SARIF dans l'onglet **Security** du dépôt.

## Avant / après

| | `vulnerable` | `main` |
|---|---|---|
| Image de base | `python:3.8-slim` (fin de vie) | `python:3.13-slim`, épinglée par digest |
| Dépendances | Flask 2.2.5, Werkzeug 2.2.3, Jinja2 3.1.2, requests 2.28.2 (CVE connues) | Versions à jour, `requests` retiré (inutilisé) |
| Utilisateur | root | UID 10001, sans shell |
| Serveur | serveur de développement Flask | gunicorn |
| Kubernetes | `runAsUser: 0`, image `:latest` | non-root, pas d'élévation de privilèges, racine en lecture seule, capacités retirées, seccomp, sondes |

## Politiques Kubernetes (`policy/`)

Les règles sont écrites en Rego v1 et couvertes par 10 tests unitaires (`deny_root_test.rego`) :

1. pas de conteneur lancé en root (`runAsUser: 0`) ;
2. `runAsNonRoot: true` obligatoire ;
3. `allowPrivilegeEscalation: false` obligatoire ;
4. système de fichiers racine en lecture seule ;
5. toutes les capacités Linux retirées (`drop: [ALL]`) ;
6. image avec une version explicite (ni tag absent, ni `:latest`) ;
7. limites CPU et mémoire obligatoires.

## Chaîne d'approvisionnement

Un pipeline de sécurité ne doit pas devenir lui-même une porte d'entrée :
- les actions GitHub tierces sont **épinglées par SHA de commit**, car un tag peut être déplacé vers du code malveillant ;
- le binaire Conftest est vérifié par **somme de contrôle** avant d'être exécuté ;
- le jeton du workflow est en lecture seule par défaut. Seuls les jobs Trivy reçoivent `security-events: write` ;
- **Dependabot** propose chaque semaine les mises à jour des dépendances Python, de l'image de base et des actions.

## Lancer en local

```bash
pip install -r requirements.txt -r requirements-dev.txt
pytest                                   # tests de l'API
conftest verify --policy policy/         # tests des politiques
conftest test k8s/ --policy policy/      # vérification des manifestes
gunicorn --bind 0.0.0.0:5000 app:app     # ou : python app.py
```

Endpoints : `GET /`, `GET /health`, `GET /items`, `GET /items/<id>`, `POST /items`.

## Structure

```
├── app.py                  # API REST Flask
├── test_app.py             # Tests pytest
├── requirements.txt        # Dépendances
├── Dockerfile
├── k8s/deployment.yaml     # Deployment + Service
├── policy/                 # Règles Conftest (Rego) et leurs tests
├── .github/workflows/ci.yml
├── .github/dependabot.yml
└── RAPPORT_SECURITE.md     # Rapport d'analyse (module 5DVSCOPS, ESTIAM)
```

## Licence

MIT
