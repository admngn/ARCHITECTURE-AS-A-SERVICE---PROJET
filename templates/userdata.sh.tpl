#!/bin/bash
###############################################################################
# UserData – Phase 2 : Serveur Applicatif Node.js (Ubuntu)
# Ce script bootstrap l'instance EC2 :
#   1. Met à jour le système
#   2. Configure les variables d'environnement pour l'application
#   3. Télécharge et exécute le script fourni par l'atelier
#   4. Configure l'application pour utiliser Secrets Manager
###############################################################################

set -euo pipefail
exec > >(tee /var/log/userdata-phase2.log | logger -t userdata -s 2>/dev/console) 2>&1

echo "======================================================="
echo " Université Exemple – Phase 2 – Démarrage UserData"
echo " $(date)"
echo "======================================================="

# ── Variables d'environnement (injectées par Terraform) ──────────────────────
export DB_HOST="${db_host}"
export DB_NAME="${db_name}"
export DB_PORT="${db_port}"
export SECRET_NAME="${secret_name}"
export AWS_DEFAULT_REGION="${aws_region}"
export APP_PORT="${app_port}"
export APP_DIR="/var/www/students-app"

echo "[INFO] Configuration :"
echo "  DB_HOST     = $DB_HOST"
echo "  DB_NAME     = $DB_NAME"
echo "  DB_PORT     = $DB_PORT"
echo "  SECRET_NAME = $SECRET_NAME"
echo "  APP_PORT    = $APP_PORT"
echo "  AWS_REGION  = $AWS_DEFAULT_REGION"

# ── 1. Mise à jour du système ─────────────────────────────────────────────────
echo "[STEP 1] Mise à jour du système..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# ── 2. Installation des dépendances système ───────────────────────────────────
echo "[STEP 2] Installation des dépendances..."
apt-get install -y \
  curl \
  wget \
  git \
  unzip \
  jq \
  mysql-client \
  awscli \
  ca-certificates \
  gnupg

# ── 3. Installation de Node.js 18.x LTS ──────────────────────────────────────
echo "[STEP 3] Installation de Node.js 18.x..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs
node --version
npm --version

# ── 4. Récupération des identifiants DB depuis Secrets Manager ────────────────
echo "[STEP 4] Récupération du secret depuis Secrets Manager..."
SECRET_VALUE=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_NAME" \
  --region "$AWS_DEFAULT_REGION" \
  --query 'SecretString' \
  --output text)

DB_USERNAME=$(echo "$SECRET_VALUE" | jq -r '.username')
DB_PASSWORD=$(echo "$SECRET_VALUE" | jq -r '.password')

echo "[INFO] Secret récupéré – utilisateur : $DB_USERNAME"

# ── 5. Création du fichier d'environnement application ───────────────────────
echo "[STEP 5] Création du fichier .env application..."
mkdir -p "$APP_DIR"
cat > "$APP_DIR/.env" << EOF
# Configuration générée automatiquement par Terraform – NE PAS MODIFIER MANUELLEMENT
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_NAME=$DB_NAME
DB_USER=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
SECRET_ARN=$SECRET_NAME
AWS_REGION=$AWS_DEFAULT_REGION
PORT=$APP_PORT
NODE_ENV=production
EOF
chmod 600 "$APP_DIR/.env"

# ── 6. Téléchargement et exécution du script de l'atelier ────────────────────
echo "[STEP 6] Téléchargement du script UserData de l'atelier..."
ATELIER_SCRIPT="/tmp/userdata-atelier.sh"

curl -fsSL "${userdata_script_url}" -o "$ATELIER_SCRIPT" || {
  echo "[WARN] Impossible de télécharger le script de l'atelier. Vérifiez l'URL."
  echo "[WARN] URL : ${userdata_script_url}"
}

if [ -f "$ATELIER_SCRIPT" ] && [ -s "$ATELIER_SCRIPT" ]; then
  echo "[INFO] Exécution du script de l'atelier..."
  chmod +x "$ATELIER_SCRIPT"
  bash "$ATELIER_SCRIPT"
else
  echo "[WARN] Script atelier vide ou absent – installation manuelle requise."
fi

# ── 7. Configuration du service systemd pour Node.js ─────────────────────────
echo "[STEP 7] Configuration du service systemd..."

# Détection du point d'entrée de l'application
APP_ENTRY=""
for candidate in "app.js" "server.js" "index.js" "src/app.js" "src/server.js"; do
  if [ -f "$APP_DIR/$candidate" ]; then
    APP_ENTRY="$candidate"
    break
  fi
done

if [ -z "$APP_ENTRY" ]; then
  echo "[WARN] Point d'entrée app non trouvé. Le service systemd sera créé sans le démarrer."
  APP_ENTRY="app.js"
fi

cat > /etc/systemd/system/students-app.service << EOF
[Unit]
Description=Université Exemple – Application Dossiers Étudiants (Node.js)
Documentation=https://github.com/universite-exemple/students-app
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=www-data
WorkingDirectory=$APP_DIR
EnvironmentFile=$APP_DIR/.env
ExecStart=/usr/bin/node $APP_ENTRY
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=students-app

# Limites de ressources
LimitNOFILE=65536
MemoryMax=512M

[Install]
WantedBy=multi-user.target
EOF

# ── 8. Démarrage du service ───────────────────────────────────────────────────
echo "[STEP 8] Activation et démarrage du service..."
systemctl daemon-reload
systemctl enable students-app

# Installation des dépendances npm si package.json présent
if [ -f "$APP_DIR/package.json" ]; then
  echo "[INFO] Installation des dépendances npm..."
  cd "$APP_DIR"
  npm install --production
  systemctl start students-app
  echo "[INFO] Service students-app démarré."
else
  echo "[WARN] Pas de package.json trouvé dans $APP_DIR"
  echo "[WARN] Démarrez le service manuellement après installation de l'application."
fi

# ── 9. Vérification finale ────────────────────────────────────────────────────
echo "[STEP 9] Vérification..."
sleep 5

if systemctl is-active --quiet students-app; then
  echo "[OK] Service students-app : ACTIF"
else
  echo "[WARN] Service students-app : INACTIF (vérifiez journalctl -u students-app)"
fi

# Test de connectivité RDS
if [ -n "$DB_HOST" ]; then
  if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" \
     -e "SELECT 1;" "$DB_NAME" 2>/dev/null; then
    echo "[OK] Connexion RDS : SUCCÈS"
  else
    echo "[WARN] Connexion RDS : ÉCHEC (normale si RDS pas encore prêt)"
  fi
fi

echo "======================================================="
echo " UserData Phase 2 terminé – $(date)"
echo " Logs : /var/log/userdata-phase2.log"
echo " Service : journalctl -u students-app -f"
echo "======================================================="
