terraform {
  # State remoto en HCP Terraform (Terraform Cloud).
  # Free tier — gratis hasta 500 recursos/mes (caben ~80 clientes a 6 recursos cada uno).
  #
  # La organization y workspace NO admiten interpolación, así que se pasan
  # en `terraform init` vía -backend-config=backend.hcl (ver backend.hcl.example).
  #
  # Migración desde backend local existente:
  #   terraform login
  #   terraform init -backend-config=backend.hcl -migrate-state
  #
  # Cliente nuevo (sin state previo):
  #   terraform login
  #   terraform init -backend-config=backend.hcl
  cloud {}
}
