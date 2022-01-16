terraform {
  source = "git::git@github.com:terraform-aws-modules/terraform-aws-s3-bucket.git?ref=v2.12.0"
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

  bucket_prefix = "backups"
  acl    = "private"

  versioning = {
    enabled = false
  }

  lifecycle_rule = [
    {
      id      = "delete_after_10days"
      enabled = true
      # prefix  = "log/"
      expiration = {
        days = 10
      }
    },
  ]
  // tags        = local.tags
}
