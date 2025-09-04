output "vpc_id" {
  description = "The ID of the created VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "A list of the public subnet IDs."
  value       = [for s in aws_subnet.public : s.id]
}

output "alb_dns_name" {
  description = "The public DNS name of the Application Load Balancer."
  value       = var.deploy_app_stack ? aws_lb.main[0].dns_name : "N/A"
}

output "jump_server_public_ip" {
  description = "The public IP of the jump server."
  value       = var.deploy_jump_server ? aws_instance.jump_server[0].public_ip : "N/A"
}
