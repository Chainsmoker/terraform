output "id" {
  description = "Droplet ID."
  value       = digitalocean_droplet.this.id
}

output "ipv4_address" {
  description = "Droplet public IPv4 (non-reserved)."
  value       = digitalocean_droplet.this.ipv4_address
}

output "ipv6_address" {
  description = "Droplet public IPv6."
  value       = digitalocean_droplet.this.ipv6_address
}

output "urn" {
  description = "Droplet URN."
  value       = digitalocean_droplet.this.urn
}
