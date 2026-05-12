output "vpc_id" {
  description = "DigitalOcean VPC UUID."
  value       = digitalocean_vpc.this.id
}

output "reserved_ip_address" {
  description = "Stable public IPv4 (reserved IP)."
  value       = digitalocean_reserved_ip.this.ip_address
}

output "reserved_ip_urn" {
  description = "URN of the reserved IP resource."
  value       = digitalocean_reserved_ip.this.urn
}
