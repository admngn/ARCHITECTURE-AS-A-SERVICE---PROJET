#!/bin/bash
###############################################################################
# deploy-eks.sh - Configure kubectl et deploie l'app sur EKS
# Usage : bash deploy-eks.sh
###############################################################################

set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[0;33m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }

CLUSTER_NAME="universite-exemple-eks"
AWS_REGION="us-east-1"
RDS_ENDPOINT="universite-exemple-poc-mysql.czcugausmn9e.us-east-1.rds.amazonaws.com"

echo "================================================="
echo "  Phase 6 - Deploy sur EKS"
echo "================================================="

# 1. Configurer kubectl
info "Configuration de kubectl..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
success "kubectl configure"

# 2. Verifier les noeuds
info "Verification des noeuds EKS..."
kubectl get nodes

# 3. Recuperer le mot de passe DB
info "Recuperation du mot de passe DB..."
DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id "universite-exemple-poc/rds/credentials" \
  --query 'SecretString' --output text | \
  python3 -c "import json,sys; print(json.load(sys.stdin)['password'])")
success "Mot de passe recupere"

# 4. Creer le secret Kubernetes
info "Creation du secret Kubernetes db-secret..."
kubectl create secret generic db-secret \
  --from-literal=host="$RDS_ENDPOINT" \
  --from-literal=user="dbadmin" \
  --from-literal=password="$DB_PASSWORD" \
  --from-literal=dbname="students" \
  --dry-run=client -o yaml | kubectl apply -f -
success "Secret db-secret cree"

# 5. Deployer l'application
info "Deploiement de l'application..."
kubectl apply -f k8s/deployment.yml
success "Deployment applique"

# 6. Attendre que les pods soient prets
info "Attente des pods (max 3 min)..."
kubectl rollout status deployment/students-app --timeout=180s

# 7. Recuperer l'URL du LoadBalancer
info "Recuperation de l'URL du LoadBalancer..."
for i in $(seq 1 20); do
  LB_URL=$(kubectl get svc students-app-service \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
  [ -n "$LB_URL" ] && break
  warn "Attente LoadBalancer ($i/20)..."
  sleep 15
done

echo ""
echo "================================================="
if [ -n "$LB_URL" ]; then
  success "Phase 6 EKS operationnelle !"
  echo ""
  echo "  Cluster  : $CLUSTER_NAME"
  echo "  App URL  : http://$LB_URL"
  echo "  Students : http://$LB_URL/students"
  echo ""
  echo "  Commandes utiles :"
  echo "  kubectl get pods"
  echo "  kubectl get svc"
  echo "  kubectl get hpa"
  echo "  kubectl logs -l app=students-app -f"
else
  warn "LoadBalancer en cours de provisioning"
  echo "  Verifiez dans 2 min : kubectl get svc students-app-service"
fi
echo "================================================="
