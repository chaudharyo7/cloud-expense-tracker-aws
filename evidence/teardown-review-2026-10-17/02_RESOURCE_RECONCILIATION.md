# AWS Resource Reconciliation & Dependency Matrix

**Project**: Cloud Expense Tracker AWS  
**Audit Date**: 2026-10-17  
**Region**: `ap-south-1`  
**State-Management Status Across All Resources**: **Untracked** (Local state file missing).  

---

## 1. Summary of Reconciliation Findings

- **Total Resource Blocks Declared in Terraform**: **115**
- **Total Confirmed Live Resources in AWS**: **114**
- **Declared Resources Never Deployed**: **1** (`aws_sns_topic_subscription.email_alerts` in `cloudwatch.tf` — verified via `aws sns list-subscriptions-by-topic`, which returned zero subscriptions because `var.alert_email` defaulted to `""`).
- **External Unmanaged Dependencies**: **1** (ACM Certificate `arn:aws:acm:ap-south-1:205639******:certificate/6936d865-c954-4ff2-af0e-eb41fb14525f` for `projects.yamandeep.in` — used by ALB but created outside Terraform).

---

## 2. Resource Reconciliation Table

| AWS Service & Type | Sanitized Resource Identifier | Live State | Terraform Config Reference | Verification Status | Deletion Phase | Continuing Charges? |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **EC2 / Instance** | `i-0b0294fc87c9ac832` (`frontend-1`) | `running` | `aws_instance.frontend_1` | **Verified Live** | Phase 2 (Compute) | **Yes** (IPv4 + compute over free tier) |
| **EC2 / Instance** | `i-0d180a9a22ab66f1a` (`frontend-2`) | `running` | `aws_instance.frontend_2` | **Verified Live** | Phase 2 (Compute) | **Yes** (IPv4 + compute over free tier) |
| **EC2 / Instance** | `i-0a973fbbf1c0e01e3` (`backend-1`) | `running` | `aws_instance.backend_1` | **Verified Live** | Phase 2 (Compute) | **Yes** (Compute over free tier) |
| **EC2 / Instance** | `i-048b2374625ee144e` (`backend-2`) | `running` | `aws_instance.backend_2` | **Verified Live** | Phase 2 (Compute) | **Yes** (Compute over free tier) |
| **EBS / Volume** | `vol-0fa935f3d760752d9` (8GB gp3) | `in-use` | `root_block_device` (`frontend_1`) | **Verified Live** | Auto (on EC2 termination) | **Yes** (Part of 32GB total) |
| **EBS / Volume** | `vol-02a98a774e69f72ca` (8GB gp3) | `in-use` | `root_block_device` (`frontend_2`) | **Verified Live** | Auto (on EC2 termination) | **Yes** (Part of 32GB total) |
| **EBS / Volume** | `vol-09c60a37584778b0d` (8GB gp3) | `in-use` | `root_block_device` (`backend_1`) | **Verified Live** | Auto (on EC2 termination) | **Yes** (Part of 32GB total) |
| **EBS / Volume** | `vol-0dd9c0a4661577e6a` (8GB gp3) | `in-use` | `root_block_device` (`backend_2`) | **Verified Live** | Auto (on EC2 termination) | **Yes** (Part of 32GB total) |
| **ELBv2 / Load Balancer** | `arn:...:loadbalancer/app/expense-alb/...` | `active` | `aws_lb.expense_alb` | **Verified Live** | Phase 2 (Ingress) | **Yes** (~$16.20/mo + 2 IPv4s) |
| **ELBv2 / Target Group** | `arn:...:targetgroup/expense-target-group-backend/...` | `active` | `aws_lb_target_group.backend` | **Verified Live** | Phase 2 (Ingress) | No (included in ALB) |
| **ELBv2 / Target Group** | `arn:...:targetgroup/expense-target-group-frontend/...`| `active` | `aws_lb_target_group.frontend` | **Verified Live** | Phase 2 (Ingress) | No (included in ALB) |
| **ELBv2 / Listener (80)** | `arn:...:listener/app/expense-alb/.../be0a...` | `active` | `aws_lb_listener.frontend` | **Verified Live** | Auto with ALB | No |
| **ELBv2 / Listener (443)**| `arn:...:listener/app/expense-alb/.../f0fb...` | `active` | `aws_lb_listener.https` | **Verified Live** | Auto with ALB | No |
| **ACM / Certificate** | `arn:aws:acm:...:certificate/6936d865...` | `ISSUED` | `var.certificate_arn` | **External / Shared** | **DO NOT DELETE** | No (Amazon-issued cert is free) |
| **RDS / DB Instance** | `expense-tracker-db` (Postgres 17.9) | `available` | `aws_db_instance.expense_db_instance` | **Verified Live** | Phase 3 (Database) | No (covered by 12-mo free tier) |
| **RDS / Subnet Group** | `expense-db-subnet-group` | `Complete` | `aws_db_subnet_group.db_subnet` | **Verified Live** | Phase 3 (Database) | No |
| **Secrets Manager / Secret** | `arn:...:secret:rds!db-22302a8e...` | `active` | Managed by RDS master secret | **Verified Live** | Auto with RDS | **Yes** (after 30-day trial ~$0.40/mo) |
| **EC2 / NAT Gateway** | `nat-00b6ef51e976e5998` | `available` | `aws_nat_gateway.main` | **Verified Live** | Phase 4 (Egress) | **Yes** (~$32.40/mo + IPv4) |
| **EC2 / Elastic IP** | `eipalloc-032da56bffc50c262` | `associated` (NAT) | `aws_eip.nat` | **Verified Live** | Phase 4 (Egress) | **Yes** (IPv4 $0.005/hr) |
| **EC2 / Elastic IP** | `eipalloc-0614a80423136e81d` | `associated` (ALB) | Managed by ALB | **Verified Live** | Auto with ALB | **Yes** (IPv4 $0.005/hr) |
| **EC2 / Elastic IP** | `eipalloc-0cd9c1792aab159bb` | `associated` (ALB) | Managed by ALB | **Verified Live** | Auto with ALB | **Yes** (IPv4 $0.005/hr) |
| **EC2 / Internet Gateway**| `igw-0671a80fa042e5e38` | `available` | `aws_internet_gateway.main` | **Verified Live** | Phase 5 (Network) | No |
| **EC2 / Route Table** | `rtb-0c7000649511dd55c` (`public-rt`) | `available` | `aws_route_table.public` | **Verified Live** | Phase 5 (Network) | No |
| **EC2 / Route Table** | `rtb-0d5d13fdd17ceef60` (`private-app-rt`) | `available` | `aws_route_table.private_app` | **Verified Live** | Phase 5 (Network) | No |
| **EC2 / Route Table** | `rtb-0cf9ba9e14e8f5f04` (`private-db-rt`) | `available` | `aws_route_table.private_db` | **Verified Live** | Phase 5 (Network) | No |
| **EC2 / VPC Endpoint** | `vpce-07109946b5c3f8627` (S3 Gateway) | `available` | `aws_vpc_endpoint.s3` | **Verified Live** | Phase 5 (Network) | No (S3 Gateway is free) |
| **EC2 / Security Group** | `sg-0da1e182fb34451f4` (`public_sg`) | `active` | `aws_security_group.public_sg` | **Verified Live** | Phase 5 (Network) | No |
| **EC2 / Security Group** | `sg-06b195c60984cc4bb` (`app_sg`) | `active` | `aws_security_group.app_sg` | **Verified Live** | Phase 5 (Network) | No |
| **EC2 / Security Group** | `sg-025d39bbcd6e498ca` (`db_sg`) | `active` | `aws_security_group.db_sg` | **Verified Live** | Phase 5 (Network) | No |
| **EC2 / Security Group** | `sg-062f5922343d0d946` (`alb_sg`) | `active` | `aws_security_group.alb_sg` | **Verified Live** | Phase 5 (Network) | No |
| **EC2 / Security Group** | `sg-0313b7e368981c66e` (`lambda_sg`) | `active` | `aws_security_group.lambda_sg` | **Verified Live** | Phase 5 (Network) | No |
| **EC2 / Subnet** | `subnet-00c7e3570173ad9ac` (`public-1`) | `available` | `aws_subnet.public_1` | **Verified Live** | Phase 5 (Network) | No |
| **EC2 / Subnet** | `subnet-0841b2134835eeb46` (`public-2`) | `available` | `aws_subnet.public_2` | **Verified Live** | Phase 5 (Network) | No |
| **EC2 / Subnet** | `subnet-0590bcf4e7f83b99e` (`private-app-1`)| `available` | `aws_subnet.private_app_1` | **Verified Live** | Phase 5 (Network) | No |
| **EC2 / Subnet** | `subnet-00056e4d7fa32703b` (`private-app-2`)| `available` | `aws_subnet.private_app_2` | **Verified Live** | Phase 5 (Network) | No |
| **EC2 / Subnet** | `subnet-098dc863142d53b31` (`private-db-1`) | `available` | `aws_subnet.private_db_1` | **Verified Live** | Phase 5 (Network) | No |
| **EC2 / Subnet** | `subnet-00a652a5d80acf99f` (`private-db-2`) | `available` | `aws_subnet.private_db_2` | **Verified Live** | Phase 5 (Network) | No |
| **EC2 / VPC** | `vpc-0c0e6084ab7a5ea70` | `available` | `aws_vpc.main` | **Verified Live** | Phase 5 (Network) | No |
| **S3 / Bucket** | `expense-tracker-bucket-yd2026` | `Enabled` | `aws_s3_bucket.expense_bucket` | **Verified Live** | Phase 6 (Storage) | Minimal storage |
| **S3 / Bucket** | `expense-tracker-logs-yd2026` | `Disabled` | `aws_s3_bucket.expense_logs_bucket` | **Verified Live** | Phase 6 (Storage) | Minimal storage |
| **S3 / Bucket** | `expense-tracker-ansible-ssm-yd2026` | `Disabled` | `aws_s3_bucket.ansible_ssm_bucket` | **Verified Live** | Phase 6 (Storage) | None (empty) |
| **Lambda / Function** | `expense-tracker-lambda` | `Active` | `aws_lambda_function.expense_lambda` | **Verified Live** | Phase 2 (Compute) | No (within free tier) |
| **API Gateway / API** | `d3dpf59d6g` (HTTP API) | `active` | `aws_apigatewayv2_api.expense_api` | **Verified Live** | Phase 2 (Ingress) | No (within free tier) |
| **Cognito / User Pool** | `ap-south-1_uaZaEifVt` | `active` | `aws_cognito_user_pool.user_pool` | **Verified Live** | Phase 6 (Storage/Auth) | No (< 50,000 MAU free) |
| **ECR / Repository** | `expense-tracker-frontend` | `active` | `aws_ecr_repository.frontend` | **Verified Live** | Phase 6 (Storage) | Minimal storage |
| **ECR / Repository** | `expense-tracker-backend` | `active` | `aws_ecr_repository.backend` | **Verified Live** | Phase 6 (Storage) | Minimal storage |
| **CloudWatch / Dashboard**| `expense-tracker-dashboard` | `active` | `aws_cloudwatch_dashboard.dash` | **Verified Live** | Phase 6 (Telemetry) | Free (3 dashboards free) |
| **CloudWatch / Log Group**| `/aws/apigateway/expense-tracker` | `active` | `aws_cloudwatch_log_group.api_gw` | **Verified Live** | Phase 6 (Telemetry) | Minimal |
| **CloudWatch / Log Group**| `/aws/lambda/expense-tracker-lambda` | `active` | `aws_cloudwatch_log_group.lambda` | **Verified Live** | Phase 6 (Telemetry) | Minimal |
| **CloudWatch / Alarms (17)**| 17 Metric Alarms (EC2, ALB, RDS, Lambda, NAT)| `OK` | 17x `aws_cloudwatch_metric_alarm` | **Verified Live** | Phase 6 (Telemetry) | **Yes** (Consuming 85.5% free quota) |
| **SNS / Topic** | `arn:...:expense-tracker-alerts` | `active` | `aws_sns_topic.alerts` | **Verified Live** | Phase 6 (Telemetry) | No |
| **SNS / Subscription** | None (`Subscriptions: []`) | `Not Deployed` | `aws_sns_topic_subscription.email_alerts` | **Declared but Absent**| N/A | None |
| **IAM / Role** | `expense-ec2-ssm-role` | `active` | `aws_iam_role.ec2_ssm_role` | **Verified Live** | Phase 7 (IAM) | Free |
| **IAM / Role** | `expense-github-actions-ecr-role` | `active` | `aws_iam_role.github_actions` | **Verified Live** | Phase 7 (IAM) | Free |
| **IAM / Role** | `expense_lambda_role` | `active` | `aws_iam_role.expense_lambda` | **Verified Live** | Phase 7 (IAM) | Free |
| **IAM / Instance Profile**| `expense-ec2-ssm-profile` | `active` | `aws_iam_instance_profile.ssm` | **Verified Live** | Phase 7 (IAM) | Free |
| **IAM / OIDC Provider** | `token.actions.githubusercontent.com` | `active` | `aws_iam_openid_connect_provider` | **Verified Live** | Phase 7 (IAM) | Free |
| **IAM / Policies (9)** | 9 Custom Customer Managed Policies | `active` | 9x `aws_iam_policy` | **Verified Live** | Phase 7 (IAM) | Free |

---

## 3. Discrepancy Investigation

### Discrepancy 1: Declared vs. Deployed Count
- **Finding**: In the initial pre-teardown inventory, 115 resources were declared in Terraform configuration.
- **Audit Verification**: Exactly 114 resources are active in AWS. The single un-deployed resource is `aws_sns_topic_subscription.email_alerts` (`count = 0` due to empty default email).

### Discrepancy 2: External ACM Certificate
- The certificate for `projects.yamandeep.in` was passed via input variable `certificate_arn`.
- It is an account-level asset that must remain intact if the user hosts other projects or intends to preserve DNS TLS certificates.
