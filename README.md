# gitops-homelab

GitOps configuration for **aeon**, a three-node Talos Linux Kubernetes cluster reconciled entirely by
Flux from this repository. There is no build step, no test suite and no application source code. The
cluster is the runtime, and a change is correct when the manifests render and Flux converges.

## The cluster

| Node  | Role          | Address       |
| ----- | ------------- | ------------- |
| shiva | control plane | 192.168.10.10 |
| ifrit | control plane | 192.168.10.11 |
| ramuh | control plane | 192.168.10.12 |

All three nodes are control planes and also run workloads. The Kubernetes and Talos versions are
declared in `infrastructure/controllers/system-upgrade/tuppr/upgrades/` and rolled out node by node
by tuppr, gated on Ceph health. Renovate raises the version bumps and a human merges them. At the
time of writing that is Kubernetes v1.36.0 on Talos v1.13.9.

## Layout

```shell
.
├── bootstrap/         helmfile and resources used once, to get Flux running
├── clusters/
│   ├── aeon/apps/       workloads, one directory per group: home, media, personal, security, tools
│   └── truenas/         compose file for the exporters that run on the NAS, not on the cluster
├── docs/
├── infrastructure/
│   ├── components/      reusable kustomize components: namespace, kopiur, kopiur-migrate, volsync, zeroscaler
│   ├── controllers/     the platform, one directory per namespace
│   ├── flux/            the entrypoint Kustomizations, and the OCI, Helm and Git sources
│   ├── netboot/         PXE boot helper, runs off-cluster
│   ├── seedbox/         scripts for the off-cluster seedbox
│   └── unifi/           bgp.conf for the UDM, applied by hand on the router
├── talos/             machine config template, per-node patches
└── .taskfiles/        the Task definitions included by Taskfile.yaml
```

## How Flux reconciles this

`infrastructure/flux/cluster/ks.yaml` defines the whole chain, in strict order:

```text
flux-repositories     ./infrastructure/flux/repositories     OCI, Helm and Git sources
        |
cluster-controllers   ./infrastructure/controllers           platform, one directory per namespace
        |
cluster-apps          ./clusters/aeon/apps                   workloads, one directory per group
```

`cluster-controllers` and `cluster-apps` each carry a `patches:` block that injects HelmRelease
defaults into every child: `crds: CreateReplace`, `cleanupOnFail`, and `RemediateOnFailure` with two
retries. Individual HelmReleases rarely need to restate any of that.

**There is no `kustomization.yaml` at `infrastructure/controllers/`, nor at `clusters/aeon/apps/`.**
Flux walks the subdirectories itself. Adding a platform namespace means creating
`infrastructure/controllers/<namespace>/kustomization.yaml` and nothing else; it is picked up on the
next reconcile.

### The two-level shape

Apps and controllers follow the same pattern:

```text
<app>/ks.yaml     Flux Kustomization: path, components, dependsOn, postBuild.substitute
<app>/app/        the manifests that ks.yaml points at
```

`postBuild.substitute.APP` is the pivot. Shared components template off `${APP}` to generate the PVC,
backup policy and ExternalSecret, so the app name has to match the PVC name and the workload name for
them to line up.

Component paths inside `ks.yaml` are relative to `spec.path`, not to the `ks.yaml` file. For an app at
`clusters/aeon/apps/<group>/<app>/app` that is six levels up; for a controller at
`infrastructure/controllers/<namespace>/<app>/app` it is four. Getting this wrong is the most common
mistake when adding something.

### Turning things on and off

An app is enabled by uncommenting its `ks.yaml` line in `clusters/aeon/apps/<group>/kustomization.yaml`;
controllers work the same way in `infrastructure/controllers/<namespace>/kustomization.yaml`. Several
are commented out at any given time. A commented-out app has no pods and no PVC, so a manifest change
to it has no blast radius. Check the group kustomization before assuming a change is risky.

## Platform

**Networking.** Cilium provides the CNI and LoadBalancer IPAM, advertising service addresses to the
UDM over BGP out of `192.168.20.0/24`. The cluster half lives in
`infrastructure/controllers/kube-system/cilium/configs/`, the router half in
`infrastructure/unifi/bgp.conf`, which is applied by hand on the UDM. Ingress is Envoy Gateway with
two Gateways, `envoy-internal` and `envoy-external`; external-dns publishes the records under
`omux.io` and cloudflared fronts the external one.

**Storage.** Rook-Ceph, with `ceph-block` as the default StorageClass and `ceph-filesystem` for shared
volumes. `openebs-hostpath` covers node-local scratch. The CSI snapshot-controller lives in the
`storage` namespace.

**Secrets.** Everything in-cluster comes from 1Password through External Secrets, against a single
ClusterSecretStore, `onepassword-connect`. A manifest declares an `ExternalSecret` that reads a key
from the vault and templates it into a `Secret`. Nothing sensitive is committed. The two places that
need secrets before External Secrets exists, the Talos machine config and `bootstrap/resources.yaml`,
carry `op://` references and are piped through `op inject` at apply time, so the 1Password CLI has to
be signed in for those tasks.

**Backups.** Migrating from VolSync to Kopiur. Both components live in `infrastructure/components/`
and both are in use while that proceeds, alongside a transitional `kopiur-migrate` component that
pins the old VolSync snapshot identity for a one-time restore, because the two write to different
repository paths. Which apps sit on which is changing, so read the app's `ks.yaml` rather than
trusting a list. Cutting a live app over is destructive and order-dependent; see `CLAUDE.md`.

**Observability.** kube-prometheus-stack, Grafana, Gatus, Karma, VictoriaLogs with Fluent Bit
shipping into it, and a set of exporters, all under `infrastructure/controllers/monitoring/`.

## Working on it

The command runner is [Task](https://taskfile.dev). `Taskfile.yaml` includes everything under
`.taskfiles/`. Run `task` on its own for the full list.

### Setting up a workstation

```bash
task workstation:setup          # Homebrew bundle plus krew plugins, per platform
task workstation:check-tools    # what is missing
```

The toolchain is `.taskfiles/workstation/resources/Brewfile`: talosctl, kubectl, flux, helm, helmfile,
kustomize, minijinja-cli, the 1Password CLI, jq, yq, k9s, stern and friends.

`Taskfile.yaml` and `.mise.toml` both export `KUBECONFIG` and `TALOSCONFIG`. Neither file is
committed, so a fresh checkout needs `task talos:kubeconfig`, which writes to `infrastructure/kubeconfig`.
Note that the two exports have drifted: `.mise.toml` points `KUBECONFIG` at the repository root and
`TALOSCONFIG` at `talos/clusterconfig/talosconfig`, while the tasks write to `infrastructure/kubeconfig`
and `talos/talosconfig`. Set the variables explicitly if a tool cannot find the cluster.

### Everyday tasks

```bash
task flux:not-ready                              # Flux objects that are not ready, the usual start
task flux:workloads                              # kustomizations and helm releases at a glance
task flux:sync                                   # force reconciliation of everything
task flux:err                                    # controller errors
task flux:events                                 # Flux events, sorted by time
task flux:trace KIND=<kind> NAME=<name> NAMESPACE=<ns>
task flux:helm-debug RELEASE=<name> NAMESPACE=<ns>

task kubernetes:browse-pvc NS=<ns> CLAIM=<pvc>   # mount a PVC in a temp container
task kubernetes:sync-secrets                     # force every ExternalSecret to resync
task kubernetes:node-shell NODE=<node>
task kubernetes:cleanse-pods

task talos:apply-node NODE=<node> [MODE=auto]
task talos:upgrade-node NODE=<node>
task talos:reboot-node NODE=<node>
task talos:kubeconfig

task k9s
```

`task volsync:snapshot` and `task volsync:restore` still exist for the VolSync side of the backup
migration. `task r2:ls` and `task r2:empty BUCKET=<bucket>` cover the Cloudflare R2 buckets.

### Validating a change

```bash
kubectl kustomize infrastructure/controllers/<namespace>
kubectl kustomize clusters/aeon/apps/<group>/<app>/app
yq e 'true' <file>.yaml
```

There is no local linter for the cluster manifests. The real check is the Flate comment on the pull
request, described below.

## Bootstrapping from scratch

Every step needs the 1Password CLI signed in.

1. `task talos:generate-schematic`, then `task talos:generate-iso VERSION=<version>` to build the
   installer image from the Talos factory.
2. `task talos:apply-node NODE=<node>` for each node. The task renders `talos/machineconfig.yaml.j2`,
   injects the `op://` references, applies the per-node patch from `talos/controlplane/<node>.yaml`,
   and adds `--insecure` on its own when the node has no config yet. There are also
   `talos:init-node` and `talos:init-all` tasks, but they still reference a `controlplane.yaml.j2`
   that is no longer in the tree and will fail their preconditions.
3. `task bootstrap:talos` runs `talosctl bootstrap` and writes the kubeconfig.
4. `task bootstrap:controllers` applies the op-injected `bootstrap/resources.yaml`, then runs the
   helmfile in `bootstrap/helmfile.d/`: Cilium, CoreDNS, Spegel, cert-manager, External Secrets,
   1Password Connect, flux-operator and flux-instance, in that order.
5. Flux takes over from `infrastructure/flux/cluster/ks.yaml` and reconciles the rest.

## CI

Four workflows in `.github/workflows/`:

- **Flate** renders the before and after of every HelmRelease and Kustomization touched by a pull
  request and posts the result as a comment. That rendered diff is the review artefact, not the
  source diff, which for a version bump is two lines and tells you nothing. The same bump can render
  a hundred hunks across a dozen objects.
- **Image Pull** extracts every image the pull request introduces and pulls it onto the nodes from a
  self-hosted runner, so a bad reference fails on the PR and the rollout is warm on merge.
- **Renovate** runs hourly. `automerge` is false on every rule, so nothing reaches the cluster
  without a human merge. `minimumReleaseAge` is 14 days, but `internalChecksFilter` is deliberately
  `none`: most images here live on GHCR and quay without a creation timestamp, and a strict filter
  would hold them back permanently rather than for two weeks. Config is `.renovaterc.json5` plus
  `.renovate/*.json5`, extending the shared `home-operations/renovate-presets`.
- **Label Sync** reconciles `.github/labels.yaml`.

## Conventions

`CLAUDE.md` at the root and `.cursor/rules/` hold these in full. The short version:

- British English, no Oxford comma. No emojis and no em dashes anywhere, including commit messages.
- Conventional Commits, single line, imperative, lowercase, no trailing full stop, no body or footer.
- The shell is zsh. Unquoted variables do not word-split, so use arrays for lists and quote globs
  and any URL containing `?` or `&`.
- Stage explicit paths. Never `git add -A`, `git add .` or `git add <directory>`.
- Confirm an image tag actually exists in the registry before pinning it, and confirm a chart value
  key exists with `helm show values`. Helm silently ignores keys that do not exist, so a setting can
  look applied for months while doing nothing.
- `PersistentVolumeClaim.spec.dataSourceRef` is immutable once bound. Swapping a component that
  changes it will wedge the Kustomization.

Config lifted from upstream repos, chiefly [buroa/k8s-gitops](https://github.com/buroa/k8s-gitops),
needs remapping on the way in: paths, namespaces, the domain and the timezone all differ. `CLAUDE.md`
has the table.

## Thanks

Inspiration and ideas from [onedr0p](https://github.com/onedr0p),
[kashalls](https://github.com/kashalls), [buroa](https://github.com/buroa),
[hotio.dev](https://hotio.dev), [linuxserver.io](https://linuxserver.io) and everyone in the
[Home Operations](https://discord.gg/home-operations) Discord.

## Licence

GPL-3.0. See [LICENSE](./LICENSE).
