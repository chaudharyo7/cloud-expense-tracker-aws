# Second-Phase Teardown Review & Audit Summary

**Project**: AWS Cloud Expense Tracker  
**Audit Phase**: Second-Phase Read-Only Audit & Teardown Runbook  
**Review Date**: 2026-10-17  
**Evaluator**: Antigravity Assistant  
**AWS Account**: `205639******` (Redacted) | IAM: `arn:aws:iam::205639******:user/Terraform-User`  
**Region**: `ap-south-1`  
**Execution Mode**: **Strictly Read-Only (Zero Infrastructure Modifications)**  

---

## 1. Executive Summary & Audit Scope

This second-phase review builds directly on the initial pre-teardown evidence collected on 2026-10-17. The primary objective is to verify the missing Terraform state situation, reconcile live AWS resources against configuration definitions, validate cost and Free Tier consumption claims, establish data preservation requirements, and provide a dependency-aware teardown runbook without executing any destructive commands.

All findings in this document were corroborated through live read-only AWS CLI queries (`aws ec2`, `aws elbv2`, `aws rds`, `aws s3api`, `aws lambda`, `aws apigatewayv2`, `aws cloudwatch`, `aws freetier`, `aws ce`) and local inspection of the Terraform codebase.

---

## 2. Key Audit Determinations

### A. Terraform State Situation (Task A)
- **Local State Missing**: The Terraform workspace is set to `default`. No other workspaces exist. The backend is configured as `local` (in `terraform/vpc.tf`), but no `terraform.tfstate` file exists anywhere in the repository, git history, or workspace filesystem.
- **Root Cause of State Absence**: The repository `.gitignore` ignores `*.tfstate*` and `.terraform/`. While the infrastructure was deployed declaratively via Terraform in late September 2026, the state file was never committed (as expected for secrets), and was subsequently cleared or created in an ephemeral execution environment.
- **Destruction Implication**: Running `terraform destroy` in the current workspace **will not delete any AWS resources**. Terraform will read an empty state and exit with `No changes. No objects need to be destroyed.` Attempting to blindly import 115 declared resources is fraught with risk due to drift, calculated attributes, and provider schema differences. A dependency-aware CLI teardown or selective import is required.

### B. Live Infrastructure Reconciliation (Task B)
- **Declared vs. Deployed**:
  - Exactly **115 resource blocks** are declared across `terraform/*.tf`.
  - Exactly **114 of these resources** were confirmed provisioned and active in AWS `ap-south-1`.
  - **1 declared resource was NEVER deployed**: `aws_sns_topic_subscription.email_alerts` in `cloudwatch.tf`. Live inspection of SNS topic `expense-tracker-alerts` showed `Subscriptions: []` because the input variable `alert_email` defaulted to `""`, resulting in `count = 0`.
- **External Shared Resources Discovered**:
  - The Application Load Balancer (`expense-alb`) utilizes ACM Certificate `arn:aws:acm:ap-south-1:205639******:certificate/6936d865-c954-4ff2-af0e-eb41fb14525f` issued for `projects.yamandeep.in`.
  - This ACM certificate is **NOT managed by Terraform**. It is an external dependency managed outside this codebase and **must NOT be deleted** during infrastructure teardown.

### C. Cost & Free Tier Validation (Task E)
- **Verified Source of 85% Alert**: Real-time AWS Free Tier telemetry confirms that **Amazon CloudWatch Alarm Monitor Usage (`CW:AlarmMonitorUsage`)** is at **8.55 alarm-months utilized out of 10.0 free alarm-months (85.46%)**, with an end-of-month projection of **16.56 alarm-months (165.6%)**. The 17 configured alarms are consuming the free quota and will trigger overage charges ($0.10/alarm/month) once 10.0 is passed.
- **Estimated Run Rate**: The ongoing baseline run rate of the infrastructure is approximately **$88.50 - $92.50 / month**, driven primarily by the NAT Gateway (~$32.40/mo), Application Load Balancer (~$16.20/mo), 5 in-use public IPv4 addresses (~$18.00/mo), and multi-instance EC2 compute exceeding single-instance free tier allowances (~$22.15/mo).

### D. Critical Blockers to Teardown (Task D)
1. **RDS Deletion Protection**: Enabled on `expense-tracker-db`. Must be explicitly disabled via AWS CLI before RDS termination.
2. **Non-Empty S3 Bucket**: `expense-tracker-bucket-yd2026` contains **49 report JSON files** (versioning enabled). S3 API will reject bucket deletion until all versions are purged.
3. **Missing Terraform State**: Precludes simple `terraform destroy`.

---

## 3. Teardown Readiness Verdict

| Readiness Dimension | Status | Notes |
| :--- | :--- | :--- |
| **Evidence & Inventory** | **COMPLETE** | 100% of live resources mapped to configuration. |
| **Data Preservation Plan** | **DEFINED** | 49 S3 reports and RDS snapshot steps cataloged. |
| **Teardown Sequence** | **DEFINED** | Strict reverse-dependency ordering provided. |
| **State File Available** | **NO** | Local state missing; automated `terraform destroy` unavailable. |
| **Blockers Unlocked** | **NO** | RDS deletion protection and non-empty S3 buckets remain active. |

**Final Recommendation**:  
The project is **READY FOR A SEPARATELY AUTHORIZED TEARDOWN**, provided that the teardown follows the **safe, dependency-aware manual/CLI procedure** detailed in [`PROPOSED_TEARDOWN_RUNBOOK.md`](file:///Users/chaudhary/Codes/Personel/Devops-practice/cloud-expense-tracker-aws/evidence/teardown-review-2026-10-17/PROPOSED_TEARDOWN_RUNBOOK.md). Automated `terraform destroy` should NOT be attempted.

**Current Action**: **HOLD.** No changes have been made to infrastructure. All destructive operations await explicit user authorization.
