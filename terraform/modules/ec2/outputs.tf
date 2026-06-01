output "instance_id" {
  value = aws_instance.app.id
}

output "private_ip" {
  value = aws_instance.app.private_ip
}

output "public_ip" {
  description = "Public IP for SSH access"
  value       = aws_instance.app.public_ip
}
