# use with https://github.com/casey/just

export TALOS_CONTROLLER := `talosctl config info --output json | jq --raw-output '.endpoints[]' | shuf -n 1`

nodes :=  `talosctl config info --output json | jq --join-output '[.nodes[]] | join(",")'`

conf_file := "clusterconfig/talosconfig"
secret_file := "talsecret.sops.yaml"
helm_file := "apps/helmfile.yaml"

timestamp := `date +%Y-%m-%d`

cluster := "main"

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
@bootstrap-apps:
  helmfile --quiet --kube-context admin@{{cluster}} -f {{helm_file}} apply --skip-diff-on-install --suppress-diff

# Talos: Get kubeconfig
@kubeconfig:
  talosctl --context {{cluster}} kubeconfig --force-context-name {{cluster}} --talosconfig=./clusterconfig/talosconfig --nodes={{TALOS_CONTROLLER}} -f ../../kubeconfig

# Talos: Reset node {nodeIp}
@reset-node node:
  talosctl reset --nodes {{node}} --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL --graceful=false --reboot

# Talos: Reset cluster
@reset-cluster:
  talosctl reset --nodes {{nodes}} --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL --system-labels-to-wip META --graceful=false --reboot

# Talos: Take snapshots
@snapshot:
  talosctl -n 192.168.10.10 etcd snapshot snapshots/{{timestamp}}-shiva-snapshot.db
  talosctl -n 192.168.10.11 etcd snapshot snapshots/{{timestamp}}-ifrit-snapshot.db
  talosctl -n 192.168.10.12 etcd snapshot snapshots/{{timestamp}}-ramuh-snapshot.db
