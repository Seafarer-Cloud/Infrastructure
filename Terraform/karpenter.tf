resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1beta1
    kind: EC2NodeClass
    metadata:
      name: karpenter
    spec:
      amiFamily: AL2
      role: "${basename(module.eks_blueprints_addons.karpenter.node_iam_role_arn)}"
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      ttlSecondsAfterEmpty: 30
      ttlSecondsAfterScaleUp: 300
  YAML

  depends_on = [
    module.eks,
    aws_eks_access_entry.karpenter_node_access_entry,
    aws_security_group.karpenter_node_sg,
  ]
}

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
            - key: kubernetes.io/arch
              operator: In
              values: ["arm64"]
            - key: kubernetes.io/os
              operator: In
              values: ["linux"]
      disruption:
        consolidationPolicy: WhenEmpty
        consolidateAfter: 30s

  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class,
  ]
}

provider "kubectl" {
  config_path            = pathexpand("~/.kube/config")
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}
