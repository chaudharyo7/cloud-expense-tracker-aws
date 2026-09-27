resource "aws_s3_bucket" "expense_bucket" {
  bucket = "expense-tracker-bucket-${var.project_suffix}"
  tags = {
    Name = "expense-tracker-bucket-${var.project_suffix}"
  }
}

resource "aws_s3_bucket_public_access_block" "expense_bucket_access" {
  bucket = aws_s3_bucket.expense_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "expense_bucket_versioning" {
  bucket = aws_s3_bucket.expense_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "expense_bucket_encryption" {
  bucket = aws_s3_bucket.expense_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "expense_bucket_policy" {
  bucket = aws_s3_bucket.expense_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceTLSRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.expense_bucket.arn,
          "${aws_s3_bucket.expense_bucket.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
resource "aws_s3_bucket" "expense_logs_bucket" {
  bucket = "expense-tracker-logs-${var.project_suffix}"
  tags = {
    Name = "expense-tracker-logs-${var.project_suffix}"
  }
}

resource "aws_s3_bucket_public_access_block" "expense_logs_bucket_access" {
  bucket = aws_s3_bucket.expense_logs_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_s3_bucket_logging" "expense_bucket_logging" {
  bucket = aws_s3_bucket.expense_bucket.id

  target_bucket = aws_s3_bucket.expense_logs_bucket.id
  target_prefix = "access-logs/"
}

resource "aws_s3_bucket_policy" "expense_logs_bucket_policy" {
  bucket = aws_s3_bucket.expense_logs_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "S3ServerAccessLogsPolicy"
        Effect = "Allow"

        Principal = {
          Service = "logging.s3.amazonaws.com"
        }

        Action = "s3:PutObject"

        Resource = "${aws_s3_bucket.expense_logs_bucket.arn}/access-logs/*"

        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.expense_bucket.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "ansible_ssm_bucket" {
  bucket = "expense-tracker-ansible-ssm-${var.project_suffix}"
  tags = {
    Name = "expense-tracker-ansible-ssm-${var.project_suffix}"
  }
}

resource "aws_s3_bucket_public_access_block" "ansible_ssm_bucket_access" {
  bucket = aws_s3_bucket.ansible_ssm_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
