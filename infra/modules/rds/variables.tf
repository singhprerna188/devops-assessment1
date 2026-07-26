variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "engine" {
  description = "postgres or mysql"
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  type    = string
  default = "16.4"
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "db_name" {
  type    = string
  default = "app"
}

variable "db_username" {
  type      = string
  default   = "app_admin"
  sensitive = true
}

variable "db_password" {
  description = "Master password. In real usage, source from a secrets manager / TF_VAR env var, never commit plaintext."
  type        = string
  sensitive   = true
}

variable "db_port" {
  type    = number
  default = 5432
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  type    = bool
  default = true
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "vpc_security_group_ids" {
  type = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
