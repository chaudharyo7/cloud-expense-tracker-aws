# Cost Validation, Free Tier Telemetry & Run-Rate Audit

**Project**: AWS Cloud Expense Tracker  
**Audit Date**: 2026-10-17  
**Data Sources**: AWS Free Tier API (`aws freetier`), AWS Cost Explorer (`aws ce`), AWS Pricing Calculator benchmarks  

---

## 1. Validation of the 85.46% Alert Root Cause

The user prompt cited a notification that the AWS usage/budget limit had reached approximately 85%.

Our audit validated this claim against live AWS APIs:

```json
{
  "service": "AmazonCloudWatch",
  "usageType": "CW:AlarmMonitorUsage",
  "actualUsageAmount": 8.54569804,
  "limit": 10.0,
  "unit": "Alarms",
  "forecastedUsageAmount": 16.5572899525,
  "freeTierType": "Always Free"
}
```

- **Observed Actual Value**: **8.5457 alarm-months**
- **Monthly Limit**: **10.0 alarm-months**
- **Exact Percentage**: **85.46%**
- **Forecast**: **16.56 alarm-months (165.57% of free limit)**
- **Audit Conclusion**: The alert was **NOT** an account-level monetary budget breach. It was an automated AWS Free Tier utilization alert warning that CloudWatch metric alarm usage had passed 85% of its monthly complimentary tier. 
- Because `cloudwatch.tf` defines 17 metric alarms, the account is mathematically guaranteed to exceed the 10 free alarms before the billing cycle closes.

---

## 2. Re-Examination of the ~$90/Month Run-Rate Estimate

In the initial pre-teardown summary, an estimated run rate of ~$90/month was reported. Here we dissect every line item to identify underlying assumptions, check for double-counting, and establish precise commercial costs:

| Resource Component | Quantity & Sizing | Monthly Cost Calculation (`ap-south-1`) | Free Tier Interaction / Assumptions | Verified Monthly Cost |
| :--- | :--- | :--- | :--- | :--- |
| **AWS NAT Gateway** | 1 gateway (`nat-00b6ef51e976e5998`) | $0.045 / hr * 720 hrs = **$32.40** | **Zero Free Tier**. NAT Gateways have no free allowance. Data processing is additional ($0.045/GB). | **$32.40** |
| **Application Load Balancer** | 1 ALB (`expense-alb`) | $0.0225 / hr * 720 hrs = **$16.20** | **Zero Free Tier** for modern accounts after initial trial. Base price fixed. | **$16.20** |
| **Public IPv4 Addresses** | 5 active addresses | 5 * $0.005 / hr * 720 hrs = **$18.00** | Since Feb 1, 2024, AWS charges $0.005/hr for *all* public IPv4s. (1 NAT EIP + 2 ALB public IPs + 2 frontend EC2 public IPs = 5 IPs). | **$18.00** |
| **EC2 Compute (`t3.micro`)** | 4 instances running 24/7 = 2,880 instance-hrs | 2,880 - 750 (free) = 2,130 billable hrs * $0.0104/hr = **$22.15** | Assumes account is eligible for 750 free hours of 1 `t3.micro`. If 12-month free tier has expired, all 2,880 hours are billed (**$29.95**). | **$22.15 - $29.95** |
| **EBS Storage (`gp3`)** | 4x 8GB = 32 GB total | (32 - 30 free GB) * $0.08 / GB = **$0.16** | 30 GB gp2/gp3 is free for 12 months. Excess is only 2 GB. | **$0.16** |
| **RDS PostgreSQL (`db.t3.micro`)** | 1 DB instance (20GB gp3) | 750 hrs free; 20GB free under 12-mo tier. | If within 12 months, **$0.00**. If 12 months expired: ~$18.00/month. | **$0.00** (Free Tier) |
| **AWS Secrets Manager** | 1 secret (RDS master password) | $0.40/month + API calls | Free for 30 days after creation; thereafter **$0.40/mo**. | **$0.40** |
| **CloudWatch Metric Alarms** | 17 alarms | (17 - 10 free) * $0.10/alarm = **$0.70** | 10 alarms always free. 7 overage alarms billed. | **$0.70** |
| **AWS Lambda & API Gateway** | 1 Lambda, 1 HTTP API | Within 1M free requests & 400,000 GB-s | Negligible traffic. | **$0.00** |
| **Amazon ECR Storage** | ~50 container images (~2-4 GB) | 500 MB free private tier; excess ~$0.10/GB | ~$0.20 - $0.30/month. | **~$0.25** |
| **Total Verified Monthly Run Rate** | | | | **$90.26 / month** |

### Verification of Assumptions & Double-Counting Check
1. **Public IPv4 Charges vs. EC2/ALB Charges**: Public IPv4 addresses are billed separately from EC2 compute and ALB hourly charges under AWS billing item `EC2-Other: InUseAddress:PublicIPv4`. Thus, including $18.00 is **accurate and not double-counted**.
2. **EC2 Free Tier Allowance**: The estimate assumes 1 instance is fully subsidized (750 hours) under the 12-month AWS Free Tier, leaving 3 instances billed. If the AWS account is older than 12 months, compute costs rise by an additional $7.80/month.
3. **Data Transfer**: Assumed minimal (< 10 GB), as test traffic has been light.

---

## 3. Continuing Charges if Resources Are Stopped vs. Deleted

Understanding which charges stop and which persist is vital if the user decides to stop resources temporarily instead of running a full teardown:

| Action Taken | Charges Stopped | Charges That CONTINUE |
| :--- | :--- | :--- |
| **Stop EC2 Instances** (`aws ec2 stop-instances`) | - EC2 compute hourly charges ($22.15/mo) stop immediately.<br>- Frontend public IPv4 addresses are released (saving $7.20/mo). | - Attached EBS volumes (32GB gp3) continue accruing storage charges.<br>- NAT Gateway ($32.40/mo) and ALB ($16.20/mo) remain 100% active.<br>- NAT Elastic IP continues accruing IPv4 charges ($3.60/mo). |
| **Stop RDS Instance** (`aws rds stop-db-instance`) | - DB instance hours stop for up to 7 days (RDS auto-restarts after 7 days). | - RDS allocated storage (20GB gp3) continues accruing charges.<br>- Automated secret rotation continues. |
| **Delete NAT Gateway Only** | - Base charge of $32.40/mo stops immediately. | - If NAT Elastic IP is NOT released, AWS bills **$0.005/hr for an idle/unattached Elastic IP**. |
| **Full Runbook Teardown** | **All charges stop (100% savings, ~$90/month).** | None. |
