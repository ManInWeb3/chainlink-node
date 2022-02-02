inputs = {

  node_to_run  = "cl"

  #!!! EC2 Instance
  # CL - t3.micro
  # OE - t3.large
  instance_type         = "t3.micro"

  #!!!  Depends on the backup size
  # cl = 300
  asg_health_check_grace_period = 300

}
