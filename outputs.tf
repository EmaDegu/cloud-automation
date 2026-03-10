output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "private_subnet_ids" {
  value = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

output "alb_dns_name" {
  value = aws_lb.app_alb.dns_name
}

output "db_endpoint" {
  value       = aws_db_instance.app_db.endpoint
  sensitive   = true
  description = "Database endpoint for applications"
}
