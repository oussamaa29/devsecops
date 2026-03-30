# DevSecOps Pipeline — 5DVSCOPS 2025/2026

Pipeline DevSecOps complet avec GitHub Actions, Trivy, et Conftest.

## Structure du projet

```
devsecops-project/
├── app.py                        # API REST Flask
├── requirements.txt              # Dépendances Python
├── Dockerfile                    # Image Docker
├── .yamllint.yml                 # Configuration yamllint
├── k8s/
│   └── deployment.yaml           # Manifeste Kubernetes
├── policy/
│   └── deny_root.rego            # Règles Conftest (Rego)
├── .github/
│   └── workflows/
│       └── ci.yml                # Pipeline GitHub Actions
└── RAPPORT_SECURITE.md           # Rapport synthétique
```

## Pipeline CI/CD

| Job | Outil | Rôle |
|-----|-------|------|
| lint-yaml | yamllint | Valide la syntaxe YAML |
| build | Docker | Construit l'image |
| trivy-fs-scan | Trivy | Scan des dépendances Python |
| trivy-image-scan | Trivy | Scan de l'image Docker |
| conftest-policy | Conftest | Vérifie les politiques K8s |
| security-summary | — | Résumé global |

## Lancer le projet localement

```bash
pip install -r requirements.txt
python app.py
```

Endpoints disponibles :
- `GET /` — statut de l'API
- `GET /health` — health check
- `GET /items` — liste des items
- `GET /items/<id>` — item par ID
- `POST /items` — créer un item
