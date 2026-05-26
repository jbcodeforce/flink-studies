# Wiki Schema

## Domain
Apache Flink streaming data infrastructure — core concepts, deployment patterns, connectors, and engineering best practices for real-time data pipelines.

## Conventions
- File names: lowercase, hyphens, no spaces (e.g., `changelog-mode.md`)
- Every wiki page starts with YAML frontmatter (defined below)
- Use `[[wikilinks]]` to link between pages (minimum 2 outbound links per page)
- When updating a page, always bump the `updated` date
- Every new page must be added to `index.md` under the correct section
- Every action must be appended to `log.md`
- **Provenance markers:** On pages that synthesize 3+ sources, append `^[raw/articles/source-file.md]` at the end of paragraphs whose claims come from a specific source. This lets a reader trace each claim back without re-reading the whole raw file. Optional on single-source pages where the `sources:` frontmatter is enough.

## Frontmatter
```yaml
---
title: Page Title
created: YYYY-MM-DD
updated: YYYY-MM-DD
type: entity | concept | comparison | query | summary
tags: [from taxonomy below]
sources: [raw/articles/source-name.md]
confidence: high | medium | low
contested: true
contradictions: [other-page-slug]
---
```

`confidence` and `contested` are optional but recommended for opinion-heavy or fast-moving topics. Lint surfaces `contested: true` and `confidence: low` pages for review so weak claims don't silently harden into accepted wiki fact.

### raw/ Frontmatter

Raw sources ALSO get a small frontmatter block so re-ingests can detect drift:

```yaml
---
source_url: https://example.com/article
ingested: YYYY-MM-DD
sha256: <hex digest of the raw content below the frontmatter>
---
```

The `sha256:` lets a future re-ingest of the same URL skip processing when content is unchanged, and flag drift when it has changed. Compute over the body only (everything after the closing `---`), not the frontmatter itself.

## Tag Taxonomy

### models
Model or version of a technology product — e.g., `flink-2.2`, `debezium-2.0`

### deployment
Deployment environment or infrastructure pattern — e.g., `kubernetes`, `docker`, `confluent-cloud`, `confluent-platform`

### connector
Data source or sink connector — e.g., `kafka`, `filesystem`, `faker`, `datagen`

### sql
Flink SQL concepts — e.g., `ddl`, `dml`, `watermark`, `changelog`

### architecture
System design patterns — e.g., `medallion`, `cdc`, `star-schema`, `event-driven`

### state
State management concepts — e.g., `backend-state`, `checkpointing`, `savepoint`

### api
Programming interface — e.g., `DataStream`, `TableAPI`, `SQL`

### schema
Schema management — e.g., `avro`, `protobuf`, `schema-evolution`

### tool
Development tool or utility — e.g., `datafaker`, `jupyter`

### performance
Performance and tuning — e.g., `partitioning`, `serialization`, `cfu`

### metadata
Metadata handling — e.g., `watermark`, `timestamp`, `partition-key`

### comparison
Side-by-side analysis

### timeline
Chronological event or chronology

### person
Person name

### company
Organization or company

### open-source
Open-source project or library

## Page Thresholds
- **Create a page** when an entity/concept appears in 2+ sources OR is central to one source
- **Add to existing page** when a source mentions something already covered
- **DON'T create a page** for passing mentions, minor details, or things outside the domain
- **Split a page** when it exceeds ~200 lines — break into sub-topics with cross-links
- **Archive a page** when its content is fully superseded — move to `_archive/`, remove from index

## Entity Pages
One page per notable entity. Include:
- Overview / what it is
- Key facts and dates
- Relationships to other entities ([[wikilinks]])
- Source references

## Concept Pages
One page per concept or topic. Include:
- Definition / explanation
- Current state of knowledge
- Open questions or debates
- Related concepts ([[wikilinks]])

## Comparison Pages
Side-by-side analyses. Include:
- What is being compared and why
- Dimensions of comparison (table format preferred)
- Verdict or synthesis
- Sources

## Update Policy
When new information conflicts with existing content:
1. Check the dates — newer sources generally supersede older ones
2. If genuinely contradictory, note both positions with dates and sources
3. Mark the contradiction in frontmatter: `contradictions: [page-name]`
4. Flag for user review in the lint report
