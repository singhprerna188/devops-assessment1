variable "project" {
  description = "Project name, used for resource naming/tagging"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod, etc.)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
}

variable "azs" {
  description = "Availability zones to spread subnets across"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Whether to create a NAT gateway for private subnet egress"
  type        = bool
  default     = true
}

variable "container_port" {
  description = "Port the application container listens on (allowed from ALB SG)"
  type        = number
  default     = 80
}

variable "db_port" {
  description = "Port the database listens on (allowed from ECS SG)"
  type        = number
  default     = 5432
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
