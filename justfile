# use with https://github.com/casey/just

set dotenv-load := true
set export

mod talos 'infrastructure/talos/talos.just'
mod netboot 'infrastructure/netboot/netboot.just'
mod flux 'infrastructure/flux/flux.just'

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
