# ARCHITECTURE-AS-A-SERVICE---PROJET

## Phase 4 : Packaging de l'application

### Objectif

Conteneuriser l'application web Node.js pour la rendre facilement déployable, stocker l'image sur un registry (Amazon ECR) et valider son exécution localement et sur EC2.

---

### Architecture

```
┌──────────────────────────────────────────────────┐
│                  Docker Compose                  │
│                                                  │
│   ┌──────────────┐       ┌──────────────────┐    │
│   │   app (Node)  │──────▶│   db (MySQL 8)   │    │
│   │   Port 80     │       │   Port 3306      │    │
│   └──────────────┘       └──────────────────┘    │
│         ▲                        ▲               │
│         │                        │               │
│     Dockerfile              init.sql             │
│  (build depuis              (crée la table       │
│   resources/)                students)            │
└──────────────────────────────────────────────────┘
         │
         ▼
   http://localhost
```

### Push sur ECR

```
┌────────────┐     docker build     ┌────────────┐     docker push     ┌─────────────────┐
│  Code source│ ──────────────────▶ │ Image Docker │ ─────────────────▶ │   Amazon ECR     │
│  resources/ │                     │ phase4-xyz   │                    │   phase4-xyz     │
└────────────┘                     └────────────┘                     └─────────────────┘
                                                                              │
                                                                         docker pull
                                                                              │
                                                                              ▼
                                                                      ┌──────────────┐
                                                                      │  Instance EC2 │
                                                                      │  Port 80      │
                                                                      └──────────────┘
```

---

### Structure des fichiers (Phase 4)

```
.
├── Dockerfile                  # Image Node.js de l'application
├── docker-compose.yml          # Orchestration locale (app + MySQL)
├── init.sql                    # Script SQL d'initialisation de la BDD
└── resources/
    └── codebase_partner/       # Code source de l'application Node.js
        ├── index.js
        ├── package.json
        ├── app/
        │   ├── config/
        │   ├── controller/
        │   └── models/
        ├── views/
        └── public/
```

---

### Prérequis

- Docker et Docker Compose installés
- AWS CLI configuré (`aws configure`)
- Un repository ECR créé

---

### Etape 1 : Test local avec Docker Compose

Lancer les deux containers (app + base de données) :

```bash
docker-compose up --build
```

Accéder à l'application : http://localhost

Arrêter les containers :

```bash
docker-compose down
```

Arrêter et supprimer les données MySQL :

```bash
docker-compose down -v
```

---

### Etape 2 : Build et push de l'image sur ECR

#### 2.1 — Créer le repository ECR (si pas encore fait)

```bash
aws ecr create-repository --repository-name phase4-xyz
```

#### 2.2 — Se connecter à ECR

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account_id>.dkr.ecr.us-east-1.amazonaws.com
```

#### 2.3 — Build, tag et push

```bash
docker build -t phase4-xyz .
docker tag phase4-xyz:latest <account_id>.dkr.ecr.us-east-1.amazonaws.com/phase4-xyz:latest
docker push <account_id>.dkr.ecr.us-east-1.amazonaws.com/phase4-xyz:latest
```
