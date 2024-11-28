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

@logs:
  flux logs -A
