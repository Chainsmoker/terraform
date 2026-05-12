variable "do_token" {
  type        = string
  description = "DigitalOcean API token. Set via TF_VAR_do_token or export DIGITALOCEAN_TOKEN for provider auth."
  sensitive   = true
  default     = null
}

variable "project_name" {
  type        = string
  description = "Prefix used for resource names and tags."
  default     = "infra"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.project_name))
    error_message = "project_name must be lowercase, start with a letter, and contain only letters, digits and hyphens (max 31 chars)."
  }
}

variable "default_region" {
  type        = string
  description = "DigitalOcean region slug."
  default     = "nyc3"
}

variable "vpc_ip_range" {
  type        = string
  description = "Private IPv4 CIDR for the VPC. Override only if running multiple infras in the same DO account + region (rare for single-client setups)."
  default     = "10.20.0.0/20"
}

variable "default_size" {
  type        = string
  description = "Droplet size slug."
  default     = "s-2vcpu-4gb"
}

variable "droplet_image" {
  type        = string
  description = "Droplet base image slug."
  default     = "ubuntu-24-04-x64"
}

variable "ssh_port" {
  type        = number
  description = "SSH port exposed by the droplet. Default 22; use a non-standard port (e.g. 2222) for scan-noise reduction."
  default     = 22

  validation {
    condition     = var.ssh_port >= 1 && var.ssh_port <= 65535
    error_message = "ssh_port must be in 1-65535."
  }
}

variable "ssh_public_key_paths" {
  type        = list(string)
  description = "Paths a pubkeys autorizadas en el deploy user. La primera se registra en DO; todas van a authorized_keys via cloud-init. Mínimo 1."
  default     = ["~/.ssh/id_ed25519.pub"]

  validation {
    condition     = length(var.ssh_public_key_paths) >= 1
    error_message = "ssh_public_key_paths debe contener al menos una ruta."
  }
}

variable "allowed_ssh_ips" {
  type        = list(string)
  description = "CIDR blocks allowed to reach SSH. Lock down to your public IP for higher security."
  default     = ["0.0.0.0/0", "::/0"]
}

variable "deploy_user" {
  type        = string
  description = "Non-root Linux user created by cloud-init."
  default     = "deploy"
}

variable "acme_email" {
  type        = string
  description = "Contact email submitted to Let's Encrypt for certificate issuance and expiry notices."

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.acme_email))
    error_message = "acme_email must be a valid email address."
  }
}

variable "enable_backups" {
  type        = bool
  description = "Enable DigitalOcean weekly droplet backups."
  default     = true
}

variable "enable_monitoring" {
  type        = bool
  description = "Install the DigitalOcean monitoring agent."
  default     = true
}

variable "install_docker" {
  type        = bool
  description = "Install Docker Engine and the compose plugin on the droplet."
  default     = true
}

variable "tags" {
  type        = list(string)
  description = "Extra DigitalOcean tags applied to all resources that support tagging."
  default     = []
}
