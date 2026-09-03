set unstable := true
set quiet := true
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

# Recipes in a module run with the working directory set to the directory
# holding this file, not the repo root. just 1.36 has no `working-directory`
# setting, so every path below is absolute; recipes that take a path from the
# caller cd to the invocation directory first.
#
# justfile_directory() is the repo root even inside a module, so these mirror
# the `vars:` block of Taskfile.yaml.
kubernetes_dir := justfile_directory() / 'infrastructure'
talos_dir := justfile_directory() / 'talos'

[private]
default:
    just --list talos

# The Taskfile rendered talos/controlplane.yaml.j2, which does not exist, and
# passed `-D machinetype=controlplane`, which machineconfig.yaml.j2 does not
# read. The real template is machineconfig.yaml.j2 and it reads
# ENV.MACHINE_TYPE, so both are corrected here.
[doc('Apply initial Talos config to a node without requiring a context')]
[script]
init-node node ip mode='auto':
    just require minijinja-cli op talosctl
    op user get --me >/dev/null
    test -f "{{ talos_dir }}/machineconfig.yaml.j2"
    test -f "{{ talos_dir }}/controlplane/{{ node }}.yaml"
    export MACHINE_TYPE='controlplane'
    just template "{{ talos_dir }}/machineconfig.yaml.j2" \
        | talosctl --nodes {{ ip }} --endpoints {{ ip }} apply-config \
            --insecure \
            --mode {{ mode }} \
            --config-patch "@{{ talos_dir }}/controlplane/{{ node }}.yaml" \
            --file /dev/stdin

# Same template correction as init-node. The Taskfile also emitted a stray
# backslash mid-command in both talosconfig calls, which talosctl received as a
# literal argument; that is dropped here.
[confirm('Apply initial configuration to all nodes ... continue? [y|N]')]
[doc('Apply initial Talos config to all nodes without requiring a context')]
[script]
init-all:
    just require minijinja-cli op talosctl
    op user get --me >/dev/null
    test -f "{{ talos_dir }}/machineconfig.yaml.j2"
    for node in shiva ifrit ramuh; do
        test -f "{{ talos_dir }}/controlplane/$node.yaml"
    done
    just talos init-node shiva 192.168.10.10
    just talos init-node ifrit 192.168.10.11
    just talos init-node ramuh 192.168.10.12
    echo "All nodes configured. Waiting for nodes to be ready (30s)..."
    sleep 30
    echo "Generating talosconfig..."
    talosctl --talosconfig="{{ talos_dir }}/talosconfig" config endpoint 192.168.10.10 192.168.10.11 192.168.10.12
    talosctl --talosconfig="{{ talos_dir }}/talosconfig" config nodes 192.168.10.10 192.168.10.11 192.168.10.12
    echo "Talos configuration complete. You can now run 'just bootstrap talos' to bootstrap the cluster."

[doc('Apply Talos config to a node')]
[script]
apply-node node mode='auto':
    just require minijinja-cli op talosctl
    op user get --me >/dev/null
    talosctl config info >/dev/null
    test -f "{{ talos_dir }}/machineconfig.yaml.j2"
    MACHINE_TYPE="$(just talos machine-type {{ node }})"
    export MACHINE_TYPE
    test -f "{{ talos_dir }}/$MACHINE_TYPE/{{ node }}.yaml"
    insecure=()
    talosctl --nodes {{ node }} get machineconfig &>/dev/null || insecure=(--insecure)
    just template "{{ talos_dir }}/machineconfig.yaml.j2" \
        | talosctl --nodes {{ node }} apply-config \
            --mode {{ mode }} \
            --config-patch "@{{ talos_dir }}/$MACHINE_TYPE/{{ node }}.yaml" \
            --file /dev/stdin "${insecure[@]}"

[doc('Upgrade Talos on a single node')]
[script]
upgrade-node node:
    just require talosctl yq
    talosctl config info >/dev/null
    talosctl --nodes {{ node }} get machineconfig >/dev/null
    image="$(talosctl --nodes {{ node }} get machineconfig --output=jsonpath='{.spec}' \
        | yq '.machine.install.image | select(. != null)')"
    talosctl --nodes {{ node }} upgrade --image="$image" --timeout=10m

[doc('Reboot Talos on a single node')]
reboot-node node mode='default':
    just require talosctl
    talosctl config info >/dev/null
    talosctl --nodes {{ node }} get machineconfig >/dev/null
    talosctl --nodes {{ node }} reboot --mode={{ mode }}

[confirm('Shutdown the Talos cluster ... continue? [y|N]')]
[doc('Shutdown Talos across the whole cluster')]
[script]
shutdown-cluster:
    just require jq talosctl
    talosctl config info >/dev/null
    nodes="$(just talos node-list)"
    talosctl --nodes "$nodes" get machineconfig >/dev/null
    talosctl --nodes "$nodes" shutdown --force

[confirm('Reset the Talos node ... continue? [y|N]')]
[doc('Reset Talos on a single node')]
reset-node node:
    just require talosctl
    talosctl config info >/dev/null
    talosctl --nodes {{ node }} get machineconfig >/dev/null
    talosctl --nodes {{ node }} reset --graceful=false

[confirm('Reset the Talos cluster ... continue? [y|N]')]
[doc('Reset Talos across the whole cluster')]
[script]
reset-cluster:
    just require jq talosctl
    talosctl config info >/dev/null
    nodes="$(just talos node-list)"
    talosctl --nodes "$nodes" get machineconfig >/dev/null
    talosctl --nodes "$nodes" reset --graceful=false

[doc('Generate the kubeconfig for a Talos cluster')]
[script]
kubeconfig:
    just require jq talosctl
    talosctl config info >/dev/null
    controller="$(just talos random-controller)"
    talosctl --nodes "$controller" get machineconfig >/dev/null
    talosctl kubeconfig --nodes "$controller" --force "{{ kubernetes_dir }}"

[doc('Generate a Talos ISO for a specific version')]
[script]
generate-iso version:
    just require curl
    schematic="$(just talos generate-schematic true)"
    curl -L -o "{{ talos_dir }}/talos-{{ version }}.iso" \
        "https://factory.talos.dev/image/$schematic/{{ version }}/metal-amd64.iso"

# `iso` is carried over from the Taskfile, which exported it as ISO. Note that
# schematic.yaml.j2 does not read ENV.ISO, so it currently has no effect.
[doc('Generate a Talos schematic')]
generate-schematic iso='false':
    just require curl jq minijinja-cli
    test -f "{{ talos_dir }}/schematic.yaml.j2"
    ISO={{ iso }} minijinja-cli "{{ talos_dir }}/schematic.yaml.j2" | curl --silent -X POST --data-binary @- https://factory.talos.dev/schematics | jq --raw-output '.id'

# Same template correction as init-node: the Taskfile pointed at
# talos/<machine type>.yaml.j2, which does not exist.
[doc('Debug Talos template rendering')]
[script]
debug-template node='shiva':
    just require minijinja-cli
    template="{{ talos_dir }}/machineconfig.yaml.j2"
    MACHINE_TYPE="$(just talos machine-type {{ node }})"
    export MACHINE_TYPE
    echo "=== Template Information ==="
    echo "Template: $template"
    echo "Template exists: $(test -f "$template" && echo 'Yes' || echo 'No')"
    echo "Template size: $(wc -l < "$template" | tr -d ' ') lines"
    echo ""
    echo "=== Template Content (first 20 lines) ==="
    head -n 20 "$template"
    echo "..."
    echo ""
    echo "=== Environment Variables Required ==="
    grep -o "ENV\.[A-Z_]\+" "$template" | sort | uniq
    echo ""
    echo "=== Environment Variables Set ==="
    echo "MACHINE_TYPE: $MACHINE_TYPE"
    echo ""
    echo "=== Testing Template Rendering ==="
    output="$(mktemp)"
    echo "Command: minijinja-cli $template"
    if ! minijinja-cli "$template" > "$output"; then
        echo "Template rendering failed"
        exit 1
    fi
    echo "Template rendering succeeded. Output saved to $output"
    echo "First 20 lines of output:"
    head -n 20 "$output"

# The Taskfile referenced an undefined SYSTEM_UPGRADE_KS, so it always read an
# empty path. Exposed as a required argument instead. Note that no manifest in
# this repo currently carries KUBERNETES_VERSION or TALOS_VERSION under
# postBuild.substitute, so those lookups are expected to come back empty.
[doc('Debug variable extraction from a Flux Kustomization')]
[script]
debug-vars ks_file:
    # cd first so a relative path argument resolves against the caller's directory.
    cd "{{ invocation_directory() }}"
    just require yq
    test -f "{{ ks_file }}"
    echo "KUBERNETES_DIR: {{ kubernetes_dir }}"
    echo "SYSTEM_UPGRADE_KS: {{ ks_file }}"
    echo ""
    echo "Extracted versions:"
    echo "KUBERNETES_VERSION from yq: $(yq '.spec.postBuild.substitute.KUBERNETES_VERSION' "{{ ks_file }}" | tail -1 || echo 'failed')"
    echo "TALOS_VERSION from yq: $(yq '.spec.postBuild.substitute.TALOS_VERSION' "{{ ks_file }}" | tail -1 || echo 'failed')"
    echo ""
    echo "File content (first 20 lines):"
    head -n 20 "{{ ks_file }}"

[doc('Check the node-specific configuration file')]
[script]
debug-check-node-config node:
    just require yq
    machine_type="$(just talos machine-type {{ node }})"
    node_config="{{ talos_dir }}/$machine_type/{{ node }}.yaml"
    echo "Checking node config: $node_config"
    if [[ ! -f "$node_config" ]]; then
        echo "Error: Node config file does not exist"
        exit 1
    fi
    echo "Node config file exists. Content:"
    cat "$node_config"
    echo ""
    echo "Validating YAML structure..."
    if ! yq eval '.' "$node_config" > /dev/null; then
        echo "Error: Node config file is not valid YAML"
        exit 1
    fi
    echo "Node config file is valid YAML."

# Same template correction as init-node.
[doc('Check the rendered and injected configuration')]
[script]
debug-check-rendered-config node:
    just require minijinja-cli op
    op user get --me >/dev/null
    test -f "{{ talos_dir }}/machineconfig.yaml.j2"
    MACHINE_TYPE="$(just talos machine-type {{ node }})"
    export MACHINE_TYPE
    rendered="$(mktemp)"
    echo "Rendering template to $rendered..."
    minijinja-cli "{{ talos_dir }}/machineconfig.yaml.j2" > "$rendered"
    echo "=== Rendered Configuration (first 30 lines) ==="
    head -n 30 "$rendered"
    echo "..."
    injected="$(mktemp)"
    echo "Injecting secrets to $injected..."
    op inject --in-file "$rendered" > "$injected"
    echo "=== Injected Configuration (first 30 lines) ==="
    head -n 30 "$injected"
    echo "..."
    save_dir="$(mktemp -d)"
    cp "$rendered" "$save_dir/{{ node }}-rendered.yaml"
    cp "$injected" "$save_dir/{{ node }}-injected.yaml"
    echo "=== Full configurations saved to ==="
    echo "Rendered: $save_dir/{{ node }}-rendered.yaml"
    echo "Injected: $save_dir/{{ node }}-injected.yaml"
    rm "$rendered" "$injected"

[doc('Debug the node configuration file structure')]
[script]
debug-node-config node:
    machine_type="$(just talos machine-type {{ node }})"
    node_config="{{ talos_dir }}/$machine_type/{{ node }}.yaml"
    echo "Examining node config: $node_config"
    if [[ ! -f "$node_config" ]]; then
        echo "Error: Node config file does not exist"
        exit 1
    fi
    echo "=== Node Config Content ==="
    cat "$node_config"
    echo ""
    echo "=== YAML Structure Analysis ==="
    echo "Number of documents (separated by ---): $(grep -c "^---$" "$node_config" || true)"
    echo "First level keys:"
    grep -v "^#" "$node_config" | grep -v "^$" | grep -v "^---$" | grep -v "^  " | sort
    echo ""
    echo "=== Creating a clean version without document separators ==="
    clean_config="$(mktemp)"
    grep -v "^---$" "$node_config" > "$clean_config"
    echo "Clean config:"
    cat "$clean_config"
    rm "$clean_config"

# Pick a random control plane endpoint from the current talosctl context.
[private]
random-controller:
    talosctl config info --output json | jq --raw-output '.endpoints[]' | shuf -n 1

# Every node in the current talosctl context, comma separated.
[private]
node-list:
    talosctl config info --output json | jq --join-output '[.nodes[]] | join(",")'

# Ask the node for its machine type, falling back to the directory the node's
# config patch lives in when the node is not reachable.
[private]
[script]
machine-type node:
    talosctl --nodes {{ node }} get machinetypes --output=jsonpath='{.spec}' 2>/dev/null \
        || basename "$(find "{{ talos_dir }}" -name '{{ node }}.yaml' -printf '%h')"
