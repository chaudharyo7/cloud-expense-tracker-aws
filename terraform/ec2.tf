data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}


resource "aws_security_group" "public_sg" {
  name        = "public_sg"
  description = "Security group for public instances"
  vpc_id      = aws_vpc.main.id



  # ALB → EC2 application

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app_sg" {
  name        = "app_sg"
  description = "Security group for app instances"
  vpc_id      = aws_vpc.main.id



  # ALB → EC2 application

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_sg" {
  name        = "db_sg"
  description = "Security group for db instances"
  vpc_id      = aws_vpc.main.id



  # Backend → PostgreSQL

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }
  ingress {
    description     = "Lambda to PostgreSQL"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
  }

}


resource "aws_instance" "frontend_1" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  instance_type          = "t3.micro"
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name
  subnet_id              = aws_subnet.public_1.id
  monitoring             = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = {
    Name = "expense-tracker-frontend-1"
    Role = "frontend"
  }
}

resource "aws_instance" "frontend_2" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  instance_type          = "t3.micro"
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name
  subnet_id              = aws_subnet.public_2.id
  monitoring             = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = {
    Name = "expense-tracker-frontend-2"
    Role = "frontend"
  }
}


resource "aws_instance" "backend_1" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = "t3.micro"
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name
  subnet_id              = aws_subnet.private_app_1.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  monitoring             = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = {
    Name = "expense-tracker-backend-1"
    Role = "backend"
  }
}

resource "aws_instance" "backend_2" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = "t3.micro"
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name
  subnet_id              = aws_subnet.private_app_2.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  monitoring             = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = {
    Name = "expense-tracker-backend-2"
    Role = "backend"
  }
}
