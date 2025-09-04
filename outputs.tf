output "jump_server_public_ip" {
  description = "The public IP address of the Jump Server for SSH access."
  value       = module.admin_vpc.jump_server_public_ip
}

output "development_load_balancer_dns" {
  description = "The public DNS name of the Development ALB."
  value       = module.dev_vpc.alb_dns_name
}

output "production_load_balancer_dns" {
  description = "The public DNS name of the Production ALB."
  value       = module.prod_vpc.alb_dns_name
}