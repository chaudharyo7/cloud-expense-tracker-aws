# Backup Manifest & Asset Verification Record

**Project**: AWS Cloud Expense Tracker  
**Audit Date**: 2026-10-17  
**Storage Location**: `evidence/final-teardown-2026-10-17/backups/`  
**Integrity Status**: **100% Verified (0 Failed Downloads)**  

---

## 1. Summary of Preserved Assets

| Asset Category | Source Location | Local Backup Destination | Total Files / Size | Verification Method |
| :--- | :--- | :--- | :--- | :--- |
| **S3 Expense Reports** | `s3://expense-tracker-bucket-yd2026/reports/` | [`backups/s3_reports/`](file:///Users/chaudhary/Codes/Personel/Devops-practice/cloud-expense-tracker-aws/evidence/final-teardown-2026-10-17/backups/s3_reports) | **50 JSON files** (~2.5 MB) | Byte size & MD5 hash verification via [`s3_reports_manifest.json`](file:///Users/chaudhary/Codes/Personel/Devops-practice/cloud-expense-tracker-aws/evidence/final-teardown-2026-10-17/backups/s3_reports_manifest.json) |
| **S3 Server Access Logs** | `s3://expense-tracker-logs-yd2026/access-logs/` | [`backups/access_logs/`](file:///Users/chaudhary/Codes/Personel/Devops-practice/cloud-expense-tracker-aws/evidence/final-teardown-2026-10-17/backups/access_logs) | **464 log files** (~15 MB) | File count & size audit via [`access_logs_manifest.json`](file:///Users/chaudhary/Codes/Personel/Devops-practice/cloud-expense-tracker-aws/evidence/final-teardown-2026-10-17/backups/access_logs_manifest.json) |
| **ECR Container Manifests** | `expense-tracker-frontend` & `backend` | [`backups/ecr_manifests/`](file:///Users/chaudhary/Codes/Personel/Devops-practice/cloud-expense-tracker-aws/evidence/final-teardown-2026-10-17/backups/ecr_manifests) | **2 JSON manifests** (53 total image tags) | Image digest JSON audit (`frontend_images.json`, `backend_images.json`) |
| **Git Project State** | Local Git HEAD (`main`) | [`backups/git_metadata.json`](file:///Users/chaudhary/Codes/Personel/Devops-practice/cloud-expense-tracker-aws/evidence/final-teardown-2026-10-17/backups/git_metadata.json) | Commit SHA & author log | `git log -1` metadata capture |

---

## 2. Sample Report Verification Manifest

Below is a representative sample of the 50 verified JSON reports cataloged in [`s3_reports_manifest.json`](file:///Users/chaudhary/Codes/Personel/Devops-practice/cloud-expense-tracker-aws/evidence/final-teardown-2026-10-17/backups/s3_reports_manifest.json):

```json
[
  {
    "file": "expense-report-20260926-143003.json",
    "size_bytes": 1054,
    "md5": "0b15b2e9c20a9a5fbeec7ba4940f5a9e"
  },
  {
    "file": "expense-report-20260927-025048.json",
    "size_bytes": 1054,
    "md5": "a8206ec1438914b14d59ee8ce0a9f5c4"
  },
  {
    "file": "expense-report-20260929-153425.json",
    "size_bytes": 1054,
    "md5": "33a4bf6b0744a6ea7e6f663f73966a35"
  },
  {
    "file": "expense-report-20261005-153414.json",
    "size_bytes": 1054,
    "md5": "17d23d8c2ecab7b7f8f11ca8e9323c6d"
  }
]
```

---

## 3. Preservation Safety & Data Isolation

- All downloaded reports, manifests, and logs were saved strictly to local workspace directories.
- No files were transmitted to third-party endpoints or external cloud storage.
- Project Dockerfiles (`frontend/Dockerfile`, `backend/Dockerfile`), Terraform IaC (`terraform/*.tf`), and Ansible automation (`ansible/*.yml`) remain fully intact in Git.
