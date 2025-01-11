# 🏠 Homelab GitOps Project

Todo..

## 🌟 Features

- **Fully Automated**: GitOps-driven deployments using Flux CD
- **Secure by Design**: SOPS encryption, age keys, and strict security policies
- **High Availability**: Multi-node Kubernetes cluster powered by Talos Linux
- **Monitoring Stack**: Comprehensive monitoring with Prometheus, Grafana, and Gatus
- **Automated Updates**: Renovate bot keeps dependencies current
- **CI/CD Integration**: GitHub Actions with self-hosted runners
- **Network Security**: Cilium CNI for advanced networking and security policies

## 🚀 Getting Started

### Prerequisites

The following tools are required to work with this repository:

- `talosctl`: Talos Linux management
- `talhelper`: Talos configuration helper
- `kubectl`: Kubernetes CLI
- `flux`: FluxCD CLI
- `sops`: Secret encryption
- `age`: Encryption key management
- `just`: Command runner
- `helm`: Package manager
- `jq`: JSON processor

- `helm-diff`: Helm chart diff tool:

```bash
helm plugin install https://github.com/databus23/helm-diff
```

### 🔧 Initial Setup

1. Generate age encryption key:

```bash
age-keygen -o age.agekey
```

2. Create encrypted secrets:

```bash
just talos secrets
```

3. Generate cluster configuration:

```bash
just talos conf-gen
```

4. Bootstrap the cluster:

```bash
just cluster-bootstrap
```


## 🏗️ Project Structure

### Core Components

- **Infrastructure Layer**
  - Talos Linux base configuration
  - Core networking (Cilium)
  - DNS services (CoreDNS)
  - Certificate management

- **Platform Services**
  - Flux CD controllers
  - Monitoring stack
  - Backup solutions
  - External secrets management

- **Application Layer**
  - User applications
  - Development tools
  - Home automation services

### Directory Layout

```shell
.
├── bootstrap             # Initial cluster bootstrap configurations
├── clusters              # Cluster-specific configurations
│   └── main                # Production cluster
│       ├── apps              # User applications (home automation, tools, etc.)
│       ├── flux-system       # Core Flux configuration
│       ├── repositories      # External resource definitions (git, helm, oci)
│       └── vars              # Cluster-wide variables
├── docs                  # Project documentation
├── flux                  # Flux-specific configurations and templates
└── infrastructure        # Core infrastructure components
    ├── bootstrap           # Infrastructure bootstrapping resources
    ├── controllers         # System controllers and services
    │   ├── cert-manager      # Certificate management
    │   ├── database          # Database operators and clusters
    │   ├── kube-system       # Core kubernetes components
    │   ├── monitoring        # Observability stack
    │   ├── networking        # Network services and ingress
    │   ├── security          # Secret management and security tools
    │   └── storage           # Storage controllers and operators
    ├── talos             # Talos Linux configurations
    └── unifi             # UniFi network configurations
```

The repository follows a hierarchical structure:

- `clusters/`: Contains cluster-specific applications and configurations
- `infrastructure/`: Houses all core system components and controllers
- `infrastructure/controllers`: The controllers are grouped by namespace

## 🔄 Deployment Workflow

1. **Infrastructure Provisioning**
   - Talos Linux deployment
   - Network configuration
   - Storage setup

2. **Core Services**
   - CNI (Cilium) deployment
   - DNS configuration
   - Certificate management

3. **Platform Services**
   - Monitoring stack
   - Backup solutions
   - Security tools

4. **Application Deployment**
   - Automated via Flux CD
   - Version controlled
   - Encrypted secrets

## 🛠️ Development

This project follows GitOps principles:

1. **All changes through Git**
   - Infrastructure changes
   - Application deployments
   - Configuration updates

2. **Automated Processes**
   - CI/CD via GitHub Actions
   - Automated dependency updates
   - Continuous monitoring

3. **Security First**
   - Encrypted secrets
   - Least privilege access
   - Regular security updates

## 📚 Documentation

- [FluxCD Documentation](https://fluxcd.io/flux/guides/repository-structure/)
- [Talos Linux Guides](https://www.talos.dev/latest/introduction/getting-started/)

---

## 🙏 Gratitude and Thanks

A lot of inspiration and ideas are thanks to the hard work of [hotio.dev](https://hotio.dev) and [linuxserver.io](https://linuxserver.io) contributors.

Many thanks to [onedrop](https://github.com/onedr0p), [kashals](https://github.com/kashalls), [buroa](https://github.com/buroa), and all the fantastic people who donate their time to the [Home Operations](https://discord.gg/home-operations) Discord.

## 🚧 Changelog

See the latest [release](https://github.com/KyteProject/gitops-homelab/releases/latest) notes.

## 📝 License

See [LICENSE](./LICENSE).
