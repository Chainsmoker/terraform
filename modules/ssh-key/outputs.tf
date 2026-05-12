output "id" {
  description = "DigitalOcean SSH key ID (existing match or newly created)."
  value = coalesce(
    try(digitalocean_ssh_key.this[0].id, null),
    try(local.existing.id, null),
  )
}

output "fingerprint" {
  description = "Fingerprint of the SSH key used by the droplet."
  value = coalesce(
    try(digitalocean_ssh_key.this[0].fingerprint, null),
    try(local.existing.fingerprint, null),
  )
}

output "reused_existing" {
  description = "true if an existing DO SSH key matching the supplied public key was reused."
  value       = !local.needs_new
}
