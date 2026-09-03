---
name: lint
description: Check this GitOps repository for broken references, wrong component paths, unsubstituted variables and convention drift
argument-hint: "[path prefix] - optional scope, e.g. clusters/aeon/apps/media"
---

# GitOps Lint Protocol

**MISSION**: Find structural problems that stop Flux reconciling, and drift from this repo's
conventions. Report only. Do not fix anything without being asked.

**SCOPE**: $ARGUMENTS

*With no argument, scan `clusters/aeon` and `infrastructure`.*

There is no manifest linter for this repo. The mechanical checks live in `check.py` beside this
file, and the judgement checks are below.

## Run the mechanical checks

From the repository root:

```bash
python3 .claude/skills/lint/check.py                      # whole repo
python3 .claude/skills/lint/check.py clusters/aeon/apps/media   # scoped
```

It needs `yq` and `python3`, both present. pyyaml is not installed on this machine, which is why the
script shells out to `yq` rather than importing yaml. It covers:

| Check | Severity | Why it matters |
| --- | --- | --- |
| `resources`/`components` entries that do not exist | CRITICAL | kustomize build fails, the whole branch of the tree stops |
| `spec.path` that does not exist | CRITICAL | usually an unported upstream ks.yaml still pointing at `kubernetes/apps/...` |
| component path that resolves nowhere | CRITICAL | component paths are relative to `spec.path`, not to ks.yaml. Six `../` for an app, four for a controller |
| `${VAR}` with no `:=default` and no `postBuild.substitute` entry | CRITICAL | Flux leaves it literal, so it lands in the object as the string `${VAR}` |
| `volsync.backube` or `${VOLSYNC_*}` | CRITICAL | VolSync is retired, the CRDs are gone, those variables are never substituted |
| `kind: Ingress` | WARNING | this cluster routes with HTTPRoute through Envoy Gateway |
| `tag: latest` | WARNING | a digest makes it immutable but the version becomes unreadable |
| HelmRelease naming a source defined nowhere | WARNING | sources live in `infrastructure/flux/repositories/` or beside the HelmRelease as a second document |
| per-app app-template `ocirepository.yaml` | WARNING | the shared one in `flux-system` is the convention |
| file in an app dir not listed in its `kustomization.yaml` | INFO | often deliberate, sometimes a forgotten wiring |

The known false-positive shape is a container command containing a runtime shell variable. The
script only flags a name that some other ks in this repo substitutes, which filters those out.

## Then check by hand

These need reading, not grepping.

### Is the app live or dormant

`clusters/aeon/apps/<group>/kustomization.yaml` switches apps on by commenting. Most of `media/` and
several of `personal/` are off. A dormant app has no pods and no PVC, so a finding against it is
housekeeping rather than an incident. Say which it is.

### Backup coverage and mover identity

An app with a PVC and no `components/kopiur` in its ks.yaml is not backed up.

An app whose pod runs as a UID other than the mover's is a silent backup failure waiting to happen.
The mover defaults to 1000; the app's `defaultPodOptions.securityContext.runAsUser` is usually 568.
It only works when the app's files are world-readable, which is luck. Compare the two and flag any
app that has a PVC, runs as non-1000, and does not set `KOPIUR_MOVER_UID`.

```bash
kubectl get snapshot -A --field-selector=status.phase=Failed
```

### dependsOn completeness

- An app with an `externalsecret.yaml` should depend on `onepassword-connect-store` in
  `external-secrets`
- An app with a PVC on `ceph-block` or `ceph-filesystem` should depend on `rook-ceph-cluster` in
  `rook-ceph`
- An app on `openebs-hostpath` should depend on `openebs` in `storage`
- An app with `INIT_POSTGRES_*` should depend on `cloudnative-pg` in `database`

Missing entries usually work, until a cold start or a controller restart reorders things.

### APP must line up

`postBuild.substitute.APP` names the PVC, the SnapshotPolicy, the SnapshotSchedule and the Restore,
all at once. It has to match the `existingClaim` in the HelmRelease. `personal/actual` uses
`APP: actual-data` with `existingClaim: "{{ .Release.Name }}-data"`, which lines up; a mismatch
leaves the app mounting a PVC nothing backs up.

### Build every namespace you touched

```bash
kubectl kustomize infrastructure/controllers/<namespace>
kubectl kustomize clusters/aeon/apps/<group>/<app>/app
```

`${APP}` stays literal here because substitution happens in-cluster. A duplicate-resource error such
as `may not add resource with an already registered id: Namespace.v1.[noGrp]/_` means the Namespace
is being added twice, once by `namespace.yaml` and once by a component.

### Fetching at build time

Anything pulling a URL during `kustomize build` is a liability: the cluster has no IPv6 egress, so
the build fails whenever DNS returns AAAA. Vendor the file and record its provenance in a header.

## Reporting

Group by severity, most severe first. For each finding give the exact path and line, one sentence on
what breaks, and the minimal fix. Do not pad the list with hypotheticals; if a check found nothing,
say so and move on.

Do not report schema-header absence as an issue. Only 25 of 453 YAML files carry a
`# yaml-language-server: $schema=` comment. That is the norm here, not drift.
