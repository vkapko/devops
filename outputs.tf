output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.main.id
}

output "instance_private_ip" {
  description = "EC2 instance private IP address"
  value       = aws_instance.main.private_ip
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.test_bucket.id
}