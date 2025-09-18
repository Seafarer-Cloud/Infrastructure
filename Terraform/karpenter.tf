################################################################################
# Controller & Node IAM roles, SQS Queue, Eventbridge Rules
################################################################################

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 21.0"

  cluster_name = module.eks.cluster_name
  namespace    = local.namespace

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  node_iam_role_use_name_prefix = false
  node_iam_role_name            = local.name

  # Use IRSA instead of Pod Identity
  create_pod_identity_association = false
  create_instance_profile         = true

  # Force recreation of IAM role with correct trust policy for IRSA
  iam_role_use_name_prefix = false

  tags = local.tags

  depends_on = [module.eks]
}

# Override the controller role trust policy to use IRSA instead of Pod Identity
resource "aws_iam_role" "karpenter_controller_irsa" {
  name = "KarpenterController"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:karpenter:karpenter"
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.tags

  depends_on = [module.karpenter]
}

################################################################################
# Helm charts
################################################################################

resource "helm_release" "karpenter" {
  name                = "karpenter"
  namespace           = local.namespace
  create_namespace    = true
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "1.6.3"
  wait                = false

  set = [{
    name  = "settings.clusterName"
    value = module.eks.cluster_name
    }, {
    name  = "settings.clusterEndpoint"
    value = module.eks.cluster_endpoint
    }, {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.iam_role_arn
    }, {
    name  = "settings.aws.defaultInstanceProfile"
    value = module.karpenter.instance_profile_name
    }, {
    name  = "settings.aws.interruptionQueueName"
    value = module.karpenter.queue_name
  }]

  lifecycle {
    ignore_changes = [
      repository_password
    ]
  }

  depends_on = [
    module.karpenter,
    module.eks.fargate_profiles
  ]
}

# Karpenter Node Class
resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: karpenter
    spec:
      amiSelectorTerms:
        - alias: al2023@latest
      role: "${module.karpenter.node_iam_role_arn}"
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      # userData: |
      #   #!/bin/bash
      #   dnf install -y amazon-eks-node
      #   /usr/bin/nodeadm init --cluster-name ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
  YAML

  depends_on = [
    module.eks,
    module.karpenter,
    helm_release.karpenter
  ]
}

# Karpenter Node Pool
resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: karpenter
    spec:
      template:
        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: karpenter
          requirements:
            - key: "karpenter.sh/capacity-type"
              operator: In
              values: ["on-demand", "spot"]
            - key: kubernetes.io/os
              operator: In
              values: ["linux"]
            - key: "karpenter.k8s.aws/instance-hypervisor"
              operator: In
              values: ["nitro"]
      ttlSecondsAfterEmpty: 30
      ttlSecondsUntilExpired: 2592000
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class,
  ]
}
