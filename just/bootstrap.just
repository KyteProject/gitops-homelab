set unstable := true
set quiet := true
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

# Recipes in a module run with the working directory set to the directory
# holding this file, not the repo root. just 1.36 has no `working-directory`
# setting, so every path below is absolute; recipes that take a path from the
# caller cd to the invocation directory first.
#
# justfile_directory() is the repo root even inside a module, so these mirror
# the `vars:` block of Taskfile.yaml.
bootstrap_dir := justfile_directory() / 'bootstrap'
kubernetes_dir := justfile_directory() / 'infrastructure'

[private]
default:
    just --list bootstrap

[confirm('Bootstrap Talos ...? [y|N]')]
[doc('Bootstrap Talos')]
[script]
talos:
    just require jq talosctl
    talosctl config info >/dev/null
    controller="$(just talos random-controller)"
    talosctl --nodes "$controller" get machineconfig >/dev/null
    until talosctl --nodes "$controller" bootstrap; do sleep 5; done
    talosctl kubeconfig --nodes "$controller" --force "{{ kubernetes_dir }}"

[confirm('Bootstrap Kubernetes Controllers ...? [y|N]')]
[doc('Bootstrap Kubernetes Controllers')]
[script]
controllers:
    just require jq kubectl op talosctl
    op user get --me >/dev/null
    talosctl config info >/dev/null
    test -f "{{ bootstrap_dir }}/resources.yaml"
    context="$(talosctl config info --output json | jq --raw-output '.context')"
    controller="$(just talos random-controller)"
    talosctl --nodes "$controller" get machineconfig >/dev/null
    # Equivalent to the Taskfile `defer:` step: always refresh the kubeconfig,
    # whether the bootstrap succeeds or fails.
    trap 'talosctl kubeconfig --nodes "$controller" --force "{{ kubernetes_dir }}"' EXIT
    kubectl config set-cluster "$context" --server "https://$controller:6443"
    until kubectl wait nodes --for=condition=Ready=False --all --timeout=10m; do sleep 5; done
    op inject --in-file "{{ bootstrap_dir }}/resources.yaml" | kubectl apply --server-side --filename -
    just bootstrap helmfile

[private]
[script]
helmfile:
    just require helmfile kubectl yq
    test -f "{{ bootstrap_dir }}/helmfile.d/00-crds.yaml"
    test -f "{{ bootstrap_dir }}/helmfile.d/01-apps.yaml"
    helmfile --file "{{ bootstrap_dir }}/helmfile.d/00-crds.yaml" template --quiet \
        | yq ea -e 'select(.kind == "CustomResourceDefinition")' \
        | kubectl apply --server-side --field-manager bootstrap --force-conflicts --filename -
    helmfile --file "{{ bootstrap_dir }}/helmfile.d/01-apps.yaml" sync --hide-notes
