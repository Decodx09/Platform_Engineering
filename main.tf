terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --- Data Sources ---
data "aws_availability_zones" "available" {
  state = "available"
}

data "tls_public_key" "main" {
  private_key_pem = file(var.private_key_path)
}


# --- Locals ---
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}


# --- Resources ---
resource "aws_key_pair" "main" {
  key_name   = "hub-spoke-key-${substr(sha1(data.tls_public_key.main.public_key_openssh), 0, 7)}"
  public_key = data.tls_public_key.main.public_key_openssh
}

# --- Administrator VPC --- The Management Hub
# -----------------------------------------------------------------------------
module "admin_vpc" {
  source = "./modules/vpc"

  env_name                 = "admin"
  vpc_cidr                 = "10.0.0.0/16"
  key_name                 = aws_key_pair.main.key_name
  azs                      = local.azs
  public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24"] # One public subnet in each AZ
  private_app_subnet_cidrs = []                               # No app servers
  private_db_subnet_cidrs  = []                               # No databases

  deploy_app_stack   = false
  deploy_jump_server = true
}

# --- Development VPC --- The Application Environment
# -----------------------------------------------------------------------------
module "dev_vpc" {
  source = "./modules/vpc"

  env_name                 = "development"
  vpc_cidr                 = "10.1.0.0/16"
  key_name                 = aws_key_pair.main.key_name
  azs                      = local.azs
  public_subnet_cidrs      = ["10.1.1.0/24", "10.1.4.0/24"]
  private_app_subnet_cidrs = ["10.1.2.0/24", "10.1.5.0/24"]
  private_db_subnet_cidrs  = ["10.1.3.0/24", "10.1.6.0/24"]

  deploy_app_stack   = true
  deploy_jump_server = false
}

# --- Production VPC --- The Live Environment
# -----------------------------------------------------------------------------
module "prod_vpc" {
  source = "./modules/vpc"

  env_name                 = "production"
  vpc_cidr                 = "10.2.0.0/16"
  key_name                 = aws_key_pair.main.key_name
  azs                      = local.azs
  public_subnet_cidrs      = ["10.2.1.0/24", "10.2.4.0/24"]
  private_app_subnet_cidrs = ["10.2.2.0/24", "10.2.5.0/24"]
  private_db_subnet_cidrs  = ["10.2.3.0/24", "10.2.6.0/24"]

  deploy_app_stack   = true
  deploy_jump_server = false
}


# --- Transit Gateway --- The Central Network Hub
# -----------------------------------------------------------------------------
resource "aws_ec2_transit_gateway" "main" {
  description = "Central hub for inter-VPC traffic"
  tags = {
    Name = "main-transit-gateway"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "admin" {
  subnet_ids         = module.admin_vpc.public_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = module.admin_vpc.vpc_id
  tags               = { Name = "tgw-attach-admin" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "dev" {
  subnet_ids         = module.dev_vpc.public_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = module.dev_vpc.vpc_id
  tags               = { Name = "tgw-attach-dev" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "prod" {
  subnet_ids         = module.prod_vpc.public_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = module.prod_vpc.vpc_id
  tags               = { Name = "tgw-attach-prod" }
}

# --- Transit Gateway Routing ---
# -----------------------------------------------------------------------------
# Add routes to Admin VPC to reach the other environments
resource "aws_route" "admin_to_dev" {
  for_each = toset(module.admin_vpc.public_route_table_ids)

  route_table_id         = each.value
  destination_cidr_block = module.dev_vpc.vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}

resource "aws_route" "admin_to_prod" {
  for_each = toset(module.admin_vpc.public_route_table_ids)

  route_table_id         = each.value
  destination_cidr_block = module.prod_vpc.vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}

# Add routes to Dev VPC's PRIVATE subnets to reach the other environments
resource "aws_route" "dev_to_admin" {
  for_each = toset(module.dev_vpc.private_route_table_ids)

  route_table_id         = each.value
  destination_cidr_block = module.admin_vpc.vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}

resource "aws_route" "dev_to_prod" {
  for_each = toset(module.dev_vpc.private_route_table_ids)

  route_table_id         = each.value
  destination_cidr_block = module.prod_vpc.vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}

# Add routes to Prod VPC's PRIVATE subnets to reach the other environments
resource "aws_route" "prod_to_admin" {
  for_each = toset(module.prod_vpc.private_route_table_ids)

  route_table_id         = each.value
  destination_cidr_block = module.admin_vpc.vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}

resource "aws_route" "prod_to_dev" {
  for_each = toset(module.prod_vpc.private_route_table_ids)

  route_table_id         = each.value
  destination_cidr_block = module.dev_vpc.vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}