# Gestión de SSH keys para consultor multi-cliente

Guía práctica para mantener acceso SSH limpio y revocable cuando trabajas con varios clientes a la vez. Modelo: **una key dedicada por cliente**, con backup obligatorio y `~/.ssh/config` como índice.

---

## 1. Filosofía: una key por cliente

| Modelo | Cuándo usar |
|---|---|
| 1 key personal para todo | NO recomendado para consultor — si la roban, acceso a todos los clientes |
| 1 key por máquina (laptop, desktop, CI) | Aislamiento por dispositivo |
| **1 key por cliente** | **Recomendado para consultor** — revocas por cliente sin afectar al resto |

Combinable: tu laptop genera una key distinta por cada cliente. Cuando termines con un cliente, ellos borran tu pubkey y tú archivas/borras la suya, sin tocar las demás.

Ventajas concretas:
- Auditoría limpia: el comentario de la key (`-C "german@cliente-X"`) aparece en `authorized_keys` y en logs sshd.
- Si te roban la laptop, revocas key por key sin downtime para todos los clientes a la vez.
- Si un cliente exige rotar credenciales, rotas solo esa key.

---

## 2. Layout recomendado en local

```
~/.ssh/
├── config                          # Índice de hosts → keys (no secretos)
├── known_hosts                     # Fingerprints de hosts ya visitados
├── personal/
│   ├── github_ed25519              # Para git push/pull personal
│   └── github_ed25519.pub
└── clients/
    ├── plugplay_ed25519            # Cliente "plugplay"
    ├── plugplay_ed25519.pub
    ├── acme_ed25519                # Cliente "acme"
    ├── acme_ed25519.pub
    └── ...
```

Crea los directorios:
```bash
mkdir -p ~/.ssh/personal ~/.ssh/clients
chmod 700 ~/.ssh ~/.ssh/personal ~/.ssh/clients
```

---

## 3. Generar una key nueva para un cliente

```bash
ssh-keygen -t ed25519 \
  -C "german@cliente-x-$(date +%Y-%m)" \
  -f ~/.ssh/clients/cliente-x_ed25519
```

Cuando te pida passphrase: **pon una passphrase fuerte**. Nunca dejes una privkey sin passphrase. Si te roban el fichero, sin la passphrase no sirve.

Permisos correctos (sshd y git son estrictos):
```bash
chmod 600 ~/.ssh/clients/cliente-x_ed25519
chmod 644 ~/.ssh/clients/cliente-x_ed25519.pub
```

---

## 4. Backup en Bitwarden (OBLIGATORIO antes de seguir)

Antes de subir la pubkey al server, **guarda el privkey en Bitwarden**. Si pierdes la privkey y no tienes backup, recuperar acceso al server es lento y doloroso (recovery console, mount, chroot — visto en directo).

Estructura recomendada del item de Bitwarden:

- **Tipo:** Secure Note
- **Nombre:** `SSH key — cliente-x`
- **Notas:**
  ```
  Generada: 2026-05-04
  Para: Cliente X (proyecto plugplayblends)
  Hostname: 138.197.49.84 (terraform-v2-01 en DigitalOcean)
  Usuario remoto: deploy
  Passphrase: <copiar al campo Custom Field hidden, no aquí>
  ```
- **Custom Fields:**
  - `passphrase` (hidden) — la passphrase de la privkey
  - `pubkey` (text) — pegar contenido de `cliente-x_ed25519.pub` para verificación rápida
- **Attachments:**
  - `cliente-x_ed25519` (privkey)
  - `cliente-x_ed25519.pub` (pubkey)

Verifica antes de cerrar el item:
```bash
cat ~/.ssh/clients/cliente-x_ed25519.pub
# compara con lo guardado en Bitwarden
```

---

## 5. Configurar `~/.ssh/config`

Una entrada por host. Ejemplo completo:

```ssh-config
# ~/.ssh/config

# Defaults para todos los hosts
Host *
    AddKeysToAgent yes
    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
    HashKnownHosts yes

# Cliente plugplay (terraform-v2)
Host plugplay
    HostName 138.197.49.84
    User deploy
    IdentityFile ~/.ssh/clients/plugplay_ed25519

# Cliente acme — staging
Host acme-staging
    HostName 1.2.3.4
    User deploy
    Port 2222
    IdentityFile ~/.ssh/clients/acme_ed25519

# Cliente acme — prod
Host acme-prod
    HostName 5.6.7.8
    User deploy
    Port 2222
    IdentityFile ~/.ssh/clients/acme_ed25519

# Personal — GitHub
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/personal/github_ed25519
```

Permisos:
```bash
chmod 600 ~/.ssh/config
```

Tras esto:
```bash
ssh plugplay              # ssh deploy@138.197.49.84 con key correcta
ssh acme-prod             # otro cliente, otra key, sin pensarlo
git clone github.com:...  # usa key personal automáticamente
```

**`IdentitiesOnly yes` es crítico**: sin él, ssh ofrece *todas* tus keys cargadas en el agent una por una. El server tiene `MaxAuthTries 3` (en este template) — si tienes 4+ keys, te rechaza antes de probar la correcta. Además fail2ban podría banearte tu propia IP.

---

## 6. Añadir la pubkey al server

Cuando tienes acceso (vía otra key, password, o consola):

### Método A: ssh-copy-id (la primera vez, si tienes password)
```bash
ssh-copy-id -i ~/.ssh/clients/cliente-x_ed25519.pub deploy@<ip>
```

### Método B: manual (sin password, vía otra key existente)
```bash
ssh deploy@<ip>
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "ssh-ed25519 AAAA... german@cliente-x-2026-05" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
exit
```

### Método C: en el momento de provisionar (Terraform / cloud-init)
La pubkey va en el `user_data` del droplet a través de `var.ssh_public_key_path`. Cloud-init la escribe en `/home/deploy/.ssh/authorized_keys` en el primer boot.

### Verifica
```bash
ssh -v plugplay 2>&1 | grep -E "Offering|accepted|authenticated"
# Debes ver "Authenticated to ... using publickey"
```

---

## 7. ssh-agent: passphrase una sola vez por sesión

Sin agent: cada `ssh` te pide la passphrase. Pesado.

Con agent (auto-arranca en macOS y la mayoría de Linux desktop):

```bash
ssh-add ~/.ssh/clients/plugplay_ed25519
# Te pide passphrase UNA vez. La key queda cargada en memoria.

ssh-add -l                        # lista keys cargadas
ssh-add -L                        # lista pubkeys cargadas (formato authorized_keys)
ssh-add -d ~/.ssh/clients/...     # quita una key específica
ssh-add -D                        # quita todas
```

En Linux, si `ssh-agent` no arranca solo, añade a tu `~/.zshrc` o `~/.bashrc`:
```bash
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null
fi
```

Con `AddKeysToAgent yes` en el config, ssh añade la key al agent automáticamente la primera vez que la usas.

---

## 8. Hardware key (YubiKey) — nivel pro

Cuando llegues a un cliente con infra crítica, considera generar keys que vivan **dentro** del YubiKey:

```bash
ssh-keygen -t ed25519-sk \
  -O resident \
  -C "german-yubikey5-cliente-x"
```

- El privkey está físicamente en el YubiKey, no en disco.
- Para cada `ssh`, tienes que tocar el botón del YubiKey.
- Si te roban la laptop, no pueden autenticar sin el YubiKey físico.
- `-O resident` permite que cualquier laptop lea la key del YubiKey con `ssh-keygen -K`.

Trade-off: más fricción, mucho más seguro.

---

## 9. Procedure: pérdida de la privkey

Si pierdes el privkey y no tienes backup, sigues sin acceso al server hasta recuperarlo. Pasos en orden:

### Si **tienes backup en Bitwarden** ✅
1. Descarga `cliente-x_ed25519` y `.pub` de Bitwarden a `~/.ssh/clients/`.
2. `chmod 600 cliente-x_ed25519`
3. `ssh cliente-x` — entra normal.

### Si **no tienes backup** ❌

Estás en el escenario "lockout". Soluciones (de menos a más invasiva):

**a) ¿Hay otra key autorizada en el server (otra laptop, CI, otro consultor)?**
Usa esa para entrar y añadir tu pubkey nueva al `authorized_keys`.

**b) ¿Tienes una sesión SSH activa abierta en otra terminal?**
Antes de cerrarla, añade la pubkey nueva manualmente:
```bash
echo "ssh-ed25519 AAAA... nuevo" >> ~/.ssh/authorized_keys
```

**c) DigitalOcean Recovery Console (cuando es un droplet DO)**

Visto en vivo el 2026-05-04. Pasos:

1. Panel DO → droplet → menú izquierdo **Recovery**.
2. Cambia "Boot from Hard Drive" → **"Boot from Recovery ISO"** → **Save**.
3. Power Cycle.
4. Espera ~30 seg, abre **Launch Recovery Console**.
5. En el menú: opción `1` (Mount Disk Image), luego opción `4` (Attempt to chroot into installed system).
6. Ya estás como root dentro del sistema real. Ejecuta:
   ```bash
   echo "ssh-ed25519 AAAA... nuevo" >> /home/deploy/.ssh/authorized_keys
   chown deploy:deploy /home/deploy/.ssh/authorized_keys
   chmod 600 /home/deploy/.ssh/authorized_keys
   ```
7. **NO toques** la opción 7 ("Clear out Cloud-Init cached data") — regenera host keys y dispara cloud-init como first-boot, lo que puede wipear tu authorized_keys recién añadido.
8. `sync; exit; exit`
9. Panel DO → Recovery → cambia a **"Boot from Hard Drive"** → Save → Power Cycle.
10. Espera ~45 seg.
11. Local: `ssh-keygen -R <ip>` (los host keys del server cambiaron tras el reboot desde recovery — esperado).
12. `ssh deploy@<ip>` → acepta el nuevo fingerprint.

Cuesta ~10-15 minutos. Hace downtime breve (durante power cycles). Por eso: **backup obligatorio en Bitwarden**, no es opcional.

**d) Otros providers (AWS, GCP, Azure)**
Cada uno tiene su propio recovery path. AWS: detener instancia, montar el EBS en otra instancia, editar authorized_keys, remontar. GCP: similar con metadata SSH keys. Documenta el procedure de cada provider la primera vez que lo uses.

---

## 10. Cuando termina la relación con un cliente

Doble pase para limpieza:

**En el server (cliente borra tu pubkey):**
```bash
ssh deploy@<ip>
sed -i '/german@cliente-x/d' ~/.ssh/authorized_keys
```

**En tu local (archivar privkey):**
```bash
mv ~/.ssh/clients/cliente-x_ed25519* ~/Archive/closed-clients/
# elimina la entrada del ~/.ssh/config
```

Mantén el item de Bitwarden por algunos meses (auditoría / re-engagement); luego archiva o elimina.

---

## 11. Anti-patrones a evitar

| ❌ NO | ✅ SÍ |
|---|---|
| Una sola key personal para todos los clientes | Una key dedicada por cliente |
| Privkey sin passphrase | Privkey con passphrase fuerte (Bitwarden la guarda) |
| Pubkey con comentario `-C "user@hostname"` genérico | Comentario descriptivo: `-C "german@cliente-x-2026-05"` |
| Ejecutar `ssh-keygen -t ed25519` sin `-f <path>` (sobreescribe `id_ed25519`) | Siempre `-f ~/.ssh/clients/<cliente>_ed25519` |
| Sin `IdentitiesOnly yes` en config | Siempre `IdentitiesOnly yes` (evita ban por `MaxAuthTries`) |
| Backup de privkey en Dropbox/Google Drive sin cifrar | Bitwarden / 1Password (ya cifrado) |
| Compartir privkey con compañero de equipo | Cada persona tiene su propia key, todas se añaden a `authorized_keys` |

---

## 12. Checklist de onboarding por cliente nuevo

```
[ ] Generar key:  ssh-keygen -t ed25519 -C "german@cliente-X-YYYY-MM" -f ~/.ssh/clients/cliente-X_ed25519
[ ] Subir backup a Bitwarden (privkey + pubkey + passphrase)
[ ] Añadir entrada a ~/.ssh/config con alias corto
[ ] Subir pubkey al/los server(s) del cliente (cloud-init / ssh-copy-id / manual)
[ ] Verificar: ssh <alias> entra sin pedir password
[ ] Documentar en wiki/notas del cliente: hostname, IP, alias en config, fecha onboarding
```

## 13. Checklist de offboarding por cliente

```
[ ] Confirmar con cliente que tu pubkey ya no está en authorized_keys
[ ] Mover ~/.ssh/clients/cliente-X_ed25519* a ~/Archive/
[ ] Quitar entrada de ~/.ssh/config
[ ] Marcar item de Bitwarden como archivado (no borrar inmediatamente)
[ ] Tras 3-6 meses: borrar Bitwarden item si confirmas no haber re-engagement
```
