# Executive Summary: Pre-Teardown Evidence Collection

**Project Name**: AWS Cloud Expense Tracker  
**Date of Collection**: 2026-10-17  
**Evaluator**: Antigravity Assistant  
**AWS Region**: `ap-south-1` (Asia Pacific - Mumbai)  
**AWS Account**: `205639******` (Redacted)  
**Execution Mode**: **Strictly Read-Only (Zero Infrastructure Modifications)**  

---

## 1. Project Background & Scope

The Cloud Expense Tracker is a multi-tier AWS cloud architecture designed with declarative Infrastructure as Code (Terraform), zero-SSH configuration management (AWS Systems Manager via Ansible), containerized microservices (EC2 + Docker + ECR), relational persistence (RDS PostgreSQL 17), and serverless reporting (AWS Lambda + S3 + API Gateway HTTP API).

The infrastructure has been operational in AWS since late September 2026 (~3 weeks uptime). The user initiated this review after receiving notifications that AWS usage/budget had reached approximately 85%.

**Scope of this task**: Comprehensive, non-destructive evidence gathering across Terraform state, AWS infrastructure inventories, cost and usage telemetry, data preservation needs, and teardown risks. **No resources were deleted, modified, stopped, or recreated during this evaluation.**

---

## 2. Key Findings & Discoveries

### A. The 85% Usage Threshold Root Cause Identified
Through the AWS Free Tier API (`aws freetier get-free-tier-usage`), the exact source of the 85% notification was definitively pinpointed:
- **Service**: Amazon CloudWatch Alarm Monitoring (`CW:AlarmMonitorUsage`)
- **Current Usage**: **8.55 alarm-months**
- **Free Tier Limit**: **10.0 alarm-months**
- **Percentage Utilized**: **85.46%**
- **Forecasted Usage**: **16.56 alarm-months (165.6% of allowance)**
- **Impact**: The Terraform stack provisions 17 metric alarms. Once usage passes 10 alarm-months, AWS bills additional alarms at standard rates ($0.10/alarm/month).

### B. Critical Terraform State Discrepancy
- **Local State Status**: There is **no local `terraform.tfstate` file** in the repository workspace.
- **`terraform state list`**: Returned `No state file was found!`.
- **Declared Configuration**: 115 resources declared in `terraform/*.tf`.
- **Live AWS Status**: All primary resources corresponding to the 115 declared resources are actively provisioned and running in AWS (VPC, 6 subnets, NAT Gateway, ALB, 4 EC2 instances, RDS PostgreSQL, S3 buckets, Lambda, Cognito, ECR, CloudWatch).
- **Risk Assessment**: If a user runs `terraform destroy` without restoring or importing state, Terraform detects 0 tracked resources and deletes nothing. Conversely, running `terraform apply` attempts to create duplicate resources, resulting in immediate naming and CIDR collisions. A formal state recovery/import or scripted teardown plan is required before any teardown can safely occur.

### C. Live Billable Resource Footprint
The active AWS infrastructure contains several components that incur ongoing hourly or monthly charges:
1. **NAT Gateway (`nat-00b6ef51e976e5998`)**: Running since 2026-09-29. Base rate ~$0.045/hour (~$32.40/month) + data processing.
2. **Application Load Balancer (`expense-alb`)**: Running since 2026-09-24. Base rate ~$0.0225/hour (~$16.20/month) + LCU hours.
3. **In-Use Public IPv4 Addresses**: Since Feb 2024, AWS charges $0.005/hr/IP. There are at least 5 active public IPs (2 for ALB, 1 for NAT EIP, 2 for frontend EC2s) = ~$18.00/month.
4. **EC2 Instances (4x t3.micro)**: 4 instances running 24/7 = 2,880 instance-hours/month, exceeding the single-instance 750 free tier hours by 2,130 hours (~$22.15/month).
5. **RDS PostgreSQL (`expense-tracker-db`)**: Covered by initial 12-month Free Tier (750 hours/month of db.t3.micro + 20GB gp3 storage).
6. **EBS Volumes (4x 8GB = 32GB gp3)**: 2GB above the 30GB free tier allowance (~$0.16/month).

---

## 3. Critical Teardown Blockers & Safeguards

Before any infrastructure destruction can be approved in the future, the following safeguards must be addressed:

| Safeguard / Blocker | Current State | Risk if Ignored | Required Action Prior to Teardown |
| :--- | :--- | :--- | :--- |
| **RDS Deletion Protection** | **`DeletionProtection: true`** | `terraform destroy` will fail with an error when trying to delete the DB. | Must disable deletion protection explicitly before teardown. |
| **Non-Empty S3 Bucket** | `expense-tracker-bucket-yd2026` has 49 reports; `logs` bucket has access logs. | S3 API rejects bucket deletion if objects or versions exist. | Back up desired report files locally, then purge bucket objects. |
| **Missing Terraform State** | `terraform.tfstate` is absent locally. | Terraform cannot locate or delete cloud resources. | Either import resources into a state file or execute an orderly teardown via AWS CLI. |
| **GitHub Actions OIDC Trust** | `arn:aws:iam::205639******:role/expense-github-actions-ecr-role` | Automated CI/CD runs will fail if role/OIDC is removed while workflows run. | Disable or coordinate GitHub Actions workflow triggers. |

---

## 4. Teardown Readiness Verdict

- **Evidence Sufficiency**: **Sufficient & Complete.** Full inventory of all live components, configurations, cost factors, and dependencies has been recorded without altering any cloud resources.
- **Teardown Action**: **HOLD / DO NOT DESTROY.** As instructed, no destructive actions have been performed. Await explicit review and approval of the recommended teardown sequencing plan.
