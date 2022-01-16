locals {
  region = get_env("region", "us-east-1")
}

terraform {
  extra_arguments "common" {
    commands = get_terraform_commands_that_need_vars()
    optional_var_files = [
      "${get_terragrunt_dir()}/../common.hcl"
    ]
    env_vars = {
      TF_VAR_region = get_env("region", "us-east-1")
    }
  }
}

# Generate an AWS provider block
generate "provider" {
  path      = "aws_provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
terraform {
  backend "s3" {}
}

provider "aws" {
  region = "${local.region}"
}
EOF
}

remote_state {
  backend = "s3"
  config = {
    bucket         = "tfstate.clnodes"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = get_env("region", "us-east-1")
    encrypt        = true
    dynamodb_table = "tf-locks"
  }
}
