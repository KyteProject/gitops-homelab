# Talos Configuration with Jinja2 Templates

This directory contains the configuration for a Talos Kubernetes cluster using Jinja2 templates and Taskfile automation.

## Directory Structure

- `controlplane/`: Contains node-specific configuration files
  - `shiva.yaml`: Configuration for the shiva node
  - `ifrit.yaml`: Configuration for the ifrit node
  - `ramuh.yaml`: Configuration for the ramuh node
- `controlplane.yaml.j2`: The Jinja2 template for control plane nodes
- `talsecret.sops.yaml`: Encrypted secrets for the Talos cluster

## How to Use

### Using Task (Recommended)

This repository includes a Taskfile with tasks for managing the Talos cluster. Below are the available commands:

#### Configuration Management

```bash
# Apply configuration to a specific node
# Parameters:
#   NODE: (required) The hostname of the node to apply configuration to
#   MODE: (optional, default: auto) The mode to use when applying configuration
#         Options: auto, interactive, no-reboot, reboot, staged, try
task talos:apply-node NODE=shiva [MODE=auto]

# Generate the kubeconfig for the cluster
# This will save the kubeconfig to the Kubernetes directory
task talos:kubeconfig
```

#### Node Management

```bash
# Upgrade Talos on a specific node
# Parameters:
#   NODE: (required) The hostname of the node to upgrade
task talos:upgrade-node NODE=shiva

# Upgrade Kubernetes across the whole cluster
# This will upgrade all nodes to the version specified in the system-upgrade-controller
task talos:upgrade-k8s

# Reboot a specific node
# Parameters:
#   NODE: (required) The hostname of the node to reboot
#   MODE: (optional, default: default) The reboot mode
#         Options: default, powercycle
task talos:reboot-node NODE=shiva [MODE=default]

# Reset a specific node (wipes the node)
# Parameters:
#   NODE: (required) The hostname of the node to reset
task talos:reset-node NODE=shiva

# Reset the entire cluster (wipes all nodes)
task talos:reset-cluster

# Shutdown the entire cluster
task talos:shutdown-cluster
```

#### Secret Management

```bash
# Generate a new Talos secret
# This will create a SOPS-encrypted talsecret.sops.yaml file
task talos:generate-secret
```

#### Debugging Tools

```bash
# Debug template rendering
# Parameters:
#   NODE: (optional, default: shiva) The node to use for template rendering
task talos:debug:template [NODE=shiva]

# Debug variable extraction
# Shows the Kubernetes and Talos versions being used
task talos:debug:vars

# Check node-specific configuration
# Parameters:
#   NODE: (required) The node configuration to check
task talos:debug:check-node-config NODE=shiva

# Check rendered and injected configuration
# Parameters:
#   NODE: (required) The node to check configuration for
# Outputs files to /tmp/talos-config-check/
task talos:debug:check-rendered-config NODE=shiva

# Debug node configuration structure
# Parameters:
#   NODE: (required) The node configuration to analyze
task talos:debug:node-config NODE=shiva
```

## Node Configuration Format

Each node configuration file in the `controlplane/` directory should have the following format:

```yaml
---
install:
  diskSelector:
    model: "DISK_MODEL"
  network:
    hostname: node-hostname
    interfaces:
      - deviceSelector: [{hardwareAddr: XX:XX:XX:XX:XX:XX, driver: driver_name}]
        dhcp: true
        mtu: 1500
        vlans:
          - vlanId: XX
            dhcp: false
            addresses:
              - 192.168.XX.XX/24
            mtu: 1500
      # Additional interfaces as needed
```

## Secrets Management

### Understanding the Secrets Flow

The Talos configuration uses 1Password for secrets management:

1. The Jinja2 template contains references to 1Password secrets (e.g., `op://homelab/talos/MACHINE_TOKEN`)
2. When applying configurations with the `apply-node` task:
   - The Jinja2 template is rendered with `minijinja-cli`
   - The 1Password CLI (`op`) injects secrets into the rendered template
   - The configuration is applied to the node with `talosctl`

### Required Secrets in 1Password

You need to store the following secrets in your 1Password vault under the `homelab/talos` item:

| Secret Name | Description |
|-------------|-------------|
| `MACHINE_TOKEN` | Machine authentication token |
| `MACHINE_CA_CRT` | Machine CA certificate |
| `MACHINE_CA_KEY` | Machine CA key |
| `CLUSTER_ID` | Cluster ID |
| `CLUSTER_SECRET` | Cluster secret |
| `CLUSTER_TOKEN` | Cluster bootstrap token |
| `CLUSTER_SECRETBOXENCRYPTIONSECRET` | Secret for encryption |
| `CLUSTER_CA_CRT` | Cluster CA certificate |
| `CLUSTER_CA_KEY` | Cluster CA key |
| `CLUSTER_AGGREGATORCA_CRT` | Aggregator CA certificate |
| `CLUSTER_AGGREGATORCA_KEY` | Aggregator CA key |
| `CLUSTER_SERVICEACCOUNT_KEY` | Service account key |
| `CLUSTER_ETCD_CA_CRT` | ETCD CA certificate |
| `CLUSTER_ETCD_CA_KEY` | ETCD CA key |

### Setting Up Secrets

To set up the required secrets:

1. **Generate the encrypted secrets file**:

   ```bash
   task talos:generate-secret
   ```

   This will create a SOPS-encrypted `talsecret.sops.yaml` file.

2. **Decrypt the secrets file** to view the contents:

   ```bash
   sops --decrypt talsecret.sops.yaml
   ```

3. **Create a 1Password item** named `talos` in the `homelab` vault with fields for each secret listed above.

4. **Copy the values** from the decrypted `talsecret.sops.yaml` to the corresponding fields in 1Password.

5. **Verify 1Password CLI access**:

   ```bash
   op user get --me
   ```

## Bootstrapping the Cluster

After applying the configuration to all nodes, bootstrap the cluster:

```bash
# Bootstrap the cluster using one of the control plane nodes
talosctl bootstrap --nodes <control-plane-ip>
```

## Typical Workflow

1. **Initial Setup**:

   ```bash
   # Generate secrets
   task talos:generate-secret

   # Apply configuration to each node
   task talos:apply-node NODE=shiva
   task talos:apply-node NODE=ifrit
   task talos:apply-node NODE=ramuh

   # Bootstrap the cluster
   talosctl bootstrap --nodes <control-plane-ip>

   # Generate kubeconfig
   task talos:kubeconfig
   ```

2. **Maintenance**:

   ```bash
   # Upgrade Talos on a node
   task talos:upgrade-node NODE=shiva

   # Upgrade Kubernetes across the cluster
   task talos:upgrade-k8s

   # Reboot a node
   task talos:reboot-node NODE=shiva
   ```

3. **Troubleshooting**:

   ```bash
   # Check node configuration
   task talos:debug:check-node-config NODE=shiva

   # Check rendered configuration
   task talos:debug:check-rendered-config NODE=shiva

   # Debug template rendering
   task talos:debug:template NODE=shiva
   ```

## Requirements

- `talosctl`: Talos Linux management CLI
- `minijinja-cli`: Jinja2 template rendering tool
- `op`: 1Password CLI for secrets injection
- `yq`: YAML processor
- `jq`: JSON processor
- `sops`: Secret encryption tool
