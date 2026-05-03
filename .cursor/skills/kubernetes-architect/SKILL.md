---
name: kubernetes-architect
description: Design Kubernetes platforms — GitOps (ArgoCD/Flux), service mesh, progressive delivery, multi-tenancy, security, and FinOps. Use for K8s architecture, GitOps implementation, platform engineering, or cloud-native platform design on EKS/AKS/GKE.
---

# Kubernetes Architect

Design Kubernetes platforms that developers want to use and operators can sleep through.

## Core tenets (OpenGitOps)

1. **Declarative** — desired state expressed in code.
2. **Versioned & immutable** — Git is the source of truth.
3. **Pulled automatically** — agents reconcile from the repo.
4. **Continuously reconciled** — drift is detected and corrected.

## Platform design areas

**Cluster topology**
- One cluster per blast-radius unit (prod / non-prod, per-region, per-tenant).
- Namespaces as soft multi-tenancy; separate clusters for hard isolation.
- Cluster API / Crossplane for fleet management.

**Delivery**
- **GitOps** with ArgoCD or Flux. App-of-apps or ApplicationSets.
- **Progressive delivery** with Argo Rollouts or Flagger (canary / blue-green / experiment).
- Policy-as-code: OPA Gatekeeper or Kyverno for admission control.

**Workloads**
- Deployments for stateless, StatefulSets with careful ordering for stateful.
- HPA + KEDA for event-driven scaling; VPA where safe.
- PodDisruptionBudgets and topology spread constraints.
- Resource requests/limits on every container (no "burstable by accident").

**Service mesh**
- Only when you need mTLS, traffic shaping, or observability across services — not by default.
- Istio / Linkerd / Cilium based on team capacity and feature needs.

**Security**
- Pod Security Standards at `restricted` for most workloads.
- NetworkPolicies deny-by-default.
- SLSA-grade build provenance, image signing (cosign), SBOM.
- Secrets from external manager (ESO, Vault, cloud native) — not plain K8s Secrets.

**Observability**
- Metrics: Prometheus + Grafana (or managed equivalent). SLOs and error budgets per service.
- Logs: structured, centralised, retention defined.
- Traces: OpenTelemetry end-to-end.

**DR & backup**
- Velero for cluster + PV backup, with restore drills on a cadence.
- etcd backups (if self-managed).

**FinOps**
- Kubecost / OpenCost for allocation by namespace/team.
- Spot/preemptible nodes for stateless workloads.
- Cluster autoscaler tuned for cost vs latency trade-off.

## Developer experience

- Platform API (CRDs / operators / Backstage) for self-service.
- Gateway API for ingress (succeeding Ingress).
- Paved-road templates for common workload types.
- Documented upgrade/rollback procedure per workload.

## Deliverables

- Reference architecture diagram.
- GitOps repo layout and promotion model.
- Security & policy baseline (PSS, NetworkPolicy, admission controllers).
- Observability baseline with example SLOs.
- Cost model and autoscaling strategy.
- Ops runbook: upgrade, rollback, DR, incident.

## Constraints

- No bespoke CRDs without justification — prefer upstream / community operators.
- No service mesh by default — only with a clear problem it solves.
- No cluster upgrades without a rehearsed rollback.
