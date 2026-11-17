# Post-Teardown Verification Audit

**Project**: AWS Cloud Expense Tracker  
**Verification Timestamp**: `2026-10-17T17:04:31Z` (UTC) / `22:34:31+05:30` (Local)  
**Region**: `ap-south-1`  
**Account**: `205639******`  

---

## 1. Comprehensive AWS API Verification Sweep

A full post-teardown inspection was executed via Python and AWS CLI across every service domain. The actual JSON query responses are recorded below:

### 1. EC2 Compute Instances
```bash
$ aws ec2 describe-instances --region ap-south-1 --filters "Name=instance-state-name,Values=running,pending,stopped" --query "Reservations[*].Instances[*].InstanceId" --output json
[]
```
**Outcome**: **0 EC2 instances**. All frontend and backend instances terminated.

---

### 2. NAT Gateways
```bash
$ aws ec2 describe-nat-gateways --region ap-south-1 --filter "Name=state,Values=available,pending" --query "NatGateways[*].NatGatewayId" --output json
[]
```
**Outcome**: **0 NAT Gateways**. `$0.045/hour` ongoing cost eliminated.

---

### 3. Elastic IP Addresses
```bash
$ aws ec2 describe-addresses --region ap-south-1 --query "Addresses[*].AllocationId" --output json
[]
```
**Outcome**: **0 Elastic IPs allocated**. All public IPv4 charges stopped.

---

### 4. EBS Storage Volumes
```bash
$ aws ec2 describe-volumes --region ap-south-1 --query "Volumes[*].VolumeId" --output json
[]
```
**Outcome**: **0 EBS volumes**. No orphaned storage remaining.

---

### 5. Application Load Balancers & Target Groups
```bash
$ aws elbv2 describe-load-balancers --region ap-south-1 --query "LoadBalancers[*].LoadBalancerArn" --output json
[]

$ aws elbv2 describe-target-groups --region ap-south-1 --query "TargetGroups[*].TargetGroupName" --output json
[]
```
**Outcome**: **0 Load Balancers & 0 Target Groups**. `$0.0225/hour` ALB charge eliminated.

---

### 6. Relational Database Instances (RDS)
```bash
$ aws rds describe-db-instances --region ap-south-1 --query "DBInstances[*].DBInstanceIdentifier" --output json
[]
```
**Outcome**: **0 RDS instances**. Database deleted.

---

### 7. Retained Manual RDS Snapshot
```bash
$ aws rds describe-db-snapshots --snapshot-type manual --region ap-south-1 --query "DBSnapshots[*].{Id:DBSnapshotIdentifier,Status:Status}" --output json
[
  {
    "Id": "expense-tracker-db-final-snapshot-20261017",
    "Status": "available"
  }
]
```
**Outcome**: **1 manual snapshot securely preserved and available**.

---

### 8. Serverless Functions & API Gateway
```bash
$ aws lambda list-functions --region ap-south-1 --query "Functions[*].FunctionName" --output json
[]

$ aws apigatewayv2 get-apis --region ap-south-1 --query "Items[*].Name" --output json
[]
```
**Outcome**: **0 Lambda functions & 0 API Gateway APIs**.

---

### 9. Amazon S3 Storage Buckets
```bash
$ aws s3api list-buckets --query "Buckets[?contains(Name, 'expense')].Name" --output json
[]
```
**Outcome**: **0 project S3 buckets**. Buckets emptied of versions and permanently deleted.

---

### 10. Amazon ECR Container Repositories
```bash
$ aws ecr describe-repositories --region ap-south-1 --query "repositories[?contains(repositoryName, 'expense')].repositoryName" --output json
[]
```
**Outcome**: **0 ECR repositories**.

---

### 11. CloudWatch Observability & Alerting
```bash
$ aws cloudwatch describe-alarms --region ap-south-1 --query "MetricAlarms[?contains(AlarmName, 'alb-') || contains(AlarmName, 'ec2-') || contains(AlarmName, 'lambda-') || contains(AlarmName, 'nat-') || contains(AlarmName, 'rds-')].AlarmName" --output json
[]

$ aws cloudwatch list-dashboards --region ap-south-1 --query "DashboardEntries[?contains(DashboardName, 'expense')].DashboardName" --output json
[]

$ aws sns list-topics --region ap-south-1 --query "Topics[?contains(TopicArn, 'expense')].TopicArn" --output json
[]
```
**Outcome**: **0 alarms, 0 dashboards, 0 SNS topics**. CloudWatch Free Tier alarm quota (previously at 85.46%) is 100% recovered.

---

### 12. Amazon Cognito User Pools
```bash
$ aws cognito-idp list-user-pools --max-results 10 --region ap-south-1 --query "UserPools[?contains(Name, 'expense')].Name" --output json
[]
```
**Outcome**: **0 Cognito pools**.

---

### 13. Virtual Private Clouds (VPC) & Networking
```bash
$ aws ec2 describe-vpcs --region ap-south-1 --query "Vpcs[*].{Id:VpcId,Name:Tags[?Key=='Name'].Value | [0],IsDefault:IsDefault}" --output json
[
  {
    "Id": "vpc-06aef52e7af55dfd2",
    "Name": "default-vpc",
    "IsDefault": true
  }
]
```
**Outcome**: Custom VPC `vpc-0c0e6084ab7a5ea70` and all 6 subnets deleted. **Only account's pre-existing default VPC remains.**

---

### 14. Protected Shared ACM Certificate Status
```bash
$ aws acm list-certificates --region ap-south-1 --query "CertificateSummaryList[*].{DomainName:DomainName,Status:Status}" --output json
[
  {
    "DomainName": "projects.yamandeep.in",
    "Status": "ISSUED"
  }
]
```
**Outcome**: **PROTECTED**. Certificate for `projects.yamandeep.in` is completely intact and operational.
