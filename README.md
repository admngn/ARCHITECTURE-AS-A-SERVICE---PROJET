# Phase 6 – EKS (Kubernetes sur AWS)

## Architecture

```
Internet
    │
    ▼
NLB (provisione par K8s)
    │
    ▼
EKS Cluster (universite-exemple-eks)
    ├── Node 1 (t3.medium)
    │     └── Pod students-app
    │     └── Pod students-app
    └── Node 2 (t3.medium)
          └── Pod students-app (si HPA scale)
                    │
                    ▼
              RDS MySQL (privé, Phase 2/3)
```

## Deploiement

### Etape 1 - Creer le cluster EKS (~15 min)
```bash
terraform init && terraform apply -auto-approve
```

### Etape 2 - Deployer l'application
```bash
bash deploy-eks.sh
```

### Etape 3 - Verifier
```bash
kubectl get nodes
kubectl get pods
kubectl get svc
curl http://<LB_URL>/students
```

## Commandes kubectl utiles

```bash
# Voir les pods
kubectl get pods -o wide

# Logs en temps reel
kubectl logs -l app=students-app -f

# Scaler manuellement
kubectl scale deployment students-app --replicas=4

# Voir le HPA (auto-scaling)
kubectl get hpa

# Redeploy apres nouveau push Docker
kubectl rollout restart deployment/students-app

# Voir les evenements
kubectl get events --sort-by=.metadata.creationTimestamp
```

## Mise a jour de l'image

```bash
# Apres docker push zolda/students-app:latest
kubectl rollout restart deployment/students-app
kubectl rollout status deployment/students-app
```

## Limitations AWS Academy

- `iam:CreateRole` interdit -> LabRole utilise pour cluster ET node group
- Pas d'OIDC provider -> pas d'IRSA (IAM Roles for Service Accounts)
- Secrets Manager accessible uniquement depuis l'EC2/node via LabRole
