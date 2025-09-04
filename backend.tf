terraform {
  backend "s3" {
    bucket         = "platform_engineering_shivansh_sukhija" # <-- IMPORTANT: Change this to your S3 bucket name
    key            = "global/hub-and-spoke/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-state-lock" # <-- IMPORTANT: Change this if you used a different table name
    encrypt        = true
  }
}