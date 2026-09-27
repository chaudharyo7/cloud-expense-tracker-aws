resource "aws_db_subnet_group" "expense_db_subnet_group" {
  name = "expense-db-subnet-group"

  subnet_ids = [
    aws_subnet.private_db_1.id,
    aws_subnet.private_db_2.id
  ]

  tags = {
    Name = "expense-db-subnet-group"
  }
}
resource "aws_db_instance" "expense_db_instance" {
  identifier                  = "expense-tracker-db"
  db_name                     = "expense_db"
  username                    = var.db_username
  manage_master_user_password = true
  engine                      = "postgres"
  engine_version              = "17"
  storage_type                = "gp3"

  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_subnet_group_name   = aws_db_subnet_group.expense_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  skip_final_snapshot = true
  publicly_accessible = false
  storage_encrypted   = true
  deletion_protection = true

  tags = {
    Name = "expense-tracker-db"
  }
}
