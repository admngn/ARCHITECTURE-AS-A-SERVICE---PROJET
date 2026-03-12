#!/bin/bash
###############################################################################
# deploy-eks.sh - Deploiement complet sur EKS
# Usage : bash scripts/deploy-eks.sh
###############################################################################

set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

AWS_REGION="us-east-1"
CLUSTER_NAME="universite-exemple-poc-eks"
RDS_ENDPOINT="universite-exemple-poc-mysql.czcugausmn9e.us-east-1.rds.amazonaws.com"
DOCKERHUB_IMAGE="zolda/students-app:latest"

echo "================================================="
echo "  Phase 6 - Deploy EKS"
echo "================================================="

# 1. Kubeconfig
info "Configuration kubectl..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
success "kubectl configure"

# 2. Verifier la connexion
info "Verification du cluster..."
kubectl get nodes || error "Impossible de contacter le cluster EKS"

# 3. Mot de passe RDS
info "Recuperation du mot de passe RDS..."
DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id "universite-exemple-poc/rds/credentials" \
  --query 'SecretString' --output text --region "$AWS_REGION" | \
  python3 -c "import json,sys; print(json.load(sys.stdin)['password'])")
success "Mot de passe : ${DB_PASSWORD:0:4}..."

# 4. Namespace
kubectl create namespace students 2>/dev/null || warn "Namespace deja existant"

# 5. Secret DB
info "Creation du secret db-credentials..."
kubectl create secret generic db-credentials \
  --namespace students \
  --from-literal=host="$RDS_ENDPOINT" \
  --from-literal=username="dbadmin" \
  --from-literal=password="$DB_PASSWORD" \
  --from-literal=dbname="students" \
  --dry-run=client -o yaml | kubectl apply -f -
success "Secret db-credentials OK"

# 6. Deployment + Service + HPA
info "Deploiement des manifests Kubernetes..."
kubectl apply -f manifests/app/deployment.yml
kubectl apply -f manifests/app/service.yml
success "Manifests appliques"

# 7. Attendre les pods
info "Attente des pods (timeout 3min)..."
kubectl rollout status deployment/students-app --namespace students --timeout=180s
success "Pods prets"

# 8. URL du LoadBalancer
info "Recuperation de l'URL..."
for i in $(seq 1 20); do
  LB_URL=$(kubectl get svc students-app-svc --namespace students \
    --output jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
  [ -n "$LB_URL" ] && break
  warn "LoadBalancer en creation ($i/20)..."
  sleep 15
done

echo ""
echo "================================================="
[ -n "$LB_URL" ] \
  && { success "Phase 6 EKS operationnelle !"; echo ""; \
       echo "  Application : http://$LB_URL"; \
       echo "  Students    : http://$LB_URL/students"; } \
  || warn "LB pas encore pret : kubectl get svc students-app-svc -n students"
echo "================================================="
echo ""
echo "Commandes utiles :"
echo "  kubectl get pods -n students"
echo "  kubectl get svc  -n students"
echo "  kubectl get hpa  -n students"
echo "  kubectl logs -n students -l app=students-app -f"
