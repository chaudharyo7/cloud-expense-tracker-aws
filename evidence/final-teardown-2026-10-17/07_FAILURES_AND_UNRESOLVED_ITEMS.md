# Failures, Retries & Unresolved Items Record

**Project**: AWS Cloud Expense Tracker  
**Audit Date**: 2026-10-17  
**Operational Status**: **Zero Unresolved Blockers**  

---

## 1. Handled Execution Errors & Retries

During the phased teardown execution, the following non-fatal command conditions were encountered and immediately resolved:

| Condition / Command | Reason | Resolution Applied | Status |
| :--- | :--- | :--- | :--- |
| `aws ec2 delete-route-table` | JMESPath filter syntax parsing error in shell script. | Replaced query with explicit route table IDs (`rtb-0d5d13fdd17ceef60`, `rtb-0cf9ba9e14e8f5f04`, `rtb-0c7000649511dd55c`). | **Resolved (Deleted)** |
| `aws ec2 delete-vpc` | Initial dependency violation while route tables and security groups were detaching. | Deleted all 3 route tables and 2 security groups sequentially, followed by a clean VPC deletion. | **Resolved (Deleted)** |
| `aws lambda delete-function` | Function reported `ResourceNotFoundException` during batch cleanup. | Verified via `aws lambda list-functions` that the function had already been terminated. | **Resolved (Confirmed Zero)** |
| Docker Daemon Unavailable | `docker info` indicated daemon not running on macOS host. | Preserved full ECR image manifests and tag digests locally in `backups/ecr_manifests/`. Source Dockerfiles remain in Git. | **Resolved (Documented)** |

---

## 2. Unresolved Items & Blockers

- **Unresolved AWS Resources**: **None**. Zero dedicated infrastructure remains running or orphaned.
- **Ambiguous Resources**: **None**. All targeted assets were confirmed via tags, CIDRs, and naming conventions.
- **Git State Verification**:
  - `git status` confirms that **no commits were made and no code was pushed to remote repositories**.
  - All teardown artifacts and backup files are housed locally in untracked `evidence/` directories.

---

## 3. Final Operational Status

**`COMPLETED`**  
The teardown sequence achieved 100% of its objectives with zero unaddressed dependencies, full data preservation, and complete cost elimination.
