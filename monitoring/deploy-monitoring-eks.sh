#!/bin/bash
###############################################################################
# deploy-monitoring-eks.sh
# Déploie kube-prometheus-stack sur le cluster EKS via Helm
# Usage : bash monitoring/deploy-monitoring-eks.sh
###############################################################################

set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[0;33m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }

echo "================================================="
echo "  Phase 7 - Monitoring (kube-prometheus-stack)"
echo "================================================="

# 1. Vérifier kubectl
info "Vérification de la connexion au cluster..."
kubectl get nodes || { echo "Erreur: kubectl non connecté. Lance d'abord deploy-eks.sh"; exit 1; }

# 2. Vérifier Helm
info "Vérification de Helm..."
helm version || { echo "Erreur: Helm non installé. https://helm.sh/docs/intro/install/"; exit 1; }

# 3. Ajouter le repo Helm prometheus-community
info "Ajout du repo Helm prometheus-community..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
success "Repo Helm à jour"

# 4. Créer le namespace monitoring
kubectl create namespace monitoring 2>/dev/null || warn "Namespace monitoring déjà existant"

# 5. Installer kube-prometheus-stack
info "Installation de kube-prometheus-stack (~3-5 min)..."
helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=admin \
  --set grafana.service.type=LoadBalancer \
  --set prometheus.prometheusSpec.retention=15d \
  --set alertmanager.service.type=ClusterIP \
  --wait --timeout 10m

success "kube-prometheus-stack installé"

# 6. Récupérer l'URL Grafana
info "Récupération de l'URL Grafana..."
for i in $(seq 1 20); do
  GRAFANA_URL=$(kubectl get svc kube-prometheus-stack-grafana \
    --namespace monitoring \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
  [ -n "$GRAFANA_URL" ] && break
  warn "Attente LoadBalancer Grafana ($i/20)..."
  sleep 15
done

echo ""
echo "================================================="
success "Monitoring déployé !"
echo ""
echo "  Grafana:"
if [ -n "${GRAFANA_URL:-}" ]; then
  echo "    URL      : http://$GRAFANA_URL"
else
  echo "    URL      : kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80"
  echo "               puis http://localhost:3000"
fi
echo "    Login    : admin / admin"
echo ""
echo "  Prometheus:"
echo "    kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090"
echo "    puis http://localhost:9090"
echo ""
echo "  Alertmanager:"
echo "    kubectl port-forward svc/kube-prometheus-stack-alertmanager -n monitoring 9093:9093"
echo "    puis http://localhost:9093"
echo ""
echo "  Commandes utiles :"
echo "    kubectl get pods -n monitoring"
echo "    kubectl get svc -n monitoring"
echo "    helm list -n monitoring"
echo "================================================="
