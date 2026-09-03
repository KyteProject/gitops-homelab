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

Backups are **Kopiur**. VolSync is retired: its HelmRelease, components and CRDs are gone, and any
surviving `volsync.backube` reference or `${VOLSYNC_*}` variable is a leftover, not a live path.

One repository, `ClusterRepository/nas`: a Kopia filesystem repo on NFS at `tank.lan:/mnt/tank/kopia`,
password in `kopiur-nas-secret` in `kopiur-system` (the 1Password item is still called
`volsync-template`). `credentialProjection.allowed: true`, so a policy in any namespace can
authenticate without the secret being copied into git. `kopia.omux.io` serves a read-only web UI over
the same repository, which is the easiest way to browse snapshots.

An app opts in by adding `components/kopiur` to its ks.yaml. Snapshots run hourly (`H * * * *`) with
retention 3 latest / 24 hourly / 7 daily / 4 weekly.

Two snapshot identities live in the repository, because VolSync wrote to it first:

| Era | username | hostname | sourcePath |
| --- | --- | --- | --- |
| Kopiur | `<app>` | `<namespace>` | `/pvc/<app>` |
| VolSync | `<app>` | `<namespace>` | `/data` |

Kopiur cannot adopt the VolSync ones because the path is not overridable, so they sit as
`Discovered` records. They are still restorable by naming `source.identity` explicitly on a Restore.

**The mover UID has to match the UID that owns the files.** It is set explicitly per app via
`KOPIUR_MOVER_UID`/`_GID`/`_FSGROUP`, **defaulting to 568** because that is what nearly every workload
here runs as. The exceptions override it: `paperless` and `databasus` both use 1000. Apps that back up
successfully on a mismatched UID do so because their files happen to be world-readable, which is luck
rather than design - navidrome was fine for months and then failed the moment it wrote a 0600 cache
file. When adding an app, check its `runAsUser` against the default rather than assuming.

Do not switch the component to inheriting the workload identity. That mints a *privileged* mover for
any app running as root (paperless does), which Kopiur refuses unless the whole namespace opts in.

**To stop an app being snapshotted, set `KOPIUR_SUSPEND: "true"` - do not remove the component.** The
PVC is defined by `components/kopiur` and carries an immutable `dataSourceRef`, so dropping the
component prunes the volume rather than just stopping the backups.

A failed snapshot is silent. `kubectl get snapshot -A --field-selector=status.phase=Failed`.

## Conventions that bite

These are drawn from `.claude/rules/`, which is the tracked source of truth for agent guidance.
`.cursor/` no longer exists and `.claude/` is no longer gitignored, so rules, skills, agents and
hooks are all checked in and shared rather than living on one machine.

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
- **A major upgrade can change a default that nothing in this repo sets.** external-dns v0.22.0 moved
  the default annotation prefix to `external-dns.kubernetes.io/` with no fallback, so every
  `external-dns.alpha.kubernetes.io/` annotation here was ignored and `--policy=sync` deleted the
  records. The Cloudflare instance failed loudly; the UniFi one reported "All records are already up
  to date" while removing them. Both now pin `--annotation-prefix` explicitly. When a chart or image
  bump is flagged breaking, read the release notes for changed *defaults*, not just removed keys.

### Language and commits

British English, no Oxford comma. **No emojis and no em dashes anywhere** - not in code, comments,
commit messages, docs or chat. Use a hyphen or rephrase.

Commits are Conventional Commits, single line, imperative, lowercase, no trailing full stop, and
**no body or footer** (no `Co-authored-by`):

```
fix(hoarder): pull alpine-chrome from docker hub as gcr project lost billing
```

## Porting from upstream

When lifting config from other repos, check for non-transferrable values, these examples always need remapping:

| Upstream | Here |
| --- | --- |
| `./kubernetes/apps/<ns>/...` | `./clusters/aeon/apps/<group>/...` or `./infrastructure/controllers/<ns>/...` |
| `components/alerts` | `components/namespace` |
| `k13.dev` | `omux.io` |
| `tank.internal` | `tank.lan` |
| `/mnt/tank/media` | `/mnt/tank/Media` (capital M) |
| `America/Chicago` | `Europe/London` |
| `onepassword-personal` | `onepassword-connect` |
| `openebs` in `openebs-system` | `openebs` in `storage` |
| `snapshot-controller` in `kube-system` | `snapshot-controller` in `storage` |

Upstream uses a `namespace.yaml` with `name: _` as a placeholder. **Keep the file, but use the real
namespace name.** `components/namespace` no longer creates the Namespace - it carries only the Flux
`Alert` and `Provider` wiring - so every directory under `infrastructure/controllers/` and every app
group under `clusters/aeon/apps/` needs its own `namespace.yaml` listed in `resources`. Kustomize
rewrites `metadata.name` on a Namespace unconditionally, so `_` and the real name render identically;
the real name is used here because it is greppable and a build that lost its `namespace:` field would
emit an invalid object rather than a silently wrong one.

**Do not port the hardened security context blindly.** Some images manage their own users and must
start as root: `databasus` bundles PostgreSQL, creates a `postgres` and a `databasus` user, chowns
their trees and drops privileges with `gosu`. Applying `runAsUser: 1000` plus `drop: [ALL]` to such an
image means it never starts. Read the image's entrypoint before copying a `securityContext`.

**Verify NFS paths against the server, not the manifest.** `showmount -e tank.lan` lists the real
exports. A path that merely looks plausible fails at mount time with `No such file or directory`, and
the share must also be exported to all three node IPs. Note the exports map every client identity to a
single UID, so an app that chowns its own data directory cannot use an NFS mount at that path unless
the share is owned by the UID the app expects.

Finish with a grep for leftovers and a `kubectl kustomize` build.

## Renovate

Config is `.renovaterc.json5` plus `.renovate/*.json5`, extending the shared
`home-operations/renovate-presets`. `automerge` is `false` on every rule - nothing reaches the
cluster without a human merge. `minimumReleaseAge` is set but `internalChecksFilter` is
deliberately `none`: most images here live on GHCR and quay without a creation timestamp, so a
strict filter would hold them back permanently rather than for 14 days.
