resource "digitalocean_vpc" "this" {
  name     = "${var.project_name}-vpc"
  region   = var.region
  ip_range = var.vpc_ip_range
}

resource "digitalocean_reserved_ip" "this" {
  region = var.region
}
