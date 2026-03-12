# Phase 5 – CI/CD avec GitHub Actions + k6

## Architecture de la pipeline

```
Push sur main
     │
     ▼
┌─────────────────────┐
│  JOB 1              │
│  Build & Quality    │  ← npm ci, ESLint, npm audit
│  - Lint             │  ← docker build (smoke test)
│  - Audit sécu       │
│  - Smoke container  │
└────────┬────────────┘
         │ succès
         ▼
┌─────────────────────┐
│  JOB 2              │
│  Docker Push        │  ← docker buildx (linux/amd64)
│  → Docker Hub       │  ← tag: latest + sha du commit
└────────┬────────────┘
         │ succès
         ▼
┌─────────────────────┐
│  JOB 3              │
│  Deploy EC2         │  ← SSH → docker pull + run
│  → Production       │  ← vérification HTTP 200
└────────┬────────────┘
         │ succès
         ▼
┌─────────────────────┐
│  JOB 4              │
│  Load Test k6       │  ← smoke (1 VU) + load (50 VU) + stress (100 VU)
│  → Rapport JSON     │  ← seuils : p95 < 2s, erreurs < 5%
└─────────────────────┘
```

## Structure des fichiers

```
.github/
└── workflows/
    └── cicd.yml              ← Pipeline principale

tests/
└── load/
    ├── load-test.js          ← Script k6
    └── results.json          ← Résultats (généré automatiquement)
```

## Configuration des secrets GitHub

Allez dans **Settings → Secrets and variables → Actions → New repository secret**

| Secret | Valeur | Comment obtenir |
|--------|--------|-----------------|
| `DOCKERHUB_USERNAME` | votre username Docker Hub | hub.docker.com |
| `DOCKERHUB_TOKEN` | token Docker Hub | hub.docker.com → Account Settings → Security |
| `EC2_HOST` | IP publique EC2 | `terraform output app_public_ip` |
| `EC2_SSH_KEY` | contenu du fichier .pem | `cat 'labsuser (1).pem'` |
| `DB_PASSWORD` | mot de passe RDS | `terraform show -json \| python3 ...` |
| `AWS_ACCESS_KEY_ID` | credentials AWS Academy | Portail AWS Academy → AWS Details |
| `AWS_SECRET_ACCESS_KEY` | credentials AWS Academy | Portail AWS Academy → AWS Details |
| `AWS_SESSION_TOKEN` | credentials AWS Academy | Portail AWS Academy → AWS Details |

### Ajouter EC2_SSH_KEY

```bash
# Copier le contenu de la clé (sur Mac)
cat ~/Downloads/'labsuser (1).pem' | pbcopy
# Puis coller dans le secret GitHub
```

## Mise en place

### 1. Intégrer dans votre repo existant

```bash
# Depuis la racine de votre projet (qui contient Dockerfile et resources/)
cp -r phase5-cicd/.github .
cp -r phase5-cicd/tests .

git add .github/ tests/
git commit -m "feat: ajout pipeline CI/CD GitHub Actions + tests k6"
git push origin main
```

### 2. Vérifier la pipeline

Allez dans **GitHub → Actions** — vous verrez la pipeline se déclencher automatiquement.

### 3. Test de charge local

```bash
# Installer k6 sur Mac
brew install k6

# Lancer le test complet
k6 run --env TARGET_URL=http://32.195.9.34 tests/load/load-test.js

# Smoke test uniquement (rapide, 30s)
k6 run --env TARGET_URL=http://32.195.9.34 \
  --scenario smoke \
  tests/load/load-test.js
```

## Comportement par branche

| Branche | Build | Tests | Push Docker | Deploy | Load Test |
|---------|-------|-------|-------------|--------|-----------|
| `main`  | ✅ | ✅ | ✅ | ✅ | ✅ |
| `dev`   | ✅ | ✅ | ❌ | ❌ | ❌ |
| PR      | ✅ | ✅ | ❌ | ❌ | ❌ |

## Seuils de performance k6

| Métrique | Seuil | Description |
|----------|-------|-------------|
| `http_req_duration p(95)` | < 2000ms | 95% des requêtes sous 2s |
| `error_rate` | < 5% | Moins de 5% d'erreurs |
| `students_page_duration p(95)` | < 3000ms | Page students sous 3s |

Si un seuil est dépassé, le job k6 échoue et GitHub notifie l'équipe.
