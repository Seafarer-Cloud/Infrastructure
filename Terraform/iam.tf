# Karpenter Node IAM Role
resource "aws_iam_role" "karpenter_node_role" {
  name = "KarpenterNodeRole-${local.name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach policies to the Karpenter Node IAM Role
resource "aws_iam_role_policy_attachment" "karpenter_worker_node_policy" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "karpenter_cni_policy" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "karpenter_ecr_readonly_policy" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "karpenter_ssm_managed_instance_core_policy" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create Instance Profile for Karpenter Nodes
resource "aws_iam_instance_profile" "karpenter_instance_profile" {
  name = "KarpenterNodeInstanceProfile-${local.name}"
  role = aws_iam_role.karpenter_node_role.name
}

# Karpenter Controller IAM Role
module "iam_assumable_role_karpenter" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "4.7.0"
  create_role                   = true
  role_name                     = "karpenter-controller-${local.name}"
  provider_url                  = module.eks.cluster_oidc_issuer_url
  oidc_fully_qualified_subjects = ["system:serviceaccount:karpenter:karpenter"]
}

# Attach policy to the Karpenter Controller IAM Role
resource "aws_iam_role_policy" "karpenter_controller" {
  name = "karpenter-controller-policy"
  role = module.iam_assumable_role_karpenter.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:RunInstances",
          "ec2:CreateTags",
          "iam:PassRole",
          "ec2:TerminateInstances",
          "ec2:DeleteLaunchTemplate",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ssm:GetParameter",
          "pricing:GetProducts",
          "iam:GetInstanceProfile",
          "ec2:DescribeImages",
          "iam:CreateInstanceProfile",
          "ec2:DescribeSpotPriceHistory",
          "iam:TagInstanceProfile",
          "eks:DescribeCluster",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:DeleteInstanceProfile",
          "eks:ListClusters"
        ],
        Resource = "*"
      }
    ]
  })
}
