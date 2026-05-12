variable "name_prefix" {
  type        = string
  description = "Prefix for the SSH key resource name registered in DigitalOcean."
}

variable "public_key" {
  type        = string
  description = "Raw public key contents (e.g. 'ssh-ed25519 AAAA... user@host')."
}
