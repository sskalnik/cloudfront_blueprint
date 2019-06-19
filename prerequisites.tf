terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  region  = var.region
  version = "~> 2.13"
}

// TODO: move this to a "common.tf" file
locals {
  log_bucket_prefix = "${replace(var.root_domain_name,".","-dot-")}"
}

// Use an S3 bucket to store the Terraform state, as the Docker image or other build/plan/apply instance may be ephemeral
resource "aws_s3_bucket" "terraform_state_bucket" {
  bucket = "${local.log_bucket_prefix}-terraform-state"
  acl    = "private"
  versioning {
    enabled = true
  }
  // Encrypt the logs using KMS. The default AWS KMS master key is used implicitly.
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

// Use a DynamoDB table as a locking mechanism for the Terraform state
resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "${local.log_bucket_prefix}-terraform-state-lock-table"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "LockKey"
  attribute {
    name = "LockKey"
    type = "S"
  }
}

