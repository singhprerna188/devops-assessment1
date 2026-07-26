# Prod environment sizing: larger instances, longer retention, protected
# from accidental deletion. db_password is intentionally NOT set here -
# pass it via TF_VAR_db_password (CI secret / secrets manager) at plan/apply time.

aws_region  = "ap-south-1"
project     = "hotel-bookings"
environment = "prod"

vpc_cidr             = "10.20.0.0/16"
azs                  = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
public_subnet_cidrs  = ["10.20.0.0/24", "10.20.1.0/24", "10.20.2.0/24"]
private_subnet_cidrs = ["10.20.10.0/24", "10.20.11.0/24", "10.20.12.0/24"]

db_engine            = "postgres"
db_engine_version    = "16.4"
db_instance_class    = "db.r6g.large"
db_allocated_storage = 100
db_name              = "hotel_bookings_prod"
db_username          = "app_admin"

db_backup_retention_period = 30
db_deletion_protection     = true
db_multi_az                = true

container_image = "nginx:latest"
container_port  = 80
task_cpu        = "1024"
task_memory     = "2048"
desired_count   = 3
