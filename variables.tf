variable "aws_region" {
  description = "The AWS region where resources will be created."
  type        = string
  default     = "us-east-2"
}

variable "private_key_path" {
  description = "./shivanshsukhijakey.pem"
  type        = string
}
