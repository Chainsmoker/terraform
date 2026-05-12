variable "project_name" {
  type        = string
  description = "Prefix for VPC and reserved IP resources."
}

variable "region" {
  type        = string
  description = "DigitalOcean region for the VPC and reserved IP."
}

variable "vpc_ip_range" {
  type        = string
  description = "Private IPv4 CIDR for the VPC. Change if you run multiple infras in the same DO account + region to avoid collision."
  default     = "10.20.0.0/20"

  validation {
    condition     = can(cidrhost(var.vpc_ip_range, 0))
    error_message = "vpc_ip_range must be a valid IPv4 CIDR (e.g. 10.20.0.0/20)."
  }
}
