# Manage Kubernetes Config

locals {
  user = "${module.eks.cluster_name}-adm"
}

resource "null_resource" "kubeconfig" {
  depends_on = [module.eks]

  # Update Kubernetes Config File
  provisioner "local-exec" {
    command = <<EOF
      aws eks update-kubeconfig --name ${module.eks.cluster_name} --user-alias ${local.user} --alias ${module.eks.cluster_name}@${local.user} --region ${var.region}
    EOF
  }

  triggers = {
    user         = local.user
    cluster_arn  = module.eks.cluster_arn
    cluster_name = module.eks.cluster_name
  }
}

output "update-kubeconfig" {
  # output "kubeconfig-update" {
  value = <<EOF
    aws eks update-kubeconfig --name ${module.eks.cluster_name} --user-alias ${local.user} --alias ${module.eks.cluster_name}@${local.user} --region ${var.region}
    EOF
}

output "delete-kubeconfig" {
  # output "kubeconfig-delete" {
  value = <<EOF
    kubectl config delete-user ${local.user}
    kubectl config delete-cluster ${module.eks.cluster_arn}
    kubectl config delete-context ${module.eks.cluster_name}@${local.user}
    EOF
}
