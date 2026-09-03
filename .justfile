#!/usr/bin/env -S just --justfile

# `set unstable` is required on just 1.36 for `script-interpreter` and the
# `[script]` attribute. Upstream (buroa) runs a newer just where both are
# stable and additionally uses `set default-script` and `set lazy`; neither
# exists in 1.36, so `[script]` is applied per recipe instead.
set unstable := true
set quiet := true
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

# Mirrors the `env:` block of Taskfile.yaml.
#
# KUBECONFIG resolves to infrastructure/kubeconfig, which is the file that
# actually exists and matches both Taskfile.yaml and .envrc. .mise.toml sets
# a repo-root kubeconfig, which does not exist.
#
# TALOSCONFIG resolves to talos/talosconfig, which is the file that actually
# exists and is the path `just talos init-all` writes. Both Taskfile.yaml and
# .mise.toml point at talos/clusterconfig/talosconfig, which does not exist;
# talosctl silently falls back to ~/.talos/config, so the drift has been
# invisible rather than harmless.
export CLUSTER_NAME := 'aeon'
export FLUX_NAMESPACE := 'flux-system'
export KUBECONFIG := justfile_directory() / 'infrastructure' / 'kubeconfig'
export MINIJINJA_CONFIG_FILE := justfile_directory() / '.minijinja.toml'
export TALOSCONFIG := justfile_directory() / 'talos' / 'talosconfig'

# Bootstrap recipes
[group('Bootstrap')]
mod bootstrap 'just/bootstrap.just'

# Flux recipes
[group('Flux')]
mod flux 'just/flux.just'

# Kube recipes
[group('Kube')]
mod kube 'just/kubernetes.just'

# Cloudflare R2 recipes
[group('R2')]
mod r2 'just/r2.just'

# Talos recipes
[group('Talos')]
mod talos 'just/talos.just'

# Workstation recipes
[group('Workstation')]
mod workstation 'just/workstation.just'

[private]
default:
    just --list --list-submodules

[doc('Open K9s for the current cluster')]
k9s:
    just require k9s
    k9s --kubeconfig "$KUBECONFIG" --context "$CLUSTER_NAME"

# Guard equivalent to a Taskfile `preconditions: - which <tool>` entry.
[private]
[script]
require +tools:
    for tool in {{ tools }}; do
        command -v "$tool" >/dev/null 2>&1 \
            || { echo "error: required tool not found on PATH: $tool" >&2; exit 1; }
    done

# Render a minijinja template and inject 1Password secrets into it.
[private]
template file *args:
    minijinja-cli "{{ file }}" {{ args }} | op inject
