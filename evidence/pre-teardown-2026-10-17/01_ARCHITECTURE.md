# Architecture Overview & AWS Service Relationships

**Project**: Cloud Expense Tracker AWS  
**Evaluation Date**: 2026-10-17  
**Region**: `ap-south-1`  

---

## 1. System Topology & Tier Architecture

The application implements a multi-tier, high-availability architecture deployed across two Availability Zones (`ap-south-1a` and `ap-south-1b`) within a dedicated Virtual Private Cloud (VPC).

```mermaid
flowchart TB
    subgraph Internet_Layer["Public Internet & Ingress"]
        Users["Web Browsers / Clients"]
        GHA["GitHub Actions CI/CD"]
    end

    subgraph AWS_Region["AWS ap-south-1 Region"]
        subgraph IAM_Identity["Security & Identity"]
            OIDC["GitHub OIDC Provider"]
            ECR_Role["expense-github-actions-ecr-role"]
            SSM_Role["expense-ec2-ssm-role"]
            SM["AWS Secrets Manager\n(RDS Master Credentials)"]
            Cognito["Cognito User Pool\n(expense-user-pool-yd2026)"]
        end

        subgraph VPC["Custom VPC: 10.0.0.0/16 (expense-tracker-vpc)"]
            IGW["Internet Gateway\n(expense-tracker-igw)"]
            NAT["NAT Gateway\n(expense-tracker-nat-gateway\nSubnet: public-1)"]
            S3_VPCE["S3 Gateway Endpoint\n(expense-s3-endpoint)"]

            subgraph Public_Tier["Public Subnets (10.0.1.0/24 & 10.0.2.0/24)"]
                ALB["Application Load Balancer\n(expense-alb)"]
                FE1["Frontend EC2 #1\n(Nginx Container :80)"]
                FE2["Frontend EC2 #2\n(Nginx Container :80)"]
            end

            subgraph App_Tier["Private App Subnets (10.0.11.0/24 & 10.0.12.0/24)"]
                BE1["Backend EC2 #1\n(Flask/Gunicorn :8000)"]
                BE2["Backend EC2 #2\n(Flask/Gunicorn :8000)"]
                Lambda["AWS Lambda\n(expense-tracker-lambda)"]
            end

            subgraph DB_Tier["Private DB Subnets (10.0.21.0/24 & 10.0.22.0/24)"]
                RDS[("Amazon RDS PostgreSQL 17\n(expense-tracker-db)\nAllocated: 20GB gp3")]
            end
        end

        subgraph Storage_Tier["Managed Storage & Registry"]
            ECR_FE["ECR: expense-tracker-frontend"]
            ECR_BE["ECR: expense-tracker-backend"]
            S3_Reports["S3: expense-tracker-bucket-yd2026\n(Generated Reports)"]
            S3_Logs["S3: expense-tracker-logs-yd2026\n(Server Access Logs)"]
            S3_SSM["S3: expense-tracker-ansible-ssm-yd2026\n(Ansible Transport)"]
        end

        subgraph Telemetry["Observability"]
            CW_Dash["CloudWatch Dashboard\n(expense-tracker-dashboard)"]
            CW_Logs["CloudWatch Log Groups\n(/aws/lambda & /aws/apigateway)"]
            Alarms["CloudWatch Metric Alarms (17)"]
            SNS["SNS Topic: expense-tracker-alerts"]
        end
    end

    Users -->|HTTPS :443 / HTTP :80| ALB
    ALB -->|Forward /| FE1 & FE2
    ALB -->|Forward /api/*| BE1 & BE2

    BE1 & BE2 -->|Read Credentials| SM
    BE1 & BE2 -->|PostgreSQL :5432| RDS
    BE1 & BE2 -->|Invoke Boto3| Lambda

    Lambda -->|PostgreSQL :5432| RDS
    Lambda -->|Upload & Presign URL| S3_Reports

    App_Tier -->|Outbound HTTPS via NAT| NAT
    NAT --> IGW
    App_Tier -->|Private AWS S3 Traffic| S3_VPCE
    S3_VPCE --> S3_Reports

    GHA -->|AssumeRoleWithWebIdentity| OIDC
    OIDC --> ECR_Role
    ECR_Role -->|Push Images| ECR_FE & ECR_BE
```

---

## 2. Core Service Relationships & Data Paths

### A. Traffic Ingress & Load Balancing
- **Application Load Balancer (`expense-alb`)**:
  - Attached to public subnets across AZ `ap-south-1a` and `ap-south-1b`.
  - HTTP Listener (port 80) redirects to HTTPS (port 443).
  - Target Group `expense-target-group-frontend` (Port 80) targets instances `i-0b0294fc87c9ac832` and `i-0d180a9a22ab66f1a`.
  - Target Group `expense-target-group-backend` (Port 8000) targets instances `i-0a973fbbf1c0e01e3` and `i-048b2374625ee144e`.

### B. Application & Serverless Reporting
- **Backend Instances**:
  - Run Gunicorn + Flask serving API endpoints (`/api/expenses`, `/api/summary`, `/api/reports`).
  - Retrieve PostgreSQL database credentials dynamically from AWS Secrets Manager using IAM instance profile `expense-ec2-ssm-profile`.
- **Lambda Reporting Service (`expense-tracker-lambda`)**:
  - Python 3.12 runtime configured in VPC private subnets.
  - Queries RDS PostgreSQL directly, formats JSON summary reports, stores them in `expense-tracker-bucket-yd2026`, and returns presigned S3 URLs to the client.
- **Standby API Gateway HTTP API (`expense-tracker-api`)**:
  - ID: `d3dpf59d6g`.
  - Standby route `POST /reports` integrated with Lambda with Cognito JWT authorizer (`ap-south-1_uaZaEifVt`).

### C. Networking & Egress
- **NAT Gateway (`nat-00b6ef51e976e5998`)**:
  - Located in public subnet `subnet-00c7e3570173ad9ac` with Elastic IP allocation `eipalloc-032da56bffc50c262`.
  - Routes internet traffic for private application subnets (package updates, container pulls if needed).
- **S3 Gateway Endpoint (`vpce-07109946b5c3f8627`)**:
  - Associated with private route table `rtb-0d5d13fdd17ceef60`.
  - Direct, zero-cost routing between private EC2/Lambda and S3 without going through NAT Gateway.

### D. Observability & Alerting
- CloudWatch alarms monitor EC2 CPU/status, ALB response times and 5xx errors, RDS connections/storage/memory, Lambda errors/duration, and NAT Gateway packet drops.
- Alarms dispatch notifications to Amazon SNS topic `expense-tracker-alerts`.
