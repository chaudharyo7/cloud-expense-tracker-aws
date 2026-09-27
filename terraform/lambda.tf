
resource "aws_iam_role" "expense_lambda_role" {
  name = "expense_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "expense_lambda_policy_attachment" {
  role       = aws_iam_role.expense_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


resource "aws_iam_policy" "lambda_s3_policy" {
  name = "lambda_s3_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.expense_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "expense_lambda_s3_policy_attachment" {
  role       = aws_iam_role.expense_lambda_role.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "expense_lambda_ssm_policy_attachment" {
  role       = aws_iam_role.expense_lambda_role.name
  policy_arn = aws_iam_policy.ec2_db_credential_read_policy.arn
}

resource "aws_lambda_function" "expense_lambda" {
  function_name = "expense-tracker-lambda"

  filename         = "lambda_function.zip"
  source_code_hash = filebase64sha256("lambda_function.zip")

  handler     = "lambda_function.lambda_handler"
  runtime     = "python3.12"
  timeout     = 30
  memory_size = 256

  depends_on = [
    aws_iam_role_policy_attachment.expense_lambda_policy_attachment,
    aws_iam_role_policy_attachment.expense_lambda_vpc_policy_attachment,
    aws_iam_role_policy_attachment.expense_lambda_s3_policy_attachment,
    aws_iam_role_policy_attachment.expense_lambda_ssm_policy_attachment
  ]

  role = aws_iam_role.expense_lambda_role.arn

  environment {
    variables = {
      DB_HOST       = aws_db_instance.expense_db_instance.address
      DB_PORT       = "5432"
      DB_NAME       = aws_db_instance.expense_db_instance.db_name
      DB_USER       = aws_db_instance.expense_db_instance.username
      S3_BUCKET     = aws_s3_bucket.expense_bucket.bucket
      DB_SECRET_ARN = aws_db_instance.expense_db_instance.master_user_secret[0].secret_arn
    }
  }

  vpc_config {
    subnet_ids = [
      aws_subnet.private_app_1.id,
      aws_subnet.private_app_2.id
    ]

    security_group_ids = [
      aws_security_group.lambda_sg.id
    ]
  }

  tags = {
    Name = "expense-tracker-lambda"
  }
}


resource "aws_security_group" "lambda_sg" {
  name        = "expense-lambda-sg"
  description = "Security group for expense tracker Lambda"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "HTTPS to AWS services (Secrets Manager, S3)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "PostgreSQL to RDS private DB subnets"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [
      aws_subnet.private_db_1.cidr_block,
      aws_subnet.private_db_2.cidr_block
    ]
  }

  tags = {
    Name = "expense-lambda-sg"
  }
}

resource "aws_iam_role_policy_attachment" "expense_lambda_vpc_policy_attachment" {
  role       = aws_iam_role.expense_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/expense-tracker-lambda"
  retention_in_days = 14

  tags = {
    Name = "expense-tracker-lambda-logs"
  }
}
