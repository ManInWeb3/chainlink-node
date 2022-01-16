terraform {
  source = "git::git@github.com:terraform-aws-modules/terraform-aws-iam.git//modules/iam-assumable-role?ref=v4.9.0"
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

inputs = {
  create_role = true
  create_instance_profile = true

  role_name = "ServiceRole-EC2"
  role_description = "ServiceRole-EC2"
  trusted_role_services= [
    "ec2.amazonaws.com",
  ]
  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
  ]
  // tags        = local.tags
}
