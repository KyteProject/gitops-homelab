# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A GitOps homelab: a three-node Talos Linux cluster (`aeon`) reconciled entirely by Flux from this
repository. There is no build, no test suite, and no application source code. "Correct" means the
manifests render and Flux converges; the cluster is the runtime.

## Commands

The command runner is **just**. `Taskfile.yaml` and `.taskfiles/` still exist and still work, but the
port to `just` has landed and new work should use it. The README still documents Task; that is the
one remaining piece of the retirement.

```bash
just                          # list recipe groups
just flux                     # list the Flux recipes, likewise `just kube`, `just talos`
just flux not-ready           # Flux objects that are not ready - the usual starting point
just flux sync                # force reconciliation of everything
just flux workloads           # kustomizations and helm releases at a glance
just flux trace <kind> <name> <namespace>
just kube browse-pvc <claim> <namespace>   # mount a PVC in a temp container
just kube sync-secrets        # force all ExternalSecrets to resync
just talos apply-node <node>
```

`.justfile` exports `KUBECONFIG` as `infrastructure/kubeconfig` and `TALOSCONFIG` as
`talos/talosconfig`, which are the paths that exist. Neither file is committed, so a fresh checkout
needs `just talos kubeconfig` first. `.mise.toml` and `Taskfile.yaml` still point `TALOSCONFIG` at
`talos/clusterconfig/talosconfig`, which does not exist; `talosctl` silently falls back to
`~/.talos/config` rather than failing, so a working `talosctl` is not proof the variable is right.

just is pinned at 1.36 here, where several constructs upstream uses do not exist. **Do not run
`just --unstable --fmt`**: at this version it strips `[group(...)]` attributes and doc comments.

Validating a change before pushing:

```bash
kubectl kustomize infrastructure/controllers/<namespace>     # does it build?
kubectl kustomize clusters/aeon/apps/<group>/<app>/app
yq e 'true' <file>.yaml                                      # YAML syntax
```

There is no linter for the cluster manifests locally. On a PR the **Flate** workflow renders the
before/after of every HelmRelease and Kustomization and posts it as a comment - that rendered diff
is the real review artifact, not the source diff.

## Architecture

### The Flux dependency chain

Everything hangs off `infrastructure/flux/cluster/ks.yaml`, which defines three Kustomizations in
strict order:

```
flux-repositories  (./infrastructure/flux/repositories)   OCI/Helm sources
      v
cluster-controllers (./infrastructure/controllers)        platform, one dir per namespace
      v
cluster-apps        (./clusters/aeon/apps)                workloads, one dir per group
```

Both `cluster-controllers` and `cluster-apps` carry a `patches:` block that injects HelmRelease
defaults into every child - `crds: CreateReplace`, `cleanupOnFail`, and `RemediateOnFailure` with
two retries. Individual HelmReleases rarely need to restate those.

### There is no kustomization.yaml at `infrastructure/controllers/`

Flux auto-discovers the subdirectories. Adding a new platform namespace means creating
`infrastructure/controllers/<namespace>/` with a `kustomization.yaml` and a `namespace.yaml`; it is
picked up on the next reconcile. The kustomization sets `namespace: <ns>`, lists `./namespace.yaml`
plus each app's `ks.yaml`, and pulls in `../../components/namespace`.

`components/namespace` does **not** create the Namespace. That object lives beside each namespace
directory as its own `namespace.yaml`. The component wires only the per-namespace Flux `Alert` and
`Provider` objects for GitHub commit statuses and Alertmanager, so dropping it silently removes that
notification wiring, and adding the Namespace to it as well makes the build fail with
`may not add resource with an already registered id`.

`clusters/aeon/apps/<group>/` follows the same pattern.

### App and controller layout

Both follow the same two-level shape:

```
<app>/ks.yaml        Flux Kustomization: path, components, dependsOn, postBuild.substitute
<app>/app/           the actual manifests, referenced by ks.yaml's path
```

`postBuild.substitute.APP` is the pivot. `components/kopiur` templates off `${APP}` to generate the
PVC, SnapshotPolicy, SnapshotSchedule and Restore, all named `${APP}`, so the value must match the
`existingClaim` in the HelmRelease.

`infrastructure/components/` holds three components: `kopiur` (backups), `namespace` (Flux alerts)
and `zeroscaler` (an HPA hardcoded to `minReplicas: 0, maxReplicas: 1`, so the app sleeps when idle).

**Component paths are relative to `spec.path`, not to the ks.yaml file.** For an app at
`clusters/aeon/apps/<group>/<app>/app` that is six levels up; for a controller at
`infrastructure/controllers/<ns>/<app>/app` it is four. Getting this wrong is the most common
porting error.

### Enabling and disabling apps

Apps are switched on by (un)commenting a line in `clusters/aeon/apps/<group>/kustomization.yaml`.
Most of `media/` and several of `personal/` are currently commented out. **Check this before
assessing the risk of any change** - a commented-out app has no running pods and no PVC, so a
manifest change to it has no blast radius.

### Secrets

All secrets come from 1Password via External Secrets. There is exactly one store,
`onepassword-connect` (upstream uses several; see below). Manifests declare an `ExternalSecret`
that reads a `key:` from the vault and templates it into a `Secret`. Nothing sensitive is committed. Talos machine config secrets are `op://` references
injected by `op inject` at apply time; SOPS and age are not used anywhere in this repo.

### Backups

Backups are **Kopiur**. One repository, `ClusterRepository/nas`: a Kopia filesystem repo on NFS at
`tank.lan:/mnt/tank/kopia`, password in `kopiur-nas-secret` in `kopiur-system` (the 1Password item is
named `volsync-template`). `credentialProjection.allowed: true`, so a policy in any namespace
authenticates without the secret being copied into git. `kopia.omux.io` is a read-only web UI over the
same repository and the easiest way to browse snapshots.

An app opts in by adding `components/kopiur` to its ks.yaml. Snapshots run hourly (`H * * * *`),
retention 3 latest / 24 hourly / 7 daily / 4 weekly.

**The mover UID must match the UID that owns the files.** Set per app via
`KOPIUR_MOVER_UID`/`_GID`/`_FSGROUP`, default **568**; `paperless` and `databasus` use 1000. When
adding an app, check its `runAsUser` against the default. A mismatch is not caught at deploy time: it
passes until the app writes its first `0600` file, then fails.

**Do not inherit the workload identity.** It mints a privileged mover for any app running as root,
which Kopiur refuses unless the whole namespace opts in.

**To opt an app out, set `KOPIUR_SUSPEND: "true"`.** Do not remove the component: it also defines the
PVC, whose `dataSourceRef` is immutable, so removing it prunes the volume.

A failed snapshot is silent: `kubectl get snapshot -A --field-selector=status.phase=Failed`.

Restoring a pre-Kopiur snapshot means naming `source.identity` explicitly, because VolSync wrote
`<app>@<namespace>:/data` where Kopiur writes `/pvc/<app>`. Those records show as `Discovered`.

## Conventions that bite

Drawn from `.claude/rules/`, the source of truth for agent guidance. Rules, skills, agents and hooks
under `.claude/` are all checked in and shared.

- **The shell is zsh.** `for x in $LIST` iterates *once* over the whole string - unquoted variables
  do not word-split. Use an array. Quote glob arguments (`--include='*.yaml'`) and URLs containing
  `?` or `&`.
- **Never `git add -A`, `git add .`, or `git add <dir>`.** This working tree routinely holds
  unrelated in-progress work. Stage explicit paths and check `git status --short` first.
- **Do not truncate output you are about to judge.** A Renovate source diff is 2-8 lines and tells
  you nothing; the same change can render 121 hunks across 14 objects.
- **Verify before landing.** Confirm an image tag exists in the registry, and confirm a chart value
  key exists with `helm show values` - Helm silently ignores keys that do not exist, so a setting can
  appear applied for months while doing nothing.
- **`PersistentVolumeClaim.spec.dataSourceRef` is immutable once bound.** Swapping a component that
  changes it wedges the Kustomization.
- **On a breaking bump, read the notes for changed *defaults*, not just removed keys.** A default
  nothing in this repo sets can still change behaviour. external-dns v0.22.0 moved the annotation
  prefix and `--policy=sync` then deleted every record; both instances now pin `--annotation-prefix`.
- **A controller reporting success is not evidence it did the right thing.** The UniFi external-dns
  logged "All records are already up to date" while deleting them. Check the effect, not the status.

### Language and commits

British English, no Oxford comma. **No emojis and no em dashes anywhere** - not in code, comments,
commit messages, docs or chat. Use a hyphen or rephrase.

Commits are Conventional Commits, single line, imperative, lowercase, no trailing full stop, and
**no body or footer** (no `Co-authored-by`):

```
fix(hoarder): pull alpine-chrome from docker hub as gcr project lost billing
```

## Porting from upstream

When lifting config from any reference repo, check for non-transferrable values. These always need remapping:

| Source repo | Here |
| --- | --- |
| `./kubernetes/apps/<ns>/...` | `./clusters/aeon/apps/<group>/...` or `./infrastructure/controllers/<ns>/...` |
| `components/alerts` | `components/namespace` |
| their domain | `omux.io` |
| `tank.internal` | `tank.lan` |
| `/mnt/tank/media` | `/mnt/tank/Media` (capital M) |
| `America/Chicago` | `Europe/London` |
| `onepassword-personal` | `onepassword-connect` |
| `openebs` in `openebs-system` | `openebs` in `storage` |
| `snapshot-controller` in `kube-system` | `snapshot-controller` in `storage` |

`components/namespace` carries only the Flux `Alert` and `Provider` wiring. **Every directory under
`infrastructure/controllers/` and every app group under `clusters/aeon/apps/` needs its own
`namespace.yaml`, with the real namespace name, listed in `resources`.** Upstream's `name: _`
placeholder renders the same but is not used here.

**Read the image's entrypoint before copying a `securityContext`.** Images that manage their own users
must start as root: `runAsUser: 1000` plus `drop: [ALL]` stops them booting.

**Verify NFS paths with `showmount -e tank.lan`.** A plausible-looking path fails at mount time, and
the export must cover all three node IPs. Exports map every client to a single UID, so an app that
chowns its own data directory needs the share owned by the UID that app expects.

Finish with a grep for leftovers and a `kubectl kustomize` build.

## Renovate

Config is `.renovaterc.json5` plus `.renovate/*.json5`, extending the shared
`home-operations/renovate-presets`. `automerge` is `false` on every rule - nothing reaches the
cluster without a human merge. `minimumReleaseAge` is set but `internalChecksFilter` is
deliberately `none`: most images here live on GHCR and quay without a creation timestamp, so a
strict filter would hold them back permanently rather than for 14 days.
