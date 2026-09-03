---
name: upgrade-app
description: Upgrade an app's image or chart version in this repo, checking for breaking changes before the HelmRelease is touched
argument-hint: "[group/app or namespace/app] [version] - e.g. media/sonarr 4.0.15"
---

# App Upgrade Protocol

**MISSION**: Move one app to a new image or chart version without breaking it, and know why it is
safe before pushing.

**SCOPE**: $ARGUMENTS

*Give `group/app` (a workload) or `namespace/app` (a controller). Without a version, find the latest.*

## First: is Renovate already doing this

Renovate raises a PR for nearly everything here and `automerge` is `false` on every rule, so nothing
reaches the cluster without a human merge. Check for an open PR before upgrading by hand:

```bash
gh pr list --search "<app>"
```

If a PR exists, review that instead of writing a parallel change. Its source diff will be two to
eight lines and tell you almost nothing; the **Flate** comment on the PR renders what the chart
actually produces, and that is the artifact to read. A version-only bump can render dozens of changed
hunks across a dozen objects.

Config is `.renovaterc.json5` plus `.renovate/*.json5`. `minimumReleaseAge` is 14 days and
`internalChecksFilter` is deliberately `none`, because most images here live on GHCR and quay with no
creation timestamp and a strict filter would hold them back forever rather than for two weeks.
`.renovate/groups.json5` carries version ceilings, currently `allowedVersions: "<1.37.0"` on the
Kubernetes group. Respect a ceiling; if it is stale, say why it can lift.

## Step 1: find the current version

Workloads live at `clusters/aeon/apps/<group>/<app>/app/release.yaml`; controllers at
`infrastructure/controllers/<namespace>/<app>/app/release.yaml`. The file is `release.yaml`, not
`helmrelease.yaml`.

```bash
grep -n -A3 'image:' clusters/aeon/apps/<group>/<app>/app/release.yaml
kubectl get helmrelease -n <namespace> <app> -o jsonpath='{.status.history[0]}{"\n"}'
```

Three shapes of version live in this repo:

| What | Where |
| --- | --- |
| Container image | `spec.values.controllers.<app>.containers.app.image.tag` |
| Shared app-template chart | `infrastructure/flux/repositories/oci/app-template.yaml`, currently `5.1.0`. Changing it moves every app at once |
| Per-controller chart | an `OCIRepository` or `HelmRepository` document beside that controller's own `release.yaml` |

## Step 2: find the target version

```bash
crane ls ghcr.io/<org>/<image> | grep -E '^v?[0-9]+\.[0-9]+' | sort -V | tail -5
crane digest ghcr.io/<org>/<image>:<tag>
crane ls ghcr.io/bjw-s-labs/helm/app-template | sort -V | tail -5
```

**Confirm the tag exists before committing a manifest that pins it.** A consistent reference is not
the same as a valid one.

## Step 3: read the changelog properly

Do not skip this for a patch release, and do not skim it for a major.

- Release notes and any migration guide for every version between current and target, not just the
  target. Multi-major skips are where the damage is: several apps refuse them outright, and one that
  refuses silently leaves the old pod serving while the new ReplicaSet never starts.
- Database schema migrations, config format changes, renamed or removed environment variables.
- Changed default ports and changed health endpoints.
- New writable paths, which break `readOnlyRootFilesystem: true`.
- Changed default UID, which breaks a PVC populated by the old one.

If the app refuses multi-major upgrades, **walk it one release family at a time**, verifying between
each. For a database-backed app, take a backup before each rung and confirm it completed before
moving:

```bash
kubectl get backup -n database --sort-by=.metadata.creationTimestamp | tail -3
```

## Step 4: edit the HelmRelease

```yaml
image:
  repository: ghcr.io/example/app
  tag: 1.2.3@sha256:<digest>
```

About half the images here carry a digest and half do not. Either is acceptable; Renovate adds the
digest on its next pass. What is not acceptable is `tag: latest`, which makes the running version
unreadable even when a digest pins it.

**Confirm any value key you add actually exists.** Helm silently ignores keys that do not, so a
setting can look applied for months while doing nothing:

```bash
helm show values oci://ghcr.io/bjw-s-labs/helm/app-template --version 5.1.0 | grep -n '<key>'
```

## Step 5: the failure modes that recur here

| Situation | What to do |
| --- | --- |
| Runs migrations on start | `strategy: Recreate`, so the old pod stops before the new one starts. An RWO PVC forces this anyway |
| Slow migration | Raise the startup probe `failureThreshold`, not the liveness timeout |
| Health endpoint moved | Check the new version's own docs. A wrong probe path means readiness never passes and the HelmRelease times out with a healthy container |
| New writable path | Add an emptyDir rather than turning off `readOnlyRootFilesystem` |
| Changed default UID | The PVC's files still belong to the old UID. Check before, not after |
| Chart moves the mover or PVC identity | `PersistentVolumeClaim.spec.dataSourceRef` is immutable once bound. Migrating a populated PVC needs scale-down, delete, repopulate |

## Step 6: commit and reconcile

Conventional Commits, single line, imperative, lowercase, no body and no footer:

```bash
git status --short                       # confirm every path about to be staged is yours
git add clusters/aeon/apps/<group>/<app>/app/release.yaml
git commit -m "chore(<app>): upgrade to <version>"
git push
```

Never `git add -A`, `git add .` or `git add <directory>`. This working tree routinely holds unrelated
in-progress work.

```bash
flux reconcile source git flux-system
flux reconcile hr <app> -n <namespace> --force
```

## Step 7: verify, and say what you verified

```bash
flux get hr <app> -n <namespace>
kubectl get pods -n <namespace> -l app.kubernetes.io/name=<app>
kubectl logs -n <namespace> -l app.kubernetes.io/name=<app> --tail=30
```

Then check the thing the upgrade could actually have broken: the app's own version endpoint, its
database schema version, the data it serves. "Pod is Running" is not verification of an upgrade that
carried a migration.

If the app has a Kopiur SnapshotPolicy, confirm the next snapshot still succeeds. An upgrade that
changes the container's UID breaks the mover's ability to read the files, and that failure is silent:

```bash
kubectl get snapshot -n <namespace> --sort-by=.metadata.creationTimestamp | tail -3
```

## Notes on this cluster

- Dormant apps, commented out in `clusters/aeon/apps/<group>/kustomization.yaml`, have no pods and no
  PVC. Upgrading one is a manifest change with no blast radius, and also with no verification
  available. Say so rather than implying it was tested.
- Moving the shared `app-template` OCIRepository tag moves every app at once. Pin one live,
  low-value, monitored app to the new version first and watch it before moving the shared tag.
- Talos and Kubernetes upgrades go through tuppr in `infrastructure/controllers/system-upgrade/`, not
  through this skill.
