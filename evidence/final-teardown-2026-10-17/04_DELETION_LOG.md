# Chronological Deletion Log & Command Execution Record

**Project**: AWS Cloud Expense Tracker  
**Audit Date**: 2026-10-17  
**Executor**: Antigravity Assistant  
**Authentication**: `arn:aws:iam::205639******:user/Terraform-User`  

---

## 1. Chronological Execution Timeline

### Step 1: Pre-Teardown Verification & Backup Synchronization (22:02 - 22:15 IST)
```bash
# 1.1 Verify Caller Identity
aws sts get-caller-identity
# Output: Account 205639151266, User Terraform-User (Exit code: 0)

# 1.2 Sync S3 Reports
aws s3 sync s3://expense-tracker-bucket-yd2026/reports/ evidence/final-teardown-2026-10-17/backups/s3_reports/
# Output: 50 JSON reports downloaded successfully (Exit code: 0)

# 1.3 Sync S3 Access Logs
aws s3 sync s3://expense-tracker-logs-yd2026/access-logs/ evidence/final-teardown-2026-10-17/backups/access_logs/
# Output: 464 access log objects downloaded successfully (Exit code: 0)

# 1.4 Validate Final RDS Snapshot
aws rds describe-db-snapshots --db-snapshot-identifier expense-tracker-db-final-snapshot-20261017 --region ap-south-1
# Output: Status 'available', Size 2.99 GB, KMS encrypted (Exit code: 0)

# 1.5 Export ECR Manifests
aws ecr describe-images --repository-name expense-tracker-frontend > frontend_images.json
aws ecr describe-images --repository-name expense-tracker-backend > backend_images.json
# Output: Full image inventories saved (Exit code: 0)
```

---

### Step 2: Public Ingress & Compute Teardown (22:16 - 22:27 IST)
```bash
# 2.1 Delete Application Load Balancer
aws elbv2 delete-load-balancer \
  --load-balancer-arn "arn:aws:elasticloadbalancing:ap-south-1:205639******:loadbalancer/app/expense-alb/489f800913f5d0ca"
aws elbv2 wait load-balancers-deleted \
  --load-balancer-arns "arn:aws:elasticloadbalancing:ap-south-1:205639******:loadbalancer/app/expense-alb/489f800913f5d0ca"
# Outcome: ALB deleted and confirmed gone (Exit code: 0)

# 2.2 Delete ALB Target Groups
aws elbv2 delete-target-group \
  --target-group-arn "arn:aws:elasticloadbalancing:ap-south-1:205639******:targetgroup/expense-target-group-backend/6bd200de57afa585"
aws elbv2 delete-target-group \
  --target-group-arn "arn:aws:elasticloadbalancing:ap-south-1:205639******:targetgroup/expense-target-group-frontend/901d857d13ef5055"
# Outcome: Both target groups deleted (Exit code: 0)

# 2.3 Terminate EC2 Compute Instances
aws ec2 terminate-instances --instance-ids i-0b0294fc87c9ac832 i-0d180a9a22ab66f1a i-0a973fbbf1c0e01e3 i-048b2374625ee144e
# Outcome: All 4 instances terminated; 4 attached EBS volumes automatically destroyed (Exit code: 0)
```

---

### Step 3: Serverless, Database & Secrets Teardown (22:27 - 22:28 IST)
```bash
# 3.1 Verify and Confirm Deletion of Lambda, API Gateway, and RDS DB Instance
aws lambda list-functions --region ap-south-1
aws apigatewayv2 get-apis --region ap-south-1
aws rds describe-db-instances --region ap-south-1
# Outcome: All reported empty []. Functions, APIs, and RDS instances confirmed completely terminated (Exit code: 0)
```

---

### Step 4: NAT Gateway & Egress Teardown (22:28 - 22:29 IST)
```bash
# 4.1 Delete NAT Gateway
aws ec2 delete-nat-gateway --nat-gateway-id nat-00b6ef51e976e5998 --region ap-south-1
aws ec2 wait nat-gateway-deleted --nat-gateway-ids nat-00b6ef51e976e5998 --region ap-south-1
# Outcome: NAT Gateway reached 'deleted' state (Exit code: 0)

# 4.2 Release Elastic IP
aws ec2 release-address --allocation-id eipalloc-032da56bffc50c262 --region ap-south-1
# Outcome: Elastic IP released immediately (Exit code: 0)
```

---

### Step 5: Observability, Telemetry, Auth & ECR Teardown (22:28 - 22:29 IST)
```bash
# 5.1 Delete all 17 CloudWatch Metric Alarms
aws cloudwatch delete-alarms --alarm-names alb-backend-unhealthy-hosts alb-target-5xx-errors-elevated alb-target-response-time-high ec2-backend-1-cpu-high ec2-backend-1-status-check-failed ec2-backend-2-status-check-failed ec2-frontend-1-status-check-failed ec2-frontend-2-status-check-failed lambda-report-duration-high lambda-report-generation-errors lambda-report-throttles nat-gateway-packets-drop nat-gateway-port-allocation-error rds-cpu-utilization-high rds-database-connections-high rds-free-storage-low rds-freeable-memory-low --region ap-south-1
# Outcome: 17 alarms deleted (Exit code: 0)

# 5.2 Delete CloudWatch Dashboard and Log Groups
aws cloudwatch delete-dashboards --dashboard-names expense-tracker-dashboard --region ap-south-1
aws logs delete-log-group --log-group-name /aws/apigateway/expense-tracker --region ap-south-1
aws logs delete-log-group --log-group-name /aws/lambda/expense-tracker-lambda --region ap-south-1
# Outcome: Observability assets deleted (Exit code: 0)

# 5.3 Delete SNS Topic
aws sns delete-topic --topic-arn "arn:aws:sns:ap-south-1:205639******:expense-tracker-alerts" --region ap-south-1
# Outcome: SNS Topic deleted (Exit code: 0)

# 5.4 Delete Cognito User Pool
aws cognito-idp delete-user-pool --user-pool-id ap-south-1_uaZaEifVt --region ap-south-1
# Outcome: Cognito pool deleted (Exit code: 0)

# 5.5 Delete ECR Repositories
aws ecr delete-repository --repository-name expense-tracker-frontend --force --region ap-south-1
aws ecr delete-repository --repository-name expense-tracker-backend --force --region ap-south-1
# Outcome: Both ECR repositories deleted (Exit code: 0)

# 5.6 Delete S3 VPC Gateway Endpoint
aws ec2 delete-vpc-endpoints --vpc-endpoint-ids vpce-07109946b5c3f8627 --region ap-south-1
# Outcome: Endpoint deleted (Exit code: 0)
```

---

### Step 6: S3 Bucket Purge & Deletion (22:29 - 22:30 IST)
```bash
# 6.1 Purge versions, delete markers, and remove buckets
aws s3api delete-objects --bucket expense-tracker-bucket-yd2026 ...
aws s3 rb s3://expense-tracker-bucket-yd2026 --force
aws s3 rb s3://expense-tracker-logs-yd2026 --force
aws s3 rb s3://expense-tracker-ansible-ssm-yd2026 --force
# Outcome: All 3 buckets purged and permanently deleted (Exit code: 0)
```

---

### Step 7: VPC Networking Teardown (22:30 - 22:31 IST)
```bash
# 7.1 Detach & Delete Internet Gateway
aws ec2 detach-internet-gateway --internet-gateway-id igw-0671a80fa042e5e38 --vpc-id vpc-0c0e6084ab7a5ea70
aws ec2 delete-internet-gateway --internet-gateway-id igw-0671a80fa042e5e38

# 7.2 Delete 6 Subnets
aws ec2 delete-subnet --subnet-id subnet-00c7e3570173ad9ac ... (repeated for all 6 subnets)

# 7.3 Delete 3 Custom Route Tables
aws ec2 delete-route-table --route-table-id rtb-0d5d13fdd17ceef60
aws ec2 delete-route-table --route-table-id rtb-0cf9ba9e14e8f5f04
aws ec2 delete-route-table --route-table-id rtb-0c7000649511dd55c

# 7.4 Delete 5 Custom Security Groups
aws ec2 delete-security-group --group-id sg-0da1e182fb34451f4
aws ec2 delete-security-group --group-id sg-06b195c60984cc4bb
aws ec2 delete-security-group --group-id sg-025d39bbcd6e498ca
aws ec2 delete-security-group --group-id sg-062f5922343d0d946
aws ec2 delete-security-group --group-id sg-0313b7e368981c66e

# 7.5 Delete Custom VPC
aws ec2 delete-vpc --vpc-id vpc-0c0e6084ab7a5ea70
# Outcome: VPC and all associated networking removed (Exit code: 0)
```

---

### Step 8: IAM Roles & Policies Teardown (22:31 - 22:34 IST)
```bash
# 8.1 Remove and Delete Instance Profile
aws iam remove-role-from-instance-profile --instance-profile-name expense-ec2-ssm-profile --role-name expense-ec2-ssm-role
aws iam delete-instance-profile --instance-profile-name expense-ec2-ssm-profile

# 8.2 Detach Policies and Delete Roles
aws iam delete-role --role-name expense-ec2-ssm-role
aws iam delete-role --role-name expense-github-actions-ecr-role
aws iam delete-role --role-name expense_lambda_role

# 8.3 Detach and Delete 9 Customer Managed Policies
aws iam delete-policy --policy-arn arn:aws:iam::205639******:policy/expense-github-actions-ssm-deployment-policy ... (all 9 policies)
# Outcome: All project-specific IAM roles and policies deleted (Exit code: 0)
```
