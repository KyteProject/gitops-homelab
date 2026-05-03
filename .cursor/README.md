# .cursor/ — Agent configuration

This directory is the Cursor counterpart to `.claude/agents/`. It contains **rules**, **skills**, **subagents**, and **hooks** following the conventions in [Cursor's docs](https://cursor.com/docs/rules).

When using this as a template in a new project, cherry-pick the bits you need — each primitive is self-contained.

## Layout

```
.cursor/
├── README.md              ← this file
├── hooks.json             ← hook wiring
├── hooks/                 ← hook scripts + runtime state
├── agents/                ← subagents (context-isolated specialists)
├── skills/                ← skills (dynamic, single-purpose workflows)
└── rules/                 ← rules (persistent conventions, glob-scoped)
```

## Choosing the right primitive

| Primitive | When to reach for it |
| --- | --- |
| **Rule** | Stable conventions that apply by file type or path (language, framework, security, style). Glob-scoped or always-on. |
| **Skill** | Single-purpose, repeatable workflow — invoked dynamically by the agent or via `/name`. Good for consultative or one-shot work. |
| **Subagent** | Genuine context-isolation needs — long research, parallel workstreams, heavy output (reviews/audits), or independent verification. |
| **Hook** | Observability, policy, or automation around the agent loop (formatting, secret blocking, command gating, audit). |

## Subagents (`agents/`)

Context-isolated specialists. Invoke with `/name` or by mention.

| Subagent | Purpose | Mode |
| --- | --- | --- |
| `debugger` | Root-cause analysis and minimal-fix debugging | read/write |
| `code-reviewer` | Comprehensive post-change review with prioritised findings | readonly |
| `security-auditor` | Threat modelling and vulnerability identification | readonly |
| `architect-reviewer` | Structural / architectural consistency check | readonly |
| `qa-expert` | Test strategy, test plans, release-readiness | readonly |
| `test-runner` | Run tests, analyse failures, fix them | read/write, fast model |
| `performance-engineer` | Performance investigation and optimisation | readonly |
| `incident-responder` | Incident Commander for production incidents | read/write |
| `devops-incident-responder` | Technical forensics during incidents | read/write |
| `verifier` | Sceptical validator for "done" claims | readonly, fast model |

## Skills (`skills/`)

Dynamic, single-purpose workflows. Each is a folder with `SKILL.md` and optional `references/`, `scripts/`, `assets/`.

**Engineering consultancy**
- `backend-architect` — backend system design
- `cloud-architect` — cloud infra (AWS/Azure/GCP, FinOps)
- `kubernetes-architect` — K8s platform, GitOps
- `deployment-engineer` — CI/CD, Docker, GitOps pipelines
- `database-optimizer` — query / index / schema tuning workflow
- `legacy-modernizer` — incremental modernisation, Strangler Fig
- `dx-optimizer` — developer-experience improvements

**AI / Data**
- `ai-engineer` — LLM feature design, RAG, agentic workflows
- `ml-engineer` — MLOps, training/serving pipelines
- `data-engineer` — ETL, streaming, warehouse design
- `data-scientist` — analytical SQL and insight workflows
- `prompt-engineer` — prompt design and optimisation
- `context-manager` — context systems for AI products (RAG, memory)

**Product / business**
- `product-manager` — task decomposition for AI-orchestrated work
- `business-analyst` — KPI frameworks and analytical reporting

**Design**
- `ui-designer` — sceptical visual validation (affordance/Gestalt/UX laws)
- `ux-designer` — research-to-handover user-centred design

**Documentation**
- `api-documenter` — OpenAPI, code examples, Postman
- `documentation-expert` — docs architecture and authoring
- `mermaid-expert` — diagram generation

**Meta**
- `agent-organizer` — explicit delegation plans (rarely needed; default Cursor delegation is usually enough)

## Rules (`rules/`)

Always-on or glob-scoped conventions.

**Always-on baseline**
- `all.mdc` — project-wide don'ts (e.g. don't start services)
- `code-quality.mdc` — short guardrails for the agent's behaviour
- `language.mdc` — English-GB and tone conventions

**Language / framework** (glob-scoped)
- `typescript.mdc` — TS conventions
- `react.mdc` — React 19+ conventions
- `react-router-v7.mdc` — React Router v7 Data Mode (SPA) patterns
- `shadcn-ui.mdc` — shadcn/ui + Tailwind component patterns
- `golang.mdc` — Go core conventions (style, errors, HTTP, DB, concurrency)
- `go-logging.mdc` — `slog` with explicit-DI logger wrapper
- `go-testing.mdc` — fakes + contracts + decorators (`*_test.go` only)
- `go-grpc.mdc` — gRPC server/client conventions (status codes, interceptors, streaming)
- `python.mdc` — Python conventions
- `rust.mdc` — Rust conventions
- `protobuf.mdc` — Protocol Buffers message/service conventions

**Data**
- `db-postgres.mdc` — SQL style (SQLC + Goose conventions)
- `pglite.mdc` — in-browser Postgres (PgLite) patterns

**Security** (glob-scoped)
- `sec-audit-backend.mdc` — secure backend coding conventions
- `sec-audit-frontend.mdc` — secure frontend coding conventions

## Hooks (`hooks.json` + `hooks/`)

| Event | Script | Purpose |
| --- | --- | --- |
| `sessionStart` | `session-init.sh` | Inject stack summary + pointers to skills/agents |
| `beforeReadFile` | `block-secrets.sh` | Deny reads of `.env`, keys, credentials (failClosed) |
| `beforeShellExecution` | `guard-shell.sh` | Deny catastrophic commands; ask on risky ones |
| `afterFileEdit` | `format.sh` | Run language-appropriate formatter on the edited file |
| `subagentStop` | `audit-subagent.sh` | Append one JSON line per subagent completion |

Hook runtime state is in `.cursor/hooks/state/` (audit log) and `.cursor/hooks/format.log`. Consider adding these to `.gitignore`.

## Conversion from `.claude/agents/`

The original `.claude/agents/` tree was converted following Cursor's **subagents ↔ skills ↔ rules** taxonomy:

| Claude agent | Destination | Reason |
| --- | --- | --- |
| `debugger`, `code-reviewer`, `architect-review`, `qa-expert`, `test-automator`, `performance-engineer`, `security-auditor`, `incident-responder`, `devops-incident-responder` | `agents/` | Benefit from context isolation and/or parallel execution |
| `mermaid-expert`, `api-documenter`, `prompt-engineer`, `documentation-expert`, `dx-optimizer`, `legacy-modernizer`, `backend-architect`, `cloud-architect`, `kubernetes-architect`, `deployment-engineer`, `business-analyst`, `product-manager`, `ai-engineer`, `ml-engineer`, `data-engineer`, `data-scientist`, `database-optimizer`, `ui-designer`, `ux-designer`, `agent-organizer`, `context-manager` | `skills/` | Dynamic, single-purpose or consultative workflows |
| `react-pro`, `typescript-pro`, `golang-pro`, `python-pro`, `rust-pro`, `shadcn-ui-pro`, `postgres-pro`, `backend-security-coder`, `frontend-security-coder` | `rules/` | Coding conventions best applied by file glob |

Added new:
- `verifier` subagent (recommended pattern in Cursor docs).
- `pglite.mdc` rule (distinguishing from server Postgres conventions).

Also migrated from a prior Go/React project's `rules-old/` (value proven in production):
- `go-logging.mdc` — explicit-DI slog wrapper pattern with component scoping.
- `go-testing.mdc` — fakes + contracts + decorators methodology (`*_test.go`-scoped).
- `go-grpc.mdc` — gRPC status-code mapping, interceptors, streaming, bufconn tests.
- `protobuf.mdc` — expanded Proto conventions (field numbers, reserves, versioning, `go_package`).
- `react-router-v7.mdc` — Data Mode SPA patterns (`createBrowserRouter`, loaders/actions, typing).
- Additional content folded into `golang.mdc`: richer error-handling patterns (`errors.Is`/`As`, `errgroup`, sentinel), net/http API guidance.
- Dropped as superseded: `go-api-general.mdc` (content folded), `go-database.mdc` (already covered in `golang.mdc` + `db-postgres.mdc`).

Deleted (content folded into the above):
- `clean-code.mdc` (generic — model already knows; avoid duplicating style guides per Cursor's rule guidance).
- `ui-affordance.mdc`, `ui-gestalt.mdc`, `ux-laws.mdc` (moved into `skills/ui-designer/references/` and `skills/ux-designer/references/` — too large to always-load; better surfaced through the skill).

## Design principles applied

1. **Descriptions are the interface.** Every subagent and skill has a `description` that names a concrete trigger ("Use when…"). Per Cursor docs, this is what drives delegation.
2. **Short, focused prompts.** Removed the repeated "Core Development Philosophy" boilerplate present in every Claude agent. One baseline rule, not 20 copies.
3. **Readonly where safe.** `code-reviewer`, `security-auditor`, `architect-reviewer`, `qa-expert`, `performance-engineer`, `verifier` — all readonly.
4. **Fast model for high-volume.** `test-runner` and `verifier` use `model: fast`.
5. **Progressive disclosure for skills.** Long reference material lives in `skills/<name>/references/`, not in the main `SKILL.md`.
6. **Hooks are fail-open by default.** Only `block-secrets.sh` is `failClosed: true`, because the cost of a false-allow (leaked secret) outweighs a false-deny.

## Extending

- Create new skills: put `SKILL.md` in `.cursor/skills/<name>/` with YAML frontmatter (`name`, `description`).
- Create new subagents: put a markdown file in `.cursor/agents/` with YAML frontmatter (`name`, `description`, optional `model`, `readonly`).
- Create new rules: put a `.mdc` file in `.cursor/rules/` with YAML frontmatter (`description`, optional `globs`, `alwaysApply`).
- Extend hooks: add scripts to `.cursor/hooks/`, wire in `hooks.json`.

Use the built-in skill commands `/create-skill`, `/create-subagent`, `/create-rule`, `/create-hook` as a fast path.
