# Université Exemple – Phase 2 : Découplage des Composants
## Infrastructure AWS avec Terraform

---

## Architecture

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│  VPC  10.0.0.0/16                                           │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Sous-réseaux Publics (AZ-a 10.0.1.0/24, AZ-b)      │   │
│  │                                                      │   │
│  │  ┌─────────────────┐    ┌─────────────────────┐      │   │
│  │  │  EC2 App Server │    │  Cloud9 IDE         │      │   │
│  │  │  t3.micro       │    │  t3.small           │      │   │
│  │  │  Node.js        │    │  (Scripts CLI)      │      │   │
│  │  │  ↓ IAM Role     │    └─────────────────────┘      │   │
│  │  │  ↓ Secrets Mgr  │                                  │   │
│  │  └────────┬────────┘                                  │   │
│  └───────────│──────────────────────────────────────────┘   │
│              │ Port 3306 (SG uniquement)                     │
│  ┌───────────│──────────────────────────────────────────┐   │
│  │  Sous-réseaux Privés (AZ-a 10.0.11.0/24, AZ-b)      │   │
│  │           │                                          │   │
│  │  ┌────────▼────────────────────────┐                 │   │
│  │  │  RDS MySQL  db.t3.micro         │                 │   │
│  │  │  Chiffré – Pas d'accès public   │                 │   │
│  │  └─────────────────────────────────┘                 │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
              │
              ▼
    AWS Secrets Manager
    (Identifiants DB – aucun mot de passe en dur)
```

---

## Structure du Projet

```
terraform-phase2/
├── main.tf                    # Point d'entrée principal
├── variables.tf               # Déclaration de toutes les variables
├── outputs.tf                 # Outputs (IPs, endpoints, URLs)
├── terraform.tfvars.example   # ← Copiez vers terraform.tfvars et personnalisez
│
├── modules/
│   ├── vpc/
│   │   ├── main.tf            # VPC, subnets, IGW, NAT GW, Route Tables, Flow Logs
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── secrets/
│   │   ├── main.tf            # AWS Secrets Manager – identifiants DB
│   │   └── variables.tf       # (inclut outputs)
│   │
│   ├── rds/
│   │   ├── main.tf            # RDS MySQL, SG, Parameter Group, Alarmes CloudWatch
│   │   └── variables.tf       # (inclut outputs)
│   │
│   ├── ec2/
│   │   ├── main.tf            # EC2 App, SG, IAM Role, EIP, Log Groups
│   │   └── variables.tf       # (inclut outputs)
│   │
│   └── cloud9/
│       ├── main.tf            # Environnement Cloud9 IDE
│       └── variables.tf       # (inclut outputs)
│
├── templates/
│   └── userdata.sh.tpl        # Template script de démarrage EC2
│
└── scripts/
    └── cloud9-scripts.sh      # Script-1 et Script-3 pour Cloud9
```

---

## Déploiement pas à pas

### Prérequis

```bash
# Vérifier Terraform >= 1.5
terraform version

# Configurer AWS CLI
aws configure
# AWS Access Key ID: <votre access key>
# AWS Secret Access Key: <votre secret key>
# Default region name: us-east-1
# Default output format: json

# Vérifier l'accès AWS
aws sts get-caller-identity
```

### Étape 1 – Configuration

```bash
# Copier et personnaliser les variables
cp terraform.tfvars.example terraform.tfvars

# Éditez terraform.tfvars :
#   key_pair_name = "votre-keypair-existante"
#   aws_region    = "us-east-1"  (ou votre région d'atelier)
```

### Étape 2 – Initialisation

```bash
terraform init
```

### Étape 3 – Planification

```bash
terraform plan -out=tfplan
```

> Vérifiez le plan avant d'appliquer. Environ **25 ressources** seront créées.

### Étape 4 – Déploiement

```bash
terraform apply tfplan
```

> ⏱ **Durée estimée : 15–20 minutes** (RDS prend 10–15 min)

### Étape 5 – Récupérer les outputs

```bash
terraform output

# Outputs importants :
terraform output app_url             # URL de l'application
terraform output rds_endpoint        # Endpoint RDS
terraform output secret_name         # Nom du secret Secrets Manager
terraform output cloud9_environment_url  # URL Cloud9
terraform output ssh_command         # Commande SSH
```

---

## Scripts Cloud9 – Script-1 et Script-3

### Ouvrir Cloud9

1. Dans la Console AWS → Cloud9 → Ouvrez votre environnement
2. Installez les dépendances :

```bash
sudo apt-get update -y
sudo apt-get install -y mysql-client jq
```

### Transférer le script

```bash
# Option A : Télécharger depuis S3 (si disponible dans votre atelier)
curl -o cloud9-scripts.sh <URL_SCRIPTS_ATELIER>

# Option B : Créer le fichier manuellement dans l'IDE Cloud9
# Copiez le contenu de scripts/cloud9-scripts.sh dans un nouveau fichier
```

### Configurer le script

```bash
# Modifiez les variables en haut du fichier :
RDS_ENDPOINT="$(terraform output -raw rds_endpoint)"   # Dans votre terminal local
PHASE1_EC2_IP="<IP de votre instance Phase 1>"
SSH_KEY_PATH="$HOME/environment/votre-cle.pem"
SECRET_NAME="$(terraform output -raw secret_name)"
```

### Exécuter Script-1 : Créer/mettre à jour le secret

```bash
source cloud9-scripts.sh
script_1_create_secret
```

### Exécuter Script-3 : Migrer les données

```bash
# Copiez votre clé SSH dans Cloud9
# Dans Cloud9 terminal :
chmod 400 $HOME/environment/votre-cle.pem

source cloud9-scripts.sh
script_3_migrate_data
```

### Vérifier l'architecture complète

```bash
source cloud9-scripts.sh
script_verify_architecture
```

---

## Tests de l'Application

### Accès web

```
http://<APP_PUBLIC_IP>
```

### Opérations CRUD à tester

| Opération | Action |
|-----------|--------|
| **Read**   | Ouvrir l'app – la liste des dossiers s'affiche |
| **Create** | Ajouter un étudiant : Nom, Prénom, Programme |
| **Update** | Modifier un dossier existant |
| **Delete** | Supprimer un dossier |
| **Persist**| Rafraîchir la page – les données restent |

### Vérification SSH

```bash
# Connexion SSH
ssh -i votre-cle.pem ubuntu@<APP_PUBLIC_IP>

# Vérifier le service
sudo systemctl status students-app

# Voir les logs applicatifs
sudo journalctl -u students-app -f

# Vérifier le fichier .env (credentials vides – récupérés depuis SM)
sudo cat /var/www/students-app/.env

# Tester la connexion RDS manuellement
mysql -h <RDS_ENDPOINT> -u dbadmin -p students
```

---

## Dépannage

### L'application ne répond pas

```bash
# 1. Vérifier le Security Group (port 80 ouvert)
aws ec2 describe-security-groups --group-names "universite-exemple-poc-sg-app"

# 2. Vérifier les logs UserData
sudo cat /var/log/userdata-phase2.log

# 3. Vérifier le service Node.js
sudo systemctl status students-app
sudo journalctl -u students-app --no-pager -n 50
```

### Erreur de connexion à RDS

```bash
# 1. Vérifier que RDS est disponible
aws rds describe-db-instances --region us-east-1 \
  --query 'DBInstances[].{ID:DBInstanceIdentifier,Status:DBInstanceStatus}'

# 2. Vérifier les Security Groups RDS (port 3306 depuis SG EC2)
# La règle doit référencer le SG de l'EC2, pas une IP

# 3. Tester depuis l'instance EC2 (pas depuis l'extérieur – RDS est privé)
mysql -h <RDS_ENDPOINT> -P 3306 -u dbadmin -p students
```

### Script-3 : Erreur SSH vers Phase 1

```bash
# Vérifier la connexion SSH
ssh -i votre-cle.pem -v ubuntu@<PHASE1_EC2_IP>

# Vérifier que l'instance Phase 1 est en cours d'exécution
aws ec2 describe-instances --filters "Name=tag:Name,Values=WebApp-Phase1"
```

---

## Nettoyage (fin d'atelier)

```bash
# Détruire toutes les ressources (ATTENTION : irréversible)
terraform destroy

# Ou cibler une ressource spécifique
terraform destroy -target=module.cloud9
```

> **Note :** `deletion_protection = false` est défini pour faciliter le nettoyage en POC.
> En production, activez `deletion_protection = true` sur RDS.

---

## Coûts Estimés (Phase 2)

| Ressource | Type | Coût/mois approx. |
|-----------|------|-------------------|
| EC2 App | t3.micro (730h) | ~$7.50 |
| RDS MySQL | db.t3.micro Single-AZ | ~$15 |
| NAT Gateway | 730h + données | ~$35 |
| Cloud9 EC2 | t3.small (si actif) | ~$15 |
| Secrets Manager | 1 secret | ~$0.40 |
| EIP | Attachée à EC2 | ~$0 |
| **Total** | | **~$73/mois** |

> 💡 **Optimisation POC** : Supprimez le NAT Gateway si les sous-réseaux privés
> n'ont pas besoin d'accès Internet sortant → économie ~$35/mois.
> Désactivez Cloud9 quand il n'est pas utilisé (hibernation auto à 30 min).

---

## Prochaines étapes – Phase 3

- [ ] Application Load Balancer (ALB)
- [ ] Auto Scaling Group multi-AZ
- [ ] Launch Template pour le déploiement automatique
- [ ] CloudFront CDN (optionnel)
- [ ] ACM + HTTPS
- [ ] WAF (optionnel)
