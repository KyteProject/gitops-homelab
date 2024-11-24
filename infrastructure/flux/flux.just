# use with https://github.com/casey/just

# Bootstrap flux into the cluster
@bootstrap:
  # Create flux-system namespace
  kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply -f -

  # Apply encrypted secrets before bootstrap
  sops --decrypt ./age-key.sops.yaml | kubectl apply --server-side  -f -
  sops --decrypt ./github-deploy-key.sops.yaml | kubectl apply --server-side  -f -

  # Bootstrap flux with GitHub repository
  flux bootstrap github \
    --owner=${GITHUB_USER} \
    --repository=${GITHUB_REPO} \
    --branch=main \
    --cluster=main \
    --path=./clusters/main \
    --path=./infrastructure/flux/repos \
    --personal \
    --network-policy=false \


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
