#!/bin/bash
###############################################################################
# loadtest-phase3.sh – Test de charge (Script-2 equivalent)
# A executer dans Cloud9 apres le deploiement Phase 3
#
# Usage : bash loadtest-phase3.sh <ALB_URL>
# Exemple : bash loadtest-phase3.sh http://universite-exemple-poc-alb-123456.us-east-1.elb.amazonaws.com
###############################################################################

set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[0;33m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }

ALB_URL="${1:-}"
ASG_NAME="universite-exemple-poc-asg"

if [ -z "$ALB_URL" ]; then
  echo "Usage: bash loadtest-phase3.sh <ALB_URL>"
  echo "Exemple: bash loadtest-phase3.sh http://universite-exemple-poc-alb-123456789.us-east-1.elb.amazonaws.com"
  exit 1
fi

echo "================================================="
echo "  Phase 3 – Test de charge + surveillance ASG"
echo "  URL : $ALB_URL"
echo "================================================="

# ── 1. Verifier que l'ALB repond ──────────────────────────────────────────────
info "Verification de l'ALB..."
HTTP=$(curl -s -o /dev/null -w "%{http_code}" "$ALB_URL" 2>/dev/null || echo "000")
[ "$HTTP" = "200" ] && success "ALB repond HTTP 200" || { warn "HTTP $HTTP - attendez que les instances soient healthy"; exit 1; }

# ── 2. Etat initial de l'ASG ──────────────────────────────────────────────────
info "Etat initial de l'ASG..."
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query 'AutoScalingGroups[0].{Min:MinSize,Max:MaxSize,Desired:DesiredCapacity,Instances:length(Instances)}' \
  --output table 2>/dev/null || warn "ASG non trouve - verifiez le nom"

# ── 3. Installation de loadtest ────────────────────────────────────────────────
info "Installation de loadtest (https://github.com/alexfernandez/loadtest)..."
if ! command -v loadtest &>/dev/null; then
  npm install -g loadtest
fi
success "loadtest $(loadtest --version 2>/dev/null || echo 'installe')"

# ── 4. Test leger – validation ────────────────────────────────────────────────
info "Test leger (validation)..."
loadtest \
  --concurrency 5 \
  --rps 20 \
  --maxRequests 100 \
  "$ALB_URL/students"
success "Test leger termine"

# ── 5. Test de charge moyen ───────────────────────────────────────────────────
info "Test de charge moyen (60s, 10 clients simultanes, 100 rps)..."
info "Surveillez le CPU dans CloudWatch > universite-exemple-poc-cpu-high"
loadtest \
  --concurrency 10 \
  --rps 100 \
  --maxSeconds 60 \
  "$ALB_URL/students" &
LOAD_PID=$!

# Surveiller l'ASG pendant le test
echo ""
info "Surveillance ASG en temps reel (toutes les 15s)..."
for i in 1 2 3 4; do
  sleep 15
  echo -n "  [$(date +%H:%M:%S)] Instances ASG : "
  aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --query 'AutoScalingGroups[0].{Desired:DesiredCapacity,Instances:length(Instances)}' \
    --output text 2>/dev/null || echo "N/A"
done

wait $LOAD_PID || true
success "Test de charge termine"

# ── 6. Test intensif – declenche le scale-out ─────────────────────────────────
echo ""
warn "Test intensif (120s, 50 clients, 500 rps) – doit declencher le scale-out..."
warn "CPU doit depasser 60% pour declencher l'alarme CloudWatch"
loadtest \
  --concurrency 50 \
  --rps 500 \
  --maxSeconds 120 \
  "$ALB_URL/students" &
LOAD_PID=$!

info "Surveillance scale-out..."
for i in $(seq 1 8); do
  sleep 15
  echo -n "  [$(date +%H:%M:%S)] Instances : "
  aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --query 'AutoScalingGroups[0].DesiredCapacity' \
    --output text 2>/dev/null || echo "N/A"
done

wait $LOAD_PID || true

# ── 7. Etat final ─────────────────────────────────────────────────────────────
echo ""
echo "================================================="
info "Etat final de l'ASG apres le test :"
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query 'AutoScalingGroups[0].{Min:MinSize,Max:MaxSize,Desired:DesiredCapacity,Instances:length(Instances)}' \
  --output table 2>/dev/null

info "Alarmes CloudWatch actives :"
aws cloudwatch describe-alarms \
  --alarm-name-prefix "universite-exemple-poc-cpu" \
  --query 'MetricAlarms[*].{Alarm:AlarmName,State:StateValue,Threshold:Threshold}' \
  --output table 2>/dev/null

echo ""
success "Test de charge termine !"
echo "  Dashboard CloudWatch :"
echo "  https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#alarmsV2:"
echo "================================================="
