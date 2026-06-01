output "alb_dns_name" {
  description = "DNS name of the load balancer — use this to access the app"
  value       = module.alb.alb_dns_name
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = module.ec2.instance_id
}

output "ec2_public_ip" {
  description = "EC2 public IP for SSH access"
  value       = module.ec2.public_ip
}
