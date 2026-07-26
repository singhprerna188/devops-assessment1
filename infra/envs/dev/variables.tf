variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "skip_aws_validation" {
  description = "Skip AWS credential. Set to false for real deployments."
  type        = bool
  default     = true
}

variable "project" {
  type    = string
  default = "hotel-bookings"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["ap-south-1a", "ap-south-1b"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.0.0/24", "10.10.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.10.0/24", "10.10.11.0/24"]
}

variable "db_engine" {
  type    = string
  default = "postgres"
}

variable "db_engine_version" {
  type    = string
  default = "16.4"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_name" {
  type    = string
  default = "hotel_bookings_dev"
}

variable "db_username" {
  type      = string
  default   = "app_admin"
  sensitive = true
}

variable "db_password" {
  description = "Set via TF_VAR_db_password or a tfvars file that is NOT committed"
  type        = string
  sensitive   = true
  default     = "changeme-local-only"
}

variable "db_backup_retention_period" {
  type    = number
  default = 3
}

variable "db_deletion_protection" {
  type    = bool
  default = false
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "container_image" {
  type    = string
  default = "nginx:latest"
}

variable "container_port" {
  type    = number
  default = 80
}

variable "task_cpu" {
  type    = string
  default = "256"
}

variable "task_memory" {
  type    = string
  default = "512"
}

variable "desired_count" {
  type    = number
  default = 1
}
