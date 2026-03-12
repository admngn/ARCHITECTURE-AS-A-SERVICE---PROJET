variable "aws_region"   { type = string; default = "us-east-1" }
variable "project_name" { type = string; default = "universite-exemple" }
variable "environment"  { type = string; default = "poc" }

variable "vpc_cidr"             { type = string; default = "10.1.0.0/16" }
variable "public_subnet_cidrs"  { type = list(string); default = ["10.1.1.0/24", "10.1.2.0/24"] }
variable "private_subnet_cidrs" { type = list(string); default = ["10.1.11.0/24", "10.1.12.0/24"] }

variable "cluster_version"    { type = string; default = "1.29" }
variable "node_instance_type" { type = string; default = "t3.medium" }
variable "node_desired_size"  { type = number; default = 2 }
variable "node_min_size"      { type = number; default = 1 }
variable "node_max_size"      { type = number; default = 4 }

variable "rds_endpoint"   { type = string; default = "universite-exemple-poc-mysql.czcugausmn9e.us-east-1.rds.amazonaws.com" }
variable "db_secret_name" { type = string; default = "Mydbsecret" }
