---
name: port-upstream
description: Adapt config copied from the buroa/k8s-gitops upstream to this repo. Use when files are pasted in from that repo and need paths, namespaces and conventions remapped.
---

# Porting from the upstream repo

Config copied across is never drop-in: the directory layout differs, and every environment-specific
value is buroa's. Work through all four sections below - partial ports fail at reconcile time, not
at review time.

## 1. Directory layout

| Upstream | Here |
| --- | --- |
| `kubernetes/apps/<ns>/` | `clusters/aeon/apps/<ns>/` (workloads) or `infrastructure/controllers/<ns>/` (platform) |
| `kubernetes/components/` | `infrastructure/components/` |
| `kubernetes/flux/cluster` | `infrastructure/flux/cluster` |

Every Flux `Kustomization.spec.path` needs rewriting. Grep for `kubernetes/apps` after any port.

**Relative paths in `spec.components` are resolved from `spec.path`, not from the file.** Count
segments from the `path` value back to the repo root. Depth often coincidentally matches upstream,
so a wrong path can still look plausible - verify with `kubectl kustomize`.

## 2. Environment values

| Setting | Upstream | Here |
| --- | --- | --- |
| Domain | `k13.dev` | `omux.io` |
| NFS server | `tank.internal` | `tank.lan` |
| Media path | `/mnt/tank/media` | `/mnt/tank/Media` (capital M) |
| Timezone | `America/Chicago` | `Europe/London` |
| Secret store | `onepassword-personal` | `onepassword-connect` |
| Gateways | varies | `envoy-internal` / `envoy-external` in `networking` |

1Password item keys differ too. `key: kopiur` upstream may need to be an existing item such as
`volsync-template` - and if the resource shares a backing store with an existing one, the password
must match or the repository will not open.

## 3. Namespaces in `dependsOn`

Upstream splits platform components into their own namespaces. Here, several live in `storage`:

- `openebs` is in **`storage`**, not `openebs-system`
- `snapshot-controller` is in **`storage`**, not `kube-system`

Confirm with `flux get ks -A` rather than trusting the upstream value.

## 4. Components and namespace creation

- Upstream has a bare `components/alerts`. Here the equivalent is **`components/namespace`**, which
  bundles both the namespace and the alert wiring.
- Upstream ships a `namespace.yaml` with `name: _` as a placeholder. Here that is **redundant** -
  `components/namespace` generates it from the kustomization's `namespace:` field. Delete it.
- `infrastructure/controllers/` has **no** aggregating `kustomization.yaml`; Flux auto-discovers
  subdirectories. Creating the directory is enough to deploy it.

## Finish with

```sh
# no upstream-isms left
grep -rnE 'kubernetes/apps|k13\.dev|tank\.internal|America/|onepassword-personal|openebs-system' <dir>

# it builds
kubectl kustomize <dir> >/dev/null && echo OK
```

Then check whether the port implies a wider migration. Upstream removing something wholesale (as
with volsync being replaced by kopiur) means the copied directory is step one of several, not a
self-contained change. Say so before landing it.
