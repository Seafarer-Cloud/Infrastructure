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

  create_pod_identity_association = true

  tags = local.tags

  depends_on = [module.eks]
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

  values = [
    <<-EOT
    dnsPolicy: Default
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: ${module.karpenter.iam_role_arn}
    webhook:
      enabled: false
    EOT
  ]

  lifecycle {
    ignore_changes = [
      repository_password
    ]
  }

  depends_on = [module.karpenter]
}

# Karpenter Node Class
resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: EC2NodeClass
    metadata:
      name: karpenter
    spec:
      amiFamily: AL2
      instanceProfile: "${aws_iam_instance_profile.karpenter_instance_profile.name}"
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
  YAML

  depends_on = [
    module.eks,
    module.karpenter,
    aws_iam_instance_profile.karpenter_instance_profile,
    aws_security_group.karpenter_node_sg,
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
            apiVersion: karpenter.k8s.aws/v1beta1
            kind: EC2NodeClass
            name: karpenter
          requirements:
            - key: "karpenter.sh/capacity-type"
              operator: In
              values: ["on-demand", "spot"]
            - key: kubernetes.io/os
              operator: In
              values: ["linux"]
      ttlSecondsAfterEmpty: 30
      ttlSecondsUntilExpired: 2592000
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class,
  ]
}
