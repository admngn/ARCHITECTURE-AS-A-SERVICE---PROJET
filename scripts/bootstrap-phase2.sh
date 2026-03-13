#!/bin/bash
###############################################################################
# bootstrap-phase2.sh
# A executer dans Cloud9 APRES terraform apply (sur le poste local)
# Ne necessite PAS Terraform dans Cloud9 - utilise AWS CLI uniquement
#
# Usage : bash bootstrap-phase2.sh
###############################################################################

set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

AWS_REGION="us-east-1"
DB_USER="dbadmin"
DB_NAME="students"
RDS_ENDPOINT=$(aws rds describe-db-instances   --db-instance-identifier universite-exemple-poc-mysql   --query 'DBInstances[0].Endpoint.Address'   --output text --region "$AWS_REGION" 2>/dev/null || echo "")
[ -z "$RDS_ENDPOINT" ] || [ "$RDS_ENDPOINT" = "None" ] &&   error "RDS non trouvee - verifiez que terraform apply s'est bien termine"
PROJECT_TAG="universite-exemple-poc-app-server"

echo "================================================="
echo "  Phase 2 - Bootstrap (Cloud9, sans Terraform)"
echo "================================================="

# 1. Mot de passe
info "Recuperation du mot de passe depuis Secrets Manager..."
DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id "universite-exemple-poc/rds/credentials" \
  --query 'SecretString' --output text --region "$AWS_REGION" | \
  python3 -c "import json,sys; print(json.load(sys.stdin)['password'])") \
  || error "Secrets Manager inaccessible - verifiez vos credentials AWS"
success "Mot de passe recupere : ${DB_PASSWORD:0:4}..."

# 2. IP EC2
info "Recherche de l'instance EC2..."
APP_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$PROJECT_TAG" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text --region "$AWS_REGION")
[ -z "$APP_IP" ] || [ "$APP_IP" = "None" ] && \
  error "Instance EC2 non trouvee - lancez terraform apply d'abord"
success "EC2 IP : $APP_IP"

# 3. Cle SSH
info "Recherche de la cle SSH..."
SSH_KEY=$(ls ~/environment/*.pem 2>/dev/null | head -1) \
  || error "Uploadez labsuser.pem (ou labsuser1.pem) dans ~/environment/ via File > Upload Local Files"
chmod 400 "$SSH_KEY"
success "Cle SSH : $SSH_KEY"

# 4. SG RDS
info "Ouverture du Security Group RDS..."
RDS_SG=$(aws rds describe-db-instances \
  --db-instance-identifier universite-exemple-poc-mysql \
  --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
  --output text --region "$AWS_REGION")
aws ec2 authorize-security-group-ingress \
  --group-id "$RDS_SG" --protocol tcp --port 3306 --cidr 10.0.0.0/16 \
  --region "$AWS_REGION" 2>/dev/null && success "Regle SG ajoutee" || warn "Regle deja existante"

# 5. Secret Mydbsecret
info "Configuration du secret Mydbsecret..."
SM_VALUE="{\"user\":\"$DB_USER\",\"password\":\"$DB_PASSWORD\",\"host\":\"$RDS_ENDPOINT\",\"db\":\"$DB_NAME\"}"
aws secretsmanager create-secret --name "Mydbsecret" \
  --secret-string "$SM_VALUE" --region "$AWS_REGION" 2>/dev/null \
  && success "Secret Mydbsecret cree" \
  || { aws secretsmanager put-secret-value --secret-id "Mydbsecret" \
       --secret-string "$SM_VALUE" --region "$AWS_REGION" \
       && success "Secret Mydbsecret mis a jour"; }

# 6. Table RDS - avec retry et diagnostic clair
info "Initialisation de la base de donnees..."

set +e
MYSQL_OK=0
for i in $(seq 1 5); do
  mysql -h "$RDS_ENDPOINT" -u "$DB_USER" -p"$DB_PASSWORD"     -e "SELECT 1;" "$DB_NAME" > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    MYSQL_OK=1
    break
  fi
  warn "RDS inaccessible ($i/5) - nouvelle tentative SG + attente 15s..."
  aws ec2 authorize-security-group-ingress     --group-id "$RDS_SG" --protocol tcp --port 3306 --cidr 10.0.0.0/16     --region "$AWS_REGION" > /dev/null 2>&1
  sleep 15
done
set -e

if [ "$MYSQL_OK" -eq 0 ]; then
  echo ""
  echo "  DIAGNOSTIC :"
  echo "  1. Test connectivite :"
  echo "     bash -c 'echo >/dev/tcp/$RDS_ENDPOINT/3306' && echo PORT_OUVERT || echo PORT_FERME"
  echo "  2. SG RDS : $RDS_SG"
  echo "  3. Statut RDS :"
  echo "     aws rds describe-db-instances --db-instance-identifier universite-exemple-poc-mysql --query 'DBInstances[0].DBInstanceStatus'"
  error "Impossible de se connecter a RDS apres 5 tentatives"
fi

mysql -h "$RDS_ENDPOINT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
  -e "CREATE TABLE IF NOT EXISTS students (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100), address VARCHAR(200), city VARCHAR(100), state VARCHAR(50), email VARCHAR(100), phone VARCHAR(20));"

mysql -h "$RDS_ENDPOINT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
  -e "INSERT IGNORE INTO students (id,name,address,city,state,email,phone) VALUES (1,'Alice Martin','12 rue de Paris','Paris','IDF','alice@exemple.fr','0601020304'),(2,'Bob Dupont','5 avenue Victor Hugo','Lyon','ARA','bob@exemple.fr','0611223344'),(3,'Clara Durand','8 bd Gambetta','Bordeaux','NAQ','clara@exemple.fr','0622334455');"

COUNT=$(mysql -h "$RDS_ENDPOINT" -u "$DB_USER" -p"$DB_PASSWORD" \
  -sN -e "SELECT COUNT(*) FROM ${DB_NAME}.students;")
success "Table students : $COUNT enregistrements"

# 7. Service Node.js sur EC2
info "Configuration du service Node.js sur l'EC2..."
for i in $(seq 1 10); do
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
    ubuntu@"$APP_IP" "echo ok" &>/dev/null && break
  warn "SSH indisponible - attente 15s ($i/10)..."
  sleep 15
done

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$APP_IP" \
  "DB_PASSWORD='$DB_PASSWORD' RDS='$RDS_ENDPOINT' DBU='$DB_USER' DBN='$DB_NAME' bash -s" << 'ENDSSH'
sudo chmod -R 755 /home/ubuntu/resources/ 2>/dev/null || true
sudo fuser -k 80/tcp 2>/dev/null || true
sleep 2
sudo bash -c "cat > /etc/systemd/system/students-app.service << EOF
[Unit]
Description=Students App - XYZ University
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/home/ubuntu/resources/codebase_partner
Environment=APP_DB_HOST=${RDS}
Environment=APP_DB_USER=${DBU}
Environment=APP_DB_PASSWORD=${DB_PASSWORD}
Environment=APP_DB_NAME=${DBN}
Environment=APP_PORT=80
ExecStart=/usr/bin/node index.js
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
[Install]
WantedBy=multi-user.target
EOF"
sudo systemctl daemon-reload
sudo systemctl enable students-app
sudo systemctl restart students-app
sleep 3
sudo systemctl is-active students-app
ENDSSH
success "Service Node.js configure et demarre"

# 8. Verification finale
sleep 3
HTTP=$(curl -s -o /dev/null -w "%{http_code}" "http://$APP_IP" 2>/dev/null || echo "000")
echo ""
echo "================================================="
[ "$HTTP" = "200" ] \
  && { success "Phase 2 operationnelle !"; echo ""; \
       echo "  Application : http://$APP_IP"; \
       echo "  Students    : http://$APP_IP/students"; } \
  || warn "HTTP $HTTP - attendez 30s et testez : curl http://$APP_IP"
echo "================================================="
