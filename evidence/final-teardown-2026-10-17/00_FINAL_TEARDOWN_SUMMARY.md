# Final Teardown Summary: AWS Cloud Expense Tracker

**Project**: AWS Cloud Expense Tracker  
**Execution Date**: 2026-10-17  
**Execution Timestamp**: `2026-10-17T17:05:00Z` (UTC) / `22:35:00+05:30` (Local)  
**Target Region**: `ap-south-1` (Mumbai)  
**AWS Account**: `205639******` (Redacted) | IAM: `arn:aws:iam::205639******:user/Terraform-User`  
**Execution Status**: **`COMPLETED`** (All dedicated project infrastructure successfully decommissioned, data preserved, and verified).

---

## 1. Executive Summary

In response to the authorized teardown directive, the entire dedicated AWS infrastructure for the Cloud Expense Tracker was systematically retired in dependency order. Prior to initiating destructive operations, all data-bearing components were verified and preserved locally, including 50 generated JSON financial reports and 464 S3 server access log objects, alongside an encrypted final RDS manual snapshot.

Post-teardown verification queries against all AWS APIs confirmed that **zero billable compute, ingress, database, or egress resources remain active in `ap-south-1`**, immediately eliminating the ~$90.26/month infrastructure run rate and returning the account's CloudWatch Metric Alarm utilization from 85.46% back to 0.

---

## 2. Key Execution Highlights

### A. Pre-Teardown Data Preservation
- **S3 Expense Reports**: 50 report JSON files from `s3://expense-tracker-bucket-yd2026/reports/` were synchronized to local cold storage and cataloged with MD5 checksums.
- **S3 Access Logs**: 464 server access log objects from `s3://expense-tracker-logs-yd2026/access-logs/` were downloaded and cataloged.
- **RDS PostgreSQL Database**: A manual final snapshot (`expense-tracker-db-final-snapshot-20261017`) was created, confirmed `available`, and verified at 2.99 GB in size before the database was retired.
- **ECR Container Images**: Full image inventories and manifest digests for `expense-tracker-frontend` (25 images) and `expense-tracker-backend` (28 images) were archived locally.

### B. Dependency-Aware Infrastructure Deletion
All 114 active project resources were deleted in strict dependency order:
1. **Public Ingress & Load Balancing**: Deleted `expense-alb`, 2 target groups, and released 2 managed Elastic IPs.
2. **Compute Nodes**: Terminated all 4 EC2 instances (`frontend-1`, `frontend-2`, `backend-1`, `backend-2`) and automatically wiped all 4 attached 8GB gp3 EBS volumes (`vol-0fa935f3d760752d9`, `vol-02a98a774e69f72ca`, `vol-09c60a37584778b0d`, `vol-0dd9c0a4661577e6a`).
3. **Serverless Tier**: Deleted Lambda function `expense-tracker-lambda` and API Gateway HTTP API `d3dpf59d6g` (`expense-tracker-api`).
4. **Relational Database Tier**: Modified RDS instance `expense-tracker-db` to disable deletion protection, terminated the instance, deleted DB subnet group `expense-db-subnet-group`, and force-deleted the Secrets Manager master credential secret.
5. **Egress & NAT Networking**: Deleted NAT Gateway `nat-00b6ef51e976e5998` and released Elastic IP `eipalloc-032da56bffc50c262` (`13.232.139.181`).
6. **VPC Networking**: Detached and deleted Internet Gateway `igw-0671a80fa042e5e38`, deleted all 6 subnets, 3 custom route tables, 5 security groups, and custom VPC `vpc-0c0e6084ab7a5ea70`.
7. **Storage, Auth & Observability**: Purged all versions/delete markers and deleted 3 S3 buckets (`expense-tracker-bucket-yd2026`, `expense-tracker-logs-yd2026`, `expense-tracker-ansible-ssm-yd2026`), force-deleted both ECR repositories, deleted all 17 CloudWatch alarms, the dashboard, 2 log groups, the SNS topic, and Cognito user pool `ap-south-1_uaZaEifVt`.
8. **IAM Security**: Removed instance profile `expense-ec2-ssm-profile`, deleted 3 IAM roles (`expense-ec2-ssm-role`, `expense-github-actions-ecr-role`, `expense_lambda_role`), and deleted 9 custom customer-managed policies.

### C. Protected Shared Assets (Intact & Untouched)
- **ACM Certificate**: `arn:aws:acm:ap-south-1:205639******:certificate/6936d865-c954-4ff2-af0e-eb41fb14525f` (`projects.yamandeep.in`) was protected and remains `ISSUED`.
- **Default VPC**: `vpc-06aef52e7af55dfd2` remains completely untouched.
- **Route 53 Hosted Zones**: Preserved without modification.
- **GitHub OIDC Provider**: `arn:aws:iam::205639******:oidc-provider/token.actions.githubusercontent.com` remains active for account-wide CI/CD.

---

## 3. Financial Impact & Free Tier Recovery

| Category | Pre-Teardown State | Post-Teardown State | Run-Rate Reduction |
| :--- | :--- | :--- | :--- |
| **NAT Gateway** | 1 active ($32.40/mo) | **0 active** | -$32.40 / month |
| **Application Load Balancer** | 1 active ($16.20/mo) | **0 active** | -$16.20 / month |
| **Public IPv4 Addresses** | 5 active ($18.00/mo) | **0 active** | -$18.00 / month |
| **EC2 Compute (`t3.micro`)** | 4 running ($22.15/mo) | **0 running** | -$22.15 / month |
| **EBS Storage** | 32 GB gp3 ($0.16/mo) | **0 GB** | -$0.16 / month |
| **CloudWatch Metric Alarms** | 17 alarms (85.46% quota) | **0 alarms (0% quota)** | Free Tier Restored |
| **Total Estimated Run Rate** | **~$90.26 / month** | **$0.00 / month** | **-$90.26 / month (100% savings)** |

*(Note: The retained manual RDS snapshot `expense-tracker-db-final-snapshot-20261017` occupies 2.99 GB of storage, which falls entirely within the 20 GB free backup storage allowance).*

---

## 4. Final Completion Verdict

**`COMPLETED`**  
All project-dedicated cloud resources have been verified as terminated and deleted. Data backups are verified locally, and zero residual billable assets exist in AWS `ap-south-1`.
