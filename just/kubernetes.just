set unstable := true
set quiet := true
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

[private]
default:
    just --list kube

# Required arguments come first because just only allows defaults on trailing
# parameters, so NS/CLAIM ordering is reversed relative to the Taskfile.
[doc('Mount a PVC to a temp container')]
browse-pvc claim ns='default':
    just require kubectl
    kubectl --namespace {{ ns }} get persistentvolumeclaims {{ claim }}
    kubectl browse-pvc --version
    kubectl browse-pvc --namespace {{ ns }} --image docker.io/library/alpine:latest {{ claim }}

[doc('Open a shell to a node')]
node-shell node ns='kube-system':
    just require kubectl
    kubectl get nodes {{ node }}
    kubectl node-shell --version
    kubectl node-shell -n {{ ns }} -x {{ node }}

[doc('Sync all ExternalSecrets')]
[script]
sync-secrets:
    just require kubectl
    kubectl get externalsecret --all-namespaces --no-headers \
        --output=jsonpath='{range .items[*]}{.metadata.namespace},{.metadata.name}{"\n"}{end}' \
    | while IFS=, read -r ns name; do
        if [[ -z "$ns" || -z "$name" ]]; then continue; fi
        kubectl --namespace "$ns" annotate externalsecret "$name" "force-sync=$(date +%s)" --overwrite
    done

[doc('Cleanse pods with a Failed/Pending/Succeeded phase')]
[script]
cleanse-pods:
    just require kubectl
    for phase in Failed Pending Succeeded; do
        kubectl delete pods --all-namespaces --field-selector "status.phase=$phase" --ignore-not-found=true
    done

# https://docs.github.com/en/enterprise-cloud@latest/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/deploying-runner-scale-sets-with-actions-runner-controller#upgrading-arc
[doc('Upgrade the ARC')]
upgrade-arc:
    just require flux helm
    helm -n actions-runner-system uninstall k8s-gitops-runner
    helm -n actions-runner-system uninstall actions-runner-controller
    sleep 5
    flux -n actions-runner-system reconcile hr actions-runner-controller
    flux -n actions-runner-system reconcile hr k8s-gitops-runner
