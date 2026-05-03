---
name: context-manager
description: Design context-management systems for AI-powered products — RAG, vector stores, knowledge graphs, episodic/semantic memory, multi-agent context handoff. Use when architecting AI features that need long-running or cross-session memory. Not for conversational context inside Cursor itself (handled by built-in compaction).
disable-model-invocation: true
---

# Context Manager

> Cursor has built-in context compaction (`preCompact` hook) and the `explore` subagent for codebase context. This skill is about **building context systems for your own AI products**, not about managing Cursor's own context window.

Design context systems that are relevant, fresh, auditable, and cost-aware.

## Memory taxonomy

| Type | Purpose | Typical store |
| --- | --- | --- |
| Working memory | Current turn / session | LLM context window |
| Episodic | Past interactions with this user | Vector + metadata store |
| Semantic | General facts / domain knowledge | Vector + keyword + KG |
| Procedural | How-to patterns / tools | Structured definitions |

## Design axes

1. **Relevance** — retrieval precision > recall for LLMs; rank ruthlessly.
2. **Freshness** — stale context poisons answers; track write time and TTL.
3. **Tenancy** — multi-tenant isolation at retrieval, not just storage.
4. **Compliance** — PII classification, audit of which context produced which answer.
5. **Cost** — token cost of every retrieved chunk; measure the marginal value.

## Response workflow

1. **Requirements** — what does the AI feature need to remember, about whom, for how long?
2. **Architecture** — pick stores (vector, KG, SQL, object), integration surface, caching layer.
3. **Dynamic assembly** — given a query, how is the context pack built? Rules + retrieval + reranker.
4. **Optimise** — compression / summarisation, dedup, hierarchical retrieval.
5. **Integrate** — clean API surface between retrieval and generation.
6. **Measure** — relevance @ k, answer quality with/without retrieved chunks, cost per query.
7. **Iterate** — A/B different retrievers, chunk sizes, rerankers.
8. **Scale** — sharding, read replicas, async indexing.
9. **Document** — data flow, lineage, retention, compliance.
10. **Evolve** — retire stale sources; update as the product learns.

## Enterprise considerations

- Multi-tenant isolation at the query level (tenant ID in every filter).
- Source integrations: Confluence, SharePoint, Notion, Drive; respect source-level ACLs.
- Lifecycle: archival, deletion on user request (GDPR / right to erasure).
- Audit trail: every answer links back to the chunks that produced it.

## Anti-patterns

- "Throw everything into the vector store and hope."
- Reranking every query with an expensive cross-encoder when a cheap filter would suffice.
- Ignoring recency — old wiki pages beating out current docs.
- Caching without an invalidation strategy.

## Constraints

- Never bypass source ACLs when indexing.
- Never mix tenants' data in the same retrieval namespace without hard filters.
- Never claim a context improvement without a quality-metric delta.
