#!/usr/bin/env bash
#
# Tools custom — se ejecuta como root al final del bootstrap de cloud-init.
# Idempotente: puedes re-correrlo manualmente con `sudo /usr/local/bin/install-tools.sh`
# si añades cosas más adelante.
#
# Edita libremente por cliente. Si lo dejas con todo comentado, no instala nada.

set -euo pipefail

apt-get update -qq

# ────────────────────────────────────────────────────────────────────────────
# Ejemplos — descomenta los que necesites o añade tus propios comandos
# ────────────────────────────────────────────────────────────────────────────

# GitHub CLI
(type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)) \
	&& sudo mkdir -p -m 755 /etc/apt/keyrings \
	&& out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	&& cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& sudo mkdir -p -m 755 /etc/apt/sources.list.d \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& sudo apt update \
	&& sudo apt install gh -y

# Utilidades comunes (apt)
# DEBIAN_FRONTEND=noninteractive apt-get install -y \
#   htop \
#   ncdu \
#   tmux \
#   ripgrep \
#   tree

# Node.js LTS (NodeSource) — pinea major version para reproducibilidad
#NODE_MAJOR=24
#curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash -
#DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs

# Bun
#curl -fsSL https://bun.sh/install | bash
#install -m 0755 ~/.bun/bin/bun /usr/local/bin/bun
