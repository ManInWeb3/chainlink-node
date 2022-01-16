terraform {
  source = "git::git@github.com:terraform-aws-modules/terraform-aws-security-group.git?ref=v4.8.0"
  # source = "../../..//modules/terraform-aws-security-group"
}

include {
  path = find_in_parent_folders()
}


dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  name = "${dependency.vpc.outputs.vpc_id}-sg"
  use_name_prefix = false
  description = "Security group Allow all tcp"
  vpc_id = dependency.vpc.outputs.vpc_id

  ingress_cidr_blocks = [
    dependency.vpc.outputs.vpc_cidr_block,
  ]
  ingress_rules = [
    "all-tcp",
    "all-icmp",
  ]
  egress_rules = ["all-all"]

    # "rpc-8545-tcp",
    # "ws-8546-tcp",
  # tags = {
  #   environment  = "dev"
  # }
}
