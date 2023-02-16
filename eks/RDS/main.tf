provider "aws" {
  region     = "eu-west-1"
}

data "aws_availability_zones" "available" {
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "rds-vpc"
  cidr = "10.0.0.0/16"

  azs              = data.aws_availability_zones.available.names
  private_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets   = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]

  tags = {
    Terraform = "true"
    Environment = "rds-test"
  }
}

resource "aws_security_group" "allow_ssh_conn" {
  name        = "allow_ssh_conn"
  description = "Allow SSH inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH into VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP into VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Outbound Allowed"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_mysql_conn" {
  name        = "allow_mysql_conn"
  description = "Allow MySQL inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "MySQL into VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Outbound Allowed"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "myec2" {
   ami = "ami-01cae1550c0adea9c"
   instance_type = "t2.micro"
   key_name = "Elly"
   vpc_security_group_ids  = [aws_security_group.allow_ssh_conn.id]
   subnet_id = module.vpc.public_subnets[0]
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"

  identifier = "rds-todo"

  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 5
  storage_encrypted = false

  create_random_password = false
  db_name  = "flask"
  username = "user"
  password = "password"
  port     = "3306"

  create_db_subnet_group = true
  subnet_ids = module.vpc.database_subnets
  vpc_security_group_ids  = [aws_security_group.allow_mysql_conn.id]

  #maintenance_window = "Mon:00:00-Mon:03:00"
  #backup_window      = "03:00-06:00"

  ## Enhanced Monitoring - see example for details on how to create the role
  ## by yourself, in case you don't want to create it automatically
  #monitoring_interval = "30"
  #monitoring_role_name = "MyRDSMonitoringRole"
  #create_monitoring_role = true

  tags = {
    Owner       = "user"
    Environment = "dev"
  }

  family = "mysql8.0"
  major_engine_version = "8.0"

}
