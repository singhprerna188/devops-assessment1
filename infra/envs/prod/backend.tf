terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state for the prod environment — commented out for local plan-only testing.
  backend "s3" {
     bucket         = "example-terraform-state-prod"
     key            = "devops-assessment/prod/terraform.tfstate"
     region         = "ap-south-1"
     dynamodb_table = "terraform-locks-prod"
     encrypt        = true
   }
}
#test
