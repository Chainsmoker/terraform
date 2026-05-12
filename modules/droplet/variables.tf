variable "name" {
  type        = string
  description = "Droplet hostname / resource name."
}

variable "region" {
  type        = string
  description = "DigitalOcean region slug."
}

variable "size" {
  type        = string
  description = "Droplet size slug."
}

variable "image" {
  type        = string
  description = "Droplet base image slug."
}

variable "vpc_id" {
  type        = string
  description = "UUID of the VPC the droplet will join."
}

variable "ssh_key_ids" {
  type        = list(string)
  description = "SSH key IDs to inject as root's authorized_keys at boot."
}

variable "tags" {
  type        = list(string)
  description = "DigitalOcean tags applied to the droplet."
  default     = []
}

variable "backups" {
  type        = bool
  description = "Enable DO weekly backups."
  default     = true
}

variable "monitoring" {
  type        = bool
  description = "Install the DO monitoring agent."
  default     = true
}

variable "user_data" {
  type        = string
  description = "Rendered cloud-init payload (already gzipped + base64 by cloudinit_config)."
}
