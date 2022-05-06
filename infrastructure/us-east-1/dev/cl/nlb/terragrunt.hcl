terraform {
  source = "git::git@github.com:terraform-aws-modules/terraform-aws-alb.git?ref=v6.6.1"
}

include {
  path = find_in_parent_folders()
}

locals {
  env = merge(read_terragrunt_config(find_in_parent_folders("environment.hcl")),
              read_terragrunt_config(find_in_parent_folders("node.hcl"))
  )

  name = "${local.env.inputs.node_to_run}-${local.env.inputs.ethereum_network}-${local.env.inputs.environment}"
}
dependency "vpc" {
  config_path = "../../vpc"
}

inputs = {
  name = "${local.name}-nlb"

  vpc_id          = dependency.vpc.outputs.vpc_id
  subnets         = dependency.vpc.outputs.public_subnets
  # security_groups = [dependency.sg.outputs.security_group_id]
  internal        = false
  enable_cross_zone_load_balancing = true
  load_balancer_type = "network"

  http_tcp_listeners = [
    {
      port               = 6689
      protocol           = "TCP"
      target_group_index = 0
    },
  ]

  target_groups = [
    {
      name             = "${local.name}-tcp6689"
      backend_protocol = "TCP"
      backend_port     = 6689
      target_type      = "instance"
    },
  ]

  # access_logs = {
  #   bucket = aws_s3_bucket.logs.id
  # }

  tags = local.env.inputs.tags
}
