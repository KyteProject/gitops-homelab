# use with https://github.com/casey/just

export BOOTSTRAP_DIR := "../bootstrap"
export KUBERNETES_DIR := "../clusters"

# Bootstrap flux into the cluster
@bootstrap cluster:
    # Create namespace and install Flux
    kubectl apply --server-side --kustomize ${BOOTSTRAP_DIR}

    # Install secrets
    sops --decrypt ${BOOTSTRAP_DIR}/age-key.secret.sops.yaml | kubectl apply --server-side -f -
    sops --decrypt ${BOOTSTRAP_DIR}/github-deploy-key.secret.sops.yaml | kubectl apply --server-side -f -
    sops --decrypt ${KUBERNETES_DIR}/{{cluster}}/vars/cluster-secrets.secret.sops.yaml | kubectl apply --server-side -f -

    flux bootstrap github \
    --owner=${GITHUB_USER} \
    --repository=${GITHUB_REPO} \
    --branch=main \
    --path=./clusters/main \
    --personal

# Test flux builds
@test:
  flux build kustomization system-controllers \
    --path ../infrastructure/controllers \
    --kustomization-file ./infrastructure.yaml \
    --dry-run

@reset:
  flux uninstall --namespace=flux-system
  kubectl get namespace flux-system -o json \
  | tr -d "\n" | sed "s/\"finalizers\": \[[^]]\+\]/\"finalizers\": []/" \
  | kubectl replace --raw /api/v1/namespaces/flux-system/finalize -f -

@logs:
  flux logs -A

@sync:
  flux reconcile source git flux-system
  flux reconcile source helm flux-system
  flux reconcile kustomization flux-system
  flux reconcile kustomization system-controllers
  flux reconcile kustomization apps

# Debug:
# Show all Flux objects that are not ready
@not-ready:
    flux get all -A --status-selector ready=false

# Show flux warning events
@warn:
    kubectl get events -n flux-system --field-selector type=Warning

# Check all sources status
@sources:
    flux get sources all -A

# Check all kustomizations and helm releases
@workloads:
    flux get kustomizations -A
    flux get helmreleases -A

# Check detailed helm charts and releases status
@helm-status:
    kubectl get helmcharts.source.toolkit.fluxcd.io -A
    kubectl get helmreleases.helm.toolkit.fluxcd.io -A

# Show controller errors
@err:
    flux logs --all-namespaces --level=error

# Check controllers readiness and versions
@health:
    flux check

# Get detailed status of a specific helm release (usage: just helm-debug <release-name> <namespace>)
@helm-debug release namespace:
    kubectl describe helmrelease {{release}} -n {{namespace}}

# Get all sources with kubectl for deeper inspection
@sources-kubectl:
    kubectl get gitrepositories.source.toolkit.fluxcd.io -A
    kubectl get helmrepositories.source.toolkit.fluxcd.io -A
