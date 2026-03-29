########################################################
# VARIABLES
########################################################

variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "node_group_name" {
  type = string
}

variable "desired_size" {
  type = number
}

variable "max_size" {
  type = number
}

variable "min_size" {
  type = number
}

variable "addon_versions" {
  type = map(string)
}

variable "subnet_ids" {
  type    = list(string)
  default = []
}

variable "security_group_ids" {
  type    = list(string)
  default = []
}

variable "github_role_arn" {
  type = string
}

########################################################
# TAG VARIABLES
########################################################

variable "pillar_name" {
  type = string
}

variable "customer_name" {
  type = string
}

variable "file_name" {
  type = string
}