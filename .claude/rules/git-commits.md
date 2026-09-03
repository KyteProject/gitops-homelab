
# Git commit messages

Use Conventional Commits, single line only:

```
<type>[optional scope]: <description>
```

- Imperative mood, lowercase description, English-GB spelling.
- The body and footer fields from the spec are deliberately not used.
- Scope is optional, in parens (`feat(api):`, `fix(events):`, `docs(adr):`).
  Skip the scope if the change is cross-cutting.
- No trailing full stop.

## Allowed types

| Type | When to use |
| --- | --- |
| `feat` | new user-visible feature |
| `fix` | bug fix |
| `docs` | documentation only |
| `style` | formatting / whitespace, no code-meaning change |
| `refactor` | restructure with no behaviour change |
| `perf` | performance improvement |
| `test` | adding or refining tests |
| `build` | build system, deployment artefacts, dependencies |
| `ci` | CI workflow / pipeline changes |
| `chore` | tooling, config, repo hygiene |
| `revert` | revert of a prior commit |

## Examples

```
feat(api): add /healthz endpoint
fix(events): drop publish after bus drain
docs: add contributing guide
ci: add goose-up idempotence assertion
build: add docker, compose, and helm deployment artefacts
chore: scaffold round 1 build skeleton
```

## Anti-examples

```
Add new endpoint                ← no type prefix
feat: Added new endpoint.       ← past tense, capitalised, trailing dot
feat: add /healthz endpoint     ← do not append a body or footer (e.g.
                                  Co-authored-by) below the subject line
```
