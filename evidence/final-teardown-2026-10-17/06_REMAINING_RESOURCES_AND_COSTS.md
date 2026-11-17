# Remaining Resources & Projected Ongoing Charges

**Project**: AWS Cloud Expense Tracker  
**Audit Date**: 2026-10-17  
**Region**: `ap-south-1`  

---

## 1. Intentionally Retained Resources

The following resources were deliberately preserved during teardown in accordance with safety and asset preservation rules:

| Resource Identifier | Description & Role | Reason for Retention | Ongoing Cost |
| :--- | :--- | :--- | :--- |
| `expense-tracker-db-final-snapshot-20261017` | Manual RDS PostgreSQL Snapshot (2.99 GB, KMS Encrypted) | Preserves database records for future reference or project restoration. | **$0.00 / month** (Covered by AWS 20 GB free backup allowance). |
| `arn:aws:acm:ap-south-1:205639******:certificate/6936d865-c954-4ff2-af0e-eb41fb14525f` | ACM Certificate for `projects.yamandeep.in` | External domain TLS certificate shared with user's portfolio infrastructure. | **$0.00 / month** (Amazon-issued ACM certificates are free). |
| `vpc-06aef52e7af55dfd2` (`default-vpc`) | AWS Pre-existing Default VPC | Default account-level networking; untouched. | **$0.00 / month** |
| `token.actions.githubusercontent.com` | IAM OIDC Identity Provider | Account-wide identity provider for GitHub Actions CI/CD workflows. | **$0.00 / month** |

---

## 2. Projected Monthly Charges

| Billing Dimension | Pre-Teardown Run Rate | Post-Teardown Projected Run Rate |
| :--- | :--- | :--- |
| **Compute (EC2 + EBS)** | ~$22.31 / month | **$0.00** |
| **Load Balancing (ALB)** | ~$16.20 / month | **$0.00** |
| **Egress (NAT Gateway)** | ~$32.40 / month | **$0.00** |
| **Networking (Public IPv4)** | ~$18.00 / month | **$0.00** |
| **Relational Database** | Free Tier (or ~$18.00/mo) | **$0.00** |
| **Secrets Manager** | ~$0.40 / month | **$0.00** |
| **CloudWatch Alarms** | ~$0.70 / month | **$0.00** |
| **S3 Storage & Requests** | ~$0.25 / month | **$0.00** |
| **Total Projected Project Cost**| **~$90.26 / month** | **$0.00 / month** |

---

## 3. Important Billing Latency Notice

> [!NOTE]
> **AWS Billing & Cost Explorer Latency**:  
> AWS billing and Cost Explorer reports experience an inherent **24 to 48-hour processing latency**. While resource deletion took effect immediately in the AWS data plane (stopping hourly compute, NAT, and IP metering instantly), your billing dashboard will continue reflecting accrued partial-month charges from the past 17 days of October until the next invoice cycle.
