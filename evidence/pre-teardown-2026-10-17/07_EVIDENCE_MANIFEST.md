# Evidence Manifest & Audit Trail

**Project**: Cloud Expense Tracker AWS  
**Date of Audit**: 2026-10-17  
**Collection Timestamp**: `2026-10-17T01:38:00Z` (UTC) / `07:08:00+05:30` (Local)  
**Evaluator**: Antigravity Assistant  
**Authentication**: AWS IAM User `arn:aws:iam::205639******:user/Terraform-User`  

---

## 1. Evidence Artifacts Generated

The following files have been saved to directory:
`/Users/chaudhary/Codes/Personel/Devops-practice/cloud-expense-tracker-aws/evidence/pre-teardown-2026-10-17/`

| File Name | Description | Status |
| :--- | :--- | :--- |
| `00_EXECUTIVE_SUMMARY.md` | High-level synthesis, root cause of 85% alert, and risk overview. | **Complete** |
| `01_ARCHITECTURE.md` | Architectural diagram, tier topology, and AWS service interactions. | **Complete** |
| `02_TERRAFORM_INVENTORY.md` | Comparison of Terraform configuration (115 declared) vs local state (0 tracked). | **Complete** |
| `03_AWS_RESOURCE_INVENTORY.md` | Full inventory of confirmed live AWS resources queried via AWS CLI. | **Complete** |
| `04_COST_AND_BUDGET.md` | Free Tier usage breakdown, Cost Explorer data, and monthly run rate analysis. | **Complete** |
| `05_DATA_PRESERVATION.md` | Identification of 49 S3 reports and RDS database data needing backup. | **Complete** |
| `06_TEARDOWN_READINESS.md` | Assessment of blockers (RDS deletion protection, non-empty S3, missing state) and sequenced teardown guide. | **Complete** |
| `07_EVIDENCE_MANIFEST.md` | This audit trail, command log, and skipped checks record. | **Complete** |
| `terraform_state_resource_addresses.txt` | Complete list of declared Terraform resource addresses and state absence notation. | **Complete** |
| `aws_resource_inventory.json` | Machine-readable, sanitized JSON inventory of all discovered AWS resources. | **Complete** |
| `screenshots/README.md` | Policy documentation explaining CLI-only evidence to prevent credential exposure. | **Complete** |

---

## 2. Command Execution Log (Read-Only)

All commands used during this evidence gathering were strictly read-only:

```bash
# Identity & Account Verification
aws sts get-caller-identity

# Compute Tier Telemetry
aws ec2 describe-instances --region ap-south-1
aws ec2 describe-volumes --region ap-south-1
aws ec2 describe-snapshots --owner-ids self --region ap-south-1
aws lambda list-functions --region ap-south-1
aws ecr describe-repositories --region ap-south-1
aws ecr list-images --repository-name expense-tracker-frontend --region ap-south-1
aws ecr list-images --repository-name expense-tracker-backend --region ap-south-1

# Networking & Ingress Telemetry
aws ec2 describe-vpcs --region ap-south-1
aws ec2 describe-subnets --region ap-south-1
aws ec2 describe-nat-gateways --region ap-south-1
aws ec2 describe-addresses --region ap-south-1
aws ec2 describe-internet-gateways --region ap-south-1
aws ec2 describe-route-tables --region ap-south-1
aws ec2 describe-security-groups --region ap-south-1
aws ec2 describe-vpc-endpoints --region ap-south-1
aws elbv2 describe-load-balancers --region ap-south-1
aws elbv2 describe-target-groups --region ap-south-1
aws apigatewayv2 get-apis --region ap-south-1

# Database & Secrets Telemetry
aws rds describe-db-instances --region ap-south-1
aws secretsmanager list-secrets --region ap-south-1
aws dynamodb list-tables --region ap-south-1

# Storage Telemetry (Metadata Only - No Object Content Downloaded)
aws s3api list-buckets
aws s3api get-bucket-versioning --bucket <bucket-name>
aws s3api list-objects-v2 --bucket <bucket-name> --query "Contents[].Key"

# Observability Telemetry
aws logs describe-log-groups --region ap-south-1
aws cloudwatch list-dashboards --region ap-south-1
aws cloudwatch describe-alarms --region ap-south-1
aws sns list-topics --region ap-south-1

# Billing & Free Tier Telemetry
aws freetier get-free-tier-usage
aws ce get-cost-and-usage --time-period Start=2026-10-01,End=2026-10-17 --granularity MONTHLY --metrics "UnblendedCost" --group-by Type=DIMENSION,Key=SERVICE
aws ce get-cost-and-usage --time-period Start=2026-10-01,End=2026-10-17 --granularity DAILY --metrics "UnblendedCost" "NetUnblendedCost"

# Local Terraform & Git Status
git status
git log -5 --oneline
terraform version
terraform workspace show
terraform state list
```

---

## 3. Skipped Checks & Justifications

| Check / Operation | Status | Justification |
| :--- | :--- | :--- |
| `terraform destroy` / `terraform apply` | **SKIPPED** | Strictly prohibited by safety mandate; would alter or delete infrastructure. |
| Object Content Downloads (`s3 cp` / `s3 sync`) | **SKIPPED** | Non-destructive evidence phase; metadata and object keys were enumerated without downloading payload data. |
| RDS Master Password / Secret SecretValue | **SKIPPED** | Mandated security compliance; no secrets or private keys were printed or retrieved. |
| AWS Management Console Browser Capture | **SKIPPED** | Avoided browser-based session captures to eliminate risk of exposing session tokens, credentials, or unredacted account numbers. |
| AWS Budgets API (`aws budgets describe-budgets`) | **SKIPPED (Empty Result)** | No AWS Budgets instances are configured under this account ID. The 85% notification was traced directly to AWS Free Tier CloudWatch alarms. |
