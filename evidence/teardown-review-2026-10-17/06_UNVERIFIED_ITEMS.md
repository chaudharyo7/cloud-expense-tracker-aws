# Unverified Items & Operational Limitations

**Project**: AWS Cloud Expense Tracker  
**Audit Date**: 2026-10-17  
**Compliance Standard**: In accordance with the mandatory restrictions, any item whose status could not be verified safely and non-destructively is explicitly marked **UNVERIFIED** rather than guessed.

---

## 1. Catalog of Unverified Items

### Item 1: AWS Account Age & 12-Month Free Tier Expiration Date
- **Status**: **UNVERIFIED**
- **Detail**: The AWS STS identity confirms user `Terraform-User` under account `205639******`. However, the exact account creation date and the expiration date of the 12-Month Free Tier (which grants the 750 monthly hours of `t3.micro` and `db.t3.micro`) cannot be queried via standard IAM or EC2 describe commands without root or billing portal administrative permissions.
- **Impact**: If the account is within its first 12 months, the RDS instance and 1 EC2 instance are free. If the account is older than 12 months, the baseline monthly run rate increases from ~$90/month to ~$116/month.

### Item 2: External DNS Configuration for `projects.yamandeep.in`
- **Status**: **UNVERIFIED (External to AWS Route 53)**
- **Detail**: An audit of Amazon Route 53 (`aws route53 list-hosted-zones`) revealed only one hosted zone (`buildwithyaman.in.`). The domain `yamandeep.in` is registered and hosted at an external DNS registrar/DNS service (e.g., Cloudflare, Namecheap, GoDaddy).
- **Impact**: While the ACM certificate is bound to `projects.yamandeep.in`, the external CNAME or ALIAS record pointing to `expense-alb-1555251367.ap-south-1.elb.amazonaws.com` cannot be inspected or altered from AWS. Once the ALB is deleted, client requests to `https://projects.yamandeep.in` will fail with DNS or connection timeout errors until the external DNS record is updated.

### Item 3: Presence of `terraform.tfstate` on Alternate Developer Machines
- **Status**: **UNVERIFIED (Local Scope Only)**
- **Detail**: Our search proved conclusively that no state file exists on the current host machine (`/Users/chaudhary`). However, whether the initial `terraform apply` was executed from a different workstation, a Docker container, a CI runner, or another repository clone cannot be determined locally.
- **Impact**: If another machine holds the original state file, running `terraform destroy` from that alternate host would delete resources automatically. If no other machine has it, the scripted CLI runbook in `PROPOSED_TEARDOWN_RUNBOOK.md` is the only viable path.

### Item 4: Nature of Data Inside PostgreSQL RDS (`expense_db`)
- **Status**: **UNVERIFIED (Read-Only Safety Rule Enforced)**
- **Detail**: To strictly observe security and credential-safety rules, no SQL connection was established to `expense-tracker-db.c1ewiss4yrgw.ap-south-1.rds.amazonaws.com`, and Secrets Manager passwords were not dumped. It is unverified whether the database contains real, sensitive personal expense data or purely synthetic mock transactions.
- **Impact**: Dictates whether the operator should take a manual RDS snapshot (`aws rds create-db-snapshot`) before teardown or simply skip the snapshot to avoid the ~$1.90/month snapshot storage charge.

### Item 5: Organization-Level Billing Alerts
- **Status**: **UNVERIFIED**
- **Detail**: Querying `aws budgets describe-budgets` under account `205639******` returned an empty list. It remains unverified whether the 85% alert received by the user was relayed from an AWS Organizations parent/payer account budget, or exclusively from the native AWS Free Tier CloudWatch monitor (`CW:AlarmMonitorUsage` at 85.46%).

---

## 2. Summary of Operational Limitations

1. **No Destructive Probing**: No commands were executed to test whether RDS deletion protection was bypassable without explicit modification.
2. **No Payload Extraction**: S3 report content was cataloged by object key and timestamp only; no data was downloaded to local scratch or uploaded elsewhere.
3. **No Network Penetration**: Port scanning and internal database queries were avoided to eliminate any possibility of triggering security alarms or operational disruption.
