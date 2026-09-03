# `.claude/` - Claude Code configuration

Companion to `.cursor/`. Same primitives, mapped onto Claude Code's surface:

- **Rules** in `.claude/rules/*.md` (path-scoped via `paths:` frontmatter)
- **Skills** in `.claude/skills/<name>/SKILL.md`
- **Subagents** in `.claude/agents/<name>.md`
- **Hooks** wired in `.claude/settings.json`, scripts in `.claude/hooks/`

The `.cursor/` tree remains the source of truth for Cursor and is kept in sync by hand. This directory exists so Claude Code sessions get the same defaults without relying on Cursor-specific filenames.

## Choosing the right primitive

| Primitive | When to reach for it |
| --- | --- |
| **Rule** (`rules/`) | Stable conventions tied to file paths or always-on baseline. Loaded automatically via `InstructionsLoaded`. |
| **Skill** (`skills/`) | Single-purpose, repeatable workflow - invoked dynamically by Claude or via `/<name>`. Long reference content stays in `references/` and only loads when used. |
| **Subagent** (`agents/`) | Genuine context-isolation needs - long research, parallel workstreams, heavy output (reviews/audits), or independent verification. |
| **Hook** (`hooks/`) | Deterministic enforcement - format on save, deny secret reads, guard destructive shell commands, audit subagent runs. |

## Subagents (`agents/`)

Project-level subagents (`.claude/agents/*.md`) get priority over user-level ones. Invoke with the Agent tool, `@<name>`, or natural-language reference ("use the code-reviewer subagent"). Frontmatter follows Claude Code's [subagent reference](https://code.claude.com/docs/en/sub-agents) - `name`, `description`, `tools`, `disallowedTools`, `model`, etc.

| Subagent | Purpose | Tool access | Model |
| --- | --- | --- | --- |
| `code-reviewer` | Comprehensive post-change review | Read, Grep, Glob, Bash | inherit |
| `architect-reviewer` | Structural / architectural consistency | Read, Grep, Glob, Bash | inherit |
| `debugger` | Root-cause analysis and minimal fixes | all (incl. Edit) | inherit |
| `security-auditor` | Threat modelling, vulnerability ID | Read, Grep, Glob, Bash | inherit |
| `qa-expert` | Test strategy, plans, release readiness | Read, Grep, Glob, Bash | inherit |
| `test-runner` | Run tests, fix failures, keep suite green | all | haiku |
| `performance-engineer` | Bottleneck investigation, RCA | Read, Grep, Glob, Bash | inherit |
| `incident-responder` | Incident Commander persona | all | inherit |
| `devops-incident-responder` | Forensic technical IR arm | all | inherit |
| `verifier` | Sceptical "is this actually done?" check | Read, Grep, Glob, Bash | haiku |

The "readonly" intent (Cursor's `readonly: true` field) is encoded in Claude Code via the `tools:` allowlist: each readonly agent lists only Read, Grep, Glob, Bash and so cannot Edit/Write. `model: fast` from Cursor maps to `model: haiku` (Haiku is the fast model in Claude Code).

## Skills (`skills/`)

Skills are invocable via `/<name>` or auto-loaded by Claude when the description matches the request. Each is a directory containing `SKILL.md` and optional supporting files (`references/`, `scripts/`, `assets/`).

The 21 skills mirror `.cursor/skills/` 1:1. The `name`/`description` frontmatter Cursor uses is already compatible with Claude Code's spec, so the SKILL.md files were copied verbatim.

| Bucket | Skills |
| --- | --- |
| Engineering consultancy | `backend-architect`, `cloud-architect`, `kubernetes-architect`, `deployment-engineer`, `database-optimizer`, `legacy-modernizer`, `dx-optimizer` |
| AI / Data | `ai-engineer`, `ml-engineer`, `data-engineer`, `data-scientist`, `prompt-engineer`, `context-manager` |
| Product / business | `product-manager`, `business-analyst` |
| Design | `ui-designer`, `ux-designer` (each carries a `references/` folder with affordance / Gestalt / UX-laws long reads) |
| Documentation | `api-documenter`, `documentation-expert`, `mermaid-expert` |
| Meta | `agent-organizer` |
| Homelab operations | `port-upstream` - remap config copied from `buroa/k8s-gitops` onto this repo's layout and conventions |

## Rules (`rules/`)

Per the [memory docs](https://code.claude.com/docs/en/memory#path-specific-rules), `.claude/rules/*.md` is a first-class location for path-scoped or always-on instructions. Files without a `paths:` frontmatter load every session; files with `paths:` lazy-load when Claude reads matching files.

**Always-on baseline** (no `paths:`)
- `all.md` - project-wide don'ts (e.g. don't start dev services).
- `code-quality.md` - short behavioural guardrails for the agent.
- `language.md` - English-GB and tone conventions.
- `git-commits.md` - Conventional Commits, single-line, lowercase, no body/footer.
- `shell-and-verification.md` - zsh pitfalls, explicit staging, and verify-before-landing checks.

**Language / framework** (path-scoped)
- `golang.md`, `go-logging.md`, `go-testing.md`, `go-grpc.md` - Go layered conventions.
- `typescript.md`, `react.md`, `react-router-v7.md`, `shadcn-ui.md` - frontend stack.
- `python.md`, `rust.md`, `protobuf.md` - other-language conventions in case they're added later.

**Data**
- `db-postgres.md` - SQL style, scoped to `db/`, `internal/db/`, `**/*.sql`.

**Security** (path-scoped)
- `sec-audit-backend.md`, `sec-audit-frontend.md` - implementation-level secure coding.

## Hooks (`settings.json` + `hooks/`)

| Event | Script | Purpose | Notes |
| --- | --- | --- | --- |
| `SessionStart` | `session-init.sh` | Print stack summary + pointers to skills/agents/rules. Stdout is added to context. | Fires on session start, resume, clear, compact. |
| `PreToolUse` (matcher: `Read\|Edit\|Write`) | `block-secrets.sh` | Deny reads/edits/writes whose `tool_input.file_path` matches a secret-file pattern. | Exit 2 + stderr blocks; message reaches Claude. |
| `PreToolUse` (matcher: `Bash`) | `guard-shell.sh` | Block catastrophic commands; escalate risky ones to a permission prompt. | Uses `hookSpecificOutput.permissionDecision: "ask"` for the escalations. |
| `PostToolUse` (matcher: `Edit\|Write`) | `format.sh` | Run a language-appropriate formatter on the edited file. | Fails open: formatter errors are logged to `.claude/hooks/format.log`. |
| `SubagentStop` | `audit-subagent.sh` | Append one JSON line per subagent completion to `.claude/hooks/state/subagent-audit.jsonl`. | Observability only; never blocks. |

State and logs (`.claude/hooks/format.log`, `.claude/hooks/state/`) should be added to `.gitignore`.

## Conversion notes (Cursor → Claude Code)

The differences that mattered when porting `.cursor/` to `.claude/`:

- **Rule frontmatter.** Cursor's `globs:` (comma-separated) became Claude Code's `paths:` (YAML list). Cursor's `alwaysApply: true` is implicit in Claude Code (no `paths:` = always-on), so it was dropped. Cursor's `description:` field on rules has no Claude Code equivalent and was dropped too - the body of each rule already explains its scope.
- **Subagent frontmatter.** Cursor's `readonly: true` is not a Claude Code field - the same intent is now expressed via `tools: Read, Grep, Glob, Bash` (no Edit, no Write). Cursor's `model: fast` became `model: haiku` (Haiku is Claude Code's fast model).
- **Hook events.** Cursor's `sessionStart`, `beforeReadFile`, `beforeShellExecution`, `afterFileEdit`, `subagentStop` map to Claude Code's `SessionStart`, `PreToolUse` (with `Read|Edit|Write` and `Bash` matchers), `PostToolUse` (`Edit|Write` matcher), and `SubagentStop` respectively.
- **Hook input/output protocol.** Cursor scripts read `.file_path` / `.command` directly off stdin and return JSON like `{"permission":"deny"}`. Claude Code wraps these as `.tool_input.file_path` / `.tool_input.command` and uses exit codes (`exit 2` to block, with stderr feedback) plus optional `hookSpecificOutput.permissionDecision` JSON. The scripts were rewritten end-to-end rather than wrapped, because the protocols are too different for a thin shim to be useful.
- **Hook environment variables.** `CURSOR_PROJECT_DIR` became `CLAUDE_PROJECT_DIR`.
- **Skills.** No translation needed. Cursor's SKILL.md frontmatter (`name`, `description`) is a strict subset of Claude Code's. Files were copied verbatim, including the `references/` subfolders.

## Extending

- New skill: `mkdir -p .claude/skills/<name> && $EDITOR .claude/skills/<name>/SKILL.md`. Frontmatter needs `description`; everything else is optional.
- New subagent: `$EDITOR .claude/agents/<name>.md` with a `name` and `description`. Add `tools:` to constrain scope, `model:` to pin to a model.
- New rule: drop a `.md` file in `.claude/rules/`. Add `paths:` to scope it; omit it for always-on.
- New hook: edit `.claude/settings.json` and drop the script in `.claude/hooks/`. Run `chmod +x` on it. Use `/hooks` in a session to verify.

The bundled skills (`/init`, `/review`, `/security-review`) and any plugin-supplied skills override or coexist with these by name; if a plugin-supplied skill shares a name with a project skill, the project version wins.
