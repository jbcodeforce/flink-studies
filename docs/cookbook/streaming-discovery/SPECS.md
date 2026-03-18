# Streaming discovery webapp — product specification

**Status:** Draft  
**Methodology source:** [Flink Project Management (pm.md)](../pm.md)  
**Repository:** Intended for a separate git repository (copy this file to repo root as `SPECS.md` or keep as upstream reference).

---

## 1. Document purpose

This specification defines a web application that makes the pm.md discovery methodology **actionable**: guided workshops, captured answers, LLM-assisted follow-ups and gap detection, and exportable discovery briefs. Implementation details may evolve; this document is the **single agreed intent** before build.

---

## 2. Problem statement

Teams scoping Flink or streaming projects often walk through checklist documents ad hoc. Notes scatter across docs and chats. Important dimensions (contracts, SLAs, ownership, mesh alignment) are easy to skip. A structured session with **persistent answers** and a **facilitator copilot** improves completeness and produces one artifact for downstream design.

---

## 3. Goals and non-goals

### 3.1 Goals

- Guide facilitators through pm.md modules in a logical order with clear progress.
- Capture **draft** and **agreed** answers per question with audit context.
- Use an LLM to propose **follow-up questions**, **gaps** vs methodology, and **short summaries** without inventing project facts.
- Export a **Markdown brief** (and optionally JSON) aligned to pm.md headings.

### 3.2 Non-goals (initial releases)

- Generating production Flink SQL or Terraform.
- Replacing architecture sign-off or compliance certification.
- Full real-time collaboration (optional later).

---

## 4. Users and roles

| Role | Responsibilities |
|------|------------------|
| **Facilitator** | Creates session, selects modules, runs wizard, reviews LLM output, marks answers agreed, exports. |
| **Contributor** | Submits answers where invited; may see only assigned sections (policy-dependent). |
| **Reader** | View-only on shared session (optional). |

Authentication is required for multi-user sessions; MVP may be single-user with export.

---

## 5. Methodology mapping

The application **question catalog** MUST be derivable from pm.md. Stable `question_id` values allow versioning when the doc changes.

### 5.1 Modules

| Module ID | pm.md anchor | Description |
|-----------|--------------|-------------|
| `scope_discovery` | Scope Discovery | Project type, owners, volume, semantics. |
| `stage_sources` | Per-stage → Source of data | |
| `stage_ingestion` | Per-stage → Ingestion | |
| `stage_processing` | Per-stage → Processing | |
| `stage_serve` | Per-stage → Serve | |
| `stage_consumers` | Per-stage → Consumers | |
| `data_mesh` | Data mesh alignment | Optional track. |
| `generic_streaming` | Generic streaming review | Cross-cutting. |
| `migrating_batch` | Migrating from Batch Processing | When migration or hybrid. |
| `design_event_semantic` | Design → Event semantic | Often **per stream**. |
| `design_scalability` | Design → Scalability | Per stream or global. |
| `design_privacy` | Design → Privacy | |
| `design_data_integrity` | Design → Data Integrity | |

### 5.2 Optional entity: Stream / data product

When one workshop covers multiple pipelines, **Design** and parts of **Processing** repeat per `stream_id`. Sessions without streams use a single implicit default stream.

### 5.3 Recommended session flow (default wizard)

1. `scope_discovery`  
2. `stage_sources` → `stage_ingestion` → `stage_processing` → `stage_serve` → `stage_consumers`  
3. If enabled: `data_mesh`  
4. `generic_streaming`  
5. If enabled: `migrating_batch`  
6. For each stream: `design_*` subsections  

Facilitator may skip or reorder modules; skipped modules appear as **not covered** in export.

---

## 6. Functional requirements

### 6.1 Session management

- **FR-S1:** Create session with title, optional description, project type (greenfield | migration | extension).  
- **FR-S2:** Toggle optional tracks: data mesh, batch migration.  
- **FR-S3:** Add zero or more named streams (data products / pipelines).  
- **FR-S4:** List, open, archive sessions.

### 6.2 Questionnaire

- **FR-Q1:** Display questions from catalog with module grouping and progress indicator.  
- **FR-Q2:** Free-text answer per question; optional status: `draft` | `agreed`.  
- **FR-Q3:** Persist all answers with `question_id`, `session_id`, optional `stream_id`, timestamps, user id.  
- **FR-Q4:** Show pm.md cross-references as read-only hints (e.g. "See Design → Event semantic").

### 6.3 LLM assistance

- **FR-L1:** On user action (e.g. "Analyze answer" or section complete), send: module id, question id, question text, current answer, optional prior answers in same module (truncated if long).  
- **FR-L2:** LLM returns **structured JSON** (schema in section 10). UI displays follow-ups, gaps, summary bullet, optional risk flags.  
- **FR-L3:** Facilitator can dismiss or pin follow-ups; pinned items may become checklist items or export appendix.  
- **FR-L4:** Session-level synthesis: after selected modules complete, generate executive summary and open questions list.  
- **FR-L5:** Application usable with LLM disabled (checklist-only mode).

### 6.4 Export

- **FR-E1:** Export session to Markdown: headings mirror pm.md structure; agreed answers inline; draft answers marked or omitted (configurable).  
- **FR-E2:** Optional JSON export for tooling (same logical content).  
- **FR-E3:** Appendix: unresolved follow-ups, LLM gap list, skipped modules.

---

## 7. Non-functional requirements

| ID | Requirement |
|----|-------------|
| NFR-1 | Answers and prompts may contain sensitive data: support org policy (API region, zero-retention, self-hosted model). |
| NFR-2 | Authenticated API; session scoped to tenant or user. |
| NFR-3 | Question catalog versioned; migrations when pm.md adds or renames questions. |
| NFR-4 | Target: facilitator completes Scope + five stages in one workshop session without UI timeouts on save. |

---

## 8. Data model (logical)

```
Session
  id, title, description, project_type, flags (mesh, migration), catalog_version, created_at, updated_at

Stream (optional)
  id, session_id, name, sort_order

Answer
  id, session_id, stream_id (nullable), question_id, body (text), status (draft|agreed), updated_by, created_at, updated_at

LlmArtifact (optional audit)
  id, session_id, question_id (nullable), stream_id (nullable), response_json, model_id, created_at

FollowUp (optional)
  id, session_id, source_question_id, text, pinned (bool), resolved (bool)
```

---

## 9. API outline (REST or RPC)

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/sessions` | Create session |
| GET | `/sessions` | List |
| GET | `/sessions/:id` | Detail + answers |
| PATCH | `/sessions/:id` | Update meta, flags |
| PUT | `/sessions/:id/answers/:questionId` | Upsert answer (optional stream query param) |
| POST | `/sessions/:id/llm/analyze` | Body: question_id, answer text; returns structured LLM response |
| POST | `/sessions/:id/llm/synthesize` | Section or full session summary |
| GET | `/sessions/:id/export.md` | Markdown download |
| GET | `/catalog/questions` | Versioned question list (for client cache) |

Authorize all routes by session ownership or membership.

---

## 10. LLM contract (structured output)

The model MUST return valid JSON matching this shape (field names stable for clients):

```json
{
  "follow_up_questions": ["string"],
  "gaps": [
    { "topic": "string", "pm_reference": "string", "rationale": "string" }
  ],
  "summary_bullet": "string",
  "risk_flags": [
    { "severity": "low|medium|high", "message": "string" }
  ]
}
```

**System prompt constraints (spec):**

- Ground on the exact question text and module name from the catalog.  
- Do not fabricate organizational facts; if the answer is empty, ask clarifying questions.  
- Reference pm.md section names in `pm_reference` where applicable.

---

## 11. Question catalog artifact

Maintain `questions.yaml` (or JSON) in the application repository:

- Fields per item: `question_id`, `module_id`, `text`, `hint_links[]`, `applies_to_stream` (bool).  
- Generate or validate against pm.md in CI to reduce drift.

---

## 12. UI specification (high level)

- **Dashboard:** Sessions list, new session.  
- **Session workspace:** Left: module navigation; center: current question + answer editor; right: LLM panel (follow-ups, gaps).  
- **Export:** Button with format options.  
- **Settings:** Model selection (if allowed), redaction toggle placeholder.

Accessibility: keyboard navigation through questions; sufficient contrast for long sessions.

---

## 13. Phased delivery

| Phase | Scope |
|-------|--------|
| **P0** | Session + catalog + answers persistence + Markdown export (no LLM). |
| **P1** | LLM analyze per question + structured JSON UI + session synthesize. |
| **P2** | Streams, repeated Design per stream; optional contributor invites. |
| **P3** | JSON export, follow-up pinning, catalog sync from pm.md automation. |

---

## 14. Open decisions (edit as you refine)

- Tenant model: single-user MVP vs multi-tenant SaaS.  
- Hosting: cloud-only vs customer VPC.  
- Whether LLM calls run server-side only (recommended) or client-side with user keys.  
- Localization: English-only v1 is acceptable.

---

## 15. Traceability

| Spec section | pm.md |
|--------------|-------|
| Modules | Sections Scope Discovery through Design |
| Cross-cutting streaming | Generic streaming review, Design subsections |

End of specification.
