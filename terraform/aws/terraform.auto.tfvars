cluster_name       = "dev-eks-cluster"
kubernetes_version = "1.35"
node_group_name    = "dev-node-group"

desired_size = 2
max_size     = 3
min_size     = 2

pillar_name     = "devops"
customer_name   = "acme"
file_name       = "eks-cluster"
github_role_arn = "arn:aws:iam::088310115913:role/OpenID-Connect"

addon_versions = {

  vpc-cni    = "v1.16.4-eksbuild.1"
  kube-proxy = "v1.29.0-eksbuild.1"
  coredns    = "v1.11.1-eksbuild.4"

}