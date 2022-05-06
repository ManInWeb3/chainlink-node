terraform {
  source = "git::git@github.com:terraform-aws-modules/terraform-aws-security-group.git?ref=v4.8.0"
  # source = "../../..//modules/terraform-aws-security-group"
}

include {
  path = find_in_parent_folders()
}

locals {
  # Allowed CIDRs ","
  whitelist_cidrs = "121.98.71.0/24" 
}

dependency "vpc" {
  config_path = "../../vpc"
}

inputs = {
  name = "${dependency.vpc.outputs.vpc_id}-sg"
  use_name_prefix = false
  description = "Security group whitelist Chainlink Operator UI"
  vpc_id = dependency.vpc.outputs.vpc_id

  # ingress_cidr_blocks = [
  #   dependency.vpc.outputs.vpc_cidr_block,
  #   "121.98.71.0/24"
  # ]
  # ingress_rules = [
  #   "all-tcp",
  #   "all-icmp",
  # ]

  ingress_with_self = [{rule = "all-all"},]

  ingress_with_cidr_blocks = [
    {
      from_port   = 6689
      to_port     = 6689
      protocol    = "tcp"
      description = "HTTPS chainlink operator UI"
      cidr_blocks = local.whitelist_cidrs
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "SSH"
      cidr_blocks = local.whitelist_cidrs
    },
  ]

  egress_rules = ["all-all"]

    # "rpc-8545-tcp",
    # "ws-8546-tcp",
  # tags = {
  #   environment  = "dev"
  # }
}
