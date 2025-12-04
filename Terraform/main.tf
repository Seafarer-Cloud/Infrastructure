# This provider is required for ECR to authenticate with public repos. Please note ECR authentication requires us-east-1 as region hence its hardcoded below.
# If your region is same as us-east-1 then you can just use one aws provider

data "aws_availability_zones" "available" {
  # Do not include local zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}


################################################################################
# Cluster
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name                   = local.name
  kubernetes_version     = "1.33"
  endpoint_public_access = true

  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnets
  endpoint_private_access = false

  enable_irsa = true



  addons = {
    coredns = {
      most_recent = true

      timeouts = {
        create = "25m"
        delete = "10m"
      }

      configuration_values = jsonencode({
        computeType = "Fargate"
        # Ensure that the we have a replica that is not on the same node
        # to avoid single point of failure
        replicaCount = 2
        resources = {
          limits = {
            cpu    = "0.25"
            memory = "256M"
          }
          requests = {
            cpu    = "0.25"
            memory = "256M"
          }
        }
      })
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  fargate_profiles = {
    karpenter = {
      selectors = [
        { namespace = "karpenter" }
      ]
    }
    kube-system = {
      selectors = [
        { namespace = "kube-system" }
      ]
    }
  }

  tags = local.tags
}
