# use with https://github.com/casey/just

export TALOS_CONTROLLER := `talosctl config info --output json | jq --raw-output '.endpoints[]' | shuf -n 1`

nodes :=  `talosctl config info --output json | jq --join-output '[.nodes[]] | join(",")'`

conf_file := "clusterconfig/talosconfig"
secret_file := "talsecret.sops.yaml"
helm_file := "apps/helmfile.yaml"

# Talos: Generate Secrets
@secrets:
  talhelper gensecret > {{secret_file}}
  sops -e -i {{secret_file}}

# Talos: Generate configuration
@conf-gen:
  talhelper genconfig

# Talos: Apply config
@conf-apply:
  talhelper gencommand apply | bash
  talosctl config merge {{conf_file}}

# Talos: Apply config (insecure)
@conf-apply-insecure node:
  talhelper gencommand apply -n {{node}} --extra-flags -i | bash
  talosctl config merge {{conf_file}}

# Talos: Bootstrap
@bootstrap:
  until echo Bootstrapping node: {{TALOS_CONTROLLER}} && talosctl bootstrap -n {{TALOS_CONTROLLER}}; do sleep 10; done

# Talos: Bootstrap core apps
bootstrap-apps:
  # until kubectl wait --for=condition=Ready=False nodes --all --timeout=10m; do sleep 10; done
  helmfile -f {{helm_file}} apply --skip-diff-on-install --suppress-diff
  # until kubectl wait --for=condition=Ready nodes --all --timeout=10m; do sleep 10; done

# Talos: Get kubeconfig
@kubeconfig:
  talosctl kubeconfig -n {{TALOS_CONTROLLER}}

# Talos: Reset node {nodeIp}
@reset-node node:
  talosctl reset --nodes {{node}} --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL --graceful=false --reboot

# Talos: Reset cluster
@reset-cluster:
  talosctl reset --nodes {{nodes}} --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL --graceful=false --reboot
