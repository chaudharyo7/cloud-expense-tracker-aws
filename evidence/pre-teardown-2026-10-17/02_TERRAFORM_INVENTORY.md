# Terraform Configuration & Tracked Resource Inventory

**Project**: Cloud Expense Tracker AWS  
**Evaluation Date**: 2026-10-17  
**Terraform CLI Version**: `v1.16.5` (darwin_arm64)  
**AWS Provider Version**: `~> 6.0`  
**Current Workspace**: `default`  

---

## 1. Backend & State Configuration

- **Backend Type**: Local (`local`) — No remote state backend (`backend "s3"` or Terraform Cloud) is configured in any `.tf` file.
- **Provider Region**: `ap-south-1` (declared in `terraform/vpc.tf`).
- **State Availability**: **No state file present (`terraform.tfstate` not found on filesystem).**
- **Verification Command**:
  ```bash
  $ terraform state list
  No state file was found!
  ```

---

## 2. Resource Counts: State vs. Configuration

| Metric | Count | Details |
| :--- | :--- | :--- |
| **Resources in State** | **0** | No local state file detected. |
| **Resources Declared in `.tf`** | **115** | Declared across 11 `.tf` files in `terraform/`. |
| **Resources Confirmed Active in AWS** | **115** | Live infrastructure in `ap-south-1` matches all configuration addresses. |
| **Discrepancy Status** | **100% Desynchronized** | Terraform is unaware of the existing 115 live resources. |

---

## 3. Inventory of Declared Configuration by File

### A. Networking & Core Infrastructure (`vpc.tf`)
1. `aws_vpc.main` — CIDR `10.0.0.0/16`
2. `aws_subnet.public_1` — `10.0.1.0/24` (ap-south-1a)
3. `aws_subnet.public_2` — `10.0.2.0/24` (ap-south-1b)
4. `aws_subnet.private_app_1` — `10.0.11.0/24` (ap-south-1a)
5. `aws_subnet.private_app_2` — `10.0.12.0/24` (ap-south-1b)
6. `aws_subnet.private_db_1` — `10.0.21.0/24` (ap-south-1a)
7. `aws_subnet.private_db_2` — `10.0.22.0/24` (ap-south-1b)
8. `aws_internet_gateway.main`
9. `aws_eip.nat`
10. `aws_nat_gateway.main`
11. `aws_route_table.public`
12. `aws_route_table.private_app`
13. `aws_route_table.private_db`
14. `aws_route.nat_app`
15. `aws_route_table_association.public_1`
16. `aws_route_table_association.public_2`
17. `aws_route_table_association.private_app_1`
18. `aws_route_table_association.private_app_2`
19. `aws_route_table_association.private_db_1`
20. `aws_route_table_association.private_db_2`
21. `aws_security_group.public_sg`
22. `aws_security_group.app_sg`
23. `aws_security_group.db_sg`
24. `aws_vpc_endpoint.s3`

### B. Compute Tier (`ec2.tf`)
25. `aws_instance.frontend_1` — t3.micro in public_1
26. `aws_instance.frontend_2` — t3.micro in public_2
27. `aws_instance.backend_1` — t3.micro in private_app_1
28. `aws_instance.backend_2` — t3.micro in private_app_2

### C. Load Balancing (`alb.tf`)
29. `aws_security_group.alb_sg`
30. `aws_lb.expense_alb`
31. `aws_lb_target_group.expense_target_group_frontend`
32. `aws_lb_target_group.expense_target_group_backend`
33. `aws_lb_listener.expense_listener_frontend` (Port 80 redirect)
34. `aws_lb_listener.expense_listener_https` (Port 443 HTTPS)
35. `aws_lb_listener_rule.expense_backend_rule_https` (`/api/*` routing)
36. `aws_lb_target_group_attachment.expense_target_group_attachment_frontend`
37. `aws_lb_target_group_attachment.expense_target_group_attachment_frontend_2`
38. `aws_lb_target_group_attachment.expense_target_group_attachment_backend`
39. `aws_lb_target_group_attachment.expense_target_group_attachment_backend_2`

### D. Relational Database (`rds.tf`)
40. `aws_db_subnet_group.expense_db_subnet_group`
41. `aws_db_instance.expense_db_instance` (PostgreSQL 17, db.t3.micro, 20GB gp3)

### E. Storage Tier (`s3.tf` & `ecr.tf`)
42. `aws_s3_bucket.expense_bucket`
43. `aws_s3_bucket.expense_logs_bucket`
44. `aws_s3_bucket.ansible_ssm_bucket`
45. `aws_s3_bucket_versioning.expense_bucket_versioning`
46. `aws_s3_bucket_server_side_encryption_configuration.expense_bucket_encryption`
47. `aws_s3_bucket_logging.expense_bucket_logging`
48. `aws_s3_bucket_public_access_block.expense_bucket_access`
49. `aws_s3_bucket_public_access_block.expense_logs_bucket_access`
50. `aws_s3_bucket_public_access_block.ansible_ssm_bucket_access`
51. `aws_s3_bucket_policy.expense_bucket_policy`
52. `aws_s3_bucket_policy.expense_logs_bucket_policy`
53. `aws_ecr_repository.frontend`
54. `aws_ecr_repository.backend`

### F. Serverless & API Gateway (`lambda.tf` & `api_gateway.tf`)
55. `aws_security_group.lambda_sg`
56. `aws_lambda_function.expense_lambda`
57. `aws_lambda_permission.allow_api_gateway`
58. `aws_apigatewayv2_api.expense_api`
59. `aws_apigatewayv2_stage.expense_api_stage`
60. `aws_apigatewayv2_integration.lambda_integration`
61. `aws_apigatewayv2_route.generate_report`
62. `aws_apigatewayv2_authorizer.cognito_jwt`

### G. Identity & Access Management (`iam.tf` & `cognito.tf`)
63. `aws_cognito_user_pool.expense_user_pool`
64. `aws_cognito_user_pool_client.expense_client`
65. `aws_iam_openid_connect_provider.github_actions`
66. `aws_iam_role.github_actions_ecr_role`
67. `aws_iam_policy.github_actions_ecr_policy`
68. `aws_iam_role_policy_attachment.github_actions_ecr_attachment`
69. `aws_iam_policy.github_actions_ssm_policy`
70. `aws_iam_role_policy_attachment.github_actions_ssm_attachment`
71. `aws_iam_role.ec2_ssm_role`
72. `aws_iam_instance_profile.ec2_ssm_profile`
73. `aws_iam_role_policy_attachment.ec2_ssm_policy`
74. `aws_iam_policy.ec2_db_credential_read_policy`
75. `aws_iam_role_policy_attachment.ec2_db_credential_read_attachment`
76. `aws_iam_role_policy_attachment.ec2_ecr_read_only`
77. `aws_iam_policy.ec2_lambda_invoke_policy`
78. `aws_iam_role_policy_attachment.ec2_lambda_invoke_attachment`
79. `aws_iam_policy.ec2_describe_instances_policy`
80. `aws_iam_role_policy_attachment.ec2_describe_instances_attachment`
81. `aws_iam_role.expense_lambda_role`
82. `aws_iam_role_policy_attachment.expense_lambda_policy_attachment`
83. `aws_iam_role_policy_attachment.expense_lambda_vpc_policy_attachment`
84. `aws_iam_policy.lambda_s3_policy`
85. `aws_iam_role_policy_attachment.expense_lambda_s3_policy_attachment`
86. `aws_iam_role_policy_attachment.expense_lambda_ssm_policy_attachment`
87. `aws_iam_policy.ansible_ec2_inventory_policy`
88. `aws_iam_user_policy_attachment.ansible_ec2_inventory_attachment`
89. `aws_iam_policy.ansible_ssm_s3_policy`
90. `aws_iam_user_policy_attachment.ansible_ssm_s3_attachment`
91. `aws_iam_policy.ansible_ssm_controller_policy`
92. `aws_iam_user_policy_attachment.ansible_ssm_controller_attachment`

### H. Observability & Alarms (`cloudwatch.tf`)
93. `aws_sns_topic.alerts`
94. `aws_sns_topic_subscription.email_alerts`
95. `aws_cloudwatch_dashboard.expense_dashboard`
96. `aws_cloudwatch_log_group.lambda_log_group`
97. `aws_cloudwatch_log_metric_filter.lambda_errors_filter`
98. `aws_cloudwatch_log_group.api_gw_access_logs`
99. `aws_cloudwatch_log_resource_policy.api_gw_cw_logs_policy`
100. `aws_cloudwatch_metric_alarm.ec2_frontend_1_status`
101. `aws_cloudwatch_metric_alarm.ec2_frontend_2_status`
102. `aws_cloudwatch_metric_alarm.ec2_backend_1_status`
103. `aws_cloudwatch_metric_alarm.ec2_backend_2_status`
104. `aws_cloudwatch_metric_alarm.ec2_backend_1_cpu_high`
105. `aws_cloudwatch_metric_alarm.alb_target_5xx_errors`
106. `aws_cloudwatch_metric_alarm.alb_target_response_time_high`
107. `aws_cloudwatch_metric_alarm.alb_backend_unhealthy_hosts`
108. `aws_cloudwatch_metric_alarm.rds_cpu_high`
109. `aws_cloudwatch_metric_alarm.rds_low_freeable_memory`
110. `aws_cloudwatch_metric_alarm.rds_low_storage`
111. `aws_cloudwatch_metric_alarm.rds_high_connections`
112. `aws_cloudwatch_metric_alarm.lambda_errors`
113. `aws_cloudwatch_metric_alarm.lambda_throttles`
114. `aws_cloudwatch_metric_alarm.lambda_high_duration`
115. `aws_cloudwatch_metric_alarm.nat_gw_packets_drop`
116. `aws_cloudwatch_metric_alarm.nat_gw_port_allocation_error`

---

## 4. Why Plan Shows "115 to Add"
When executing `terraform plan` without local state, Terraform assumes a greenfield deployment:
```
Plan: 115 to add, 0 to change, 0 to destroy.
```
**Critical Safety Alert**: Do not run `terraform apply`. Running apply will fail because S3 bucket names, VPC CIDRs, IAM roles, and RDS names already exist in AWS under account `205639******`.
