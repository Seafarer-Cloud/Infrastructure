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
  kubernetes_version     = "1.31"
  endpoint_public_access = true

  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnets
  endpoint_private_access = false

  enable_irsa                              = true
  enable_cluster_creator_admin_permissions = true

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
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa_role.arn
    }
  }

  eks_managed_node_groups = {
    system = {
      name           = "system-node-group"
      instance_types = ["t3.small"]
      min_size       = 1
      max_size       = 2
      desired_size   = 2

      taints = {
        # This taint tells kubernetes that this node is only for system components
        # We don't want to schedule user workloads on it
        # But we don't strictly enforce it with "NoSchedule" to allow some flexibility if needed
        # actually for system components we usually don't taint, or we use CriticalAddonsOnly
        # Let's keep it simple for now and just rely on node selector/affinity if needed, 
        # or just let them run here. 
        # Actually, to ensure only system components run here, we could taint. 
        # But for now, let's just create the node group.
      }
    }
  }



  tags = local.tags
}
