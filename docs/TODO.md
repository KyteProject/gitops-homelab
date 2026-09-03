# Homelab TODO

## Hardware

- [ ] More RAM
- [ ] More CEPH storage
- [ ] Coral TPU's
- [ ] Node GPU's
- [ ]

## Home Automation

- [ ] [Tempest weather station](https://shop.tempest.earth/collections/uk)
- [ ] Light switches
- [ ]

## Cluster

- [ ] Setup AI/LLMs
- [ ] N8N workflows and automations
- [ ] HA Dashboard for homelab/NAS
- [ ] Documentation
- [ ] Setup music systems (navidrome, tagging, organising .etc)
- [ ]

## Upgrade backlog

Blocking / sequence-sensitive:

- [ ] **Hold #507 (Kubernetes v1.37.0).** Already merged and awaiting a Flux reconcile. No Rook release
      supports v1.37; 1.20.6 tops out at v1.36 and the running 1.19 only claims v1.30-v1.35, so we are
      already outside the supported matrix. `flux suspend ks tuppr-upgrades -n system-upgrade` stops it.
- [ ] **#495 tuppr 0.1.11 to 0.5.2** - contains "judge Job outcome by the JobFailed condition", the exact
      bug that left the upgrade controller terminally Failed for four months. Take before any k8s upgrade.

Needs work before merging:

- [ ] **#508 rook-ceph v1.19.5 to v1.20.6** - 121 rendered hunks. Removes 44 entries from the operator
      ConfigMap, taking our `cephFSKernelMountOptions`, `enableLiveness` and CSI `serviceMonitor` with them.
      Port those to the `ceph-csi-drivers` chart first. Also rewrites ~90 Ceph alert rules.
- [ ] **#512 app-template 4.6.2 to 5.1.0** - 79 hunks across 60 objects, 25 HelmReleases in one tag bump.
      Adds 23 ServiceAccounts (one per app) and flips `automountServiceAccountToken` to false. Split it:
      pin one low-value app first.
- [ ] **#516 kube-prometheus-stack 84.5.0 to 88.6.2** - four majors, and Flate rendered nothing but the
      tag, so there is no preview. Read all four upgrade notes; it carries the Prometheus Operator CRDs.
- [ ] **#517 unpoller v2.39.0 to v5.2.2** - v3 warns it may not work against UniFi 9.x or early 10.x.
      Check the controller version first.

Merge with care, one at a time:

- [ ] **#478 envoy-gateway 1.7.2 to 1.9.1** - adds a ValidatingAdmissionPolicy on Gateway API objects.
      Fronts both envoy-internal and envoy-external; confirm a route resolves straight after.
- [ ] **#479 cilium 1.19.3 to 1.20.1** - 9 new cilium-config entries, ClusterRoles rewritten, new
      cilium-operator-ztunnel Role. At-risk features checked and not in use. Do it alone.
- [ ] **#480 cert-manager v1.20.2 to v1.21.1** - removes the `cert-manager-tokenrequest` Role and
      RoleBinding. Confirm nothing uses ACME with ServiceAccount tokens.
- [ ] **#490 + #491 cloudnative-pg and barman-cloud** - operator before plugin, then verify a backup runs.

Safe:

- [ ] #345, #492, #519 - meilisearch, hoarder, immich. Apps are dormant, nothing renders. Note immich v3
      requires VectorChord and `709a7367` removed vchord from the CNPG cluster.
- [ ] #264 + #518 postgres-init 18.6 and postgres client 18 - both psql clients, not server upgrades.
- [ ] #476, #504, #505 - cloudflared, authentik, windmill. Routine.

Full assessment: https://claude.ai/code/artifact/12a61137-d45d-4d83-a6fa-b33c542e45fc

## App shortlist

- [ ] Advanture Log
- [ ] [Dawarich](https://github.com/Freika/dawarich)
- [ ] [Ghostfolio](https://github.com/ghostfolio/ghostfolio)
- [ ] Kite
- [ ] Sonarqube
- [ ] Monica
- [ ] Maloja
- [ ] Multiscrobbler
- [ ] watchstate
- [ ] [Opencloud](opencloudeu/opencloud-rolling)? or nextcloud?
- [ ] Netbox
- [ ] wikijs (or similar)
- [ ] Penpot
- [ ] Zipline
- [ ] Gitsave
- [ ] Crowdsec
- [ ] Tailscale
- [ ] Convertx
- [ ] wrtag
- [ ] [openfaas](https://www.openfaas.com/)
- [ ] [Bitfocus](https://bitfocus.io/companion)
- [ ] [Gramps](https://www.grampsweb.org/)

- Some kind of watcher/feed app that monitors all apps/controllers source control and reports the number of maintainers, when the last release was, when the last commit , number of open issues .etc. Intent is to monitor and risk assess active or inactive services, and flag if something should be replaced. This could be a single maintainer risk, unpatched security issues for too long, dead project .etc
