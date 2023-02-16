provider "aws" {
  region  = var.region
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

data "aws_availability_zones" "available" {
}

resource "aws_security_group" "worker_group_mgmt_one" {
  name_prefix = "worker_group_mgmt_one"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }
}

resource "aws_security_group" "all_worker_mgmt" {
  name_prefix = "all_worker_management"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
    ]
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


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"

  name                 = "test-vpc"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  database_subnets     = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  identifier = "rds-todo"

  engine               = "mysql"
  engine_version       = "8.0"
  family               = "mysql8.0"
  major_engine_version = "8.0"
  instance_class       = "db.t3.micro"
  allocated_storage    = 5
  storage_encrypted    = false
  skip_final_snapshot  = true
  create_random_password = false

  db_name  = "flask"
  username = "user"
  password = "password"
  port     = "3306"

  create_db_subnet_group = true
  subnet_ids = module.vpc.database_subnets
  vpc_security_group_ids  = [aws_security_group.allow_mysql_conn.id]

  tags = {
    Owner       = "user"
    Environment = "dev"
  }
}


module "eks" {
  source       = "terraform-aws-modules/eks/aws"
  cluster_name    = var.cluster_name
  cluster_version = "1.22"
  subnets         = module.vpc.private_subnets
  version = "17.1.0"
  cluster_create_timeout = "1h"
  cluster_endpoint_private_access = true 

  vpc_id = module.vpc.vpc_id

  worker_groups = [
    {
      name                          = "worker-group-1"
      instance_type                 = "t2.small"
      additional_userdata           = "echo foo bar"
      asg_desired_capacity          = 1
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
    },
  ]

  worker_additional_security_group_ids = [aws_security_group.all_worker_mgmt.id]
  map_roles                            = var.map_roles
  map_users                            = var.map_users
  map_accounts                         = var.map_accounts
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

resource "kubernetes_deployment" "todo-app" {
  metadata {
    name = "todo-app"
    labels = {
      test = "todo-app"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        test = "todo-app"
      }
    }

    template {
      metadata {
        labels = {
          test = "todo-app"
        }
      }

      spec {
        container {
          image = "mfermie/myapp:1.0.4"
          name  = "todo-app"

          env {
            name = "MYSQL_HOST"
            value = module.db.db_instance_address
          }
          env {
            name  = "MYSQL_USER"
            value = "user"
          }
          env {
            name  = "MYSQL_PASS"
            value = "password"
          }
          env {
            name  = "MYSQL_DB"
            value = "flask"
          }

          resources {
            limits = {
              cpu    = "100"
              memory = "128Mi"
            }
            requests = {
              cpu    = "150m"
              memory = "128Mi"
            }
          }

        }
      }
    }
  }
}

resource "kubernetes_service" "example" {       	   
  metadata {    					   
    name = "todo-app"  			   
  }     						   
  spec {						   
    selector = {					   
      test = "todo-app"     			   
    }   						   
    port {      					   
      port        = 80  				   
      target_port = 5000  				   
    }   						   
							   
    type = "LoadBalancer"       			   
  }     						   
}							   
