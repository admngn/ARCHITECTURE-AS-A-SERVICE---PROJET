###############################################################################
# Module Secrets Manager – Phase 2
# Crée un secret contenant les identifiants de la base de données RDS.
# L'application EC2 les récupère via l'API Secrets Manager (aucun mot de passe
# en dur dans le code ou les variables d'environnement).
###############################################################################

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  secret_name = "${local.name_prefix}/rds/credentials"
}

# ── Secret principal ──────────────────────────────────────────────────────────

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = local.secret_name
  description = "RDS database credentials for ${local.name_prefix}"

  # En POC : recovery_window_in_days = 0 pour permettre la suppression immédiate
  # En production : utilisez 7 à 30 jours minimum
  recovery_window_in_days = var.secret_recovery_days

  tags = {
    Name        = local.secret_name
    Application = "StudentRecords"
  }
}

# ── Valeur du secret (JSON avec tous les champs de connexion) ─────────────────

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  # Format compatible avec AWS SDK (boto3, AWS SDK for JS, etc.)
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    dbname   = var.db_name
    port     = tostring(var.db_port)
    engine   = "mysql"
    # host sera mis à jour après création de RDS (ou injecté via l'app)
  })
}

# ── Politique de rotation automatique (recommandée en production) ─────────────
# Décommentez et configurez une Lambda de rotation pour la production.
#
# resource "aws_secretsmanager_secret_rotation" "db_credentials" {
#   secret_id           = aws_secretsmanager_secret.db_credentials.id
#   rotation_lambda_arn = aws_lambda_function.rotate_secret.arn
#
#   rotation_rules {
#     automatically_after_days = 30
#   }
# }
