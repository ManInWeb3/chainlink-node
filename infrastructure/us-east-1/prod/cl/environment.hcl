inputs = {
##### === COMMON settings
  #!!! EC2 Instance
  # CL - t3.micro
  # OE - t3.large
  instance_type         = "t3.micro"

  environment      = "dev"
  node_to_run      = "cl"
  ethereum_network = "rinkeby"
  #!!!  Depends on the backup size
  # cl = 300
  asg_health_check_grace_period = 900

  # EC2 instance
  key_name              = "vlad"
  image_id              = "ami-0ed9277fb7eb570c9"
  #Backups
  backup_s3  = "backups20220116021100973800000001"

  # REgion
  aws_region = "us-east-1"

  # tags
  tags = {
    Owner       = "user"
    Environment = "dev"
    node        = "chainlink"
  }

#####=== Ethereum node settings
  # openethereum -> oe
  openethereum_version    = "v3.3.3"

#####=== ChainLink node settings
  # chainlink    -> cl
  # nonroot id 14933
  chainlink_version    = "1.0.1-nonroot"

  ethereum_url = "wss://rinkeby-light.eth.linkpool.io/ws"
  # ethereum_url = "wss://oe-rinkeby-dev-nlb-2f0d028af47f2019.elb.us-east-1.amazonaws.com:8546/"     # By dependency???

  # DB
  db_instance_class = "db.t3.medium"
  db_database_name  = "chainlink"
  db_username       = "root"

}
