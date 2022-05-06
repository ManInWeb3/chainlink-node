terraform {
  source = "git::git@github.com:terraform-aws-modules/terraform-aws-autoscaling.git?ref=v4.9.0"
  // source = "../../..//modules/terraform-aws-autoscaling"
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
dependency "sg" {
  config_path = "../../security-group"
}
dependency "iam" {
  config_path = "../../ec2-iam-role"
}
dependency "nlb" {
  config_path = "../nlb"
}
dependency "db" {
  config_path = "../aurora"
}

inputs = {
  name = "${local.name}-asg"
  create_asg = true

  vpc_zone_identifier       = dependency.vpc.outputs.private_subnets
  security_groups           = [dependency.sg.outputs.security_group_id]
  min_size                  = 0
  max_size                  = 1
  desired_capacity          = 1
  # wait_for_capacity_timeout = 0
  health_check_type         = "ELB"
  health_check_grace_period = local.env.inputs.asg_health_check_grace_period # !!!!!!!
  target_group_arns = dependency.nlb.outputs.target_group_arns
  # Launch template
  user_data_base64 = base64encode(templatefile("../../../templates/userdata.sh", {
    backup_s3            = local.env.inputs.backup_s3
    node_to_run          = local.env.inputs.node_to_run
    ethereum_network     = local.env.inputs.ethereum_network
    ethereum_url         = local.env.inputs.ethereum_url

    db_name     = local.env.inputs.db_database_name
    db_address  = dependency.db.outputs.cluster_endpoint
    db_username = dependency.db.outputs.cluster_master_username
    db_password = dependency.db.outputs.cluster_master_password

    openethereum_version = local.env.inputs.openethereum_version
    chainlink_version    = local.env.inputs.chainlink_version

    aws_region  = local.env.inputs.aws_region
  }))

  use_lt                 = true
  create_lt              = true
  update_default_version = true

  lt_name               = "${local.name}-lt"
  key_name              = local.env.inputs.key_name
  image_id              = local.env.inputs.image_id
  instance_type         = local.env.inputs.instance_type

  iam_instance_profile_arn = dependency.iam.outputs.iam_instance_profile_arn
  block_device_mappings = [
   {
      device_name = "/dev/sdb"
      no_device   = 1
      ebs = {
        delete_on_termination = true
        encrypted             = false
        volume_size           = 500
        volume_type           = "gp2"
      }
    }
  ]
  # enable_monitoring = true

  # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-optimized.html
  # ebs_optimized     = true

  # cpu_options = {
  #   core_count       = 1
  #   threads_per_core = 1
  # }

  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      checkpoint_delay       = 600
      checkpoint_percentages = [35, 70, 100]
      instance_warmup        = 300
      min_healthy_percentage = 50
    }
    triggers = ["tag"]
  }

  // network_interfaces = [
  //   {
  //     delete_on_termination = true
  //     description           = "eth0"
  //     device_index          = 0
  //     security_groups       = [module.asg_sg.security_group_id]
  //   },
  //   {
  //     delete_on_termination = true
  //     description           = "eth1"
  //     device_index          = 1
  //     security_groups       = [module.asg_sg.security_group_id]
  //   }
  // ]

  // placement = {
  //   availability_zone = "${local.env.inputs.region}b"
  // }

  # instance_refresh = {
  #   strategy = "Rolling"
  #   preferences = {
  #     checkpoint_delay       = 600
  #     checkpoint_percentages = [35, 70, 100]
  #     instance_warmup        = 300
  #     min_healthy_percentage = 50
  #   }
  #   triggers = ["tag"]
  # }

  // tag_specifications = [
  //   {
  //     resource_type = "instance"
  //     tags          = { WhatAmI = "Instance" }
  //   },
  //   {
  //     resource_type = "volume"
  //     tags          = merge({ WhatAmI = "Volume" }, local.env.inputs.tags_as_map)
  //   },
  //   {
  //     resource_type = "spot-instances-request"
  //     tags          = merge({ WhatAmI = "SpotInstanceRequest" }, local.env.inputs.tags_as_map)
  //   }
  // ]
  tags = [local.env.inputs.tags]
  // tags        = local.env.inputs.tags
  // tags_as_map = local.env.inputs.tags_as_map

}
