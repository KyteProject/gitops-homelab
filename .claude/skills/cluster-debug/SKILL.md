---
name: cluster-debug
description: Investigate cluster and Flux reconciliation issues on aeon, starting from events and walking the Flux chain down to pod logs
argument-hint: "[namespace/app or issue description] - optional focus area"
---

# Cluster Debug Protocol

**MISSION**: Investigate cluster state with read-only operations, identify the root cause, and
propose a fix that goes through Git.

**SCOPE**: $ARGUMENTS

*With no argument, do a full health check.*

## Ground rules

- **Read-only by default.** `kubectl apply`, `patch`, `edit` and `delete` do not survive the next
  reconcile and they hide the real bug. Fix the manifest, commit, push, reconcile.
- The only routinely legitimate cluster-side writes are: deleting a completed Job that Helm cannot
  patch, deleting a stuck Pod, and forcing a reconcile.
- **Check whether the app is even live** before assessing blast radius. Most of `media/` and several
  of `personal/` are commented out in `clusters/aeon/apps/<group>/kustomization.yaml`. A commented-out
  app has no pods and no PVC.
- Present evidence before proposing a fix. Quote the decisive line, not the whole log.

## The reconciliation chain

Everything hangs off `infrastructure/flux/cluster/ks.yaml`:

```
GitRepository flux-system
      v
flux-repositories    ./infrastructure/flux/repositories     OCI/Helm/Git sources
      v
cluster-controllers  ./infrastructure/controllers           platform, one dir per namespace
      v
cluster-apps         ./clusters/aeon/apps                   workloads, one dir per group
      v
<app> Kustomization  -> HelmRelease -> Deployment -> Pod
```

A failure anywhere above the app takes every child with it. Walk down, not up.

## Step 1: what is broken

```bash
just flux not-ready          # every Flux object that is not Ready - start here
just flux workloads          # kustomizations and helm releases at a glance
just flux err                # controller errors
just flux warn               # Flux warning events
kubectl get events -A --sort-by='.lastTimestamp' | grep -v Normal | tail -30
```

`just` is the current runner. `task flux:not-ready` and friends still work while `.taskfiles/`
survives, but new work should use `just`.

## Step 2: sources

If several unrelated apps fail at once, suspect a source rather than the apps.

```bash
flux get sources all -A
just flux sources
kubectl logs -n flux-system -l app=source-controller --tail=100
```

Sources live in `infrastructure/flux/repositories/{oci,helm,git}`. The shared `app-template`
OCIRepository is in `flux-system` and is referenced by almost every app, so a failure there is
cluster-wide.

A `kustomize build failed: dial tcp [2606:...]:443: connect: network is unreachable` means a
manifest is fetching over the network at build time and DNS returned AAAA. The cluster has no IPv6
egress. Vendor the file instead of fetching it.

## Step 3: the Kustomization

```bash
flux get ks -A | grep -v True
just flux trace kustomization <name> flux-system
kubectl describe kustomization <name> -n flux-system
just flux diff <name> <path>        # deployed vs source
```

Common causes:

| Symptom | Cause |
| --- | --- |
| `component not found` | Component paths are relative to `spec.path`, not to the ks.yaml file. Six levels up for an app (`../../../../../../infrastructure/components/...`), four for a controller |
| `variable not set` | `postBuild.substitute.APP` missing, or a component references a var the ks does not define |
| `may not add resource with an already registered id: Namespace...` | The Namespace is being added twice, once via `namespace.yaml` and once via a component |
| `dependency not ready` | Walk the `dependsOn` chain; the named object is the real failure |
| `PersistentVolumeClaim spec is immutable` | `dataSourceRef` changed on a bound PVC. See Storage below |

## Step 4: the HelmRelease

```bash
flux get hr -A | grep -v True
kubectl describe helmrelease <app> -n <namespace>
just flux helm-debug <app> <namespace>
kubectl logs -n flux-system -l app=helm-controller --tail=100
flux reconcile hr <app> -n <namespace> --force
```

A HelmRelease timeout almost always means the Pod never became Ready, so go to Step 5 rather than
raising the timeout.

`cannot patch Job ... spec.template is immutable` means Helm is trying to update a completed Job.
Delete the Job and reset the exhausted retry count on the HelmRelease.

## Step 5: the Pod

```bash
kubectl get pods -n <namespace> -o wide
kubectl describe pod -n <namespace> <pod>
kubectl logs -n <namespace> <pod> --previous     # crashlooping
kubectl logs -n <namespace> <pod> -f
```

| Symptom | Where to look |
| --- | --- |
| CrashLoopBackOff | `--previous` logs. Then `readOnlyRootFilesystem: true` with no writable emptyDir, or a securityContext UID the image does not expect |
| Pending | `describe pod` Events. Missing PVC, or an `openebs-hostpath` PV pinned to a node that is full |
| Readiness never passes | Wrong probe path. Confirm the endpoint against the image, not against the previous version |
| Multi-Attach | An RWO PVC with `RollingUpdate`. Set `strategy: Recreate` |

## Step 6: secrets

Every secret comes from 1Password through External Secrets. There is one store,
`ClusterSecretStore/onepassword-connect`. SOPS and age are not used anywhere in this repo.

```bash
kubectl get externalsecret -A | grep -v SecretSynced
kubectl describe externalsecret -n <namespace> <name>
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets --tail=50
just kube sync-secrets       # force every ExternalSecret to resync
```

`SecretSyncedError` with `key not found` means the 1Password item or field named in `dataFrom` does
not exist. That is a vault problem, not a manifest problem.

An app whose ks.yaml lacks `dependsOn: onepassword-connect-store` in `external-secrets` can race the
store on a cold start.

## Step 7: storage and backups

```bash
kubectl get pvc -A | grep -v Bound
kubectl get volumesnapshot -A
just kube browse-pvc <claim> <namespace>     # mount a PVC in a temp container
```

Storage classes: `ceph-block` (RWO, default), `ceph-filesystem` (RWX), `openebs-hostpath`
(node-local, used by the Postgres instances).

Backups are Kopiur only. VolSync is retired and its CRDs are gone.

```bash
kubectl get snapshot -A --sort-by=.metadata.creationTimestamp | tail -20
kubectl get snapshot -A --field-selector=status.phase=Failed
kubectl get clusterrepository nas -o jsonpath='{.status.phase}{"\n"}'
kubectl get snapshotpolicy,snapshotschedule,restore -A
```

`PermissionDenied ... unable to open file` on a snapshot means the mover UID cannot read the app's
files. The mover identity is explicit per app via `KOPIUR_MOVER_UID`/`_GID`/`_FSGROUP` in the app's
ks.yaml, defaulting to **568**; `paperless` and `databasus` override to 1000. Compare the policy's
mover UID against the app's `runAsUser` - a mismatch can pass for months and then fail the first time
the app writes a `0600` file, which is how both home-assistant and navidrome broke.

```bash
kubectl get snapshotpolicy <app> -n <ns> -o jsonpath='{.spec.mover.podSecurityContext.runAsUser}'
kubectl get pods -n <ns> -l app.kubernetes.io/name=<app> -o jsonpath='{.items[0].spec.securityContext.runAsUser}'
```

Do not switch to inheriting the workload identity: that mints a privileged mover for any app running
as root, and Kopiur refuses it. To opt an app out entirely, set `KOPIUR_SUSPEND: "true"` rather than
removing the component, which would prune the PVC along with it.

## Step 8: force a reconcile

```bash
just flux sync                              # everything
flux reconcile source git flux-system
flux reconcile ks <name> -n flux-system --with-source
flux reconcile hr <app> -n <namespace> --force
```

## Step 9: reproduce the build locally

```bash
kubectl kustomize clusters/aeon/apps/<group>/<app>/app
kubectl kustomize infrastructure/controllers/<namespace>
```

This renders without `postBuild.substitute`, so `${APP}` stays literal. That is expected; you are
checking that the resources resolve and the component paths are right.

## Suspend and resume

```bash
just flux suspend <name>
just flux resume <name>
```

Never resume an object that was deliberately suspended without being told to.

## Config

`KUBECONFIG` is `infrastructure/kubeconfig` and `TALOSCONFIG` is `talos/talosconfig`. Neither is
committed. A fresh checkout needs `just talos kubeconfig` first. Note that `talosctl` silently falls
back to `~/.talos/config` when `TALOSCONFIG` points nowhere, so a working `talosctl` is not proof the
variable is right.

Nodes are `shiva`, `ifrit` and `ramuh`, all control plane.
