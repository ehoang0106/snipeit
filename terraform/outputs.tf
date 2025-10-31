output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.snipeit.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.snipeit.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.snipeit.public_dns
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.snipeit_sg.id
}

output "npm_admin_url" {
  description = "Nginx Proxy Manager admin URL"
  value       = "http://${aws_instance.snipeit.public_ip}:81"
}

output "snipeit_url" {
  description = "Snipe-IT application URL"
  value       = "https://${var.domain_name}"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.snipeit.public_ip}"
}
