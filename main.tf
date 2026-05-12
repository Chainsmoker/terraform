locals {
  ssh_public_keys = [for p in var.ssh_public_key_paths : trimspace(file(pathexpand(p)))]

  all_tags = distinct(concat(
    ["managed-by:terraform", "project:${var.project_name}"],
    var.tags,
  ))

  cloud_init_vars = {
    deploy_user     = var.deploy_user
    ssh_public_keys = local.ssh_public_keys
    ssh_port        = var.ssh_port
    acme_email      = var.acme_email
    install_docker  = var.install_docker

    caddyfile_b64 = base64encode(file("${path.module}/assets/caddy/Caddyfile"))
    sshd_config_b64 = base64encode(templatefile(
      "${path.module}/assets/ssh/sshd_config.tftpl",
      { ssh_port = var.ssh_port, deploy_user = var.deploy_user },
    ))
    fail2ban_b64 = base64encode(templatefile(
      "${path.module}/assets/fail2ban/jail.local.tftpl",
      { ssh_port = var.ssh_port },
    ))
    sysctl_b64   = base64encode(file("${path.module}/assets/sysctl/99-hardening.conf"))
    tmpfiles_b64 = base64encode(file("${path.module}/assets/tmpfiles/caddy.conf"))
    tools_b64    = base64encode(file("${path.module}/assets/tools/install.sh"))
  }

  user_data = templatefile(
    "${path.module}/modules/droplet/templates/cloud-init.yaml.tftpl",
    local.cloud_init_vars,
  )
}

module "ssh_key" {
  source = "./modules/ssh-key"

  name_prefix = var.project_name
  public_key  = local.ssh_public_keys[0]
}

module "network" {
  source = "./modules/network"

  project_name = var.project_name
  region       = var.default_region
  vpc_ip_range = var.vpc_ip_range
}

module "droplet" {
  source = "./modules/droplet"

  name        = "${var.project_name}-01"
  region      = var.default_region
  size        = var.default_size
  image       = var.droplet_image
  vpc_id      = module.network.vpc_id
  ssh_key_ids = [module.ssh_key.id]
  tags        = local.all_tags
  backups     = var.enable_backups
  monitoring  = var.enable_monitoring
  user_data   = local.user_data
}

module "firewall" {
  source = "./modules/firewall"

  project_name    = var.project_name
  droplet_id      = module.droplet.id
  ssh_port        = var.ssh_port
  allowed_ssh_ips = var.allowed_ssh_ips
}

resource "digitalocean_reserved_ip_assignment" "primary" {
  ip_address = module.network.reserved_ip_address
  droplet_id = module.droplet.id
}
