resource "aws_eks_cluster" "eks" {
  name     = "eks-${var.aws_environment}"
  version  = var.eks_version
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids              = aws_subnet.eks_cp_subnets[*].id
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cp_policy]
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "eks-pod-identity-agent"

  tags = {
    Name = "eks-pod-identity-agent-${var.aws_environment}"
  }

}

resource "aws_eks_addon" "csi_addon" {
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "aws-ebs-csi-driver"

  pod_identity_association {
    role_arn        = aws_iam_role.csi_role.arn
    service_account = "ebs-csi-controller-sa"
  }

  tags = {
    Name = "eks-csi-${var.aws_environment}"
  }

  depends_on = [aws_eks_addon.pod_identity_agent]
}

resource "aws_eks_addon" "cni_addon" {
  cluster_name                = aws_eks_cluster.eks.name
  addon_name                  = "vpc-cni"
  addon_version               = "v1.19.3-eksbuild.1"
  resolve_conflicts_on_create = "OVERWRITE"

  pod_identity_association {
    role_arn        = aws_iam_role.cni_role.arn
    service_account = "aws-node"
  }

  tags = {
    Name = "eks-cni-${var.aws_environment}"
  }

  depends_on = [aws_eks_addon.pod_identity_agent]

}

resource "kubernetes_storage_class_v1" "gp3_sc" {
  metadata {
    name = "encrypted-sc"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "ebs.csi.aws.com"
  parameters = {
    type      = "gp3"
    encrypted = "true"
  }
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = "true"

  depends_on = [aws_eks_addon.csi_addon]

}

resource "aws_eks_node_group" "services_node_group" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "eks-node-group-${var.aws_environment}"
  node_role_arn   = aws_iam_role.eks_worker_nodes.arn
  subnet_ids      = aws_subnet.eks_worker_subnets[*].id
  ami_type        = var.service_node_group_ami_type
  instance_types  = var.service_node_group_instance_types
  version         = var.eks_version


  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_nodes_cni_managed_policy,
    aws_iam_role_policy_attachment.eks_worker_nodes_managed_policy,
    aws_iam_role_policy_attachment.eks_worker_nodes_ecr_read_only
  ]
}
