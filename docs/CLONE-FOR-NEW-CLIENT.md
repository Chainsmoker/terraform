# Clonar el template para un cliente nuevo

Workflow paso a paso para desplegar la misma infraestructura en otra cuenta DigitalOcean (otro cliente). Pensado para que el proceso sea reproducible en ~10 minutos sin tocar código de los módulos.

## Pre-requisitos

- Token DigitalOcean del cliente con **Full Access** (no Custom Scopes — falla en `POST /vpcs`).
- DNS del dominio del cliente — apuntable a un IP que tú elijas.
- Bitwarden / 1Password para guardar la SSH privkey (mandatorio).
- Terraform ≥ 1.7 instalado.

## Pasos

### 1. Clonar y limpiar state local

```bash
git clone <tu-repo-template> cliente-x-infra
cd cliente-x-infra

# Borrar cualquier state heredado del proyecto anterior:
rm -rf .terraform .terraform-state .terraform.lock.hcl
```

> **Nota:** `.terraform.lock.hcl` se commitea en el template original (best practice de HashiCorp para pinear versiones de provider). Lo borramos al clonar para que el cliente nuevo regenere el suyo según las versiones disponibles en su entorno.

### 2. Generar SSH key dedicada para este cliente

Ver `docs/SSH-KEYS.md` para el patrón completo. Resumen:

```bash
ssh-keygen -t ed25519 \
  -C "german@cliente-x-$(date +%Y-%m)" \
  -f ~/.ssh/clients/cliente-x_ed25519
# Pon una passphrase fuerte cuando te la pida.
```

### 3. ⚠️ Backup en Bitwarden ANTES de seguir

Antes de tocar Terraform, guarda en Bitwarden:
- Privkey (`cliente-x_ed25519`) como attachment
- Pubkey (`cliente-x_ed25519.pub`) como attachment
- Passphrase como Custom Field hidden

Si saltas este paso y pierdes la privkey, recuperarás vía DO Recovery Console — proceso de ~15 min documentado en `SSH-KEYS.md` sección 9.

### 4. Configurar credenciales y vars

```bash
cp .env.example .env
# Editar .env y pegar el token DO del cliente:
#   DIGITALOCEAN_TOKEN=dop_v1_<token-real-del-cliente>
# Sin comillas, sin espacios al final, sin CRLF.

cp terraform.tfvars.example terraform.tfvars
```

Edita `terraform.tfvars` con los valores del cliente:

```hcl
project_name   = "cliente-x"            # prefijo de recursos: <project_name>-vpc, <project_name>-01, etc.
default_region = "nyc3"                 # o el más cercano al cliente
default_size   = "s-2vcpu-4gb"          # ajustable según presupuesto
droplet_image  = "ubuntu-24-04-x64"

ssh_port            = 22
ssh_public_key_path = "~/.ssh/clients/cliente-x_ed25519.pub"   # !! la nueva, NO la default
allowed_ssh_ips     = ["0.0.0.0/0", "::/0"]                    # idealmente: ["TU.IP.PUBLICA/32"]

deploy_user = "deploy"
acme_email  = "ops@cliente-x.com"       # va a Let's Encrypt — usa email del cliente o uno tuyo

enable_backups    = true                # ~$0.80/mo, recomendado
enable_monitoring = true                # gratis, métricas en panel DO
install_docker    = true                # baja a false si el cliente no usa Docker

tags = ["client:cliente-x", "env:prod"]

# Solo si por alguna razón corres dos infras en la misma cuenta + región:
# vpc_ip_range = "10.30.0.0/20"
```

### 5. Añadir alias en `~/.ssh/config`

```ssh-config
Host cliente-x
    HostName <pendiente-tras-apply>
    User deploy
    IdentityFile ~/.ssh/clients/cliente-x_ed25519
    IdentitiesOnly yes
```

(El `HostName` lo rellenas tras el apply con el `reserved_ip`.)

### 6. Init y plan

```bash
terraform init
terraform plan -out=plan.tfplan
```

Revisa el plan. Debes ver **6 resources a crear**:

```
+ module.ssh_key.digitalocean_ssh_key.this[0]
+ module.network.digitalocean_vpc.this
+ module.network.digitalocean_reserved_ip.this
+ module.droplet.digitalocean_droplet.this
+ module.firewall.digitalocean_firewall.this
+ digitalocean_reserved_ip_assignment.primary
```

Si ves más o menos, **PARA** y revisa qué cambió.

### 7. Apply

```bash
terraform apply plan.tfplan
```

Tarda ~2 minutos. Outputs esperados:

```
droplet_id          = "12345678"
droplet_ipv4        = "138.x.y.z"
reserved_ip         = "138.a.b.c"
ssh_command         = "ssh -p 22 deploy@138.a.b.c"
ssh_key_fingerprint = "aa:bb:cc:..."
firewall_id         = "uuid"
```

### 8. Esperar a que cloud-init termine

Cloud-init corre en el primer boot del droplet — ~3-5 min más tras el apply. Comprueba:

```bash
ssh deploy@<reserved_ip> 'cloud-init status --wait'
# devuelve "status: done" cuando acaba
```

### 9. Apuntar DNS al `reserved_ip`

En el panel DNS del cliente (Cloudflare, Route53, etc.):

```
A    cliente-x.com           138.a.b.c
A    *.cliente-x.com         138.a.b.c
```

**Espera a que `dig +short cliente-x.com` resuelva al IP reservado** antes de añadir sitios al Caddyfile. Si Caddy intenta sacar cert de Let's Encrypt sin DNS propagado, falla y queda en backoff.

### 10. Actualizar `~/.ssh/config` con el IP real

Edita la entrada `Host cliente-x` y pon el `reserved_ip` en `HostName`.

Ahora:
```bash
ssh cliente-x   # entra directo sin más
```

### 11. Añadir sitios

Crea ficheros en `/etc/caddy/sites.d/<dominio>.caddy` por cada app del cliente:

```caddy
api.cliente-x.com {
    import defaults
    reverse_proxy localhost:3000
}

app.cliente-x.com {
    import defaults
    reverse_proxy localhost:3001
}
```

Reload sin downtime:
```bash
sudo systemctl reload caddy
```

(Reload usa el admin API de Caddy en `127.0.0.1:2019` — local-only, seguro.)

## Verificación post-deploy

```bash
ssh cliente-x

# Servicios arriba
systemctl is-active caddy fail2ban
sudo docker ps                                    # solo si install_docker=true

# Permisos Caddy correctos
sudo -u caddy test -w /var/lib/caddy && echo lib_OK
sudo -u caddy test -w /var/log/caddy && echo log_OK

# fail2ban activo en sshd
sudo fail2ban-client status sshd

# sysctl hardening aplicado
sysctl net.ipv4.tcp_syncookies                    # debe ser = 1

# Puertos externos: solo 22 (o ssh_port), 80, 443
exit
nmap -Pn <reserved_ip> | grep open
```

Y prueba TLS desde fuera:
```bash
curl -I https://api.cliente-x.com
# debe devolver 200 (o 502 si app no levantada todavía) con HSTS
```

## Operaciones recurrentes

### Editar Caddyfile global o assets

Cambios en `assets/caddy/Caddyfile`, `assets/ssh/sshd_config.tftpl`, etc., **disparan recreación del droplet** porque van en `user_data` (que es `ForceNew` en `digitalocean_droplet`).

`terraform plan` te lo va a mostrar como `-/+ module.droplet.digitalocean_droplet.this` — esa es la señal de "ojo, vas a destruir prod".

Para cambios en assets sin recrear:
```bash
# 1. Edita el fichero local (assets/caddy/Caddyfile)
# 2. scp al droplet manualmente:
scp assets/caddy/Caddyfile cliente-x:/tmp/Caddyfile.new
ssh cliente-x 'sudo install -o root -g caddy -m 0644 /tmp/Caddyfile.new /etc/caddy/Caddyfile && sudo systemctl reload caddy'
```

Cuando vayas a desplegar a un nuevo cliente, el cambio ya estará en los assets para que el primer boot lo recoja.

### Rotar tu SSH key local sin recrear droplet

`ssh_keys` está en `lifecycle.ignore_changes` del módulo droplet, así que cambiar `ssh_public_key_path` no destruye el droplet. Pero **sí** wipea la pubkey vieja en `authorized_keys` la próxima vez que cloud-init corra.

Para añadir/cambiar tu pubkey en un droplet existente:
```bash
ssh cliente-x  # con la key vieja
echo "ssh-ed25519 AAAA... nuevo" >> ~/.ssh/authorized_keys
```

Ver `SSH-KEYS.md` sección 9 si pierdes acceso por completo.

### Añadir Cloudflare delante (futuro)

Cuando un cliente necesite WAF / DDoS gestionado, añade Cloudflare como proxy:
1. Crea zona en Cloudflare apuntando a `reserved_ip`
2. Cambia DNS del registrar al de Cloudflare
3. Activa "Proxied" (naranja) en los registros A
4. En `terraform.tfvars`, restringe `allowed_ssh_ips` a tu IP — Cloud Firewall ya bloquea SSH desde Cloudflare automáticamente.

## Destruir (offboarding del cliente)

```bash
terraform destroy
```

Si se cuelga (cloud-init hung → no responde a ACPI shutdown):
1. Panel DO → droplet → **Power Off** (hard) manual.
2. `terraform destroy` de nuevo.

Tras destruir:
- Borra la pubkey del cliente en tu cuenta DO si ya no la usas.
- Mueve `~/.ssh/clients/cliente-x_ed25519*` a `~/Archive/`.
- Quita la entrada `cliente-x` de `~/.ssh/config`.
- Archiva el item en Bitwarden (no borrar inmediatamente — mantén 3-6 meses por re-engagement).

## Checklist resumen

```
[ ] Token DO del cliente con Full Access listo
[ ] SSH key generada en ~/.ssh/clients/cliente-x_ed25519
[ ] Privkey + pubkey + passphrase guardados en Bitwarden
[ ] .env editado con token DO (sin CRLF, sin comillas)
[ ] terraform.tfvars editado: project_name, acme_email, ssh_public_key_path, allowed_ssh_ips
[ ] Alias añadido a ~/.ssh/config
[ ] terraform init + plan revisado (6 resources a crear)
[ ] terraform apply
[ ] Esperar cloud-init status --wait
[ ] DNS apuntando al reserved_ip
[ ] HostName actualizado en ~/.ssh/config
[ ] ssh cliente-x funciona
[ ] Sitios añadidos a /etc/caddy/sites.d/
[ ] Verificación: nmap, curl https, fail2ban, sysctl
[ ] Documentar en wiki interna: cliente, fecha onboarding, IP, dominios
```
