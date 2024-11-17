# use with https://github.com/casey/just

# Test flux builds
@test-flux:
  flux build kustomization monitoring \
    --path ../../apps/monitoring \
    --kustomization-file ./clusters/main/apps/monitoring/kustomization.yaml \
    --dry-run

  flux build kustomization core \
    --path ../../apps/core \
    --kustomization-file ./clusters/main/apps/core/kustomization.yaml \
    --dry-run
