# Dev environment sizing: small and cheap, fast iteration, low blast radius.

aws_region  = "ap-south-1"
project     = "hotel-bookings"
environment = "dev"

vpc_cidr             = "10.10.0.0/16"
azs                  = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs  = ["10.10.0.0/24", "10.10.1.0/24"]
private_subnet_cidrs = ["10.10.10.0/24", "10.10.11.0/24"]

db_engine            = "postgres"
db_engine_version    = "16.4"
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
db_name              = "hotel_bookings_dev"
db_username          = "app_admin"
# db_password should be supplied via TF_VAR_db_password, not committed here.

db_backup_retention_period = 3
db_deletion_protection     = false
db_multi_az                = false

container_image = "nginx:latest"
container_port  = 80
task_cpu        = "256"
task_memory     = "512"
desired_count   = 1
