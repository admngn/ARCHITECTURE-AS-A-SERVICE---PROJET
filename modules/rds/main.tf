###############################################################################
# Module RDS - Phase 2
# Cree : DB Subnet Group, Security Group RDS, instance RDS MySQL
# Corrections :
#   - Descriptions ASCII pur (pas de tiret em, pas d'accents)
#   - family = "mysql8.0" (format exact attendu par AWS)
#   - monitoring_interval = 0 (Enhanced Monitoring desactive - IAM:CreateRole interdit)
#   - performance_insights desactive pour db.t3.micro (non supporte)
###############################################################################

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ── DB Subnet Group ────────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "main" {
  name        = "${local.name_prefix}-db-subnet-group"
  description = "Subnet group for RDS - private subnets"
  subnet_ids  = var.private_subnet_ids

  tags = {
    Name = "${local.name_prefix}-db-subnet-group"
  }
}

# ── Security Group RDS ────────────────────────────────────────────────────────

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-sg-rds"
  description = "Security Group RDS - MySQL access from EC2 app only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from EC2 app security group"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [var.app_security_group_id]
  }

  egress {
    description = "Internal VPC egress only"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8"]
  }

  tags = {
    Name = "${local.name_prefix}-sg-rds"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ── Parameter Group RDS ───────────────────────────────────────────────────────
# family doit etre "mysql8.0" (pas "mysql8")

resource "aws_db_parameter_group" "mysql" {
  name        = "${local.name_prefix}-mysql-params"
  family      = "mysql8.0"
  description = "Custom MySQL 8.0 parameters for ${local.name_prefix}"

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "1"
  }

  parameter {
    name         = "binlog_format"
    value        = "ROW"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }

  tags = {
    Name = "${local.name_prefix}-mysql-params"
  }
}

# ── Option Group RDS ──────────────────────────────────────────────────────────

resource "aws_db_option_group" "mysql" {
  name                     = "${local.name_prefix}-mysql-options"
  option_group_description = "Option group MySQL 8.0 for ${local.name_prefix}"
  engine_name              = "mysql"
  major_engine_version     = "8.0"

  tags = {
    Name = "${local.name_prefix}-mysql-options"
  }
}

# ── Instance RDS MySQL ────────────────────────────────────────────────────────

resource "aws_db_instance" "main" {
  identifier = "${local.name_prefix}-mysql"

  engine         = "mysql"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = var.db_port

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  multi_az          = var.multi_az
  availability_zone = var.multi_az ? null : "us-east-1a"

  parameter_group_name = aws_db_parameter_group.mysql.name
  option_group_name    = aws_db_option_group.mysql.name

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  auto_minor_version_upgrade = true

  # Enhanced Monitoring desactive (IAM:CreateRole non autorise dans voclabs)
  monitoring_interval = 0

  # Performance Insights non supporte sur db.t3.micro
  performance_insights_enabled = false

  deletion_protection = var.deletion_protection
  skip_final_snapshot = true

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  tags = {
    Name = "${local.name_prefix}-mysql"
    Role = "Database"
  }

  depends_on = [aws_db_subnet_group.main]
}

# ── Alarmes CloudWatch ────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${local.name_prefix}-rds-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS high connections alert (> 80)"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }

  tags = {
    Name = "${local.name_prefix}-rds-connections-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${local.name_prefix}-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 75
  alarm_description   = "RDS high CPU alert (> 75%)"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }

  tags = {
    Name = "${local.name_prefix}-rds-cpu-alarm"
  }
}
