terraform {
  # State remoto en HCP Terraform (Terraform Cloud), free tier.
  # Workspace por cliente, execution mode Local (apply corre en tu máquina).
  #
  # El bloque cloud {} no admite -backend-config — la config se pasa vía env vars:
  #   export TF_CLOUD_ORGANIZATION="tu-org"
  #   export TF_WORKSPACE="<cliente>-prod"
  #
  # Cliente nuevo:
  #   terraform login            # una vez por máquina
  #   terraform init
  #
  # Migrar state local existente:
  #   terraform init -migrate-state
  cloud {}
}
