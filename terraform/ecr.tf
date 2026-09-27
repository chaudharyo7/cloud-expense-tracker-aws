resource "aws_ecr_repository" "frontend" {
  name = "expense-tracker-frontend"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "expense-tracker-frontend"
  }
}

resource "aws_ecr_repository" "backend" {
  name = "expense-tracker-backend"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "expense-tracker-backend"
  }
}
