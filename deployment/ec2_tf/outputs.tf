output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.this.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.this.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.this.public_dns
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ${var.key_name}.pem ec2-user@${aws_instance.this.public_ip}"
}

output "private_key_file" {
  description = "Path to the private key file"
  value       = local_file.private_key.filename
}

output "ami_id" {
  description = "AMI ID used for the instance"
  value       = data.aws_ami.amazon_linux.id
}

output "vpc_id" {
  description = "VPC ID where the instance is deployed"
  value       = data.aws_vpc.default.id
}

output "security_group_id" {
  description = "Security group ID attached to the instance"
  value       = aws_security_group.ec2.id
}
