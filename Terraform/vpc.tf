
################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = local.name
  cidr = local.vpc_cidr

  azs                = local.azs
  private_subnets    = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  public_subnets     = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 4)]
  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"              = "1"
    "kubernetes.io/cluster/${local.name}" = null
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"     = 1
    "karpenter.sh/discovery"              = local.name
    "kubernetes.io/cluster/${local.name}" = null
  }
}

