# Proposed Infrastructure Teardown Runbook

> [!CAUTION]
> **OPERATIONAL STATUS: PROPOSED RUNBOOK (DO NOT EXECUTE)**  
> This runbook is strictly for review and documentation. No commands should be run until explicit, separate authorization is granted.

**Project**: AWS Cloud Expense Tracker  
**Target AWS Region**: `ap-south-1`  
**Target Account**: `205639******` (Redacted)  
**Execution Strategy**: Ordered Dependency-Aware AWS CLI Teardown (Preferred due to missing local Terraform state).

---

## 1. Pre-Teardown Health & Safety Checks

Before initiating any destructive sequence:
1. **Verify Active AWS Context**:
   ```bash
   aws sts get-caller-identity
   # Ensure Account is 205639151266 and User is Terraform-User
   ```
2. **Confirm Target Region**:
   ```bash
   echo $AWS_DEFAULT_REGION # Should be ap-south-1
   ```
3. **Notify Stakeholders / Pause Ingestion**:
   - Ensure no active testing, demonstrations, or CI/CD deployments are executing in GitHub Actions.

---

## 2. Phase 1: Data Preservation & Backup Order

Run these preservation commands locally before deleting cloud assets:

```bash
# 1.1 Download all generated JSON financial reports from S3
mkdir -p ./backups/s3_reports
aws s3 sync s3://expense-tracker-bucket-yd2026/reports/ ./backups/s3_reports/

# 1.2 Download S3 access logs (optional)
mkdir -p ./backups/access_logs
aws s3 sync s3://expense-tracker-logs-yd2026/access-logs/ ./backups/access_logs/

# 1.3 Create final manual RDS snapshot (optional, if DB data must be kept)
aws rds create-db-snapshot \
  --db-instance-identifier expense-tracker-db \
  --db-snapshot-identifier expense-tracker-db-final-snapshot-$(date +%Y%m%d) \
  --region ap-south-1

# Wait for snapshot completion:
aws rds wait db-snapshot-completed \
  --db-snapshot-identifier expense-tracker-db-final-snapshot-$(date +%Y%m%d) \
  --region ap-south-1
```

---

## 3. Phase 2: Ingress & Compute Teardown

Tear down public ingress, load balancers, and virtual compute nodes:

```bash
# 2.1 Delete Application Load Balancer
ALB_ARN=$(aws elbv2 describe-load-balancers --region ap-south-1 --names expense-alb --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null)
if [ -n "$ALB_ARN" ] && [ "$ALB_ARN" != "None" ]; then
  echo "Deleting ALB: $ALB_ARN"
  aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN" --region ap-south-1
  echo "Waiting for ALB deletion..."
  aws elbv2 wait load-balancers-deleted --load-balancer-arns "$ALB_ARN" --region ap-south-1
fi

# 2.2 Delete ALB Target Groups
TG_BE_ARN=$(aws elbv2 describe-target-groups --region ap-south-1 --names expense-target-group-backend --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null)
TG_FE_ARN=$(aws elbv2 describe-target-groups --region ap-south-1 --names expense-target-group-frontend --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null)

[ -n "$TG_BE_ARN" ] && [ "$TG_BE_ARN" != "None" ] && aws elbv2 delete-target-group --target-group-arn "$TG_BE_ARN" --region ap-south-1
[ -n "$TG_FE_ARN" ] && [ "$TG_FE_ARN" != "None" ] && aws elbv2 delete-target-group --target-group-arn "$TG_FE_ARN" --region ap-south-1

# 2.3 Terminate EC2 Compute Instances (Frontend & Backend)
INSTANCE_IDS=$(aws ec2 describe-instances --region ap-south-1 \
  --filters "Name=tag:Name,Values=expense-tracker-frontend-1,expense-tracker-frontend-2,expense-tracker-backend-1,expense-tracker-backend-2" "Name=instance-state-name,Values=running,stopped" \
  --query "Reservations[*].Instances[*].InstanceId" --output text)

if [ -n "$INSTANCE_IDS" ]; then
  echo "Terminating EC2 instances: $INSTANCE_IDS"
  aws ec2 terminate-instances --instance-ids $INSTANCE_IDS --region ap-south-1
  echo "Waiting for EC2 instances to terminate..."
  aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS --region ap-south-1
fi

# 2.4 Delete AWS Lambda Function
aws lambda delete-function --function-name expense-tracker-lambda --region ap-south-1 2>/dev/null || true

# 2.5 Delete API Gateway HTTP API
API_ID=$(aws apigatewayv2 get-apis --region ap-south-1 --query "Items[?Name=='expense-tracker-api'].ApiId" --output text 2>/dev/null)
if [ -n "$API_ID" ] && [ "$API_ID" != "None" ]; then
  echo "Deleting API Gateway: $API_ID"
  aws apigatewayv2 delete-api --api-id "$API_ID" --region ap-south-1
fi
```

---

## 4. Phase 3: Database & Secrets Teardown

Handle RDS deletion protection unlock and secret removal:

```bash
# 3.1 Disable RDS Deletion Protection
echo "Disabling deletion protection on RDS instance..."
aws rds modify-db-instance \
  --db-instance-identifier expense-tracker-db \
  --no-deletion-protection \
  --apply-immediately \
  --region ap-south-1

# Wait for RDS instance to become available after modification
aws rds wait db-instance-available --db-instance-identifier expense-tracker-db --region ap-south-1

# 3.2 Delete RDS Instance (Skip final snapshot if Phase 1 snapshot was created)
echo "Deleting RDS instance..."
aws rds delete-db-instance \
  --db-instance-identifier expense-tracker-db \
  --skip-final-snapshot \
  --delete-automated-backups \
  --region ap-south-1

echo "Waiting for RDS deletion to complete (may take 5-10 minutes)..."
aws rds wait db-instance-deleted --db-instance-identifier expense-tracker-db --region ap-south-1

# 3.3 Delete DB Subnet Group
aws rds delete-db-subnet-group --db-subnet-group-name expense-db-subnet-group --region ap-south-1 2>/dev/null || true

# 3.4 Delete RDS Secrets Manager Secret
SECRET_ARN=$(aws secretsmanager list-secrets --region ap-south-1 --query "SecretList[?contains(Name, 'rds!db')].ARN" --output text 2>/dev/null)
if [ -n "$SECRET_ARN" ] && [ "$SECRET_ARN" != "None" ]; then
  echo "Deleting secret: $SECRET_ARN"
  aws secretsmanager delete-secret --secret-id "$SECRET_ARN" --force-delete-without-recovery --region ap-south-1
fi
```

---

## 5. Phase 4: Networking & Egress Teardown (High-Cost NAT Gateway)

```bash
# 4.1 Delete NAT Gateway (Stops ~$0.045/hour cost immediately)
NAT_ID=$(aws ec2 describe-nat-gateways --region ap-south-1 \
  --filter "Name=tag:Name,Values=expense-tracker-nat-gateway" "Name=state,Values=available" \
  --query "NatGateways[0].NatGatewayId" --output text 2>/dev/null)

if [ -n "$NAT_ID" ] && [ "$NAT_ID" != "None" ]; then
  echo "Deleting NAT Gateway: $NAT_ID"
  aws ec2 delete-nat-gateway --nat-gateway-id "$NAT_ID" --region ap-south-1
  echo "Waiting for NAT Gateway to reach 'deleted' state (takes 2-4 minutes)..."
  aws ec2 wait nat-gateway-deleted --nat-gateway-ids "$NAT_ID" --region ap-south-1
fi

# 4.2 Release NAT Elastic IP Address
NAT_EIP_ALLOC=$(aws ec2 describe-addresses --region ap-south-1 \
  --filters "Name=tag:Name,Values=expense-tracker-nat-eip" \
  --query "Addresses[0].AllocationId" --output text 2>/dev/null)

if [ -n "$NAT_EIP_ALLOC" ] && [ "$NAT_EIP_ALLOC" != "None" ]; then
  echo "Releasing Elastic IP: $NAT_EIP_ALLOC"
  aws ec2 release-address --allocation-id "$NAT_EIP_ALLOC" --region ap-south-1
fi

# 4.3 Delete S3 VPC Gateway Endpoint
VPCE_ID=$(aws ec2 describe-vpc-endpoints --region ap-south-1 \
  --filters "Name=tag:Name,Values=expense-s3-endpoint" \
  --query "VpcEndpoints[0].VpcEndpointId" --output text 2>/dev/null)

[ -n "$VPCE_ID" ] && [ "$VPCE_ID" != "None" ] && aws ec2 delete-vpc-endpoints --vpc-endpoint-ids "$VPCE_ID" --region ap-south-1
```

---

## 6. Phase 5: VPC, Subnets & Routing Teardown

```bash
VPC_ID=$(aws ec2 describe-vpcs --region ap-south-1 --filters "Name=tag:Name,Values=expense-tracker-vpc" --query "Vpcs[0].VpcId" --output text 2>/dev/null)

if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
  echo "Tearing down networking for VPC: $VPC_ID"

  # Detach and delete Internet Gateway
  IGW_ID=$(aws ec2 describe-internet-gateways --region ap-south-1 --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[0].InternetGatewayId" --output text 2>/dev/null)
  if [ -n "$IGW_ID" ] && [ "$IGW_ID" != "None" ]; then
    aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" --region ap-south-1
    aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" --region ap-south-1
  fi

  # Delete Subnets
  for SUBNET in $(aws ec2 describe-subnets --region ap-south-1 --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[*].SubnetId" --output text); do
    aws ec2 delete-subnet --subnet-id "$SUBNET" --region ap-south-1
  done

  # Delete Custom Route Tables (skip default)
  for RTB in $(aws ec2 describe-route-tables --region ap-south-1 --filters "Name=vpc-id,Values=$VPC_ID" --query "RouteTables[?Associations[0].Main!=`true`].RouteTableId" --output text); do
    aws ec2 delete-route-table --route-table-id "$RTB" --region ap-south-1
  done

  # Delete Custom Security Groups (skip default)
  for SG in $(aws ec2 describe-security-groups --region ap-south-1 --filters "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text); do
    aws ec2 delete-security-group --group-id "$SG" --region ap-south-1 2>/dev/null || true
  done

  # Delete VPC
  aws ec2 delete-vpc --vpc-id "$VPC_ID" --region ap-south-1
fi
```

---

## 7. Phase 6: Storage, Observability & Auth Teardown

```bash
# 7.1 Empty and Delete S3 Buckets
for BUCKET in expense-tracker-bucket-yd2026 expense-tracker-logs-yd2026 expense-tracker-ansible-ssm-yd2026; do
  if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
    echo "Purging all object versions and delete markers from $BUCKET..."
    # Delete all versions in versioned buckets
    aws s3api delete-objects --bucket "$BUCKET" \
      --delete "$(aws s3api list-object-versions --bucket "$BUCKET" \
      --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json)" 2>/dev/null || true
    # Delete all delete markers
    aws s3api delete-objects --bucket "$BUCKET" \
      --delete "$(aws s3api list-object-versions --bucket "$BUCKET" \
      --query='{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --output json)" 2>/dev/null || true
    # Remove any remaining standard objects
    aws s3 rm "s3://$BUCKET" --recursive 2>/dev/null || true
    # Delete bucket
    aws s3 rb "s3://$BUCKET" --force
  fi
done

# 7.2 Delete ECR Repositories
aws ecr delete-repository --repository-name expense-tracker-frontend --force --region ap-south-1 2>/dev/null || true
aws ecr delete-repository --repository-name expense-tracker-backend --force --region ap-south-1 2>/dev/null || true

# 7.3 Delete CloudWatch Metric Alarms (Restores 85.5% Free Tier quota immediately)
ALARMS=$(aws cloudwatch describe-alarms --region ap-south-1 \
  --alarm-name-prefix "" \
  --query "MetricAlarms[?contains(AlarmName, 'alb-') || contains(AlarmName, 'ec2-') || contains(AlarmName, 'lambda-') || contains(AlarmName, 'nat-') || contains(AlarmName, 'rds-')].AlarmName" \
  --output text)
if [ -n "$ALARMS" ]; then
  echo "Deleting CloudWatch alarms: $ALARMS"
  aws cloudwatch delete-alarms --alarm-names $ALARMS --region ap-south-1
fi

# 7.4 Delete CloudWatch Dashboard and Log Groups
aws cloudwatch delete-dashboards --dashboard-names expense-tracker-dashboard --region ap-south-1 2>/dev/null || true
aws logs delete-log-group --log-group-name /aws/apigateway/expense-tracker --region ap-south-1 2>/dev/null || true
aws logs delete-log-group --log-group-name /aws/lambda/expense-tracker-lambda --region ap-south-1 2>/dev/null || true

# 7.5 Delete SNS Topic
SNS_TOPIC_ARN=$(aws sns list-topics --region ap-south-1 --query "Topics[?contains(TopicArn, 'expense-tracker-alerts')].TopicArn" --output text 2>/dev/null)
[ -n "$SNS_TOPIC_ARN" ] && [ "$SNS_TOPIC_ARN" != "None" ] && aws sns delete-topic --topic-arn "$SNS_TOPIC_ARN" --region ap-south-1

# 7.6 Delete Cognito User Pool
USER_POOL_ID=$(aws cognito-idp list-user-pools --max-results 10 --region ap-south-1 --query "UserPools[?Name=='expense-user-pool-yd2026'].Id" --output text 2>/dev/null)
[ -n "$USER_POOL_ID" ] && [ "$USER_POOL_ID" != "None" ] && aws cognito-idp delete-user-pool --user-pool-id "$USER_POOL_ID" --region ap-south-1
```

---

## 8. Phase 7: IAM Roles, Profiles & Policies Teardown

```bash
# 8.1 Remove Instance Profile and Roles
aws iam remove-role-from-instance-profile --instance-profile-name expense-ec2-ssm-profile --role-name expense-ec2-ssm-role 2>/dev/null || true
aws iam delete-instance-profile --instance-profile-name expense-ec2-ssm-profile 2>/dev/null || true

# Detach policies from roles, then delete roles
for ROLE in expense-ec2-ssm-role expense-github-actions-ecr-role expense_lambda_role; do
  for POL_ARN in $(aws iam list-attached-role-policies --role-name "$ROLE" --query "AttachedPolicies[*].PolicyArn" --output text 2>/dev/null); do
    aws iam detach-role-policy --role-name "$ROLE" --policy-arn "$POL_ARN" 2>/dev/null || true
  done
  aws iam delete-role --role-name "$ROLE" 2>/dev/null || true
done

# Detach policies from IAM users (Terraform-User if attached)
for POL_ARN in $(aws iam list-policies --scope Local --query "Policies[?contains(PolicyName, 'expense') || contains(PolicyName, 'ansible')].Arn" --output text 2>/dev/null); do
  # Detach from user if attached
  aws iam detach-user-policy --user-name Terraform-User --policy-arn "$POL_ARN" 2>/dev/null || true
  # Delete policy
  aws iam delete-policy --policy-arn "$POL_ARN" 2>/dev/null || true
done
```

---

## 9. Protected Assets (DO NOT DELETE)

1. **ACM Certificate**: `arn:aws:acm:ap-south-1:205639******:certificate/6936d865-c954-4ff2-af0e-eb41fb14525f` (`projects.yamandeep.in`) — Shared domain certificate.
2. **Route 53 Hosted Zone**: `buildwithyaman.in` (and any external DNS configurations).
3. **IAM User `Terraform-User`**: Active administrative credentials.

---

## 10. Post-Teardown Verification Commands

Run these checks to guarantee zero ongoing billing:
```bash
# Verify 0 running EC2 instances
aws ec2 describe-instances --region ap-south-1 --filters "Name=instance-state-name,Values=running,pending" --query "Reservations[*].Instances[*].InstanceId"

# Verify 0 NAT Gateways
aws ec2 describe-nat-gateways --region ap-south-1 --filter "Name=state,Values=available,pending" --query "NatGateways[*].NatGatewayId"

# Verify 0 Elastic IPs
aws ec2 describe-addresses --region ap-south-1 --query "Addresses[*].AllocationId"

# Verify 0 Load Balancers
aws elbv2 describe-load-balancers --region ap-south-1 --query "LoadBalancers[*].LoadBalancerArn"

# Verify 0 RDS DB instances
aws rds describe-db-instances --region ap-south-1 --query "DBInstances[*].DBInstanceIdentifier"

# Verify 0 Metric Alarms (confirms Free Tier recovery)
aws cloudwatch describe-alarms --region ap-south-1 --query "MetricAlarms[*].AlarmName"
```

---

## 11. Rollback Limitations & Irreversible Operations

- **S3 Bucket Objects**: Once purged, deleted objects cannot be recovered.
- **RDS Database**: Once deleted, data is permanently lost unless a snapshot was created in Phase 1.
- **ECR Images**: Untagged or deleted images cannot be undeleted; rebuild from source is required.
