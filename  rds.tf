resource "aws_db_subnet_group" "employee_db" {
  name       = "${var.project}-db-subnet-group"
  subnet_ids = [aws_subnet.private_db_1.id, aws_subnet.private_db_2.id]

  tags = {
    Name = "${var.project}-db-subnet-group"
  }
}

resource "aws_db_instance" "employee_db" {
  identifier             = "${var.project}-employee-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = "employee_db"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.employee_db.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  tags = {
    Name = "${var.project}-employee-db"
  }
}

output "db_endpoint" {
  value       = aws_db_instance.employee_db.endpoint
  description = "Database endpoint"
}

output "db_name" {
  value = aws_db_instance.employee_db.db_name
}