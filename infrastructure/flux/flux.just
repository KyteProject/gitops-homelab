# use with https://github.com/casey/just

export BOOTSTRAP_DIR := "../../bootstrap"
export KUBERNETES_DIR := "../../clusters"

# Bootstrap flux into the cluster
@bootstrap cluster:
    # Create namespace and install Flux
    kubectl apply --server-side --kustomize ${BOOTSTRAP_DIR}

    # Install secrets
    sops --decrypt ${BOOTSTRAP_DIR}/age-key.secret.sops.yaml | kubectl apply --server-side -f -
    sops --decrypt ${BOOTSTRAP_DIR}/github-deploy-key.secret.sops.yaml | kubectl apply --server-side -f -
    sops --decrypt ${KUBERNETES_DIR}/{{cluster}}/flux-system/vars/cluster-secrets.secret.sops.yaml | kubectl apply --server-side -f -

    flux bootstrap github \
    --owner=${GITHUB_USER} \
    --repository=${GITHUB_REPO} \
    --branch=main \
    --path=./clusters/main \
    --personal \
    --components-extra=image-reflector-controller,image-automation-controller \
    --read-write-key \
    --network-policy=false



# Test flux builds
@test-flux:
  flux build kustomization monitoring \
    --path ../../apps/monitoring \
    --kustomization-file ./clusters/main/apps/monitoring/monitoring.yaml \
    --dry-run

  flux build kustomization core \
    --path ../../apps/core \
    --kustomization-file ./clusters/main/apps/core/core.yaml \
    --dry-run

@reset:
  flux uninstall --namespace=flux-system

@logs:
  flux logs -A
