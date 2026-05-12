# terraform-v2 — Zero-Touch infra en DigitalOcean

Template reutilizable: un droplet endurecido con Caddy como reverse proxy, listo para alojar N sitios. Para desplegar a otro cliente basta con cambiar `.env` y `terraform.tfvars`.

## Requisitos locales

- Terraform ≥ 1.7
- Una SSH key en `~/.ssh/id_ed25519.pub` (o ajusta `ssh_public_key_path`)
- Un token DigitalOcean con **Full Access** (token read-only da 401 en POST)

## Uso

`.env` solo contiene el token (Terraform lo lee directamente del fichero vía regex, no hace falta exportarlo al shell). Todo lo demás vive en `terraform.tfvars`.

```bash
cp .env.example .env                          # pegar DIGITALOCEAN_TOKEN
cp terraform.tfvars.example terraform.tfvars   # ajustar acme_email, project_name, etc.
terraform init
terraform apply
```

Tras `apply`:

```
ssh_command = "ssh deploy@<reserved_ip>"
```

Apunta tus registros `A`/`AAAA` al valor de `reserved_ip` **antes** de añadir sitios a `sites.d/` (si no, Caddy falla al sacar cert de Let's Encrypt).

## Qué levanta

- **VPC** privada + **Reserved IP** estable
- **Droplet** Ubuntu 24.04 con backups + monitoring
- **DO Cloud Firewall + UFW**: solo `ssh_port`/80/443 TCP + 443 UDP + ICMP
- **Caddy** (repo oficial apt) con HTTPS automático vía Let's Encrypt, admin API en `127.0.0.1:2019` para reloads sin downtime
- Usuario **`deploy`** con `NOPASSWD:ALL` y `/srv` de su propiedad (clonas repos sin sudo)
- **SSH hardened**: solo claves Ed25519, root deshabilitado, puerto configurable (default 22)
- **fail2ban** protegiendo sshd
- **sysctl hardening** (SYN cookies, rp_filter, redirect/source-route off)
- **unattended-upgrades** para parches de seguridad automáticos
- **Docker + compose plugin** (opcional, `install_docker = true`)
- **ACL default en `/var/log/caddy`** para que logs heredan grupo `caddy` sin fricción

## Añadir un sitio

Los ficheros en `/etc/caddy/sites.d/*.caddy` se cargan automáticamente. Ejemplo:

```caddy
app.midominio.com {
    import defaults            # o import common (son equivalentes)
    reverse_proxy localhost:3000
}
```

Snippets disponibles en el Caddyfile base:
- `common` / `defaults` — security_headers + compression
- `security_headers` — HSTS, X-Content-Type-Options, etc.
- `compression` — zstd + gzip
- `deny_hidden` — bloquea paths que empiezan por `.`

Reload sin downtime:
```bash
sudo systemctl reload caddy
```

Si el dominio aún no resuelve al droplet, usa `tls internal` temporalmente para no bloquear el reload:
```caddy
staging.midominio.com {
    tls internal
    import defaults
    reverse_proxy localhost:3001
}
```
Cuando DNS propague, quitas `tls internal` y recargas — Caddy saca cert real.

## Reusabilidad por cliente

Clona el repo a otra ruta, sustituye `.env` (token del cliente) y `terraform.tfvars` (dominios, project_name). Los módulos no se tocan.

## Verificación post-deploy

```bash
terraform output ssh_command
nmap -Pn <reserved_ip>                   # solo 22, 80, 443 abiertos
ssh deploy@<reserved_ip> '
  systemctl is-active caddy fail2ban
  sudo -u caddy test -w /var/lib/caddy && echo lib_OK
  sudo -u caddy test -w /var/log/caddy && echo log_OK
  sudo fail2ban-client status sshd
  sysctl net.ipv4.tcp_syncookies
'
```

## State de Terraform

Vive en `.terraform-state/terraform.tfstate` (gitignored). Para equipo/CI, migra a DigitalOcean Spaces modificando `backend.tf` a backend `s3` con endpoint DO.

## Destruir

```bash
terraform destroy
```

Si un droplet se queda atascado destruyéndose (cloud-init colgado → shutdown ACPI no completa), apágalo manualmente en el panel DO (`Power Off` hard) y reintenta. `graceful_shutdown = false` en el módulo evita esto para futuros destroys.

## Gotchas aprendidas

Lecciones del primer deploy (ya resueltas en el template, documentadas aquí como referencia):

1. **DO NO descomprime `user_data` gzipped** — el patrón `data.cloudinit_config` + gzip+base64 que funciona en AWS rompe aquí: cloud-init recibe la cadena base64 como `text/x-not-multipart` y la ignora, dejando el droplet vanilla. Usamos `templatefile()` crudo pasado directo a `user_data`.

2. **`admin off` en Caddy rompe `systemctl reload`** — el reload de Caddy empuja config al admin API en `127.0.0.1:2019`. Con `admin off` no hay API, reload falla, solo `restart` funciona. Dejamos el admin por defecto (local-only, seguro).

3. **`ssh.socket` → `ssh.service` swap es frágil en Ubuntu 24.04** — cambiar puerto SSH vía systemd swap dejó el droplet sin SSH cuando algo fallaba. Si quieres un puerto no-estándar, usa `/etc/systemd/system/ssh.socket.d/override.conf` con `ListenStream=<puerto>` y `systemctl restart ssh.socket`. Por defecto dejamos `:22` que es lo más confiable.

4. **Token DO con "Custom Scopes" en vez de "Full Access" da 401 en POST** — el GET /account pasa, pero crear VPC/SSH key/droplet falla. Si ves 401 persistente con un token que "funciona", revisa scopes.

5. **`.env` con CRLF rompe el parsing de DigitalOcean** — un `\r` invisible al final de la línea se concatena al token y DO devuelve 401. `sed -i 's/\r$//' .env` si sospechas. Nuestro regex en `providers.tf` ignora whitespace pero no siempre.

6. **SSH key ya existente en la cuenta DO da 422** — la cuenta DO rechaza registrar la misma pubkey dos veces. El módulo `ssh-key/` usa `data "digitalocean_ssh_keys"` para buscar por contenido y reusa si ya existe; solo crea si no hay match. Idempotente.

7. **ACME_EMAIL solo en systemd drop-in no llega al CLI `caddy validate`** — `sudo caddy validate` no hereda el env del `ExecReload`. Fix: `/etc/default/caddy` con `ACME_EMAIL=...` sourceado tanto por systemd (`EnvironmentFile=-`) como manualmente si hace falta.

8. **No toques ficheros en `/var/log/caddy` con `sudo touch`** — quedan `root:root` y Caddy (que corre como `caddy`) no puede abrirlos. Deja que Caddy los cree él mismo al iniciar. Como red de seguridad, el template pone ACL default `g:caddy:rwX` en el directorio, así que si por error alguien crea algo ahí, el grupo caddy mantiene escritura.

9. **Let's Encrypt falla sin DNS propagado** — no añadas un sitio al `sites.d/` hasta que `dig +short midominio.com` devuelva la IP del droplet. Mientras propaga, usa `tls internal`.

## Fuera de scope actual

- **Rate limiting en Caddy** — Caddy core no lo trae. Para añadirlo: rebuild con el módulo `caddy-ratelimit` (xcaddy), o usa fail2ban contra patrones del `access.log`, o pon Cloudflare delante.
- **Remote state** en DO Spaces — trivial cuando quieras: cambia el bloque `backend "local"` por `backend "s3"` con `endpoints.s3 = "https://<region>.digitaloceanspaces.com"`.
- **Cloudflare proxy** — añadir como módulo opcional `modules/cloudflare-dns/` si necesitas WAF/DDoS gestionado.
