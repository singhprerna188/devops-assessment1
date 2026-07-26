variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "alb_security_group_id" {
  type = string
}

variable "ecs_security_group_id" {
  type = string
}

variable "container_image" {
  description = "Docker image for the application container (placeholder: nginx)"
  type        = string
  default     = "nginx:latest"
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

variable "health_check_path" {
  type    = string
  default = "/"
}

variable "db_endpoint" {
  description = "RDS endpoint injected into the container as an env var"
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
