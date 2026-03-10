resource "aws_db_subnet_group" "main" {
  name       = "db-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

resource "aws_db_instance" "app_db" {
  identifier        = "app-db"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.sg_db.id]

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  skip_final_snapshot     = true
  publicly_accessible     = false
  multi_az                = true
  storage_encrypted       = true
  deletion_protection     = true
  backup_retention_period = 7

}





