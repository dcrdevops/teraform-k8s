provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      PillarName   = var.pillar_name
      CustomerName = var.customer_name
      FileName     = var.file_name
    }
  }
}

########################################################
# DATA SOURCES
########################################################

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "all" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}

data "aws_security_group" "default" {
  filter {
    name   = "group-name"
    values = ["default"]
  }

  vpc_id = data.aws_vpc.default.id
}

########################################################
# LOCALS
########################################################

locals {
  supported_azs = [
    "us-east-1a",
    "us-east-1b",
    "us-east-1c",
    "us-east-1d",
    "us-east-1f"
  ]

  filtered_subnets = [
    for subnet_id, subnet in data.aws_subnet.all :
    subnet_id
    if contains(local.supported_azs, subnet.availability_zone)
  ]

  subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : local.filtered_subnets

  security_group_ids = length(var.security_group_ids) > 0 ? var.security_group_ids : [
    data.aws_security_group.default.id
  ]
}

########################################################
# IAM ROLE - EKS CLUSTER
########################################################

resource "aws_iam_role" "eks_cluster_role" {
  name_prefix = "eks-cluster-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "eks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "eks-cluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  ])

  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = each.value
}

########################################################
# IAM ROLE - NODE GROUP
########################################################

resource "aws_iam_role" "eks_node_role" {
  name_prefix = "eks-node-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "eks-node-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_node_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  ])

  role       = aws_iam_role.eks_node_role.name
  policy_arn = each.value
}

########################################################
# EKS CLUSTER
########################################################

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids         = local.subnet_ids
    security_group_ids = local.security_group_ids
  }

  tags = {
    Name = var.cluster_name
  }
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policies
  ]
}

########################################################
# NODE GROUP
########################################################

resource "aws_eks_node_group" "default" {
  cluster_name = aws_eks_cluster.main.name
  instance_types = [
    "t3.medium",
    "t3a.medium"
  ]
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = local.subnet_ids

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  tags = {
    Name = var.node_group_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policies
  ]
}

########################################################
# FETCH COMPATIBLE ADDON VERSIONS
########################################################

data "aws_eks_addon_version" "addons" {
  for_each = toset([
    "vpc-cni",
    "kube-proxy",
    "coredns"
  ])

  addon_name         = each.value
  kubernetes_version = var.kubernetes_version
  most_recent        = true
}

########################################################
# EKS ADDONS
########################################################

resource "aws_eks_addon" "addons" {
  for_each = data.aws_eks_addon_version.addons

  cluster_name  = aws_eks_cluster.main.name
  addon_name    = each.key
  addon_version = each.value.version

  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Name = "eks-addon-${each.key}"
  }

  depends_on = [
    aws_eks_node_group.default
  ]
}
resource "kubernetes_config_map_v1_data" "aws_auth" {

  force = true

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      {
        rolearn  = aws_iam_role.eks_node_role.arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups = [
          "system:bootstrappers",
          "system:nodes"
        ]
      },
      {
        rolearn  = "arn:aws:iam::088310115913:root"
        username = "admin"
        groups = [
          "system:masters"
        ]
      }
    ])
  }

  depends_on = [
    aws_eks_node_group.default
  ]
}

data "aws_eks_cluster" "cluster" {
  name = aws_eks_cluster.main.name
}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.main.name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}