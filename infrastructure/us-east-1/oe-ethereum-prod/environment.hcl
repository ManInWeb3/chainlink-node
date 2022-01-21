inputs = {
  backup_s3  = "backups20220116021100973800000001"

  #  Depends on the backup size
  asg_health_check_grace_period = 1800

  # openethereum -> oe
  # chainlink    -> cl
  node_to_run  = "oe"
  ethereum_network     = "ethereum"

  openethereum_version    = "v3.3.3"
  chainlink_version    = "v3.3.3"

  environment = "prod"

  key_name              = "vlad"
  image_id              = "ami-0ed9277fb7eb570c9"
  instance_type         = "t3.large"
}
