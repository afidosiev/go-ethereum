variable "aws_environment" {
  description = "Environment to use"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS Region to use"
  type        = string
  default     = "eu-west-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the EKS VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "dns_hostnames_enabled" {
  description = "Enable VPC DNS hostnames"
  type        = bool
  default     = true
}

variable "dns_support_enabled" {
  description = "Enable VPC DNS Support"
  type        = bool
  default     = true
}

variable "eks_cp_public_subnets" {
  description = "EKS Control Plain public subnets and zones"
  type        = list(list(string))
  default     = [["10.0.10.0/28", "a"], ["10.0.10.16/28", "b"]]
}

variable "eks_worker_nodes_subnets" {
  description = "EKS worker nodes subnets and zones"
  type        = list(list(string))
  default     = [["10.0.0.0/24", "a"]]
}

variable "eks_version" {
  description = "Version for EKS cluster"
  type        = string
  default     = "1.32"
}

variable "service_node_group_ami_type" {
  description = "AMI type for service node group"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "service_node_group_instance_types" {
  description = "Instance types for service node group"
  type        = list(string)
  default     = ["t3.medium"]
}
