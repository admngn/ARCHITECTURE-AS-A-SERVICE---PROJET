# ARCHITECTURE-AS-A-SERVICE---PROJET

## Phase 1 : POC — Application web sur une VM dans le Cloud AWS

### Objectif

Déployer une application web Node.js (CRUD étudiants) sur une instance EC2 unique dans un réseau virtuel, accessible depuis internet.

---

### Architecture

```
                        Internet
                            │
                            ▼
                   ┌─────────────────┐
                   │ Internet Gateway │
                   └────────┬────────┘
                            │
               ┌────────────┴─────────────────────────────┐
               │            VPC (10.0.0.0/16)             │
               │                                          │
               │   ┌──────────────────────────────────┐   │
               │   │   Subnet Public (10.0.1.0/24)    │   │
               │   │                                   │   │
               │   │   ┌───────────────────────────┐   │   │
               │   │   │    EC2 — AppServer         │   │   │
               │   │   │    Ubuntu 22.04 (t2.micro) │   │   │
               │   │   │                            │   │   │
               │   │   │   ┌────────┐  ┌─────────┐ │   │   │
               │   │   │   │ Node.js│  │ MySQL   │ │   │   │
               │   │   │   │ :80    │  │ :3306   │ │   │   │
               │   │   │   └────────┘  └─────────┘ │   │   │
               │   │   └───────────────────────────┘   │   │
               │   │                                   │   │
               │   │   Security Group :                │   │
               │   │    - SSH   (22)  ◀── 0.0.0.0/0   │   │
               │   │    - HTTP  (80)  ◀── 0.0.0.0/0   │   │
               │   └──────────────────────────────────┘   │
               │                                          │
               │   ┌──────────────────────────────────┐   │
               │   │   Subnet Privé (10.0.2.0/24)     │   │
               │   │   (réservé pour les phases        │   │
               │   │    suivantes)                     │   │
               │   └──────────────────────────────────┘   │
               └──────────────────────────────────────────┘
```

---

### Structure du projet

```
.
├── README.md
├── .gitignore
└── infrastructure/
    ├── terraform.tf                 # Provider AWS (us-east-1)
    ├── variable.tf                  # Variables avec valeurs par défaut
    ├── main.tf                      # Ressources (VPC, subnets, EC2...)
    ├── outputs.tf                   # IP publique, IDs des ressources
    └── UserdataScript-phase-2.sh    # Script d'init (Node.js + MySQL)
```

---

### Ressources Terraform déployées

| Ressource | Nom | Description |
|---|---|---|
| `aws_vpc` | MainVPC | Réseau virtuel isolé (10.0.0.0/16) |
| `aws_subnet` | PublicSubnet | Subnet avec IP publique auto-assignée |
| `aws_subnet` | PrivateSubnet | Subnet sans accès internet (futur usage) |
| `aws_internet_gateway` | MainIGW | Passerelle entre le VPC et internet |
| `aws_route_table` | PublicRouteTable | Route 0.0.0.0/0 vers l'IGW |
| `aws_security_group` | AppSG | Ports 22 (SSH) et 80 (HTTP) ouverts |
| `aws_instance` | AppServer | VM Ubuntu 22.04, t2.micro |

---

### Prérequis

- [Terraform](https://developer.hashicorp.com/terraform/install) installé
- AWS CLI configuré (`aws configure`)
- Une paire de clés SSH dans AWS EC2 (si accès SSH souhaité)

---

### Déploiement

```bash
cd infrastructure

# Initialiser Terraform (télécharge le provider AWS)
terraform init

# Visualiser les ressources qui seront créées
terraform plan

# Déployer l'infrastructure
terraform apply
```

Après le déploiement, récupérer l'IP publique :

```bash
terraform output public_ip
```

Ouvrir `http://<public_ip>` dans le navigateur. L'application met 2-3 min à s'installer au premier démarrage.

---

### Ce que fait le script UserData au démarrage de l'EC2

```
1. apt install nodejs npm mysql-server
2. Télécharge le code source (code.zip) depuis S3
3. npm install
4. Crée la BDD STUDENTS + table students
5. Lance l'app Node.js sur le port 80
```