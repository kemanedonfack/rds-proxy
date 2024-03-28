module "db_security_group" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "MySQL Database security group"
  description = "Security group for MySQL"
  vpc_id      = data.aws_vpc.infrastructure_vpc.id

  ingress_with_cidr_blocks = [
    {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      description = " "
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = -1
      description = " "
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

resource "aws_db_subnet_group" "database_subnet" {
  name       = "db-group-demo"
  subnet_ids = [data.aws_subnet.first_subnet.id, data.aws_subnet.second_subnet.id] #private subnets ids
}

module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier           = "mydb"
  engine               = "mysql"
  engine_version       = "8.0"
  family               = "mysql8.0" # DB parameter group
  major_engine_version = "8.0"      # DB option group
  instance_class       = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100

  db_name  = "aws"
  username = "admin"
  password = "DB-Pass01"
  port     = 3306

  multi_az               = false
  db_subnet_group_name   = aws_db_subnet_group.database_subnet.name
  vpc_security_group_ids = [module.db_security_group.security_group_id]

  enabled_cloudwatch_logs_exports = ["general"]
  create_cloudwatch_log_group     = true

  skip_final_snapshot = true
  deletion_protection = false

  performance_insights_enabled          = false
  performance_insights_retention_period = 7
  create_monitoring_role                = true
  monitoring_interval                   = 60
}

module "rds_proxy" {
  source = "terraform-aws-modules/rds-proxy/aws"

  name                   = "rds-proxy"
  iam_role_name          = "rds-proxy-role"
  vpc_subnet_ids         = [data.aws_subnet.first_subnet.id, data.aws_subnet.second_subnet.id]
  vpc_security_group_ids = [module.db_security_group.security_group_id]

  auth = {
    "admin" = {
      description = "RDS MySQL superuser password"
      secret_arn  = module.secrets_manager.secret_arn
    }
  }

  # Target MySQL Instance
  engine_family = "MYSQL"
  debug_logging = true

  # Target RDS instance
  target_db_instance     = true
  db_instance_identifier = module.db.db_instance_identifier

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

module "secrets_manager" {
  source = "terraform-aws-modules/secrets-manager/aws"

  # Secret
  name_prefix             = "example"
  description             = "Example Secrets Manager secret"
  recovery_window_in_days = 30

  # Policy
  create_policy       = true
  block_public_policy = true
  policy_statements = {
    read = {
      sid = "AllowAccountRead"
      principals = [{
        type        = "AWS"
        identifiers = ["arn:aws:iam::625243961866:root"]
      }]
      actions   = ["secretsmanager:GetSecretValue"]
      resources = ["*"]
    }
  }

  secret_string = jsonencode({
    username = "admin"
    password = "DB-Pass01"
  })

  tags = {
    Environment = "Development"
    Project     = "Example"
  }
}
