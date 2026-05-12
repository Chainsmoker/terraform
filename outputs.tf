output "droplet_id" {
  description = "DigitalOcean droplet ID."
  value       = module.droplet.id
}

output "droplet_ipv4" {
  description = "Transient droplet IPv4 (use reserved_ip for DNS)."
  value       = module.droplet.ipv4_address
}

output "reserved_ip" {
  description = "Stable public IPv4. Point your A records here."
  value       = module.network.reserved_ip_address
}

output "ssh_command" {
  description = "Ready-to-use SSH command."
  value       = "ssh -p ${var.ssh_port} ${var.deploy_user}@${module.network.reserved_ip_address}"
}

output "ssh_key_fingerprint" {
  description = "Fingerprint of the SSH key registered in DigitalOcean."
  value       = module.ssh_key.fingerprint
}

output "firewall_id" {
  description = "DigitalOcean cloud firewall ID."
  value       = module.firewall.id
}
