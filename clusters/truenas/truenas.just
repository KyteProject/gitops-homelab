# Variables
ansible_dir := "../../infrastructure/ansible"

# Setup TrueNAS dependencies
setup:
    just ansible setup

# Deploy all apps to TrueNAS
deploy-apps:
    just ansible deploy-apps

# Deploy specific app to TrueNAS
deploy app:
    just ansible deploy {{app}}

# Initialize SOPS file for an app
@secrets-init app:
    mkdir -p apps/{{app}}
    sops --encrypt --in-place apps/{{app}}/secrets.sops.yaml

# Edit encrypted secrets for an app
@secrets-edit app:
    sops apps/{{app}}/secrets.sops.yaml

# Create new app from template
create-app app:
    mkdir -p apps/{{app}}
    cp apps/_base/docker-compose.yml apps/{{app}}/
    touch apps/{{app}}/secrets.sops.yaml

# Manually run cert-sync cron
@cert-cron:
    kubectl create job -n cert-manager --from=cronjob/sync-truenas-cert manual-sync-$(date +%s) && kubectl get pods -n cert-manager -w
