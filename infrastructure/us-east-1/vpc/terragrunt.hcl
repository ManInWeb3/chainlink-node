terraform {
  source = "git::git@github.com:terraform-aws-modules/terraform-aws-vpc.git?ref=v3.11.0"

}

include {
  path = find_in_parent_folders()
}


inputs = {
  name = "main-vpc"

  cidr = "10.1.0.0/16"

  azs              = ["us-east-1a"   , "us-east-1b"  ]
  private_subnets  = ["10.1.1.0/24"  , "10.1.2.0/24" ]
  public_subnets   = ["10.1.101.0/24", "10.1.201.0/24"]
  database_subnets = ["10.1.21.0/24" , "10.1.22.0/24"]

  enable_dns_support   = true
  enable_dns_hostnames = true

  enable_nat_gateway = true
  single_nat_gateway = true
  // HA NAT gateways
  // single_nat_gateway = false
  // one_nat_gateway_per_az = true
  // reuse_nat_ips = true
  // external_nat_ip_ids = [...]

  tags = {
    environment  = "dev"
  }

  private_subnet_tags = {
    scope = "private"
  }

  public_subnet_tags = {
    scope = "public"
  }
}
