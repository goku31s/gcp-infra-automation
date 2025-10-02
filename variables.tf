variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "Region for regional resources"
  type        = string
}

variable "zone" {
  description = "Zone for zonal resources (MIG)"
  type        = string
}

variable "instance_type" {
  description = "Machine type for instances"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR range for the subnet"
  type        = string
}

variable "name_prefix" {
  description = "Prefix to use for resource names"
  type        = string
}

variable "autoscaler_min_replicas" {
  description = "Minimum size of the MIG"
  type        = number
}

variable "autoscaler_max_replicas" {
  description = "Maximum size of the MIG"
  type        = number
}
#
