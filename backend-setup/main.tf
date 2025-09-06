# backend-setup/main.tf

# This configuration's only job is to create the S3 bucket and DynamoDB table
# that our main infrastructure project will use for its remote state.
# It uses a local state file because it has no remote backend itself.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

# Create a globally unique S3 bucket name
resource "random_pet" "bucket_name" {
  length = 2
}

resource "aws_s3_bucket" "tfstate" {
  # Bucket names must be globally unique. We add a random suffix to ensure this.
  bucket = "hub-spoke-tfstate-${random_pet.bucket_name.id}"

  # Enable versioning to protect against accidental state file deletion
  lifecycle {
    prevent_destroy = true
  }
}

# This resource enables versioning on the S3 bucket defined above.
# NOTE: This replaces the separate versioning resource that was causing an error.
resource "aws_s3_bucket_versioning" "tfstate_versioning" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Create the DynamoDB table for state locking
resource "aws_dynamodb_table" "tflock" {
  name           = "terraform-state-lock"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}

