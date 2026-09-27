
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_role" "ec2_ssm_role" {
  name = "expense-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_policy" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_ecr_read_only" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "expense-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

resource "aws_iam_policy" "ec2_db_credential_read_policy" {
  name        = "expense-ec2-db-credential-read-policy"
  description = "Allows EC2 instances to retrieve and decrypt the RDS database password parameter"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadRDSSecretsManagerSecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_db_instance.expense_db_instance.master_user_secret[0].secret_arn
      }
    ]
  })

  tags = {
    Name = "expense-ec2-db-credential-read-policy"
  }
}

resource "aws_iam_role_policy_attachment" "ec2_db_credential_read_attachment" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = aws_iam_policy.ec2_db_credential_read_policy.arn
}

resource "aws_iam_policy" "ec2_describe_instances_policy" {
  name        = "expense-ec2-describe-instances-policy"
  description = "Allows backend EC2 instances to discover frontend EC2 instances and public IPs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2DescribeInstances"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "expense-ec2-describe-instances-policy"
  }
}

resource "aws_iam_role_policy_attachment" "ec2_describe_instances_attachment" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = aws_iam_policy.ec2_describe_instances_policy.arn
}


resource "aws_iam_policy" "ansible_ssm_s3_policy" {
  name = "expense-ansible-ssm-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
        ]

        Resource = [
          aws_s3_bucket.ansible_ssm_bucket.arn,
          "${aws_s3_bucket.ansible_ssm_bucket.arn}/*",
        ]
      }
    ]
  })
}


resource "aws_iam_user_policy_attachment" "ansible_ssm_s3_attachment" {
  user       = "Terraform-User"
  policy_arn = aws_iam_policy.ansible_ssm_s3_policy.arn
}

resource "aws_iam_policy" "ansible_ssm_controller_policy" {
  name = "expense-ansible-ssm-controller-policy"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ssm:StartSession",
          "ssm:TerminateSession",
          "ssm:DescribeInstanceInformation",
          "ssm:DescribeSessions",
          "ssm:GetConnectionStatus",
          "ssm:ResumeSession"
        ]

        Resource = "*"
      }
    ]
  })
}


resource "aws_iam_user_policy_attachment" "ansible_ssm_controller_attachment" {
  user       = "Terraform-User"
  policy_arn = aws_iam_policy.ansible_ssm_controller_policy.arn
}

resource "aws_iam_policy" "ansible_ec2_inventory_policy" {
  name = "expense-ansible-ec2-inventory-policy"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]

        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "ansible_ec2_inventory_attachment" {
  user       = "Terraform-User"
  policy_arn = aws_iam_policy.ansible_ec2_inventory_policy.arn
}

# ==========================================
# GitHub Actions OIDC & ECR Deployment Role
# ==========================================

resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c5824a6f5a877527f413b40f6d773a15d64acb4"
  ]

  tags = {
    Name = "github-actions-oidc-provider"
  }
}

resource "aws_iam_role" "github_actions_ecr_role" {
  name = "expense-github-actions-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_repository}:ref:refs/heads/main",
              "repo:chaudharyo7/cloud-expense-tracker-aws:ref:refs/heads/main"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name = "expense-github-actions-ecr-role"
  }
}

resource "aws_iam_policy" "github_actions_ecr_policy" {
  name        = "expense-github-actions-ecr-policy"
  description = "Allows GitHub Actions to authenticate and push Docker images to frontend and backend ECR repositories"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRPushPullRepoScoped"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories"
        ]
        Resource = [
          aws_ecr_repository.frontend.arn,
          aws_ecr_repository.backend.arn
        ]
      }
    ]
  })

  tags = {
    Name = "expense-github-actions-ecr-policy"
  }
}

resource "aws_iam_role_policy_attachment" "github_actions_ecr_attachment" {
  role       = aws_iam_role.github_actions_ecr_role.name
  policy_arn = aws_iam_policy.github_actions_ecr_policy.arn
}

resource "aws_iam_policy" "github_actions_ssm_policy" {
  name        = "expense-github-actions-ssm-deployment-policy"
  description = "Allows GitHub Actions to trigger deployments on frontend and backend EC2 instances via SSM"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SSMSendCommandOnTaggedInstances"
        Effect = "Allow"
        Action = [
          "ssm:SendCommand"
        ]
        Resource = [
          "arn:aws:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:instance/*"
        ]
        Condition = {
          StringEquals = {
            "ssm:resourceTag/Role" = ["frontend", "backend"]
          }
        }
      },
      {
        Sid    = "SSMSendCommandDocument"
        Effect = "Allow"
        Action = [
          "ssm:SendCommand"
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.current.region}::document/AWS-RunShellScript"
        ]
      },
      {
        Sid    = "SSMCommandStatusAndOutputs"
        Effect = "Allow"
        Action = [
          "ssm:GetCommandInvocation",
          "ssm:ListCommandInvocations",
          "ssm:ListCommands",
          "ssm:DescribeInstanceInformation"
        ]
        Resource = "*"
      },
      {
        Sid    = "RDSDescribeEndpoint"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "expense-github-actions-ssm-deployment-policy"
  }
}

resource "aws_iam_role_policy_attachment" "github_actions_ssm_attachment" {
  role       = aws_iam_role.github_actions_ecr_role.name
  policy_arn = aws_iam_policy.github_actions_ssm_policy.arn
}

resource "aws_iam_policy" "ec2_lambda_invoke_policy" {
  name        = "expense-ec2-lambda-invoke-policy"
  description = "Allows backend EC2 instances to invoke the expense report generation Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "InvokeExpenseLambdaOnly"
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = aws_lambda_function.expense_lambda.arn
      }
    ]
  })

  tags = {
    Name = "expense-ec2-lambda-invoke-policy"
  }
}

resource "aws_iam_role_policy_attachment" "ec2_lambda_invoke_attachment" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = aws_iam_policy.ec2_lambda_invoke_policy.arn
}


