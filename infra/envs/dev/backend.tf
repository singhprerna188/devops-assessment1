terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state for the dev environment. Bucket/table are expected to be
  # created out-of-band (or via a bootstrap stack) before running `init`.
  # For local-only validation (fmt/validate/plan), this backend block can be
  # commented out and Terraform will fall back to local state.
  backend "s3" {
    bucket         = "example-terraform-state-dev"
   key            = "devops-assessment/dev/terraform.tfstate"
    region         = "ap-south-1"
   dynamodb_table = "terraform-locks-dev"
   encrypt        = true
  }
}
