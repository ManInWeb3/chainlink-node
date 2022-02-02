terraform {
  source = "git::git@github.com:terraform-aws-modules/terraform-aws-rds-aurora.git?ref=v6.1.4"
}

include {
  path = find_in_parent_folders()
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("environment.hcl"))

  name = "${local.env.inputs.ethereum_network}-${local.env.inputs.environment}"
}
dependency "vpc" {
  config_path = "../../vpc"
}
dependency "sg" {
  config_path = "../../security-group"
}
# dependency "iam" {
#   config_path = "../../ec2-iam-role"
# }
# dependency "nlb" {
#   config_path = "../nlb"
# }

inputs = {
  name = "${local.name}-postgre-db"

  engine_mode = "provisioned"
  engine         = "aurora-postgresql"
  engine_version = "11.13"
  instances = {
    master = {
      instance_class      = local.env.inputs.db_instance_class
      publicly_accessible = false
    }
  }

  # endpoints = {
  #   static = {
  #     identifier     = "static-custom-endpt"
  #     type           = "ANY"
  #     static_members = ["static-member-1"]
  #     tags           = { Endpoint = "static-members" }
  #   }
  #   excluded = {
  #     identifier       = "excluded-custom-endpt"
  #     type             = "READER"
  #     excluded_members = ["excluded-member-1"]
  #     tags             = { Endpoint = "excluded-members" }
  #   }
  # }

  vpc_id                 = dependency.vpc.outputs.vpc_id
  db_subnet_group_name   = dependency.vpc.outputs.database_subnet_group_name
  create_db_subnet_group = false
  vpc_security_group_ids  = [dependency.sg.outputs.security_group_id]

  database_name = local.env.inputs.db_database_name
  master_username        = local.env.inputs.db_username
  create_random_password = true
  iam_database_authentication_enabled = false

  apply_immediately   = true
  skip_final_snapshot = true

  # db_parameter_group_name         = aws_db_parameter_group.example.id
  # db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.example.id
  # enabled_cloudwatch_logs_exports = ["postgresql"]

  copy_tags_to_snapshot = true
  tags = local.env.inputs.tags

}
