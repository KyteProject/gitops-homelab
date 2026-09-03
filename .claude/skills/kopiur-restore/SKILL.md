---
name: kopiur-restore
description: Restore an app's PVC from a Kopiur snapshot on the nas repository, including pre-cutover VolSync-era snapshots
argument-hint: "[namespace/app] [offset] - e.g. tools/atuin 1"
---

# Kopiur Restore

**MISSION**: Get an app's data back from the `nas` Kopia repository, either from a recent Kopiur
snapshot or from a VolSync-era snapshot that predates the cutover.

**SCOPE**: $ARGUMENTS

*Give `namespace/app`, optionally an offset. 0 is the latest snapshot, 1 the one before it.*

This is a destructive, ordered operation. Read the whole skill before starting, and confirm with the
user before deleting or overwriting a PVC.

## What the repository looks like

One repository, `ClusterRepository/nas`: a Kopia filesystem repo on NFS at `tank.lan:/mnt/tank/kopia`,
password in `kopiur-nas-secret` in `kopiur-system`. `credentialProjection.allowed: true`, so a
Restore in any namespace can authenticate without the secret being copied into git.

Two snapshot identities live in it, because VolSync wrote to the same repository before it was
retired:

| Era | username | hostname | sourcePath |
| --- | --- | --- | --- |
| Kopiur (current) | `<app>` | `<namespace>` | `/pvc/<app>` |
| VolSync (pre-cutover) | `<app>` | `<namespace>` | `/data` |

Kopiur cannot adopt the VolSync snapshots because the path is not overridable, so they show as
`Discovered` adoption records rather than as policy snapshots. They are still restorable; you just
have to name the identity explicitly.

## Step 1: find the snapshot

```bash
kubectl get snapshot -n <namespace> -l kopiur.home-operations.com/config=<app> \
  --sort-by=.metadata.creationTimestamp | tail -10
kubectl get snapshotpolicy -n <namespace> <app> -o jsonpath='{.status.resolved.identity}{"\n"}'
```

For the VolSync-era ones, and for browsing generally, use the Kopia web UI at `kopia.omux.io`. It
mounts the same NFS repository read-only through the `kopia` HelmRelease in `kopiur-system`, which is
simpler and safer than spawning a helper pod.

Check the snapshot actually has data before restoring from it. A snapshot with zero files is worse
than no restore at all:

```bash
kubectl get snapshot -n <namespace> <name> \
  -o jsonpath='{.status.phase} files={.status.stats.filesNew} bytes={.status.stats.sizeBytes}{"\n"}'
```

## Step 2: decide where the data lands

Prefer restoring **beside** the live PVC and copying across, over overwriting in place. It costs one
extra volume and it keeps the current data recoverable if the snapshot turns out to be the wrong one.

| `spec.target` | Effect | When |
| --- | --- | --- |
| `pvc:` | Creates a new PVC with the given name, size and class | Default. Safe, side-by-side |
| `pvcRef:` | Writes into an existing PVC | Only when the live data is known bad and the user has confirmed |
| `populator: {}` | Passive source for a PVC's `dataSourceRef` | What `components/kopiur` uses on first provision |

## Step 3: write the Restore

Set `policy.onMissingSnapshot: Fail`. The default in `components/kopiur` is `Continue`, which
provisions an empty volume rather than failing, and that is exactly the behaviour you do not want
during a deliberate recovery.

From the app's own policy, an offset back:

```yaml
---
apiVersion: kopiur.home-operations.com/v1alpha1
kind: Restore
metadata:
  name: <app>-recover
  namespace: <namespace>
spec:
  credentialProjection:
    enabled: true
  policy:
    onMissingSnapshot: Fail
    waitTimeout: 10m
  source:
    fromPolicy:
      name: <app>
      offset: 1          # 0 latest, 1 previous. Or use asOf for a timestamp
  target:
    pvc:
      name: <app>-recover
      capacity: 5Gi
      storageClassName: ceph-block
      accessModes: ["ReadWriteOnce"]
  mover:
    podSecurityContext:
      runAsUser: 568     # must match the UID that owns the files
      runAsGroup: 568
      fsGroup: 568
```

From a VolSync-era snapshot, name the identity and the repository explicitly:

```yaml
spec:
  repository:
    kind: ClusterRepository
    name: nas
  source:
    identity:
      username: <app>
      hostname: <namespace>
      sourcePath: /data
      offset: 0          # or snapshotID: <id> for an exact one
```

**The mover UID has to match the UID that owns the files**, exactly as it does for snapshots. Most
apps here run as 568; the mover defaults to 1000. Getting this wrong gives `PermissionDenied` on
restore, or a restored tree the app cannot read.

## Step 4: apply and watch

```bash
kubectl apply -f restore.yaml
kubectl get restore -n <namespace> <app>-recover -w
kubectl get restore -n <namespace> <app>-recover \
  -o jsonpath='{.status.phase} {.status.resolved.resolution}{"\n"}'
```

`resolution: Snapshot` means it found one. `NoSnapshot` means the identity did not match anything;
go back to Step 1 rather than changing `onMissingSnapshot`.

```bash
kubectl logs -n <namespace> -l kopiur.home-operations.com/restore=<app>-recover --tail=50
```

## Step 5: check the data before touching the live app

```bash
just kube browse-pvc <app>-recover <namespace>
```

Confirm the file count and the shape of the tree match what you expect. Only then continue.

## Step 6: swap it in

This is the destructive part. Confirm with the user first.

```bash
# 1. Stop the app so the RWO PVC is released
flux suspend hr <app> -n <namespace>
kubectl scale -n <namespace> deployment/<app> --replicas=0
kubectl wait --for=delete pod -l app.kubernetes.io/name=<app> -n <namespace> --timeout=2m

# 2. Copy from the recovery PVC into the live one, or delete and repopulate
#    Deleting means the components/kopiur Restore repopulates on the next reconcile,
#    which pulls the *latest* snapshot, not the one you chose. If you want the older
#    one, copy rather than delete.

# 3. Start it again
flux resume hr <app> -n <namespace>
flux reconcile hr <app> -n <namespace> --force
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=<app> -n <namespace> --timeout=5m
```

`PersistentVolumeClaim.spec.dataSourceRef` is immutable once bound. If you delete the live PVC, the
one Flux recreates carries the same `dataSourceRef` pointing at the app's own Restore, so it
repopulates from the newest snapshot. That is the right behaviour for disaster recovery and the
wrong one for a point-in-time rollback.

## Step 7: take a snapshot of the restored state

```bash
kubectl get snapshot -n <namespace> -l kopiur.home-operations.com/schedule=<app> \
  --sort-by=.metadata.creationTimestamp | tail -3
```

The hourly schedule (`H * * * *`) picks it up on its own. Confirm the next one succeeds rather than
assuming it will, and delete the recovery PVC and Restore once you are satisfied.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `resolution: NoSnapshot` | Identity does not match. VolSync-era snapshots are `/data`, Kopiur's are `/pvc/<app>` | Set `source.identity` explicitly, browse the repo in the Kopia UI to confirm |
| `PermissionDenied` in the mover | Mover UID cannot read the files | Set `mover.podSecurityContext` to the app's UID |
| `PrivilegedMoverNotPermitted` | Inheriting the identity of a pod that runs as root | Set the UID explicitly rather than inheriting. Do not take the namespace-wide privilege opt-in |
| `Restore phase: Pending` forever | With `target.populator`, no PVC claims it | Give the Restore a `target.pvc` instead |
| `Multi-Attach` on the live PVC | The old pod has not terminated | Wait for deletion; force-delete only the stuck pod |
| `spec is immutable` on a PVC | `dataSourceRef` changed on a bound PVC | Scale down, delete the PVC, let Flux recreate it |
