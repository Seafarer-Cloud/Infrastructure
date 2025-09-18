output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${local.region} update-kubeconfig --name ${module.eks.cluster_name}"
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_identity_oidc_issuer" {
  description = "The OIDC Identity issuer for the cluster"
  value       = module.eks.oidc_provider
}

output "karpenter_iam_role_arn" {
  description = "The Amazon Resource Name (ARN) specifying the Karpenter IAM role"
  value       = module.karpenter.iam_role_arn
}

output "karpenter_iam_role_name" {
  description = "The name of the Karpenter IAM role"
  value       = module.karpenter.iam_role_name
}
