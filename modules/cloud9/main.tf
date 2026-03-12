###############################################################################
# Module Cloud9 - Phase 2
# Cree un environnement Cloud9 pour executer les scripts AWS CLI
# Corrections :
#   - Tag "Name" supprime (reserve par EC2, rejetee par l'API Cloud9)
#   - aws_iam_role supprime (IAM:CreateRole non autorise dans voclabs)
###############################################################################

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

data "aws_caller_identity" "current" {}

locals {
  owner_arn = var.owner_arn != "" ? var.owner_arn : data.aws_caller_identity.current.arn
}

# ── Environnement Cloud9 ──────────────────────────────────────────────────────

resource "aws_cloud9_environment_ec2" "main" {
  name          = "${local.name_prefix}-cloud9"
  description   = "Cloud9 IDE for CLI scripts - ${local.name_prefix}"
  instance_type = var.instance_type
  subnet_id     = var.public_subnet_id

  # Requis depuis AWS provider v5.x
  image_id = "amazonlinux-2023-x86_64"

  # Hibernation apres 30 minutes d'inactivite
  automatic_stop_time_minutes = 30

  # CONNECT_SSH utilise (CONNECT_SSM necessite AWSCloud9SSMInstanceProfile
  # qui n'existe pas dans l'environnement voclabs)
  connection_type = "CONNECT_SSH"

  owner_arn = local.owner_arn

  # NOTE : pas de tag "Name" - cle reservee par EC2, rejetee par l'API Cloud9
  tags = {
    Project = "${local.name_prefix}"
    Role    = "AdminTooling"
  }
}
