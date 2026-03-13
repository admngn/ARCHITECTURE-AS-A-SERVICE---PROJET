# Phase 7 — Monitoring avec Prometheus, Grafana & Alertmanager

## Objectif

Mettre en place une stack de monitoring pour superviser l'application students-app, localement via Docker Compose et sur le cluster EKS via Helm.

---

## Architecture

### Test local (Docker Compose)

```
┌──────────────────────────────────────────────────────────┐
│                   Docker Compose                         │
│                                                          │
│  ┌─────────────┐    scrape     ┌──────────────────────┐  │
│  │  Prometheus  │◀────────────▶│  Blackbox Exporter   │  │
│  │  :9090       │              │  :9115               │  │
│  └──────┬───────┘              └──────────┬───────────┘  │
│         │                                 │ HTTP probe   │
│         │ datasource                      ▼              │
│         ▼                        ┌────────────────┐      │
│  ┌─────────────┐                 │  students-app  │      │
│  │   Grafana    │                │  :80           │      │
│  │   :3000      │                └────────────────┘      │
│  └─────────────┘                                         │
│         │                                                │
│  ┌──────▼──────┐                                         │
│  │ Alertmanager │                                        │
│  │ :9093        │                                        │
│  └─────────────┘                                         │
└──────────────────────────────────────────────────────────┘
```

### Cluster EKS (Helm kube-prometheus-stack)

```
┌──────────────────────────────────────────────────────────────┐
│                    Namespace: monitoring                      │
│                                                              │
│  ┌──────────────┐  ┌───────────────┐  ┌──────────────────┐  │
│  │  Prometheus   │  │ Alertmanager  │  │  node-exporter   │  │
│  │  (collecte)   │  │ (alertes)     │  │  (métriques OS)  │  │
│  └──────┬────────┘  └───────────────┘  └──────────────────┘  │
│         │                                                    │
│         │ datasource          ┌───────────────────────────┐  │
│         ▼                     │  kube-state-metrics        │  │
│  ┌──────────────┐             │  (métriques pods/deploy)   │  │
│  │   Grafana     │             └───────────────────────────┘  │
│  │   (LB :80)    │                                            │
│  └──────────────┘                                            │
└──────────────────────────────────────────────────────────────┘
         │
         │ scrape
         ▼
┌──────────────────┐
│  Namespace:       │
│  default          │
│  students-app     │
│  (pods :3000)     │
└──────────────────┘
```

---

## Structure des fichiers

```
monitoring/
├── README.md
├── docker-compose.monitoring.yml        # Stack locale (4 containers)
├── deploy-monitoring-eks.sh             # Script Helm pour EKS
│
├── prometheus/
│   ├── prometheus.yml                   # Config scrape (app + blackbox)
│   └── alerts.yml                       # Règles d'alertes
│
├── alertmanager/
│   └── alertmanager.yml                 # Routing des alertes
│
└── grafana/
    ├── provisioning/
    │   ├── datasources/datasource.yml   # Prometheus comme source auto
    │   └── dashboards/dashboards.yml    # Auto-import des dashboards
    └── dashboards/
        └── students-app.json            # Dashboard students-app
```

---

## Composants

| Service | Image | Port | Rôle |
|---|---|---|---|
| Prometheus | `prom/prometheus` | 9090 | Collecte et stocke les métriques |
| Grafana | `grafana/grafana` | 3000 | Visualisation et dashboards |
| Alertmanager | `prom/alertmanager` | 9093 | Gestion et routage des alertes |
| Blackbox Exporter | `prom/blackbox-exporter` | 9115 | Probe HTTP sur l'app |

---

## Alertes configurées

| Alerte | Condition | Sévérité |
|---|---|---|
| **AppDown** | L'app ne répond plus depuis 1 min | Critical |
| **HighLatency** | Temps de réponse > 2s depuis 2 min | Warning |
| **PrometheusHighMemory** | Prometheus utilise > 1Go RAM | Warning |

---

## Déploiement local (Docker Compose)

### Prérequis

- Docker et Docker Compose installés

### Lancer la stack

```bash
cd monitoring
docker-compose -f docker-compose.monitoring.yml up -d
```

### Accéder aux interfaces

| Service | URL | Credentials |
|---|---|---|
| Prometheus | http://localhost:9090 | — |
| Grafana | http://localhost:3000 | admin / admin |
| Alertmanager | http://localhost:9093 | — |

### Arrêter

```bash
docker-compose -f docker-compose.monitoring.yml down
```

### Arrêter et supprimer les données

```bash
docker-compose -f docker-compose.monitoring.yml down -v
```

---

## Déploiement sur EKS (Helm)

### Prérequis

- Cluster EKS actif (`kubectl get nodes`)
- [Helm](https://helm.sh/docs/intro/install/) installé

### Lancer le déploiement

```bash
bash monitoring/deploy-monitoring-eks.sh
```

Ce script :
1. Ajoute le repo Helm `prometheus-community`
2. Crée le namespace `monitoring`
3. Installe `kube-prometheus-stack` avec Grafana exposé via LoadBalancer
4. Affiche les URLs d'accès

### Accéder aux services sur EKS

```bash
# Grafana (si LoadBalancer actif)
kubectl get svc kube-prometheus-stack-grafana -n monitoring

# Ou via port-forward
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
# → http://localhost:3000 (admin / admin)

# Prometheus
kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090
# → http://localhost:9090

# Alertmanager
kubectl port-forward svc/kube-prometheus-stack-alertmanager -n monitoring 9093:9093
# → http://localhost:9093
```

### Commandes utiles

```bash
kubectl get pods -n monitoring
kubectl get svc -n monitoring
helm list -n monitoring
helm uninstall kube-prometheus-stack -n monitoring    # Désinstaller
```

---

## Push des images sur ECR (optionnel)

Si besoin de stocker les images dans un registry privé :

```bash
# Login ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account_id>.dkr.ecr.us-east-1.amazonaws.com

# Pour chaque image
for img in prom/prometheus grafana/grafana prom/alertmanager prom/blackbox-exporter; do
  name=$(echo $img | tr '/' '-')
  aws ecr create-repository --repository-name $name 2>/dev/null || true
  docker pull $img
  docker tag $img <account_id>.dkr.ecr.us-east-1.amazonaws.com/$name:latest
  docker push <account_id>.dkr.ecr.us-east-1.amazonaws.com/$name:latest
done
```
