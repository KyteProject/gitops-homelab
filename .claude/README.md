# `.claude/` - Claude Code configuration

Agent configuration for this repository: rules, skills, subagents and hooks. This directory is
checked in, so everything here is shared rather than local to one machine.

It began as a port of a `.cursor/` tree. That tree has since been deleted and this is now the only
copy, so there is nothing to keep in sync by hand any more.

- **Rules** in `.claude/rules/*.md` (path-scoped via `paths:` frontmatter)
- **Skills** in `.claude/skills/<name>/SKILL.md`
- **Subagents** in `.claude/agents/<name>.md`
- **Hooks** wired in `.claude/settings.json`, scripts in `.claude/hooks/`

Logs and state are already excluded: `.claude/hooks/.gitignore` covers `state/` and `*.log`, and
`settings.local.json` is excluded globally.

## Choosing the right primitive

| Primitive | When to reach for it |
| --- | --- |
| **Rule** (`rules/`) | Stable conventions tied to file paths, or an always-on baseline. Loaded automatically. |
| **Skill** (`skills/`) | Single-purpose, repeatable workflow, invoked by Claude or via `/<name>`. Long reference content stays in a supporting file and only loads when used. |
| **Subagent** (`agents/`) | Genuine context isolation: long research, parallel workstreams, heavy output, independent verification. |
| **Hook** (`hooks/`) | Deterministic enforcement: format on save, deny secret reads, guard destructive shell commands, audit subagent runs. |

## Skills (`skills/`)

Invocable as `/<name>`, or auto-loaded when the description matches the request.

| Skill | Purpose |
| --- | --- |
| `add-app` | Scaffold a new app-template application into `clusters/aeon/apps/<group>/` |
| `port-upstream` | Remap config copied from `buroa/k8s-gitops` onto this repo's layout and conventions |
| `upgrade-app` | Move an app to a new image or chart version, checking for breaking changes first |
| `lint` | Structural checks: broken references, wrong component paths, unsubstituted variables, convention drift |
| `cluster-debug` | Walk the Flux chain from events down to pod logs, and propose a fix that goes through Git |
| `kopiur-restore` | Restore a PVC from a Kopiur snapshot on the `nas` repository |
| `kubernetes-architect` | General Kubernetes platform design guidance, not repo-specific |

Two skills carry a supporting script:

- `lint/check.py` runs the mechanical checks. It shells out to `yq` because pyyaml is not installed.
- `upgrade-app/registry.sh` lists tags and resolves digests over the registry API with curl and jq,
  because `crane` is not installed here and is not in `just/resources/Brewfile`.

## Subagents (`agents/`)

Project-level subagents take priority over user-level ones. Invoke with the Agent tool or by naming
one ("use the code-reviewer subagent").

| Subagent | Purpose | Tool access |
| --- | --- | --- |
| `code-reviewer` | Comprehensive post-change review | Read, Grep, Glob, Bash |
| `architect-reviewer` | Structural and architectural consistency | Read, Grep, Glob, Bash |
| `security-auditor` | Threat modelling and vulnerability identification | Read, Grep, Glob, Bash |
| `debugger` | Root-cause analysis and minimal fixes | all, including Edit |
| `devops-incident-responder` | Forensic technical incident response | all |

Read-only intent is expressed through the `tools:` allowlist: an agent that lists only Read, Grep,
Glob and Bash cannot Edit or Write.

## Rules (`rules/`)

Files without `paths:` frontmatter load every session. Files with `paths:` lazy-load when Claude
reads a matching file.

**Always-on**

- `all.md` - project-wide don'ts, chiefly do not start services.
- `code-quality.md` - behavioural guardrails: verify before asserting, stay in scope.
- `language.md` - English-GB, tone, and the no-emoji / no-em-dash rule.
- `git-commits.md` - Conventional Commits, single line, lowercase, no body or footer.
- `shell-and-verification.md` - zsh pitfalls, explicit staging, verify-before-landing.

**Path-scoped**

- `sec-audit-backend.md` - scoped to `internal/**/*.go`. There is no Go in this repository, so it
  never fires. Kept in case application code is ever added.

## Hooks (`settings.json` + `hooks/`)

| Event | Script | Purpose |
| --- | --- | --- |
| `SessionStart` | `session-init.sh` | Print a stack summary and pointers to skills, agents and rules. Stdout is added to context. |
| `PreToolUse` (`Read\|Edit\|Write`) | `block-secrets.sh` | Deny access to files matching a secret-file pattern. Exit 2 plus stderr blocks and the message reaches Claude. |
| `PreToolUse` (`Bash`) | `guard-shell.sh` | Hard-deny catastrophic commands; escalate risky ones to a permission prompt via `hookSpecificOutput.permissionDecision: "ask"`. |
| `PostToolUse` (`Edit\|Write`) | `format.sh` | Run a language-appropriate formatter on the edited file. Fails open; errors go to `hooks/format.log`. |
| `SubagentStop` | `audit-subagent.sh` | Append one JSON line per subagent completion to `hooks/state/subagent-audit.jsonl`. Observability only, never blocks. |

Two details in `block-secrets.sh` are load-bearing and were both fixes to a hook that used to get
this backwards:

- Its secret-file pattern is **anchored** as `(^|[/._-])secrets?\.(yaml|...)$`, so `secrets.yaml` and
  `app-secret.yaml` are blocked while `externalsecret.yaml` is not. Every ExternalSecret in this repo
  holds vault key references and Go templates, never secret material; an unanchored pattern matched
  all 40 of them and blocked nothing that mattered.
- It explicitly lists `(^|/)kubeconfig$` and `(^|/)talosconfig$`, because this repo keeps a live
  cluster admin kubeconfig at `infrastructure/kubeconfig` and Talos client certs at
  `talos/talosconfig`, neither of which the usual `\.kube/config$` pattern catches.

## Extending

- New skill: `mkdir -p .claude/skills/<name>` and write `SKILL.md`. Frontmatter needs `name` and
  `description`; `argument-hint` is useful for a `/<name>` invocation.
- New subagent: write `.claude/agents/<name>.md` with `name` and `description`. Add `tools:` to
  constrain scope, `model:` to pin a model.
- New rule: drop a `.md` file in `.claude/rules/`. Add `paths:` to scope it, omit for always-on.
- New hook: edit `.claude/settings.json` and drop the script in `.claude/hooks/`, then `chmod +x`.
  Verify with `/hooks` in a session.

Plugin-supplied and bundled skills coexist with these by name; where a name collides, the project
version wins.
