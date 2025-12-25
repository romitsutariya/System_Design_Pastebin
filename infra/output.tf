output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id,
  ]
}

output "instance_public_ip" {
  value       = aws_instance.web.public_ip
  description = "Public IP of the EC2 instance"
}

output "instance_public_dns" {
  value       = aws_instance.web.public_dns
  description = "Public DNS of the EC2 instance"
}

output "sqs_url" {
  value       = aws_sqs_queue.pastebin-backend-queue.url
  description = "Queue URL"
}