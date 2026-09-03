---
name: add-app
description: Scaffold a new app-template application in clusters/aeon/apps for this Flux repository
argument-hint: "[group/app] - e.g. tools/linkding"
---

# Add New Application

Scaffolds a workload into `clusters/aeon/apps/<group>/<app>/`. For a platform component
(a controller, an operator, anything the apps depend on) use `infrastructure/controllers/<namespace>/`
instead, which has the same shape but a different component path depth.

**SCOPE**: $ARGUMENTS

## Layout this repo actually uses

```
clusters/aeon/apps/<group>/
  kustomization.yaml        namespace: <group>, lists each app's ks.yaml, pulls components/namespace
  namespace.yaml            the Namespace object
  <app>/
    ks.yaml                 Flux Kustomization: path, components, dependsOn, postBuild.substitute
    app/
      kustomization.yaml
      release.yaml          the HelmRelease. Not helmrelease.yaml
      externalsecret.yaml   only if the app needs secrets
```

Groups are `home`, `media`, `personal`, `security`, `tools`. They are Kubernetes namespaces, set by
`targetNamespace` on the ks and by `namespace:` on the group kustomization. Individual manifests do
not carry `metadata.namespace`.

## Step 1: collect the details

Ask for, and confirm before writing anything:

1. App name and group
2. Image repository and tag
3. Primary service port
4. Does it need persistence, and how much
5. Does it need secrets from 1Password, and under which vault item
6. Does it need an HTTPRoute, and internal or external
7. Any `dependsOn` beyond the usual

## Step 2: find a reference config

Check [kubesearch.dev](https://kubesearch.dev/) for real HelmReleases of the same image from other
home-ops repos. Convert GitHub blob URLs to raw to read the whole file. Treat these as a source of
env vars, probe paths and volume layout, not as a template to paste.

Then read one or two neighbouring apps in the same group and match their local patterns. `media/qui`
and `personal/actual` are current and representative.

## Step 3: write `app/release.yaml`

```yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: <app>
spec:
  chartRef:
    kind: OCIRepository
    name: app-template
    namespace: flux-system
  interval: 1h
  values:
    controllers:
      <app>:
        containers:
          app:
            image:
              repository: <image-repository>
              tag: <tag>
            env:
              TZ: Europe/London
            envFrom:
              - secretRef:
                  name: "{{ .Release.Name }}-secret"
            probes:
              liveness: &probes
                enabled: true
                custom: true
                spec:
                  httpGet:
                    path: /healthz
                    port: &port <port>
                  initialDelaySeconds: 0
                  periodSeconds: 10
                  timeoutSeconds: 5
                  failureThreshold: 3
              readiness: *probes
            resources:
              requests:
                cpu: 10m
              limits:
                memory: 512Mi
            securityContext:
              allowPrivilegeEscalation: false
              readOnlyRootFilesystem: true
              capabilities: { drop: ["ALL"] }
    defaultPodOptions:
      securityContext:
        runAsNonRoot: true
        runAsUser: 568
        runAsGroup: 568
        fsGroup: 568
        fsGroupChangePolicy: OnRootMismatch
    persistence:
      config:
        existingClaim: "{{ .Release.Name }}"
    route:
      app:
        hostnames:
          - "{{ .Release.Name }}.omux.io"
        parentRefs:
          - name: envoy-internal
            namespace: networking
        rules:
          - backendRefs:
              - identifier: app
                port: *port
    service:
      app:
        ports:
          http:
            port: *port
```

Notes that matter here:

- The chart is the **shared** `app-template` OCIRepository in `flux-system`. Do not create a per-app
  `ocirepository.yaml`; the only two in the repo exist because those charts are not app-template.
- Routes are HTTPRoute through Envoy Gateway. `envoy-internal` for LAN-only, `envoy-external` for
  anything published. Default to internal and only use external when asked.
- Domain is `omux.io`. Timezone is `Europe/London`.
- `568:568` is the usual UID/GID. If the image insists on something else, say so explicitly rather
  than dropping the securityContext.
- Drop `envFrom` if there is no secret, and `persistence`/`route` if not needed.
- Renovate pins most images as `tag@sha256:...`. Committing a bare tag is acceptable; Renovate adds
  the digest on its next pass.

## Step 4: write `app/externalsecret.yaml` if needed

There is exactly one store.

```yaml
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: <app>
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword-connect
  target:
    name: <app>-secret
    template:
      data:
        SOME_KEY: "{{ .SOME_KEY }}"
  dataFrom:
    - extract:
        key: <1password-item>
```

Name the keys explicitly in `template.data` rather than relying on a bare `dataFrom` passthrough, so
the manifest documents what the app consumes. For a Postgres-backed app, copy the
`INIT_POSTGRES_*` block from `tools/windmill` or `security/authentik` and add
`- extract: { key: cloudnative-pg }`.

## Step 5: write `app/kustomization.yaml`

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ./externalsecret.yaml
  - ./release.yaml
```

List only files that exist.

## Step 6: write `ks.yaml`

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: <app>
spec:
  components:
    - ../../../../../../infrastructure/components/kopiur
  dependsOn:
    - name: onepassword-connect-store
      namespace: external-secrets
    - name: rook-ceph-cluster
      namespace: rook-ceph
  interval: 1h
  path: ./clusters/aeon/apps/<group>/<app>/app
  postBuild:
    substitute:
      APP: <app>
      KOPIUR_CAPACITY: 5Gi
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
  targetNamespace: <group>
```

- **Component paths are relative to `spec.path`, not to ks.yaml.** From
  `./clusters/aeon/apps/<group>/<app>/app` that is six levels up. Getting this wrong is the most
  common error when adding an app.
- `postBuild.substitute.APP` is the pivot. The kopiur component templates the PVC, SnapshotPolicy,
  SnapshotSchedule and Restore off `${APP}`, all named `${APP}`, so the value must match the
  `existingClaim` in the HelmRelease.
- Include `dependsOn: onepassword-connect-store` only when the app has an ExternalSecret, and
  `rook-ceph-cluster` only when it has a PVC.
- Add `../../../../../../infrastructure/components/zeroscaler` for an app that should scale to zero
  when idle. That component hardcodes `minReplicas: 0, maxReplicas: 1`.
- Backup variables, all optional: `KOPIUR_CAPACITY` (5Gi), `KOPIUR_ACCESSMODES` (ReadWriteOnce),
  `KOPIUR_STORAGECLASS` (ceph-block), `KOPIUR_SNAPSHOTCLASS` (csi-ceph-block),
  `KOPIUR_MOVER_UID`/`_GID`/`_FSGROUP` (1000).
- **If the app runs as a UID other than 1000 and writes files only it can read, set the
  `KOPIUR_MOVER_*` variables to that UID.** Otherwise the hourly snapshot fails with
  `PermissionDenied` and the failure is silent until someone reads the Snapshot status. Apps whose
  files happen to be world-readable succeed by luck.
- Omit the kopiur component entirely for a stateless app.

## Step 7: wire it into the group

Add the app to `clusters/aeon/apps/<group>/kustomization.yaml`:

```yaml
resources:
  - namespace.yaml
  - <app>/ks.yaml
```

Keep the list alphabetised. Commented-out entries are dormant apps, not mistakes; leave them alone.

## Step 8: verify

```bash
kubectl kustomize clusters/aeon/apps/<group>/<app>/app     # does it build
yq e 'true' clusters/aeon/apps/<group>/<app>/ks.yaml       # YAML syntax
crane manifest <image-repository>:<tag> > /dev/null        # does the tag exist
helm show values oci://ghcr.io/bjw-s-labs/helm/app-template --version 5.1.0   # does the key exist
```

The build renders `${APP}` literally because `postBuild` substitution happens in-cluster. That is
expected.

Confirm before committing:

1. `app/` contains only files listed in its `kustomization.yaml`, and every listed file exists
2. The component path has the right number of `../`
3. `APP` matches the `existingClaim` and the workload name
4. The image tag exists in the registry
5. No plain-text secrets

On the PR, the **Flate** workflow renders the before/after of every HelmRelease and Kustomization.
That rendered diff is the review artifact, not the source diff.
