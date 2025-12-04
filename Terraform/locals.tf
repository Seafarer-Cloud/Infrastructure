locals {
  name   = "Seafarer-cluster"
  region = "eu-west-3"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  namespace = "karpenter"

  tags = {
    Blueprint                = local.name
    "karpenter.sh/discovery" = local.name
  }

  karpenter_version = "1.0.12" # Example version, will use latest helm chart
}
