terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "expense-tracker-vpc"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  availability_zone       = "ap-south-1a"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "expense-tracker-public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  availability_zone       = "ap-south-1b"
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "expense-tracker-public-subnet-2"
  }
}

resource "aws_subnet" "private_app_1" {
  vpc_id            = aws_vpc.main.id
  availability_zone = "ap-south-1a"
  cidr_block        = "10.0.11.0/24"

  tags = {
    Name = "expense-tracker-private-subnet-1"
  }

}

resource "aws_subnet" "private_app_2" {
  vpc_id            = aws_vpc.main.id
  availability_zone = "ap-south-1b"
  cidr_block        = "10.0.12.0/24"

  tags = {
    Name = "expense-tracker-private-subnet-2"
  }

}

resource "aws_subnet" "private_db_1" {
  vpc_id            = aws_vpc.main.id
  availability_zone = "ap-south-1a"
  cidr_block        = "10.0.21.0/24"

  tags = {
    Name = "expense-tracker-private-db-subnet-1"
  }
}

resource "aws_subnet" "private_db_2" {
  vpc_id            = aws_vpc.main.id
  availability_zone = "ap-south-1b"
  cidr_block        = "10.0.22.0/24"

  tags = {
    Name = "expense-tracker-private-db-subnet-2"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "expense-tracker-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "expense-tracker-public-route-table"
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "expense-tracker-private-app-route-table"
  }
}

resource "aws_route_table_association" "private_app_1" {
  subnet_id      = aws_subnet.private_app_1.id
  route_table_id = aws_route_table.private_app.id
}

resource "aws_route_table_association" "private_app_2" {
  subnet_id      = aws_subnet.private_app_2.id
  route_table_id = aws_route_table.private_app.id
}

resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "expense-tracker-private-db-route-table"
  }
}
resource "aws_route_table_association" "private_db_1" {
  subnet_id      = aws_subnet.private_db_1.id
  route_table_id = aws_route_table.private_db.id
}

resource "aws_route_table_association" "private_db_2" {
  subnet_id      = aws_subnet.private_db_2.id
  route_table_id = aws_route_table.private_db.id
}
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "expense-tracker-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  subnet_id     = aws_subnet.public_1.id
  allocation_id = aws_eip.nat.id

  tags = {
    Name = "expense-tracker-nat-gateway"
  }
  depends_on = [
    aws_internet_gateway.main
  ]
}

resource "aws_route" "nat_app" {
  route_table_id         = aws_route_table.private_app.id
  nat_gateway_id         = aws_nat_gateway.main.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id = aws_vpc.main.id

  service_name = "com.amazonaws.ap-south-1.s3"

  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private_app.id
  ]

  tags = {
    Name = "expense-s3-endpoint"
  }
}
