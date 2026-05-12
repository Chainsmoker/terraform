variable "project_name" {
  type        = string
  description = "Prefix for the firewall resource name."
}

variable "droplet_id" {
  type        = string
  description = "ID of the droplet the firewall rules attach to."
}

variable "ssh_port" {
  type        = number
  description = "Inbound SSH port allowed by the firewall."
}

variable "allowed_ssh_ips" {
  type        = list(string)
  description = "CIDR blocks allowed to reach SSH. Lock down to specific IPs for higher security."
}
