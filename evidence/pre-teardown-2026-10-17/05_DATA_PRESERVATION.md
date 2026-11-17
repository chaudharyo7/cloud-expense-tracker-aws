# Data Preservation & Backup Requirements

**Project**: Cloud Expense Tracker AWS  
**Evaluation Date**: 2026-10-17  
**Objective**: Identify all persistent data, logs, database records, and state assets that must be preserved or backed up prior to any future teardown.

---

## 1. High-Priority Data Assets

### A. Generated Expense Reports in S3
- **Bucket**: `expense-tracker-bucket-yd2026`
- **Location**: `s3://expense-tracker-bucket-yd2026/reports/`
- **Contents**: **49 generated JSON financial reports** created between 2026-09-26 and 2026-10-05 (e.g., `reports/expense-report-20261005-153414.json`).
- **Data Risk**: **Irreversible loss.** Once the bucket is deleted or emptied, these historical calculation outputs cannot be regenerated unless the database has identical transactions.
- **Preservation Action Required**:
  ```bash
  # Example read-only backup command (run locally to archive prior to teardown):
  aws s3 sync s3://expense-tracker-bucket-yd2026/reports/ ./evidence/backups/reports/
  ```

### B. Relational Database Data (RDS PostgreSQL)
- **DB Instance**: `expense-tracker-db`
- **Engine**: PostgreSQL 17.9 (`expense_db`)
- **Current Backup Retention**: `BackupRetentionPeriod: 0` (Automated backups are currently disabled).
- **Deletion Protection**: Enabled (`true`).
- **Data Risk**: Deleting the database without creating a manual snapshot results in immediate and permanent loss of all user-entered expenses, category groupings, and transactional history.
- **Preservation Action Required Prior to Teardown**:
  - Create a manual DB snapshot:
    ```bash
    aws rds create-db-snapshot \
      --db-instance-identifier expense-tracker-db \
      --db-snapshot-identifier expense-tracker-db-final-snapshot-20261017
    ```
  - Alternatively, export a SQL dump (`pg_dump`) via the application or bastion if access is enabled.

### C. Server & Application Access Logs
- **S3 Bucket**: `expense-tracker-logs-yd2026`
- **Contents**: Hundreds of access log objects under `access-logs/2026-*`.
- **Role**: S3 server access logging tracking requests and presigned download hits.
- **Preservation Recommendation**: Retain archive or download summary if access metrics are required for project reporting.

### D. Container Images in Amazon ECR
- **Repositories**: `expense-tracker-frontend` (25+ images), `expense-tracker-backend` (28+ images).
- **Latest Tag**: `latest` / Git SHA `3198f3bfe6e2041edcd5db304b751b255cb7cbfe`.
- **Preservation Assessment**: Low risk for source code because Dockerfiles exist in Git (`frontend/Dockerfile`, `backend/Dockerfile`). However, keeping the latest built images preserves build-time reproducibility.

---

## 2. Terraform State Preservation & Recovery

- **Current Status**: Local state `terraform.tfstate` is absent.
- **Risk**: Deleting infrastructure manually without capturing state prevents Terraform from having an audit trail or clean workspace closure.
- **Recommendation**:
  - If Terraform is to manage the teardown, generate an import script or reverse-engineer state for the 115 resources before issuing destroy commands.
  - Alternatively, execute an explicit, sequenced teardown via AWS CLI script.

---

## 3. Data Preservation Pre-Teardown Checklist

- [ ] Export / Sync all 49 JSON reports from `s3://expense-tracker-bucket-yd2026/reports/` to local cold storage.
- [ ] Take a manual final snapshot of RDS PostgreSQL (`expense-tracker-db`).
- [ ] Confirm whether CloudWatch log streams contain error analysis needed for portfolio case studies.
- [ ] Archive AWS Secrets Manager secret metadata if rotation history is needed.
- [ ] Verify local Git repository clean status and push tags/commits before tearing down AWS infrastructure.
