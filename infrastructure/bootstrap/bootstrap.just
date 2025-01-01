# use with https://github.com/casey/just

# Bootstrap: Wipe Rook Data
@rook-prep model cluster:
    #!/usr/bin/env bash
    set -euo pipefail
    NODE_COUNT=$(talosctl config info --output json | jq --raw-output '.nodes | length')
    export NODE_COUNT
    export MODEL="{{model}}"

    # Apply the wipe job
    envsubst '${MODEL}${NODE_COUNT}' < ./resources/rook-wipe-job.tmpl.yaml | kubectl --context admin@{{cluster}} apply --server-side -f -

    # Wait for job to exist
    until kubectl --context admin@{{cluster}} --namespace default get job/wipe-rook &>/dev/null; do
        sleep 5
    done

    # Wait for job completion
    kubectl --context admin@{{cluster}} --namespace default wait job/wipe-rook --for=condition=complete --timeout=5m

    # Show logs (optional)
    kubectl --context admin@{{cluster}} --namespace default logs -l app.kubernetes.io/name=wipe-rook

    # Clean up
    kubectl --context admin@{{cluster}} delete job wipe-rook -n default

# Bootstrap: Delete failed rook job
@rook-prep-job-del cluster:
  kubectl --context admin@{{cluster}} delete job wipe-rook -n default
