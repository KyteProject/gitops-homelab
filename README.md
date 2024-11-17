# Homelab Gitops Project

Todo..

## Getting Started

Todo..

### Prerequisites

Todo..

### Dependencies

- talosctl
- talhelper
- just
- sops
- age
- kubectl
- jq
- helm
- helm-diff
- flux

`helm plugin install https://github.com/databus23/helm-diff`

[FluxCD Docs](https://fluxcd.io/flux/guides/repository-structure/)

## Setup cluster

generate age key

todo...

Generate sops secrets

```bash
just talos secrets
```

Generate clusterconfig

```bash
just talos conf-gen
```

First time apply config insecure

```bash
just talos conf-apply-insecure
```

Bootstrap Talos

```bash
just talos bootstrap
```

Copy kubeconfig

```bash
just talos kubeconfig
```

Bootstrap core (kube-system) apps

```bash
just talos bootstrap-apps
```

## Project Structure

This repository follows GitOps principles to manage a Kubernetes homelab cluster using Talos Linux and Flux CD.

### Directory Structure

```bash
.
├── apps/                             # Application deployments
│   ├── core/                         # Core cluster services
│   │   ├── cilium/                   # CNI and network policy
│   │   ├── coredns/                  # DNS service
│   │   ├── kubelet-csr-approver/     # Certificate management
│   │   └── spegel/                   # Container registry mirror
│   │
│   └── monitoring/                   # Monitoring services
│       └── prometheus-operator-crds/ # Prometheus CRDs
│
├── infrastructure/                   # Infrastructure components
│   ├── talos/                        # Talos Linux configuration
│   │   ├── apps/                     # Bootstrap applications
│   │   └── clusterconfig/            # Talhelper configuration output
│   │
│   ├── netboot/                      # Network boot configuration
│   │
│   └── sources/                      # Flux source definitions
│
└── clusters/                         # Cluster-specific configurations
    └── main/                         # Main cluster
    │    ├── apps/                    # App deployments for this cluster
    │    │   ├── core/                # Core services deployment
    │    │   └── monitoring/          # Monitoring deployment
    │    └── infrastructure/          # Infrastructure for this cluster
    │    └── sources/                 # Source configurations
    └── pve/                          # Proxmox VE cluster
        └── ...                       # Proxmox VE cluster configuration
```

### Component Overview

#### Apps Directory

Contains all application definitions deployed to the cluster. Organized into:

- **core/**: Essential cluster services (CNI, DNS, etc.)
- **monitoring/**: Monitoring and observability tools

#### Infrastructure Directory

Houses all infrastructure-related configurations:

- **talos/**: Talos Linux cluster configuration and bootstrap process
- **netboot/**: Network boot configuration for cluster nodes
- **sources/**: Helm repository definitions for Flux

#### Clusters Directory

Contains cluster-specific configurations and overlays:

- **main/**: Production cluster configuration
  - Defines how applications are deployed
  - Specifies infrastructure requirements
  - Controls deployment order through Flux Kustomizations

### Deployment Flow

1. **Bootstrap Process**:

   - Talos Linux installation and configuration
   - Core services deployment via Helmfile
   - Flux CD installation

2. **GitOps Management**:
   - Flux manages ongoing cluster state
   - Applications deployed through Helm releases
   - Infrastructure changes tracked in Git

### Key Files

- `infrastructure/talos/talconfig.yaml`: Defines Talos cluster configuration
- `infrastructure/talos/apps/helmfile.yaml`: Manages bootstrap application deployment
- `clusters/main/apps/*/kustomization.yaml`: Flux deployment definitions
- `apps/*/kustomization.yaml`: Application resource definitions
