locals {
  env_file_raw = try(file("${path.root}/.env"), "")
  env_file_token = try(
    regex("(?m)^\\s*DIGITALOCEAN_TOKEN\\s*=\\s*\"?([^\"\\s]+)\"?", local.env_file_raw)[0],
    null,
  )

  effective_do_token = (
    var.do_token != null && var.do_token != "" ? var.do_token :
    local.env_file_token != null && local.env_file_token != "" ? local.env_file_token :
    null
  )
}

provider "digitalocean" {
  token = local.effective_do_token
}
