terraform {
  source = "git::git@github.com:terraform-aws-modules/terraform-aws-alb.git?ref=v6.6.1"
}

include {
  path = find_in_parent_folders()
}

locals {
  // env_vars = merge(
  //   yamldecode(
  //     file(find_in_parent_folders("folder.yaml")),
  //   ),
  //   yamldecode(
  //     file(find_in_parent_folders("project.yaml")),
  //   )
  // )

}
dependency "vpc" {
  config_path = "../../vpc"
}
dependency "sg" {
  config_path = "../../security-group"
}

inputs = {
  name = "ethereum-mainnet-prod-nlb"

  vpc_id          = dependency.vpc.outputs.vpc_id
  subnets         = dependency.vpc.outputs.private_subnets
  # security_groups = [dependency.sg.outputs.security_group_id]
  internal        = true
  enable_cross_zone_load_balancing = true
  load_balancer_type = "network"

  http_tcp_listeners = [
    {
      port               = 8545
      protocol           = "TCP"
      target_group_index = 0
    },
    {
      port               = 8546
      protocol           = "TCP"
      target_group_index = 1
    },
  ]

  target_groups = [
    {
      name             = "nlb-targetgroup-8545"
      backend_protocol = "TCP"
      backend_port     = 8545
      target_type      = "instance"
    },
    {
      name             = "nlb-targetgroup-8546"
      backend_protocol = "TCP"
      backend_port     = 8546
      target_type      = "instance"
    },
  ]

  # access_logs = {
  #   bucket = aws_s3_bucket.logs.id
  # }

  # tags = {
  #   Owner       = "user"
  #   Environment = "dev"
  # }

  # ELB attachments
  # number_of_instances = var.number_of_instances
  # instances           = module.ec2_instances.id
  # tags        = local.tags
}
