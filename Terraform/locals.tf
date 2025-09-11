locals {
  name   = "applications"
  region = "eu-west-3"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  namespace = "karpenter"

  tags = {
    Blueprint = local.name
  }
}
