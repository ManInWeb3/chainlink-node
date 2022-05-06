# Chainlink oracle infra

1. Creates a VPC, secirity groups and IAM policies to let VMs save data backups to S3 
2. Deploys  Ethereum node (OpenEthereum, oe to shorten) in the private VPC. Uses docker-compose to orchestrate(docker-compose config generated with https://github.com/vlad-she/blockchain-nodes/blob/main/infrastructure/templates/userdata.sh)
3. Deploys postgres RDS as a CHainlink node DB 
4. Deploys Chainlink node (cl - short form) in private VPC. Uses docker-compose to orchestrate(docker-compose config generated with https://github.com/vlad-she/blockchain-nodes/blob/main/infrastructure/templates/userdata.sh)
5. You can use Firewal to expose Chainlink web UI. Expose it only for a list of IP addresses to secure the node ( the whitelist set in https://github.com/vlad-she/blockchain-nodes/blob/main/infrastructure/us-east-1/security-group/terragrunt.hcl#L11 )

Things to fix/improve:
1. Weird thing in github.com:terraform-aws-modules/terraform-aws-security-group.git if I change security group rule this re-cretes whole security group and sometimes forsces biger redeployment. Looks like wrong usage of the TF module, or a bug in the module need to figure out
