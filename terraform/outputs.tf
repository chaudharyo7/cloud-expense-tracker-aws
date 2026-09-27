output "VPC_ID" {
  value       = aws_vpc.main.id
  description = "The ID of the VPC"
}

output "PUBLIC_SUBNET_1_ID" {
  value       = aws_subnet.public_1.id
  description = "The ID of the public subnet 1"
}

output "PUBLIC_SUBNET_2_ID" {
  value       = aws_subnet.public_2.id
  description = "The ID of the public subnet 2"
}

output "PRIVATE_APP_SUBNET_1_ID" {
  value       = aws_subnet.private_app_1.id
  description = "The ID of the private app subnet 1"
}

output "PRIVATE_APP_SUBNET_2_ID" {
  value       = aws_subnet.private_app_2.id
  description = "The ID of the private app subnet 2"
}

output "PRIVATE_DB_SUBNET_1_ID" {
  value       = aws_subnet.private_db_1.id
  description = "The ID of the private DB subnet 1"
}

output "PRIVATE_DB_SUBNET_2_ID" {
  value       = aws_subnet.private_db_2.id
  description = "The ID of the private DB subnet 2"
}

output "INTERNET_GATEWAY_ID" {
  value       = aws_internet_gateway.main.id
  description = "The ID of the internet gateway"
}

output "PUBLIC_ROUTE_TABLE_ID" {
  value       = aws_route_table.public.id
  description = "The ID of the public route table"
}

output "PRIVATE_APP_ROUTE_TABLE_ID" {
  value       = aws_route_table.private_app.id
  description = "The ID of the private app route table"
}

output "PRIVATE_DB_ROUTE_TABLE_ID" {
  value       = aws_route_table.private_db.id
  description = "The ID of the private DB route table"
}

output "NAT_GATEWAY_ID" {
  value       = aws_nat_gateway.main.id
  description = "The ID of the NAT gateway"
}

output "NAT_GATEWAY_PUBLIC_IP" {
  value       = aws_nat_gateway.main.public_ip
  description = "The public IP of the NAT gateway"
}

output "ALB_DNS_NAME" {
  value       = aws_lb.expense_alb.dns_name
  description = "The DNS name of the ALB"
}

output "FRONTEND_INSTANCE_1_PUBLIC_IP" {
  value       = aws_instance.frontend_1.public_ip
  description = "The public IP of the frontend instance 1"
}

output "FRONTEND_INSTANCE_2_PUBLIC_IP" {
  value       = aws_instance.frontend_2.public_ip
  description = "The public IP of the frontend instance 2"
}

output "BACKEND_INSTANCE_1_PRIVATE_IP" {
  value       = aws_instance.backend_1.private_ip
  description = "The private IP of the backend instance 1"
}

output "BACKEND_INSTANCE_2_PRIVATE_IP" {
  value       = aws_instance.backend_2.private_ip
  description = "The private IP of the backend instance 2"
}


output "ALB_SECURITY_GROUP_ID" {
  value       = aws_security_group.alb_sg.id
  description = "The ID of the ALB security group"
}

output "PUBLIC_SECURITY_GROUP_ID" {
  value       = aws_security_group.public_sg.id
  description = "The ID of the public security group"
}

output "PRIVATE_APP_SECURITY_GROUP_ID" {
  value       = aws_security_group.app_sg.id
  description = "The ID of the private app security group"
}

output "PRIVATE_DB_SECURITY_GROUP_ID" {
  value       = aws_security_group.db_sg.id
  description = "The ID of the private DB security group"
}

output "EXPENSE_API_URL" {
  value       = aws_apigatewayv2_stage.expense_api_stage.invoke_url
  description = "API Gateway URL for the expense tracker API"
}
output "RDS_ENDPOINT" {
  value       = aws_db_instance.expense_db_instance.address
  description = "Private endpoint of the PostgreSQL RDS instance"
}

output "LAMBDA_FUNCTION_ARN" {

  value = aws_lambda_function.expense_lambda.arn

  description = "The ARN of the expense tracker Lambda function"

}

output "EXPENSE_S3_BUCKET_NAME" {

  value = aws_s3_bucket.expense_bucket.bucket

  description = "The name of the expense tracker S3 bucket"

}

output "EXPENSE_LOGS_BUCKET_NAME" {

  value = aws_s3_bucket.expense_logs_bucket.bucket

  description = "The name of the S3 access logs bucket"

}

output "GITHUB_ACTIONS_ROLE_ARN" {
  value       = aws_iam_role.github_actions_ecr_role.arn
  description = "ARN of the IAM role for GitHub Actions OIDC to push images to ECR"
}

output "github_actions_role_arn" {
  description = "IAM role ARN assumed by GitHub Actions through OIDC"
  value       = aws_iam_role.github_actions_ecr_role.arn
}

output "ECR_FRONTEND_REPOSITORY_URL" {
  value       = aws_ecr_repository.frontend.repository_url
  description = "URL of the frontend ECR repository"
}

output "ECR_BACKEND_REPOSITORY_URL" {
  value       = aws_ecr_repository.backend.repository_url
  description = "URL of the backend ECR repository"
}

output "cloudwatch_dashboard_name" {
  value       = aws_cloudwatch_dashboard.expense_dashboard.dashboard_name
  description = "Name of the CloudWatch dashboard for Expense Tracker"
}

output "rds_master_user_secret_arn" {
  value       = try(aws_db_instance.expense_db_instance.master_user_secret[0].secret_arn, null)
  description = "ARN of the AWS Secrets Manager secret managing the RDS master user password"
}

output "cognito_user_pool_id" {
  value       = aws_cognito_user_pool.expense_user_pool.id
  description = "ID of the Cognito User Pool"
}

output "cognito_client_id" {
  value       = aws_cognito_user_pool_client.expense_client.id
  description = "ID of the Cognito User Pool Client for the frontend SPA"
}

output "cognito_issuer_url" {
  value       = "https://${aws_cognito_user_pool.expense_user_pool.endpoint}"
  description = "OIDC Issuer URL of the Cognito User Pool"
}

output "apigateway_log_group_name" {
  value       = aws_cloudwatch_log_group.api_gw_access_logs.name
  description = "Name of the CloudWatch Log Group for API Gateway access logs"
}

output "lambda_log_group_name" {
  value       = aws_cloudwatch_log_group.lambda_log_group.name
  description = "Name of the CloudWatch Log Group for Lambda function logs"
}

output "alerts_sns_topic_arn" {
  value       = aws_sns_topic.alerts.arn
  description = "ARN of the SNS topic for CloudWatch alarms"
}


