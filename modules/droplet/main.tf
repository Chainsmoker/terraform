resource "digitalocean_droplet" "this" {
  name       = var.name
  region     = var.region
  size       = var.size
  image      = var.image
  vpc_uuid   = var.vpc_id
  ssh_keys   = var.ssh_key_ids
  tags       = var.tags
  backups    = var.backups
  monitoring = var.monitoring
  ipv6       = true
  user_data  = var.user_data

  graceful_shutdown = false

  lifecycle {
    ignore_changes = [image, ssh_keys]
  }
}
