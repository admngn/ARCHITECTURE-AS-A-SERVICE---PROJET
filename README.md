# Phase 3 – Déploiement scalable et hautement disponible

## Objectif

Au cours de cette phase, l’objectif est de finaliser l’architecture afin de rendre l’application web :

- **accessible via un Load Balancer**
- **scalable automatiquement**
- **hautement disponible**
- **testable avec un script de charge**

Cette phase s’appuie sur les composants créés précédemment et ajoute les éléments nécessaires pour supporter plusieurs instances EC2 derrière un équilibreur de charge.

---

## Architecture attendue

L’infrastructure repose sur les composants suivants :

- **Application Load Balancer**
- **Launch Template**
- **Auto Scaling Group**
- **Instances EC2** hébergeant l’application web
- **Security Groups**
- **Subnets publics dans plusieurs AZ**

### Schéma simplifié

```text
                Internet
                    |
                    v
         +------------------------+
         | Application Load       |
         | Balancer (ALB)         |
         +------------------------+
              |              |
              |              |
              v              v
      +---------------+  +---------------+
      | EC2 Instance 1|  | EC2 Instance 2|
      | Web App       |  | Web App       |
      +---------------+  +---------------+
              \              /
               \            /
                \          /
                 v        v
            Auto Scaling Group
Étapes de déploiement
1. Initialiser Terraform
terraform init
2. Vérifier la configuration
terraform validate
3. Voir les ressources qui vont être créées
terraform plan
4. Lancer le déploiement
terraform apply

Confirmer avec :

yes
Vérification du déploiement

Une fois le déploiement terminé, récupérer l’endpoint exposé par Terraform :

terraform output

Le résultat attendu est l’adresse DNS du Load Balancer, à ouvrir dans un navigateur pour accéder à l’application.

Exemple :

http://<dns_du_load_balancer>
Tests fonctionnels

Après le déploiement, il faut vérifier que l’application fonctionne correctement en effectuant quelques actions, par exemple :

consulter les fiches étudiants

ajouter un étudiant

modifier un étudiant

supprimer un étudiant

## Test de charge

Pour tester la montée en charge de l’application, il faut exécuter le script `loadtest-phase3.sh` en lui passant en argument l’URL du Load Balancer. Le script attend bien un argument `<ALB_URL>` au format `http://...` et s’arrête avec un message d’usage si rien n’est fourni. :contentReference[oaicite:0]{index=0}

### Commande à exécuter

```bash
bash loadtest-phase3.sh http://<dns_du_load_balancer>
Exemple
bash loadtest-phase3.sh http://universite-exemple-poc-alb-123456789.us-east-1.elb.amazonaws.com
Ce que fait le script

Le script réalise automatiquement plusieurs vérifications et tests :

il vérifie d’abord que le Load Balancer répond bien en HTTP 200 avant de continuer

il affiche l’état initial du groupe Auto Scaling universite-exemple-poc-asg

il installe l’outil loadtest si celui-ci n’est pas déjà présent sur la machine

il exécute un test léger de validation sur l’endpoint /students pour vérifier que l’application répond correctement

il lance ensuite un test de charge moyen pendant 60 secondes avec 10 clients simultanés et 100 requêtes par seconde, tout en surveillant l’ASG toutes les 15 secondes

il exécute enfin un test intensif pendant 120 secondes avec 50 clients simultanés et 500 requêtes par seconde afin de déclencher le scale-out

à la fin, il affiche l’état final du groupe Auto Scaling et les alarmes CloudWatch liées au CPU

Objectif

Ce test permet de vérifier que :

l’application est bien accessible via le Load Balancer

les instances EC2 répondent correctement aux requêtes

le groupe Auto Scaling réagit à la charge

l’architecture peut monter en charge automatiquement

les alarmes CloudWatch associées au CPU peuvent être observées pendant le test

Commandes utiles
Afficher les outputs Terraform
terraform output
Afficher l’état des ressources Terraform
terraform state list
Détruire l’infrastructure
terraform destroy
Résultat attendu

À la fin de cette phase, l’application doit être :

accessible via le DNS du Load Balancer

déployée sur des instances EC2 gérées par un Auto Scaling Group

capable de supporter une montée en charge

hébergée sur une architecture plus résiliente et évolutive