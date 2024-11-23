# use with https://github.com/casey/just

# Bootstrap flux into the cluster
@bootstrap:
  flux bootstrap github \
    --owner=${GITHUB_USER} \
    --repository=${GITHUB_REPO} \
    --branch=main \
    --path=./clusters/main \
    --personal

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
  # Delete the existing kustomizations
  kubectl delete kustomization -n flux-system --all

  # Delete the Flux cache directory in the tmp folder
  kubectl exec -n flux-system deploy/kustomize-controller -- rm -rf /tmp/kustomization-*

  # Delete the source artifacts
  kubectl delete -n flux-system gitrepository flux-system

  # Uninstall Flux completely
  flux uninstall --namespace=flux-system -y

@logs:
  flux logs -A
