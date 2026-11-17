# Confirmed AWS Resource Inventory (Live Infrastructure)

**Project**: Cloud Expense Tracker AWS  
**Collection Date**: 2026-10-17  
**AWS Account**: `205639******` (Redacted)  
**Active Caller Identity**: `arn:aws:iam::205639******:user/Terraform-User`  
**Target Region**: `ap-south-1`  

All resources below were queried and verified live using the read-only AWS CLI on 2026-10-17.

---

## 1. Compute & Containers

### EC2 Instances
| Instance Name | Instance ID | Status | Type | AZ | Subnet ID | Public IP | Private IP |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `expense-tracker-frontend-1` | `i-0b0294fc87c9ac832` | **running** | t3.micro | `ap-south-1a` | `subnet-00c7e3570173ad9ac` (public-1) | `[REDACTED]` | `10.0.1.x` |
| `expense-tracker-frontend-2` | `i-0d180a9a22ab66f1a` | **running** | t3.micro | `ap-south-1b` | `subnet-0841b2134835eeb46` (public-2) | `[REDACTED]` | `10.0.2.x` |
| `expense-tracker-backend-1` | `i-0a973fbbf1c0e01e3` | **running** | t3.micro | `ap-south-1a` | `subnet-0590bcf4e7f83b99e` (private-app-1) | None | `10.0.11.x` |
| `expense-tracker-backend-2` | `i-048b2374625ee144e` | **running** | t3.micro | `ap-south-1b` | `subnet-00056e4d7fa32703b` (private-app-2) | None | `10.0.12.x` |

### EBS Volumes
| Volume ID | Size (GB) | Volume Type | Attached Instance | State | DeleteOnTermination |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `vol-0fa935f3d760752d9` | 8 GB | gp3 | `i-0b0294fc87c9ac832` | in-use | `true` |
| `vol-02a98a774e69f72ca` | 8 GB | gp3 | `i-0d180a9a22ab66f1a` | in-use | `true` |
| `vol-09c60a37584778b0d` | 8 GB | gp3 | `i-0a973fbbf1c0e01e3` | in-use | `true` |
| `vol-0dd9c0a4661577e6a` | 8 GB | gp3 | `i-048b2374625ee144e` | in-use | `true` |
*(Total EBS storage: 32 GB)*

### Lambda Functions
| Function Name | Runtime | Timeout | Memory | Role ARN | Last Modified |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `expense-tracker-lambda` | Python 3.12 | 30s | 256 MB | `arn:aws:iam::205639******:role/expense_lambda_role` | 2026-09-27T03:21:54Z |

### Amazon ECR Repositories
| Repository Name | Total Images | URI | Creation Date |
| :--- | :--- | :--- | :--- |
| `expense-tracker-frontend` | 25+ images | `205639******.dkr.ecr.ap-south-1.amazonaws.com/expense-tracker-frontend` | 2026-09-23 |
| `expense-tracker-backend` | 28+ images | `205639******.dkr.ecr.ap-south-1.amazonaws.com/expense-tracker-backend` | 2026-09-23 |

---

## 2. Networking & Traffic Routing

### Virtual Private Cloud (VPC)
- **VPC ID**: `vpc-0c0e6084ab7a5ea70`
- **Name Tag**: `expense-tracker-vpc`
- **IPv4 CIDR**: `10.0.0.0/16`
- **Internet Gateway**: `igw-0671a80fa042e5e38` (`expense-tracker-igw`)
- **VPC Endpoint**: `vpce-07109946b5c3f8627` (Gateway to S3)

### Subnets
| Subnet Name | Subnet ID | CIDR Block | AZ | Tier |
| :--- | :--- | :--- | :--- | :--- |
| `expense-tracker-public-subnet-1` | `subnet-00c7e3570173ad9ac` | `10.0.1.0/24` | `ap-south-1a` | Public Ingress |
| `expense-tracker-public-subnet-2` | `subnet-0841b2134835eeb46` | `10.0.2.0/24` | `ap-south-1b` | Public Ingress |
| `expense-tracker-private-subnet-1` | `subnet-0590bcf4e7f83b99e` | `10.0.11.0/24` | `ap-south-1a` | Private App Tier |
| `expense-tracker-private-subnet-2` | `subnet-00056e4d7fa32703b` | `10.0.12.0/24` | `ap-south-1b` | Private App Tier |
| `expense-tracker-private-db-subnet-1`| `subnet-098dc863142d53b31` | `10.0.21.0/24` | `ap-south-1a` | Private DB Tier |
| `expense-tracker-private-db-subnet-2`| `subnet-00a652a5d80acf99f` | `10.0.22.0/24` | `ap-south-1b` | Private DB Tier |

### NAT Gateway & Elastic IP Addresses
- **NAT Gateway**: `nat-00b6ef51e976e5998`
  - Name: `expense-tracker-nat-gateway`
  - Subnet: `subnet-00c7e3570173ad9ac`
  - Created: `2026-09-29T15:24:44Z`
  - State: `available`
- **Elastic IPs**:
  - `eipalloc-032da56bffc50c262` (NAT Gateway: `[REDACTED_PUBLIC_IP]`)
  - `eipalloc-0614a80423136e81d` (ALB ap-south-1a: `[REDACTED_PUBLIC_IP]`)
  - `eipalloc-0cd9c1792aab159bb` (ALB ap-south-1b: `[REDACTED_PUBLIC_IP]`)

### Application Load Balancer
- **Name**: `expense-alb`
- **ARN**: `arn:aws:elasticloadbalancing:ap-south-1:205639******:loadbalancer/app/expense-alb/489f800913f5d0ca`
- **DNS Name**: `expense-alb-1555251367.ap-south-1.elb.amazonaws.com`
- **Scheme**: `internet-facing`
- **State**: `active`
- **Target Groups**:
  - `expense-target-group-backend`: Port 8000, Health check `/api/health`
  - `expense-target-group-frontend`: Port 80, Health check `/`

### API Gateway
- **API ID**: `d3dpf59d6g`
- **Name**: `expense-tracker-api`
- **Protocol**: HTTP API
- **Endpoint**: `https://d3dpf59d6g.execute-api.ap-south-1.amazonaws.com`

---

## 3. Database & Secrets Tier

### Amazon RDS Instance
- **DB Identifier**: `expense-tracker-db`
- **Engine**: PostgreSQL 17.9
- **Instance Class**: `db.t3.micro`
- **Allocated Storage**: 20 GB (gp3, encrypted with KMS)
- **Status**: `available`
- **Multi-AZ**: `false`
- **Deletion Protection**: **`ENABLED` (`true`)**
- **DB Subnet Group**: `expense-db-subnet-group`
- **Endpoint**: `expense-tracker-db.c1ewiss4yrgw.ap-south-1.rds.amazonaws.com:5432`
- **Master Username**: `expense_user`

### AWS Secrets Manager
- **Secret Name**: `rds!db-22302a8e-8762-4ff6-9c36-fc94d952b157`
- **Description**: Primary RDS DB master credentials
- **Rotation**: Enabled (7 days automatic rotation)
- **Last Rotated**: `2026-10-11T23:38:45Z`

---

## 4. Storage (Amazon S3)

| Bucket Name | Versioning | Key Count / Contents | Role / Purpose |
| :--- | :--- | :--- | :--- |
| `expense-tracker-bucket-yd2026` | **Enabled** | **49 report JSON files** | Generated expense reports |
| `expense-tracker-logs-yd2026` | Disabled | **Hundreds of access logs** | S3 server access logging |
| `expense-tracker-ansible-ssm-yd2026` | Disabled | 0 objects | Ansible SSM artifact transport |

---

## 5. Security, Identity & Observability

### Amazon Cognito
- **User Pool ID**: `ap-south-1_uaZaEifVt`
- **Name**: `expense-user-pool-yd2026`

### CloudWatch Telemetry
- **Dashboard**: `expense-tracker-dashboard` (Size: 15.8 KB)
- **Log Groups**:
  - `/aws/apigateway/expense-tracker` (Retention: 14 days)
  - `/aws/lambda/expense-tracker-lambda` (Retention: 14 days, Stored: ~5.3 KB)
- **Metric Alarms**: 17 configured alarms (`rds-cpu-utilization-high`, `rds-free-storage-low`, `ec2-status`, `alb-5xx`, etc.)
- **SNS Topic**: `arn:aws:sns:ap-south-1:205639******:expense-tracker-alerts`

### IAM Roles & Policies
- Roles: `expense-ec2-ssm-role`, `expense-github-actions-ecr-role`, `expense_lambda_role`
- Instance Profile: `expense-ec2-ssm-profile`
- OIDC Provider: `arn:aws:iam::205639******:oidc-provider/token.actions.githubusercontent.com`
- Customer Managed Policies: 9 custom policies scoped for SSM, ECR, S3, and Lambda permissions.
