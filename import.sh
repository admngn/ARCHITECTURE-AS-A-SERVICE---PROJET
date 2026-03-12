#!/bin/bash
###############################################################################
# import.sh - Importe dans le state Terraform toutes les ressources AWS
# deja existantes suite aux apply partiels precedents.
# Usage : bash import.sh
###############################################################################

set -euo pipefail

ok()   { echo "[OK]   $1"; }
skip() { echo "[SKIP] $1 (deja dans le state ou absent)"; }
run()  {
  local label="$1"; shift
  terraform import "$@" && ok "$label" || skip "$label"
}

echo "================================================="
echo " Import des ressources existantes dans le state"
echo "================================================="

# ── Secrets Manager ───────────────────────────────────────────────────────────
run "Secret RDS credentials" \
  module.secrets.aws_secretsmanager_secret.db_credentials \
  "universite-exemple-poc/rds/credentials"

# ── RDS ───────────────────────────────────────────────────────────────────────
run "DB Subnet Group" \
  module.rds.aws_db_subnet_group.main \
  "universite-exemple-poc-db-subnet-group"

run "DB Parameter Group" \
  module.rds.aws_db_parameter_group.mysql \
  "universite-exemple-poc-mysql-params"

run "DB Option Group" \
  module.rds.aws_db_option_group.mysql \
  "universite-exemple-poc-mysql-options"

# ── Cloud9 ────────────────────────────────────────────────────────────────────
# Recupere l'ID de l'environnement Cloud9 existant par son nom
echo ""
echo "--> Recherche de l'environnement Cloud9 existant..."
CLOUD9_ID=$(aws cloud9 list-environments --output text --query 'environmentIds[]' 2>/dev/null | \
  xargs -r -n1 aws cloud9 describe-environments --environment-ids 2>/dev/null | \
  python3 -c "
import sys, json
data = json.load(sys.stdin)
for env in data.get('environments', []):
    if env.get('name') == 'universite-exemple-poc-cloud9':
        print(env['id'])
        break
" 2>/dev/null || echo "")

if [ -n "$CLOUD9_ID" ]; then
  run "Cloud9 environment" \
    module.cloud9.aws_cloud9_environment_ec2.main \
    "$CLOUD9_ID"
else
  echo "[WARN] Cloud9 environment non trouve - sera cree par apply"
fi

echo ""
echo "================================================="
echo " Imports termines. Lancez maintenant :"
echo "   terraform apply"
echo "================================================="
