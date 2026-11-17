# Retained RDS Snapshot Details & Retention Policy

**Project**: AWS Cloud Expense Tracker  
**Audit Date**: 2026-10-17  
**Database Name**: `expense-tracker-db`  

---

## 1. Verified Snapshot Metadata

The manual final snapshot was created and validated prior to database deletion:

| Attribute | Verified Value |
| :--- | :--- |
| **DBSnapshotIdentifier** | `expense-tracker-db-final-snapshot-20261017` |
| **DBSnapshotArn** | `arn:aws:rds:ap-south-1:205639******:snapshot:expense-tracker-db-final-snapshot-20261017` |
| **DBInstanceIdentifier** | `expense-tracker-db` |
| **Engine & Version** | `postgres` (Version: `17.9`) |
| **Status** | **`available`** (Percent progress: 100%) |
| **Snapshot Type** | `manual` |
| **Allocated Storage** | 20 GB (gp3) |
| **Actual Snapshot Size** | **2,996,830,208 bytes (~2.99 GB)** |
| **Encrypted** | `true` (AWS KMS) |
| **KmsKeyId** | `arn:aws:kms:ap-south-1:205639******:key/acf60bf6-42c6-481e-8a88-61d5a43faeb8` |
| **Availability Zone** | `ap-south-1a` |
| **Creation Time** | `2026-10-17T02:15:51.721000+00:00` |

---

## 2. Retention Implications & Cost Analysis

- **Automatic Deletion**: **None**. Unlike automated daily backups, manual RDS snapshots are retained indefinitely in your AWS account until you delete them explicitly.
- **Storage Cost**: 
  - AWS provides up to 100% of your total database storage as free backup storage. Because `expense-tracker-db` was allocated 20 GB and the compressed snapshot is only ~2.99 GB, this snapshot is currently **100% covered within the AWS backup allowance ($0.00/month)**.
  - If additional snapshots accumulate beyond 20 GB total, manual snapshot storage is billed at ~$0.095 / GB-month in `ap-south-1`.

---

## 3. How to Restore or Delete the Retained Snapshot

### To Restore to a New Database (Future Project Revival):
```bash
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier expense-tracker-db-restored \
  --db-snapshot-identifier expense-tracker-db-final-snapshot-20261017 \
  --db-instance-class db.t3.micro \
  --region ap-south-1
```

### To Permanently Delete the Snapshot (When Data is No Longer Required):
```bash
aws rds delete-db-snapshot \
  --db-snapshot-identifier expense-tracker-db-final-snapshot-20261017 \
  --region ap-south-1
```
