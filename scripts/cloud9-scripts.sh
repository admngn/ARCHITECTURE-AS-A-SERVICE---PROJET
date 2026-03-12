#!/usr/bin/env bash
###############################################################################
# cloud9-scripts.sh
# Scripts à exécuter dans l'environnement AWS Cloud9
#
# SCRIPT-1 : Créer/mettre à jour le secret Secrets Manager avec l'endpoint RDS
# SCRIPT-3 : Migrer les données depuis l'instance EC2 Phase 1 vers RDS
#
# Usage :
#   source cloud9-scripts.sh          # Charger les fonctions
#   script_1_create_secret             # Exécuter Script-1
#   script_3_migrate_data              # Exécuter Script-3
#
# Prérequis Cloud9 :
#   - AWS CLI configuré (région, credentials)
#   - mysql-client installé (sudo apt-get install -y mysql-client)
#   - jq installé (sudo apt-get install -y jq)
###############################################################################

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION – Modifiez ces variables selon votre environnement Terraform
# (récupérez les valeurs via : terraform output)
# ─────────────────────────────────────────────────────────────────────────────

# Région AWS
AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

# Nom du secret (correspond à l'output Terraform : terraform output secret_name)
SECRET_NAME="universite-exemple-poc/rds/credentials"

# Endpoint RDS (terraform output rds_endpoint)
RDS_ENDPOINT=""

# Nom de la base de données
DB_NAME="students"

# IP publique de l'instance EC2 Phase 1 (source des données)
PHASE1_EC2_IP=""

# Chemin de la clé SSH pour se connecter à l'instance Phase 1
SSH_KEY_PATH="$HOME/environment/ma-cle-ssh.pem"

# Nom d'utilisateur DB sur l'instance Phase 1
PHASE1_DB_USER="admin"
PHASE1_DB_PASSWORD="Pa\$\$w0rd"  # Mot de passe du script Phase 1

# ─────────────────────────────────────────────────────────────────────────────
# UTILITAIRES
# ─────────────────────────────────────────────────────────────────────────────

log_info()    { echo -e "\033[0;36m[INFO]\033[0m  $*"; }
log_success() { echo -e "\033[0;32m[OK]\033[0m    $*"; }
log_warn()    { echo -e "\033[0;33m[WARN]\033[0m  $*"; }
log_error()   { echo -e "\033[0;31m[ERROR]\033[0m $*"; exit 1; }

check_dependencies() {
  local missing=()
  for cmd in aws mysql mysqldump jq curl; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done

  if [ ${#missing[@]} -gt 0 ]; then
    log_warn "Dépendances manquantes : ${missing[*]}"
    log_info "Installation en cours..."
    sudo apt-get update -y -qq
    sudo apt-get install -y -qq mysql-client jq curl
  fi
  log_success "Toutes les dépendances sont disponibles."
}

# ─────────────────────────────────────────────────────────────────────────────
# SCRIPT-1 : Créer/mettre à jour le secret Secrets Manager
# ─────────────────────────────────────────────────────────────────────────────

script_1_create_secret() {
  log_info "======================================================="
  log_info " SCRIPT-1 : Création du secret Secrets Manager"
  log_info "======================================================="

  # Vérifier que l'endpoint RDS est défini
  if [ -z "$RDS_ENDPOINT" ]; then
    log_warn "RDS_ENDPOINT non défini. Récupération automatique..."
    RDS_ENDPOINT=$(aws rds describe-db-instances \
      --region "$AWS_REGION" \
      --query 'DBInstances[?DBName==`students`].Endpoint.Address' \
      --output text 2>/dev/null | head -1)

    if [ -z "$RDS_ENDPOINT" ]; then
      log_error "Impossible de récupérer l'endpoint RDS. Définissez RDS_ENDPOINT manuellement."
    fi
  fi
  log_info "Endpoint RDS détecté : $RDS_ENDPOINT"

  # Récupérer le secret existant pour obtenir username/password
  log_info "Lecture du secret existant : $SECRET_NAME..."
  SECRET_VALUE=$(aws secretsmanager get-secret-value \
    --secret-id "$SECRET_NAME" \
    --region "$AWS_REGION" \
    --query 'SecretString' \
    --output text 2>/dev/null) || {
    log_warn "Secret non trouvé. Création d'un nouveau secret..."
    SECRET_VALUE="{}"
  }

  DB_USER=$(echo "$SECRET_VALUE" | jq -r '.username // "dbadmin"')
  DB_PASS=$(echo "$SECRET_VALUE" | jq -r '.password // empty')

  if [ -z "$DB_PASS" ]; then
    log_error "Mot de passe DB non trouvé dans le secret existant. Vérifiez Terraform output."
  fi

  # Construire le secret complet avec host
  UPDATED_SECRET=$(jq -n \
    --arg username "$DB_USER" \
    --arg password "$DB_PASS" \
    --arg engine  "mysql" \
    --arg host    "$RDS_ENDPOINT" \
    --arg port    "3306" \
    --arg dbname  "$DB_NAME" \
    '{
      username: $username,
      password: $password,
      engine:   $engine,
      host:     $host,
      port:     $port,
      dbname:   $dbname
    }')

  # Mettre à jour le secret avec l'host RDS
  log_info "Mise à jour du secret avec l'endpoint RDS..."
  aws secretsmanager put-secret-value \
    --secret-id "$SECRET_NAME" \
    --secret-string "$UPDATED_SECRET" \
    --region "$AWS_REGION"

  log_success "Secret mis à jour avec succès !"
  log_info "Secret ARN : $(aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$AWS_REGION" --query 'ARN' --output text)"

  # Vérification finale
  log_info "Vérification du contenu du secret..."
  aws secretsmanager get-secret-value \
    --secret-id "$SECRET_NAME" \
    --region "$AWS_REGION" \
    --query 'SecretString' \
    --output text | jq '{
      username: .username,
      engine:   .engine,
      host:     .host,
      port:     .port,
      dbname:   .dbname,
      password: "***MASQUÉ***"
    }'

  log_success "SCRIPT-1 terminé avec succès."
  echo ""
  log_info "Prochaine étape : Exécutez script_3_migrate_data pour migrer les données."
}

# ─────────────────────────────────────────────────────────────────────────────
# SCRIPT-3 : Migrer les données depuis EC2 Phase 1 vers RDS
# ─────────────────────────────────────────────────────────────────────────────

script_3_migrate_data() {
  log_info "======================================================="
  log_info " SCRIPT-3 : Migration des données EC2 Phase 1 → RDS"
  log_info "======================================================="

  check_dependencies

  # Vérifications préalables
  if [ -z "$PHASE1_EC2_IP" ]; then
    log_error "PHASE1_EC2_IP non défini. Définissez l'IP de l'instance EC2 Phase 1."
  fi

  if [ -z "$RDS_ENDPOINT" ]; then
    RDS_ENDPOINT=$(aws rds describe-db-instances \
      --region "$AWS_REGION" \
      --query 'DBInstances[?DBName==`students`].Endpoint.Address' \
      --output text | head -1)
  fi

  if [ -z "$RDS_ENDPOINT" ]; then
    log_error "RDS_ENDPOINT non défini. Exécutez d'abord script_1_create_secret."
  fi

  # Récupérer les credentials RDS depuis Secrets Manager
  log_info "Récupération des identifiants RDS depuis Secrets Manager..."
  SECRET_VALUE=$(aws secretsmanager get-secret-value \
    --secret-id "$SECRET_NAME" \
    --region "$AWS_REGION" \
    --query 'SecretString' \
    --output text)

  RDS_USER=$(echo "$SECRET_VALUE" | jq -r '.username')
  RDS_PASS=$(echo "$SECRET_VALUE" | jq -r '.password')

  log_info "Utilisateur RDS cible : $RDS_USER"
  log_info "Endpoint RDS cible    : $RDS_ENDPOINT"
  log_info "Instance EC2 source   : $PHASE1_EC2_IP"

  # ── Étape 1 : Export depuis MariaDB sur EC2 Phase 1 ──────────────────────
  log_info "[Étape 1/4] Export de la base de données depuis EC2 Phase 1..."
  DUMP_FILE="/tmp/students_phase1_dump_$(date +%Y%m%d_%H%M%S).sql"

  ssh -i "$SSH_KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=10 \
    "ubuntu@$PHASE1_EC2_IP" \
    "mysqldump -u $PHASE1_DB_USER -p'$PHASE1_DB_PASSWORD' \
      --single-transaction \
      --routines \
      --triggers \
      --no-tablespaces \
      $DB_NAME" > "$DUMP_FILE"

  if [ ! -s "$DUMP_FILE" ]; then
    log_error "Dump vide ou erreur lors de l'export. Vérifiez la connexion SSH et les credentials Phase 1."
  fi

  DUMP_SIZE=$(wc -c < "$DUMP_FILE")
  log_success "Export réussi : $DUMP_FILE (${DUMP_SIZE} octets)"

  # ── Étape 2 : Vérification du dump ────────────────────────────────────────
  log_info "[Étape 2/4] Vérification du dump SQL..."
  TABLE_COUNT=$(grep -c "^CREATE TABLE" "$DUMP_FILE" 2>/dev/null || echo "0")
  log_info "Tables trouvées dans le dump : $TABLE_COUNT"
  head -5 "$DUMP_FILE"

  # ── Étape 3 : Préparation de la base RDS cible ────────────────────────────
  log_info "[Étape 3/4] Préparation de la base RDS cible..."

  # Tester la connexion RDS
  mysql -h "$RDS_ENDPOINT" -P 3306 \
    -u "$RDS_USER" \
    -p"$RDS_PASS" \
    -e "SELECT VERSION();" 2>/dev/null && \
    log_success "Connexion RDS : OK" || \
    log_error "Impossible de se connecter à RDS. Vérifiez les Security Groups et l'endpoint."

  # Vider la base cible (si elle contient déjà des données)
  log_warn "Suppression des tables existantes dans RDS (si présentes)..."
  mysql -h "$RDS_ENDPOINT" -P 3306 \
    -u "$RDS_USER" \
    -p"$RDS_PASS" \
    "$DB_NAME" \
    -e "SET FOREIGN_KEY_CHECKS=0; DROP TABLE IF EXISTS students; SET FOREIGN_KEY_CHECKS=1;" 2>/dev/null || true

  # ── Étape 4 : Import vers RDS ─────────────────────────────────────────────
  log_info "[Étape 4/4] Import du dump dans RDS..."
  mysql -h "$RDS_ENDPOINT" -P 3306 \
    -u "$RDS_USER" \
    -p"$RDS_PASS" \
    "$DB_NAME" < "$DUMP_FILE"

  log_success "Import terminé !"

  # ── Vérification post-migration ───────────────────────────────────────────
  log_info "Vérification post-migration..."
  RECORD_COUNT=$(mysql -h "$RDS_ENDPOINT" -P 3306 \
    -u "$RDS_USER" \
    -p"$RDS_PASS" \
    "$DB_NAME" \
    -sN -e "SELECT COUNT(*) FROM students;" 2>/dev/null || echo "0")

  log_success "Nombre d'enregistrements migrés : $RECORD_COUNT"

  # Afficher les 3 premiers enregistrements
  log_info "Aperçu des données migrées :"
  mysql -h "$RDS_ENDPOINT" -P 3306 \
    -u "$RDS_USER" \
    -p"$RDS_PASS" \
    "$DB_NAME" \
    -e "SELECT * FROM students LIMIT 3;" 2>/dev/null || true

  # Nettoyage
  rm -f "$DUMP_FILE"
  log_info "Fichier dump temporaire supprimé."

  log_success "======================================================="
  log_success " SCRIPT-3 : Migration terminée avec succès !"
  log_success " $RECORD_COUNT enregistrements migrés vers RDS"
  log_success "======================================================="
  echo ""
  log_info "Prochaine étape : Testez l'application web via http://<APP_EC2_IP>"
}

# ─────────────────────────────────────────────────────────────────────────────
# SCRIPT BONUS : Vérification complète de l'architecture Phase 2
# ─────────────────────────────────────────────────────────────────────────────

script_verify_architecture() {
  log_info "======================================================="
  log_info " VÉRIFICATION de l'architecture Phase 2"
  log_info "======================================================="

  # VPC
  log_info "VPCs dans la région $AWS_REGION :"
  aws ec2 describe-vpcs \
    --region "$AWS_REGION" \
    --query 'Vpcs[].{ID:VpcId,CIDR:CidrBlock,Tags:Tags[?Key==`Name`].Value|[0]}' \
    --output table

  # Sous-réseaux
  log_info "Sous-réseaux :"
  aws ec2 describe-subnets \
    --region "$AWS_REGION" \
    --query 'Subnets[].{ID:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone,PublicIP:MapPublicIpOnLaunch,Name:Tags[?Key==`Name`].Value|[0]}' \
    --output table

  # Instances EC2
  log_info "Instances EC2 en cours d'exécution :"
  aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].{ID:InstanceId,Type:InstanceType,IP:PublicIpAddress,State:State.Name,Name:Tags[?Key==`Name`].Value|[0]}' \
    --output table

  # RDS
  log_info "Instances RDS :"
  aws rds describe-db-instances \
    --region "$AWS_REGION" \
    --query 'DBInstances[].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Engine:Engine,Endpoint:Endpoint.Address,MultiAZ:MultiAZ}' \
    --output table

  # Secrets Manager
  log_info "Secrets Secrets Manager :"
  aws secretsmanager list-secrets \
    --region "$AWS_REGION" \
    --query 'SecretList[].{Name:Name,LastChanged:LastChangedDate}' \
    --output table

  # Cloud9
  log_info "Environnements Cloud9 :"
  aws cloud9 list-environments --region "$AWS_REGION" --output table 2>/dev/null || \
    log_warn "Cloud9 non disponible ou pas d'environnements."

  log_success "Vérification terminée."
}

# ─────────────────────────────────────────────────────────────────────────────
# EXÉCUTION DIRECTE (si le script est exécuté directement et non sourcé)
# ─────────────────────────────────────────────────────────────────────────────

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "═══════════════════════════════════════════════════════"
  echo "  Cloud9 Scripts – Phase 2"
  echo "  Usage : source cloud9-scripts.sh"
  echo "  Fonctions disponibles :"
  echo "    script_1_create_secret    – Créer/mettre à jour le secret SM"
  echo "    script_3_migrate_data     – Migrer les données Phase 1 → RDS"
  echo "    script_verify_architecture – Vérifier l'architecture complète"
  echo "═══════════════════════════════════════════════════════"
  echo ""
  echo "Configuration requise (modifiez les variables en haut du script) :"
  echo "  RDS_ENDPOINT    = <terraform output rds_endpoint>"
  echo "  PHASE1_EC2_IP   = <IP de votre instance Phase 1>"
  echo "  SSH_KEY_PATH    = <chemin vers votre .pem>"
  echo "  SECRET_NAME     = <terraform output secret_name>"
fi
