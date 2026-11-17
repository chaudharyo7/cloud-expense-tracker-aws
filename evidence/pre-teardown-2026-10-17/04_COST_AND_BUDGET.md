# Cost, Usage, and Budget Telemetry

**Project**: Cloud Expense Tracker AWS  
**Collection Date**: 2026-10-17  
**Data Sources**: AWS Free Tier API (`aws freetier`), AWS Cost Explorer (`aws ce`), AWS Budgets (`aws budgets`)  
**Data Freshness**: Current through 2026-10-17 (Cost Explorer data has typical 24-48h processing latency; Free Tier data reflects real-time monitor counts).  

---

## 1. Resolution of the 85% Limit Notification

The user reported an alert indicating that AWS usage/budget had reached approximately 85%.

Our audit queried the AWS Free Tier telemetry API (`aws freetier get-free-tier-usage`) and identified the exact threshold:

```json
{
  "service": "AmazonCloudWatch",
  "usageType": "CW:AlarmMonitorUsage",
  "region": "global",
  "actualUsageAmount": 8.54569804,
  "forecastedUsageAmount": 16.5572899525,
  "limit": 10.0,
  "unit": "Alarms",
  "description": "10.0 Alarms are always free per month as part of AWS Free Usage Tier (Global-CW:AlarmMonitorUsage)",
  "freeTierType": "Always Free"
}
```

- **Metric**: Amazon CloudWatch Metric Alarm Monitor Usage
- **Current Usage**: **8.55 alarm-months**
- **Monthly Free Allowance**: **10.0 alarm-months**
- **Calculated Percentage**: **85.46%** (Exact match to the ~85% alert)
- **Forecasted Consumption**: **16.56 alarm-months (165.6% of quota)**
- **Cost Implication**: Standard CloudWatch alarms cost $0.10/alarm/month once the 10 free alarms are exceeded. With 17 configured alarms in `cloudwatch.tf`, ~7 alarms will be charged overages (~$0.70/month).

---

## 2. Active Free Tier Consumption Overview

| Service / Resource | Free Tier Type | Metric / Usage Type | Actual Usage | Monthly Quota | % of Quota | Forecasted Usage |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **CloudWatch Alarms** | Always Free | `CW:AlarmMonitorUsage` | **8.55 Alarms** | 10.0 Alarms | **85.46%** | 16.56 Alarms (Alert Trigger) |
| **AWS Lambda** | Always Free | `Lambda-GB-Second` | 5.81 GB-Sec | 400,000 GB-Sec | < 0.01% | 11.25 GB-Sec |
| **AWS Lambda** | Always Free | `Request` | 12.0 Requests | 1,000,000 Requests | < 0.01% | 23.25 Requests |
| **CloudWatch Logs** | Always Free | `DataProcessing-Bytes` | 5.74 KB | 5.0 GB | < 0.01% | 11.12 KB |
| **CloudWatch Storage**| Always Free | `TimedStorage-ByteHrs` | 11.8 KB | 5.0 GB | < 0.01% | 22.86 KB |
| **SNS Requests** | Always Free | `APS3-Requests-Tier1` | 2.0 Requests | 1,000,000 Requests| < 0.01% | 3.88 Requests |
| **KMS Requests** | Always Free | `KMS-Requests` | 7.0 Requests | 20,000 Requests | 0.03% | 13.56 Requests |

---

## 3. High-Risk Billable Components (Non-Free Tier or Exceeding Allowance)

While the CloudWatch 85% alert triggered the evaluation, several infrastructure components in the active environment carry standard hourly costs that represent the primary ongoing expense:

### A. AWS NAT Gateway (`nat-00b6ef51e976e5998`)
- **Hourly Rate**: ~$0.045 / hour (in `ap-south-1`)
- **Monthly Run Rate**: **~$32.40 / month**
- **Data Processing**: $0.045 / GB processed
- **Note**: NAT Gateways have no Free Tier tier. They run continuously as long as provisioned.

### B. Application Load Balancer (`expense-alb`)
- **Hourly Rate**: ~$0.0225 / hour
- **Monthly Run Rate**: **~$16.20 / month**
- **LCU (Load Balancer Capacity Units)**: ~$0.008 / LCU-hour
- **Note**: ALBs carry minimum base charges regardless of traffic volume.

### C. Public IPv4 Addresses
- **Hourly Rate**: $0.005 / hour per IPv4 address (implemented by AWS on Feb 1, 2024)
- **Active Addresses**:
  - 1x NAT Gateway Elastic IP (`eipalloc-032da56bffc50c262`)
  - 2x ALB managed public IP addresses (`eipalloc-0614a80423136e81d`, `eipalloc-0cd9c1792aab159bb`)
  - 2x Public EC2 instance IPs (`expense-tracker-frontend-1`, `expense-tracker-frontend-2`)
- **Total Public IPs**: **5 active addresses**
- **Estimated Monthly IPv4 Charge**: 5 * $0.005 * 720 hrs = **~$18.00 / month**

### D. Multi-Instance EC2 Compute
- **Total Running Instances**: 4x `t3.micro` (running 24/7 = 2,880 instance-hours/month)
- **Free Tier Allowance**: 750 hours/month of 1 instance (t2.micro/t3.micro) for the first 12 months.
- **Excess Billable Hours**: 2,880 - 750 = **2,130 billable instance-hours**
- **Cost**: 2,130 * ~$0.0104/hr = **~$22.15 / month**

### E. Summary of Ongoing Run Rate
| Resource Component | Quantity | Estimated Monthly Cost (ap-south-1) |
| :--- | :--- | :--- |
| NAT Gateway | 1 | ~$32.40 |
| Application Load Balancer | 1 | ~$16.20 |
| Public IPv4 Addresses | 5 | ~$18.00 |
| EC2 Excess Compute (3 instances) | 3 | ~$22.15 |
| EBS Excess Storage (2 GB) | 32 GB total | ~$0.16 |
| Secrets Manager (after trial) | 1 secret | ~$0.40 |
| CloudWatch Alarm Overages | ~7 alarms | ~$0.70 |
| **Total Estimated Monthly Run Rate** | | **~$90.00 / month** |

---

## 4. Cost Explorer Month-to-Date Observations

- Month-to-date queries (`aws ce get-cost-and-usage`) for October 2026 report negligible net unblended costs due to AWS promotional credits or free tier billing offsets currently active on the account.
- However, as Free Tier allowances expire (especially alarm allowances and 12-month tier limits), the projected run rate will transition to standard commercial pricing (~$90/month).
