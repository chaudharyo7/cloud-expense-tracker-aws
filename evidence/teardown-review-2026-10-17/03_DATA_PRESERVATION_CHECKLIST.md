# Data Preservation & Asset Protection Checklist

**Project**: AWS Cloud Expense Tracker  
**Audit Date**: 2026-10-17  
**Objective**: Comprehensive catalog of data assets, backup procedures, cost implications, and pre-teardown verification requirements.

---

## 1. Asset Preservation Matrix

| Data Asset | Location & Volume | Recommended Preservation Procedure | Cost Impact of Preservation | Verification Required Before Teardown |
| :--- | :--- | :--- | :--- | :--- |
| **Generated Expense Reports** | `s3://expense-tracker-bucket-yd2026/reports/` (49 JSON files, ~2.5 MB total) | Run local sync to an offline directory before bucket deletion:<br>`aws s3 sync s3://expense-tracker-bucket-yd2026/reports/ ./backups/s3_reports/` | **$0.00** (Local disk storage; data transfer within AWS Free Tier for < 100 MB). | Verify file count in local backup equals 49; verify sample JSON report integrity. |
| **S3 Server Access Logs** | `s3://expense-tracker-logs-yd2026/access-logs/` (Hundreds of log files, ~15 MB total) | Run local sync or archive to compressed tarball:<br>`aws s3 sync s3://expense-tracker-logs-yd2026/access-logs/ ./backups/access_logs/` | **$0.00** (Local disk storage). | Determine whether raw HTTP access logs are needed for portfolio traffic metrics. |
| **RDS PostgreSQL Database** | Instance: `expense-tracker-db` (`expense_db` on Postgres 17.9, 20GB gp3) | Take a manual AWS RDS Snapshot:<br>`aws rds create-db-snapshot --db-instance-identifier expense-tracker-db --db-snapshot-identifier expense-db-final-snapshot-20261017`<br>*Alternative*: Run `pg_dump` via EC2 backend node. | **AWS Snapshot Storage**: ~$0.095/GB/mo after 20GB free tier. A 20GB snapshot retained indefinitely costs **~$1.90/month**. If dumped locally via `pg_dump`, cost is **$0.00**. | Confirm snapshot status reaches `available` before terminating the database instance. |
| **ECR Container Images** | Repositories: `expense-tracker-frontend` (25+ images), `expense-tracker-backend` (28+ images) | Pull latest images locally or rely on Git Dockerfiles:<br>`docker pull 205639******.dkr.ecr.ap-south-1.amazonaws.com/expense-tracker-frontend:latest` | **$0.00** (Docker image stored on local machine; ECR storage eliminated upon repository deletion). | Verify that application code and Dockerfiles in `frontend/` and `backend/` are fully committed to Git. |
| **Terraform & Infrastructure Code** | Directory: `terraform/` (17 files, 115 resource definitions) | Code is committed to Git (`git status: clean`). Retain local copy and push to GitHub remote. | **$0.00** | Confirm commit hash `3198f3b` matches origin main; verify variables template is documented. |
| **Ansible Playbooks & Config Management** | Directory: `ansible/` (`deploy-docker.yml`, `inventory_aws_ec2.yml`) | Code is committed to Git. | **$0.00** | Verify inventory filters and SSM plugin parameters are preserved. |
| **GitHub Actions Workflows** | `.github/workflows/docker-build-push.yml` | Workflow relies on OIDC role ARN. Code is in Git. | **$0.00** | Document OIDC role structure so it can be re-provisioned if CI/CD is re-enabled later. |
| **Demo Assets & Portfolio Evidence** | Repository README (`README.md`, 508 lines, complete Mermaid diagram) | Architecture and API documentation are fully preserved in `README.md`. | **$0.00** | Ensure Mermaid diagram and setup guides are preserved for portfolio case studies. |

---

## 2. Long-Term Cost Warning on RDS Snapshots

> [!WARNING]
> While taking an RDS Snapshot before teardown is an enterprise best practice for data preservation, **manual RDS snapshots do NOT terminate automatically and incur ongoing storage costs ($0.095/GB-month)** once the account's 20GB backup storage allowance is exceeded.
> 
> **Recommendation**: If the sample expense data is non-production practice data, consider either:
> 1. Exporting data locally as a JSON / SQL file using a script (`$0.00/mo`).
> 2. Setting a reminder to delete the manual RDS snapshot after 30 days.

---

## 3. Step-by-Step Data Preservation Verification Protocol (Do Not Execute Yet)

Before any destructive runbook command is initiated in a future authorized session:

- [ ] **Step 1: S3 Report Verification**
  Run `aws s3 ls s3://expense-tracker-bucket-yd2026/reports/ | wc -l`. Ensure local copy contains identical object count.
- [ ] **Step 2: Database Snapshot Verification**
  If snapshotting: Run `aws rds describe-db-snapshots --db-instance-identifier expense-tracker-db`. Confirm `Status: available`.
- [ ] **Step 3: Secrets Manager Backup**
  Confirm the RDS master credentials are not needed for any other system.
- [ ] **Step 4: Git Synchronization**
  Confirm `git status` has no uncommitted application or configuration changes.
