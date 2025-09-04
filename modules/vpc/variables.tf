variable "env_name" {
  description = "The name of the environment (e.g., 'admin', 'development')."
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
}

variable "azs" {
  description = "A list of Availability Zones to use."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "A list of CIDR blocks for the public subnets."
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "A list of CIDR blocks for the private application subnets."
  type        = list(string)
}

variable "private_db_subnet_cidrs" {
  description = "A list of CIDR blocks for the private database subnets."
  type        = list(string)
}

variable "key_name" {
  description = "The name of the EC2 key pair for SSH."
  type        = string
}

variable "deploy_app_stack" {
  description = "Boolean flag to control the deployment of the application stack (ALB, EC2)."
  type        = bool
  default     = false
}

variable "deploy_jump_server" {
  description = "Boolean flag to control the deployment of a jump server."
  type        = bool
  default     = false
}
