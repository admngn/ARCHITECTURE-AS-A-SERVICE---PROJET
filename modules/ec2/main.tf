###############################################################################
# Module EC2 Application - Phase 2
# Note : iam:CreateRole est interdit dans voclabs (AWS Academy).
#        On utilise le role "LabRole" pre-existant dans le compte,
#        ainsi que l'instance profile "LabInstanceProfile" associe.
###############################################################################

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

data "aws_region" "current" {}

# Recupere le role LabRole pre-cree par AWS Academy
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# Recupere l'instance profile LabInstanceProfile pre-cree par AWS Academy
data "aws_iam_instance_profile" "lab_profile" {
  name = "LabInstanceProfile"
}

# ── Security Group EC2 Application ───────────────────────────────────────────

resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-sg-app"
  description = "Security Group - App server Node.js Phase 2"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP public access"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH admin access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-sg-app"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ── Script UserData ───────────────────────────────────────────────────────────

locals {
  userdata = templatefile("${path.module}/../../templates/userdata.sh.tpl", {
    db_host             = var.db_host
    db_name             = var.db_name
    db_port             = var.db_port
    secret_name         = var.secret_arn
    aws_region          = data.aws_region.current.name
    app_port            = var.app_port
    userdata_script_url = var.userdata_script_url
  })
}

# ── Instance EC2 Application ──────────────────────────────────────────────────

resource "aws_instance" "app" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.app.id]

  # Utilise LabInstanceProfile (role pre-existant AWS Academy)
  iam_instance_profile   = data.aws_iam_instance_profile.lab_profile.name

  user_data                   = local.userdata
  user_data_replace_on_change = false

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 10
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${local.name_prefix}-app-root-volume"
    }
  }

  disable_api_termination = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring = true

  tags = {
    Name = "${local.name_prefix}-app-server"
    Role = "WebApplication"
  }
}

# ── Elastic IP ────────────────────────────────────────────────────────────────

resource "aws_eip" "app" {
  instance   = aws_instance.app.id
  domain     = "vpc"

  tags = {
    Name = "${local.name_prefix}-app-eip"
  }

  depends_on = [aws_instance.app]
}
