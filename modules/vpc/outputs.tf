# modules/vpc/outputs.tf

# This file defines all the information that the VPC module will "report back"
# to the main.tf file after it has finished creating resources.

output "vpc_id" {
  description = "The ID of the created VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC."
  value       = var.vpc_cidr
}

output "public_subnet_ids" {
  description = "A list of IDs for the public subnets."
  value       = aws_subnet.public[*].id
}

# This is a list of a single ID, which is easier to work with than a map for a single resource.
output "public_route_table_id" {
  description = "The ID of the public route table."
  value       = aws_route_table.public[0].id
}

# We now output the private route tables as a map, keyed by AZ name.
# This provides a stable key for for_each loops in the root module.
output "private_route_table_ids_by_az" {
  description = "A map of private route table IDs, keyed by Availability Zone."
  value = {
    for i, rt in aws_route_table.private : var.azs[i] => rt.id
  }
}

output "jump_server_public_ip" {
  description = "The public IP address of the Jump Server."
  value       = var.deploy_jump_server ? aws_eip.jump_server[0].public_ip : null
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer."
  value       = var.deploy_app_stack ? aws_lb.main[0].dns_name : null
}