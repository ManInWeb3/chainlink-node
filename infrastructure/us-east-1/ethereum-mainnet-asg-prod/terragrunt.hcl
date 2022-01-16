terraform {
  source = "git::git@github.com:terraform-aws-modules/terraform-aws-autoscaling.git?ref=v4.9.0"
  // source = "../../..//modules/terraform-aws-autoscaling"
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

  blockchain  = "ethereum" #"ethereum"
  # network     = ""
  openethereum_version    = "v3.3.3"

  environment = "prod"
  # ami_id = "ami-0ed9277fb7eb570c9"

  key_name              = "vlad"
  image_id              = "ami-0ed9277fb7eb570c9"
  instance_type         = "i3.xlarge"

  name = "${local.environment}-${local.blockchain}"

}

dependency "vpc" {
  config_path = "../vpc"
}
dependency "sg" {
  config_path = "../security-group"
}
dependency "iam" {
  config_path = "../ec2-iam-role"
}


inputs = {
  name = "${local.name}-asg"

  use_name_prefix = false
  create_asg = true
  vpc_zone_identifier       = dependency.vpc.outputs.private_subnets
  #["subnet-01f3827f09ad40727"] #dependency.vpc.outputs.private_subnets
  security_groups        = [dependency.sg.outputs.security_group_id]
  # ["sg-08f916b1638062a07"] 
  # [dependency.sg.outputs.security_group_id]


  min_size                  = 0
  max_size                  = 1
  desired_capacity          = 1
  // wait_for_capacity_timeout = 0
  health_check_type         = "EC2"

  # LB
  // load_balancers = 

  # Launch template
  user_data_base64 = base64encode(templatefile("../../templates/userdata.sh", {
    blockchain              = "${local.blockchain}"
    docker_compose_filename = "dc-openethereum-${local.blockchain}.yaml"
    # network                 = "mainnet"
    openethereum_version    = "${local.openethereum_version}"
  }))

  use_lt                 = true
  create_lt              = true
  update_default_version = true

  lt_name               = "${local.name}-lt"
  key_name              = "${local.key_name}"
  image_id              = "${local.image_id}"
  instance_type         = "${local.instance_type}"

  iam_instance_profile_arn = dependency.iam.outputs.iam_instance_profile_arn
  # block_device_mappings = [
  #  {
  #     device_name = "/dev/sdb"
  #     no_device   = 1
  #     ebs = {
  #       delete_on_termination = true
  #       encrypted             = false
  #       volume_size           = 500
  #       volume_type           = "gp2"
  #     }
  #   }
  # ]
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
  //   availability_zone = "${local.region}b"
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
  //     tags          = merge({ WhatAmI = "Volume" }, local.tags_as_map)
  //   },
  //   {
  //     resource_type = "spot-instances-request"
  //     tags          = merge({ WhatAmI = "SpotInstanceRequest" }, local.tags_as_map)
  //   }
  // ]

  // tags        = local.tags
  // tags_as_map = local.tags_as_map

}
