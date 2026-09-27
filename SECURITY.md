# Security Policy

## Reporting Security Issues

We take the security of the Cloud Expense Tracker repository seriously. If you believe you have discovered a vulnerability, security flaw, or sensitive data exposure, please report it responsibly so that it can be investigated and resolved before public disclosure.

### How to Report

- **Preferred Method**: Open a private draft security advisory via GitHub under **Security** > **Advisories** > **Report a vulnerability**.
- **Alternative**: If private repository advisories are unavailable, contact the project maintainer via a private security report through GitHub.

Please **do not** report security vulnerabilities through public GitHub issues, pull requests, or public forum discussions.

### Information to Include

When submitting a report, please provide:
1. **Description**: A clear summary of the issue and potential impact.
2. **Steps to Reproduce**: Detailed reproduction steps, sample payload, or minimal proof-of-concept.
3. **Affected Components**: The specific file, API endpoint, or infrastructure resource affected.
4. **Remediation**: Any suggested fixes or mitigation steps if you have them.

### Response Commitment

- **Acknowledgment**: You will receive an acknowledgment of your report within 48 hours.
- **Triage & Assessment**: We will assess the severity and impact within 5 business days.
- **Remediation**: Once verified, a fix will be developed, tested in isolation, and deployed through the standard CI/CD pipeline.
- **Credit**: If desired, we will acknowledge your responsible disclosure once the patch is published.

## Security Posture & Architecture Highlights

This project implements defense-in-depth security best practices:
- **No Direct SSH Access**: Instances are orchestrated purely via AWS Systems Manager (SSM) with no bastion hosts or port 22 open.
- **Private Data Layer**: Amazon RDS PostgreSQL and AWS Lambda run inside dedicated private subnets with no internet ingress.
- **Least Privilege IAM**: All IAM roles and policies are explicitly scoped to specific resource ARNs with no unnecessary wildcards.
- **Secrets Management**: Database master passwords are automatically generated and managed by AWS Secrets Manager with zero hardcoded credentials.
- **Input Validation & Rate Limiting**: All backend endpoints enforce strict payload bounds, parameter validation, and rate limiting via Flask-Limiter.
- **Transport Security**: Enforced HTTPS (TLS 1.2 / TLS 1.3) at the Application Load Balancer with HTTP-to-HTTPS redirection and strict TLS-only S3 bucket policies.
