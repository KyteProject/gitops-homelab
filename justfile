# use with https://github.com/casey/just

set dotenv-load := true
set export

BOOTSTRAP_DIR := "./infrastructure/flux/bootstrap"
KUBERNETES_DIR := "./clusters"
ROOT_DIR := "."

mod flux 'flux/flux.just'
mod talos 'infrastructure/talos/talos.just'
mod netboot 'infrastructure/netboot/netboot.just'
mod ansible 'infrastructure/ansible/ansible.just'

# default recipe to display help information
_default:
  @just --list

# Homelab: Check pre-requisites
@precheck:
  if [ -z "$(which docker)" ]; then echo "docker not found"; fi

  if [ -z "$(which kubectl)" ]; then echo "kubectl not found"; fi

  if [ -z "$(which talosctl)" ]; then echo "talosctl not found"; fi

  if [ -z "$(which flux)" ]; then echo "flux not found"; fi

  flux check --pre

# Homelab: Bootstrap setup of homelab cluster
@bootstrap:
  just precheck
  just talos bootstrap
  just talos kubeconfig
  just talos bootstrap-apps

@encrypt-secrets:
  sops encrypt --output clusters/main/vars/cluster-secrets.secret.sops.yaml --output-type yaml clusters/main/vars/cluster-secrets.sops.yaml
  just ansible truenas-secrets-edit
