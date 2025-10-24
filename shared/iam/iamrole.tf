# IAM Role for EKS to Access S3
resource "aws_iam_role" "eks_s3_role" {
  name = "eks-s3-role-${random_string.suffix.result}"

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

# IAM Policy for ClusterAutoscaler
resource "aws_iam_policy" "cluster_autoscaler_policy" {
  name = "AmazonEKSClusterAutoscalerPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeLaunchTemplateVersions"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "cluster_autoscaler_role" {
  name = "eks-cluster-autoscaler-role-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# IAM Policy for EKS to Access S3
resource "aws_iam_policy" "eks_s3_policy" {
  name = "eks-s3-policy-${random_string.suffix.result}"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = [
          "${aws_s3_bucket.eks_private_s3.arn}",
          "${aws_s3_bucket.eks_private_s3.arn}/*"
        ]
      }
    ]
  })
}

# Attach IAM Policy to Role
resource "aws_iam_role_policy_attachment" "eks_s3_attachment" {
  role       = aws_iam_role.eks_s3_role.name
  policy_arn = aws_iam_policy.eks_s3_policy.arn
}

# resource "aws_iam_role_policy_attachment" "cluster_autoscaler_attach" {
#   role       = aws_iam_role.cluster_autoscaler_role.name
#   policy_arn = aws_iam_policy.cluster_autoscaler_policy.arn
# }


resource "kubernetes_service_account" "cluster_autoscaler" {
  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.cluster_autoscaler_role.arn
    }
  }
}

resource "null_resource" "wait_for_node_group" {
  depends_on = [
    module.eks
  ]
}

data "aws_iam_role" "node_group_role" {
  depends_on = [null_resource.wait_for_node_group]
  name = module.eks.eks_managed_node_groups["main_group"].iam_role_name
}

resource "aws_iam_policy_attachment" "autoscaler_policy_attach" {
  name       = "cluster-autoscaler-attach"
  roles      = [data.aws_iam_role.node_group_role.name]
  policy_arn = aws_iam_policy.cluster_autoscaler_policy.arn

  depends_on = [null_resource.wait_for_node_group]
}


# Attach IAM Policy to Role
# resource "aws_iam_role_policy_attachment" "eks_s3_attachment" {
#   role       = aws_iam_role.eks_s3_role.name
#   policy_arn = aws_iam_policy.eks_s3_policy.arn
# }
