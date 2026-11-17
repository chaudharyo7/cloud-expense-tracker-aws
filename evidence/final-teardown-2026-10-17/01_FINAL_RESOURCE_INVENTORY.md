# Final Resource Inventory & Reconciliation Table

**Project**: AWS Cloud Expense Tracker  
**Audit Date**: 2026-10-17  
**Region**: `ap-south-1`  
**Account**: `205639******`  

---

## 1. Resource Reconciliation Summary (Before vs. After)

| AWS Resource Category | Pre-Teardown Verified Count | Post-Teardown Verified Count | Outcome | Verification Method |
| :--- | :--- | :--- | :--- | :--- |
| **EC2 Compute Instances** | 4 | **0** | Terminated | `aws ec2 describe-instances` |
| **EBS Storage Volumes** | 4 (32 GB) | **0** (0 GB) | Deleted | `aws ec2 describe-volumes` |
| **NAT Gateways** | 1 | **0** | Deleted | `aws ec2 describe-nat-gateways` |
| **Elastic IP Addresses** | 3 (1 NAT, 2 ALB) | **0** | Released | `aws ec2 describe-addresses` |
| **Application Load Balancers** | 1 | **0** | Deleted | `aws elbv2 describe-load-balancers` |
| **ALB Target Groups** | 2 | **0** | Deleted | `aws elbv2 describe-target-groups` |
| **RDS DB Instances** | 1 | **0** | Deleted | `aws rds describe-db-instances` |
| **RDS Manual Snapshots** | 0 | **1** | **Retained (Backup)**| `aws rds describe-db-snapshots` |
| **RDS DB Subnet Groups** | 1 | **0** | Deleted | `aws rds describe-db-subnet-groups` |
| **Secrets Manager Secrets** | 1 | **0** | Deleted | `aws secretsmanager list-secrets` |
| **AWS Lambda Functions** | 1 | **0** | Deleted | `aws lambda list-functions` |
| **API Gateway HTTP APIs** | 1 | **0** | Deleted | `aws apigatewayv2 get-apis` |
| **Amazon S3 Buckets** | 3 | **0** | Purged & Deleted | `aws s3api list-buckets` |
| **Amazon ECR Repositories** | 2 | **0** | Deleted | `aws ecr describe-repositories` |
| **CloudWatch Metric Alarms** | 17 | **0** | Deleted | `aws cloudwatch describe-alarms` |
| **CloudWatch Dashboards** | 1 | **0** | Deleted | `aws cloudwatch list-dashboards` |
| **CloudWatch Log Groups** | 2 | **0** | Deleted | `aws logs describe-log-groups` |
| **SNS Topics** | 1 | **0** | Deleted | `aws sns list-topics` |
| **Cognito User Pools** | 1 | **0** | Deleted | `aws cognito-idp list-user-pools` |
| **VPC Gateways (IGW / VPCE)** | 2 | **0** | Deleted | `aws ec2 describe-internet-gateways` |
| **VPC Subnets** | 6 | **0** | Deleted | `aws ec2 describe-subnets` |
| **VPC Route Tables (Custom)** | 3 | **0** | Deleted | `aws ec2 describe-route-tables` |
| **VPC Security Groups (Custom)**| 5 | **0** | Deleted | `aws ec2 describe-security-groups` |
| **Custom Virtual Private Clouds**| 1 | **0** | Deleted | `aws ec2 describe-vpcs` |
| **IAM Instance Profiles** | 1 | **0** | Deleted | `aws iam list-instance-profiles` |
| **IAM Application Roles** | 3 | **0** | Deleted | `aws iam list-roles` |
| **IAM Customer Managed Policies**| 9 | **0** | Deleted | `aws iam list-policies` |
| **Shared ACM Certificate** | 1 | **1** | **Preserved (Protected)**| `aws acm list-certificates` |
| **Default VPC & Default Subnets**| 1 | **1** | **Preserved (Shared)** | `aws ec2 describe-vpcs` |

---

## 2. Resource-by-Resource Execution Record

| Resource Identifier | Resource Name / Type | Pre-Teardown State | Final State |
| :--- | :--- | :--- | :--- |
| `i-0b0294fc87c9ac832` | `expense-tracker-frontend-1` | running | **Terminated** |
| `i-0d180a9a22ab66f1a` | `expense-tracker-frontend-2` | running | **Terminated** |
| `i-0a973fbbf1c0e01e3` | `expense-tracker-backend-1` | running | **Terminated** |
| `i-048b2374625ee144e` | `expense-tracker-backend-2` | running | **Terminated** |
| `vol-0fa935f3d760752d9` | 8GB gp3 EBS (frontend-1) | in-use | **Deleted** |
| `vol-02a98a774e69f72ca` | 8GB gp3 EBS (frontend-2) | in-use | **Deleted** |
| `vol-09c60a37584778b0d` | 8GB gp3 EBS (backend-1) | in-use | **Deleted** |
| `vol-0dd9c0a4661577e6a` | 8GB gp3 EBS (backend-2) | in-use | **Deleted** |
| `arn:...:loadbalancer/app/expense-alb/489f...` | `expense-alb` (ALB) | active | **Deleted** |
| `arn:...:targetgroup/expense-target-group-backend/...` | Backend TG | active | **Deleted** |
| `arn:...:targetgroup/expense-target-group-frontend/...` | Frontend TG | active | **Deleted** |
| `nat-00b6ef51e976e5998` | `expense-tracker-nat-gateway` | available | **Deleted** |
| `eipalloc-032da56bffc50c262` | NAT Gateway Elastic IP | associated | **Released** |
| `eipalloc-0614a80423136e81d` | ALB Managed Elastic IP 1 | associated | **Released** |
| `eipalloc-0cd9c1792aab159bb` | ALB Managed Elastic IP 2 | associated | **Released** |
| `expense-tracker-db` | RDS PostgreSQL 17.9 | available | **Deleted** |
| `expense-db-subnet-group` | RDS Subnet Group | Complete | **Deleted** |
| `arn:...:secret:rds!db-22302a8e...` | Secrets Manager Master Secret | active | **Deleted** |
| `expense-tracker-lambda` | AWS Lambda (Python 3.12) | Active | **Deleted** |
| `d3dpf59d6g` | API Gateway HTTP API | active | **Deleted** |
| `expense-tracker-bucket-yd2026` | S3 Report Storage Bucket | active | **Purged & Deleted** |
| `expense-tracker-logs-yd2026` | S3 Access Logging Bucket | active | **Purged & Deleted** |
| `expense-tracker-ansible-ssm-yd2026` | S3 Ansible Transport Bucket | active | **Purged & Deleted** |
| `expense-tracker-frontend` | ECR Docker Image Repository | active | **Deleted** |
| `expense-tracker-backend` | ECR Docker Image Repository | active | **Deleted** |
| `expense-tracker-dashboard` | CloudWatch Dashboard | active | **Deleted** |
| `/aws/apigateway/expense-tracker` | CloudWatch Log Group | active | **Deleted** |
| `/aws/lambda/expense-tracker-lambda` | CloudWatch Log Group | active | **Deleted** |
| `arn:...:expense-tracker-alerts` | Amazon SNS Topic | active | **Deleted** |
| `ap-south-1_uaZaEifVt` | Cognito User Pool | active | **Deleted** |
| `igw-0671a80fa042e5e38` | VPC Internet Gateway | available | **Deleted** |
| `vpce-07109946b5c3f8627` | VPC Gateway Endpoint for S3 | available | **Deleted** |
| `subnet-00c7e3570173ad9ac` | Public Subnet 1 | available | **Deleted** |
| `subnet-0841b2134835eeb46` | Public Subnet 2 | available | **Deleted** |
| `subnet-0590bcf4e7f83b99e` | Private App Subnet 1 | available | **Deleted** |
| `subnet-00056e4d7fa32703b` | Private App Subnet 2 | available | **Deleted** |
| `subnet-098dc863142d53b31` | Private DB Subnet 1 | available | **Deleted** |
| `subnet-00a652a5d80acf99f` | Private DB Subnet 2 | available | **Deleted** |
| `rtb-0c7000649511dd55c` | Public Route Table | available | **Deleted** |
| `rtb-0d5d13fdd17ceef60` | Private App Route Table | available | **Deleted** |
| `rtb-0cf9ba9e14e8f5f04` | Private DB Route Table | available | **Deleted** |
| `sg-0da1e182fb34451f4` | Security Group `public_sg` | active | **Deleted** |
| `sg-06b195c60984cc4bb` | Security Group `app_sg` | active | **Deleted** |
| `sg-025d39bbcd6e498ca` | Security Group `db_sg` | active | **Deleted** |
| `sg-062f5922343d0d946` | Security Group `alb_sg` | active | **Deleted** |
| `sg-0313b7e368981c66e` | Security Group `lambda_sg` | active | **Deleted** |
| `vpc-0c0e6084ab7a5ea70` | Custom VPC `expense-tracker-vpc` | available | **Deleted** |
| `expense-ec2-ssm-profile` | IAM Instance Profile | active | **Deleted** |
| `expense-ec2-ssm-role` | IAM EC2 Role | active | **Deleted** |
| `expense-github-actions-ecr-role`| IAM GitHub Actions OIDC Role | active | **Deleted** |
| `expense_lambda_role` | IAM Lambda Execution Role | active | **Deleted** |
| 9x Customer Managed Policies | IAM Policies (SSM, ECR, S3, etc.) | active | **Deleted** |
| 17x CloudWatch Metric Alarms | System Metric Alarms | OK | **Deleted** |
