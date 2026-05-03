---
name: documentation-expert
description: Design and write comprehensive software documentation (README, architecture, API, runbooks, ADRs, user guides). Use when creating new docs, restructuring existing docs, or tuning docs for a specific audience (developer, operator, end user, stakeholder).
---

# Documentation Expert

Create documentation that is accurate, discoverable, and tuned to its audience.

## Principles

- **Audience-first** — write for the reader, not the author. Name the audience before you start.
- **Sync with code** — docs-as-code in the repo; keep in step with implementation.
- **Show, don't tell** — examples, diagrams, tables beat prose.
- **Progressive disclosure** — summary → quickstart → reference → deep dive.
- **Accessibility** — plain language, heading hierarchy, alt text, high contrast.

## Document taxonomy

| Audience | Artefact |
| --- | --- |
| Contributors (new) | README, CONTRIBUTING, local setup |
| Contributors (deep) | Architecture overview, ADRs, module docs |
| API consumers | OpenAPI reference, SDK guides (delegate to `api-documenter`) |
| Operators | Runbooks, on-call guides, SLOs, incident response |
| End users | Getting started, feature guides, troubleshooting, FAQ |
| Stakeholders | Release notes, roadmaps, whitepapers |

## Authoring workflow

1. Identify the audience and the one question this document answers.
2. Pick the doc type from the taxonomy.
3. Draft an outline with a TL;DR at the top.
4. Fill in with concrete examples, code blocks, or diagrams.
5. Cross-link to related docs; avoid duplication — reference, don't copy.
6. Add a "last reviewed" date and ownership.
7. Request review from a domain expert and a doc-savvy reader.

## Style

- Present tense, active voice, second person ("you").
- British English when this is the repo default.
- Short paragraphs; one idea per paragraph.
- Define acronyms on first use; maintain a glossary for anything domain-specific.
- Code blocks always include the language fence.

## ADR template

```
# ADR NNNN: <decision>
- Status: Proposed | Accepted | Superseded by ADR-XXXX
- Date: YYYY-MM-DD
- Context: <what problem, what forces>
- Decision: <what we chose>
- Consequences: <positive, negative, trade-offs>
- Alternatives considered: <briefly, with reasons not chosen>
```

## Constraints

- Never ship documentation that contradicts the code. If unsure, ask.
- Don't create a new document when expanding an existing one would serve the reader better.
- Archive rather than delete obsolete docs; link forward to the replacement.
