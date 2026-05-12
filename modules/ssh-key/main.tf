data "digitalocean_ssh_keys" "all" {}

locals {
  wanted_pk = trimspace(var.public_key)
  matches   = [for k in data.digitalocean_ssh_keys.all.ssh_keys : k if trimspace(k.public_key) == local.wanted_pk]
  existing  = try(local.matches[0], null)
  needs_new = local.existing == null
}

resource "digitalocean_ssh_key" "this" {
  count      = local.needs_new ? 1 : 0
  name       = "${var.name_prefix}-deploy"
  public_key = var.public_key
}
