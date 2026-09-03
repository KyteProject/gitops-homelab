set unstable := true
set quiet := true
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

# Recipes in a module run with the working directory set to the directory
# holding this file, not the repo root. just 1.36 has no `working-directory`
# setting, so every path below is absolute; recipes that take a path from the
# caller cd to the invocation directory first.

[private]
default:
    just --list flux

[doc('Reset flux installation')]
reset:
    just require flux kubectl
    flux uninstall --namespace=flux-system
    kubectl get namespace flux-system -o json | tr -d "\n" | sed "s/\"finalizers\": \[[^]]\+\]/\"finalizers\": []/" | kubectl replace --raw /api/v1/namespaces/flux-system/finalize -f -

[doc('Show flux logs')]
logs:
    flux logs -A

[doc('Sync all flux resources')]
sync:
    flux reconcile source git flux-system
    flux reconcile kustomization flux-system

[doc('Show all Flux objects that are not ready')]
not-ready:
    flux get all -A --status-selector ready=false

[doc('Show flux warning events')]
warn:
    kubectl get events -n flux-system --field-selector type=Warning

[doc('Check all sources status')]
sources:
    flux get sources all -A

[doc('Check all kustomizations and helm releases')]
workloads:
    flux get kustomizations -A
    flux get helmreleases -A

[doc('Check detailed helm charts and releases status')]
helm-status:
    kubectl get helmcharts.source.toolkit.fluxcd.io -A
    kubectl get helmreleases.helm.toolkit.fluxcd.io -A

[doc('Show controller errors')]
err:
    flux logs --all-namespaces --level=error

[doc('Check controllers readiness and versions')]
health:
    flux check

[doc('Get detailed status of a specific helm release')]
helm-debug release namespace:
    kubectl describe helmrelease {{ release }} -n {{ namespace }}

[doc('Get all sources with kubectl for deeper inspection')]
sources-kubectl:
    kubectl get gitrepositories.source.toolkit.fluxcd.io -A
    kubectl get helmrepositories.source.toolkit.fluxcd.io -A

[doc('Comprehensive health check of the Flux system')]
verify: health not-ready sources warn
    echo "=== Checking Flux System Pods ==="
    kubectl get pods -n "$FLUX_NAMESPACE" -o wide
    echo "=== Checking Resource Usage ==="
    kubectl top pods -n "$FLUX_NAMESPACE"

[doc('Suspend a specific Flux Kustomization')]
suspend name:
    flux suspend kustomization {{ name }}

[doc('Resume a specific Flux Kustomization')]
resume name:
    flux resume kustomization {{ name }}

# The Taskfile referenced an undefined KUBECTL_TIMEOUT, which rendered as
# `--timeout=` and made kubectl reject the call. Exposed as an argument with a
# working default instead.
[doc('Wait for all Flux resources to be ready (with timeout)')]
wait timeout='5m':
    flux get all -A --status-selector ready=false
    kubectl wait --for=condition=ready --all pods -n "$FLUX_NAMESPACE" --timeout={{ timeout }}

# cd first so a relative path argument resolves against the caller's directory.
[doc('Show differences between deployed and source manifests')]
[script]
diff name path:
    cd "{{ invocation_directory() }}"
    flux diff kustomization {{ name }} --path {{ path }}

[doc("Trace a Flux resource's reconciliation path")]
trace kind name namespace:
    flux trace {{ kind }} {{ name }} -n {{ namespace }}

[doc('Export all Flux resources to a backup directory')]
[script]
export:
    backup_dir="{{ invocation_directory() }}/flux-backup-$(date +%Y-%m-%d-%H%M%S)"
    mkdir -p "$backup_dir"
    flux export source git --all > "$backup_dir/sources-git.yaml"
    flux export source helm --all > "$backup_dir/sources-helm.yaml"
    flux export kustomization --all > "$backup_dir/kustomizations.yaml"
    flux export helmrelease --all > "$backup_dir/helmreleases.yaml"
    echo "Backup created in $backup_dir"

# The Taskfile backgrounded the port-forward in a shell that then exited,
# orphaning it. Kept as one script so the trap can clean the child up.
[doc('Show Flux controller metrics')]
[script]
metrics:
    kubectl port-forward -n "$FLUX_NAMESPACE" svc/source-controller 8080:8080 &
    pf_pid=$!
    trap 'kill "$pf_pid" 2>/dev/null || true' EXIT
    echo "Metrics available at http://localhost:8080/metrics"
    sleep 2
    curl -s http://localhost:8080/metrics | grep ^flux

[doc('Clean up suspended and failed resources')]
clean:
    flux get kustomization -A --status-selector suspended=true
    flux get helmrelease -A --status-selector ready=false
    echo "Use 'just flux resume <name>' to resume suspended resources"

[doc('Show all Flux-related events, sorted by time')]
events:
    kubectl get events --all-namespaces --sort-by='.metadata.creationTimestamp' | grep -i "flux"

[doc('Force reconciliation of all Flux resources')]
reconcile-all:
    flux reconcile source all
    flux reconcile helmrelease all
    flux reconcile kustomization all
    just flux wait

[doc('Install useful debugging tools in the Flux namespace')]
debug-toolkit:
    kubectl run flux-debug --namespace="$FLUX_NAMESPACE" --rm -i --tty --image=registry.k8s.io/e2e-test-images/jessie-dnsutils:1.3 -- bash

[doc('List all container images managed by Flux')]
list-images:
    flux get images all -A

[doc('Remove old images based on policy')]
prune:
    flux image update
    flux image prune
