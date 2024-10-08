data "kubernetes_namespace" "karpenter" {
  metadata {
    name = "karpenter"
  }
  depends_on = [module.eks]
}

resource "kubernetes_namespace" "karpenter" {
  metadata {
    name = "karpenter"
  }

  lifecycle {
    ignore_changes = [metadata]
  }

  count = data.kubernetes_namespace.karpenter.metadata[0].name == "karpenter" ? 0 : 1

  depends_on = [module.eks]
}

# Provider kubectl
provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

# Data source pour EKS Cluster
data "aws_eks_cluster" "eks" {
  name = module.eks.cluster_name

  depends_on = [module.eks]
}

# Data source pour ECR Public Authorization Token
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.us_east
}

# Karpenter Node Class
resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1beta1
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
    aws_iam_instance_profile.karpenter_instance_profile,
    aws_security_group.karpenter_node_sg,
  ]
}

# Karpenter Node Pool
resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1beta1
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

# Helm Release pour Karpenter
resource "helm_release" "karpenter" {
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  chart               = "karpenter"
  version             = "0.36.0"
  namespace           = length(kubernetes_namespace.karpenter) > 0 ? kubernetes_namespace.karpenter[0].metadata[0].name : "karpenter"
  create_namespace    = true
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam_assumable_role_karpenter.iam_role_arn
  }

  set {
    name  = "settings.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = module.eks.cluster_endpoint
  }

  set {
    name  = "settings.defaultInstanceProfile"
    value = aws_iam_instance_profile.karpenter_instance_profile.name
  }

  set {
    name  = "logLevel"
    value = "debug"
  }

  set {
    name  = "logConfig.enabled"
    value = "true"
  }

  set {
    name  = "logConfig.errorOutputPaths[0]"
    value = "stderr"
  }

  set {
    name  = "logConfig.logEncoding"
    value = "json"
  }

  set {
    name  = "logConfig.logLevel.controller"
    value = "debug"
  }

  set {
    name  = "logConfig.logLevel.global"
    value = "debug"
  }

  set {
    name  = "logConfig.logLevel.webhook"
    value = "error"
  }

  set {
    name  = "logConfig.outputPaths[0]"
    value = "stdout"
  }

  depends_on = [
    module.eks,
    module.iam_assumable_role_karpenter,
    aws_iam_role_policy.karpenter_controller,
  ]
}
