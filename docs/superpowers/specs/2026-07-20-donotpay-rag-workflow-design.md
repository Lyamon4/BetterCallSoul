# BetterCallSaul — action workflow and Kazakhstan legal RAG

**Date:** 2026-07-20  
**Status:** Approved architecture, storage, and product flow  
**Supabase target:** existing empty project `Lyamon4's Project`  
**Jurisdiction:** Republic of Kazakhstan  
**Scope:** all five working case categories

## 1. Problem

The current document flow can present a deterministic fallback template as a completed legal claim. A short user sentence is copied into the facts section, two generic demands are appended, unresolved fields are summarized as a number, and the user can still export the document. This produces a polished-looking but substantively weak result.

The new product must behave like an action-oriented consumer assistant:

1. collect the facts required for the selected problem;
2. ask only the missing questions;
3. retrieve applicable and current Kazakhstan legal provisions;
4. explain the proposed strategy and its sources;
5. block a “ready” state until required facts and citations pass validation;
6. create a complete, editable document;
7. hand the user to a real delivery channel and track the response deadline.

The design may reproduce useful product mechanics associated with DoNotPay, but it must not copy DoNotPay branding, proprietary text, artwork, or interface trade dress.

## 2. Product promise

> Describe the problem → prove the facts → see the legal basis → approve the case → send the document → track the response.

The value is not a letter preview. BetterCallSaul assembles a case and moves it toward a concrete action.

## 3. Supported categories

The same workflow engine supports five category-specific playbooks.

### 3.1 Disputed charge

Required facts include the merchant or payment recipient, amount, date, payment method, whether the payment was authorized, previous contact with the merchant or bank, and the requested remedy.

Primary source families:

- Law of the Republic of Kazakhstan “On Payments and Payment Systems”;
- payment-card rules and applicable National Bank acts;
- Consumer Protection Law where the underlying merchant relationship is a consumer transaction;
- Civil Code provisions applicable to the underlying obligation.

### 3.2 Fine appeal

Required facts include the issuing authority, decision or prescription number, date of receipt, amount, alleged violation, appeal ground, evidence, and deadline status.

Primary source families:

- Code of Administrative Offences;
- Administrative Procedural and Process-Related Code where applicable;
- official eGov/eOtinish submission instructions;
- category-specific acts identified from the issuing authority and violation type.

### 3.3 Subscription cancellation and renewal dispute

Required facts include the service, renewal amount and date, consent or renewal disclosure, cancellation attempt, post-renewal use, merchant response, and requested cancellation/refund.

Primary source families:

- Consumer Protection Law;
- Civil Code contract and paid-services provisions;
- payments legislation when a debit is disputed;
- user-provided merchant terms, treated as evidence rather than legislation.

### 3.4 Product problem

Required facts include the seller, item, purchase date, price, defect, discovery date, warranty information, attempted resolution, evidence, and desired remedy.

Primary source families:

- Consumer Protection Law;
- Civil Code sale-of-goods provisions;
- official government consumer guidance;
- category-specific safety or warranty acts only when identified and verified.

### 3.5 Inflated bill

Required facts include the provider, billing period, invoice or account number, total, disputed line, expected amount, tariff or meter evidence, previous bills, and provider response.

Primary source families:

- Consumer Protection Law;
- Civil Code provisions;
- utility-service, communications, medical, or other sector rules selected from the provider and service type;
- natural-monopoly and tariff acts where applicable.

## 4. Official source registry

The initial ingestion registry is curated and reviewable. It contains only official sources, including:

- Consumer Protection Law: `https://adilet.zan.kz/rus/docs/Z100000274_`
- Civil Code, Special Part: `https://www.adilet.zan.kz/rus/docs/K990000409_`
- Law “On Payments and Payment Systems”: `https://adilet.zan.kz/rus/docs/Z1600000011`
- Payment-card rules: `https://www.adilet.zan.kz/rus/docs/V1600014299`
- Code of Administrative Offences: `https://www.adilet.zan.kz/rus/docs/K1400000235/k14235.htm`
- Administrative Procedural and Process-Related Code: `https://adilet.zan.kz/rus/docs/K2000000350`
- eGov electronic appeals guidance: `https://egov.kz/cms/ru/services/e_app?mobile=no`
- official Consumer Protection Committee guidance on e-Tutynushy and eOtinish: `https://www.gov.kz/memleket/entities/mti-kzpp/press/news/details/678401?lang=ru`

Sectoral and territorial acts are added to the registry only after their jurisdiction, status, and effective dates are verified. Search-engine snippets and third-party legal summaries are never stored as legal authority.

## 5. System architecture

### 5.1 Components

1. **Native iOS application** — intake, evidence review, structured interview, strategy review, document editing, delivery handoff, and local resilience.
2. **FastAPI backend** — authentication verification, workflow orchestration, retrieval, model calls, citation validation, and stable versioned APIs.
3. **Supabase PostgreSQL** — authenticated cases, documents, legal-source versions, chunks, embeddings, ingestion audit, and retrieval audit.
4. **Ingestion worker** — fetches allowlisted official sources, records immutable source snapshots, parses provisions, chunks text, creates embeddings, and activates a revision only after validation.
5. **Gemini** — visual evidence analysis and `gemini-embedding-2` embeddings. Raw visual evidence is never sent to DeepSeek.
6. **DeepSeek** — structured case analysis and document generation using user-confirmed facts plus retrieved legal chunks.

### 5.2 Runtime data flow

1. The iOS app creates a case and gathers a narrative and evidence.
2. A photo or PDF may be sent to Gemini for visual analysis but is not persisted by BetterCallSaul or inserted into the RAG corpus.
3. The user reviews extracted fields.
4. The backend builds a category-specific completeness checklist.
5. Missing facts become a maximum of five questions at a time.
6. Confirmed fields are converted into a legal-retrieval query.
7. Gemini produces a 768-dimensional query embedding.
8. Supabase performs filtered hybrid retrieval over effective legal revisions.
9. DeepSeek receives only confirmed text, question answers, and retrieved chunks.
10. DeepSeek returns strict structured JSON containing source chunk IDs for every legal proposition.
11. The backend validates completeness, citations, effective dates, and traceability.
12. The iOS app shows the strategy, sources, remaining risks, and a case-completeness gate.
13. After user approval, the backend produces a document with a frozen source manifest.
14. The app renders the PDF and opens an appropriate delivery route.
15. A confirmed delivery event starts response tracking.

## 6. Supabase design

### 6.1 Extensions and schemas

- Enable `vector` in the `extensions` schema.
- Use a private `rag` schema for sources, provisions, chunks, ingestion, retrieval functions, and audit data.
- Use `public` for user-scoped cases and generated documents so Supabase RLS can enforce ownership through the Data API.
- Do not expose private RAG tables through the Data API.
- Explicitly grant only required privileges on user tables and enable RLS before any Data API access.

### 6.2 Legal corpus tables

#### `rag.legal_sources`

- identity primary key;
- stable source code;
- title, issuing authority, official URL, jurisdiction, language, and document type;
- adoption date and source metadata;
- allowlist and active flags.

#### `rag.legal_revisions`

- source foreign key;
- official revision identifier where available;
- effective-from and effective-to dates;
- fetched-at timestamp;
- raw-content checksum;
- parser version;
- immutable snapshot location or normalized source text;
- status: staged, validated, active, superseded, rejected.

Only one active revision may cover a given effective interval for the same source.

#### `rag.legal_provisions`

- revision foreign key;
- article, paragraph, and subparagraph identifiers;
- heading, hierarchy path, normalized text, and source anchor;
- category and sector tags;
- generated Russian `tsvector` search column;
- content checksum.

#### `rag.legal_chunks`

- provision foreign key;
- sequence number, content, token count, and contextual heading;
- `extensions.vector(768)` embedding;
- embedding model and version;
- metadata required for filtered retrieval.

Indexes include foreign-key B-trees, a GIN full-text index, category/effective-date composite indexes, and an HNSW cosine index. Retrieval filters are pushed into the SQL function instead of being applied after the result limit.

#### `rag.ingestion_runs`

- source, start/end timestamps, status, parser and embedding versions;
- fetched checksum, revision counts, provision/chunk counts;
- validation errors and operator notes.

The last validated active revision remains available when an update fails.

### 6.3 Application tables

#### `public.cases`

- owner ID from Supabase Auth;
- category, status, narrative, structured confirmed fields, and completeness state;
- created, updated, next-action, and response-deadline timestamps.

#### `public.case_answers`

- case foreign key, stable question ID, value, provenance, confirmation state, and timestamps.

#### `public.case_evidence`

- case foreign key and local evidence metadata only;
- extracted text, reviewed fields, checksum, and analyzer metadata;
- no required persistent binary column.

#### `public.case_strategies`

- case foreign key, revision, summary, proposed action, warnings, completeness report, and retrieved-source manifest.

#### `public.generated_documents`

- case foreign key, revision, structured sections, rendered text checksum, status, and source-manifest checksum.

#### `public.document_citations`

- document foreign key;
- legal chunk and provision foreign keys;
- supported proposition, display label, and official source URL.

#### `public.case_events`

- case foreign key, event type, confirmed timestamp, delivery method, evidence of delivery, and actor.

### 6.4 Access control

- The iOS client never receives the Supabase service-role key.
- Gemini and DeepSeek secrets live only in backend environment variables or a protected secret store.
- Supabase Auth provides an anonymous or normal user session, and the backend verifies its JWT.
- FastAPI performs user-data operations through Supabase with the caller’s JWT, so RLS remains active; it never substitutes the service role for owner-scoped queries.
- Case tables enforce owner-scoped RLS using `(select auth.uid()) = owner_id` with indexed owner columns.
- The server-side secret is restricted to corpus ingestion and private retrieval operations.
- Corpus reads occur through narrowly scoped backend retrieval functions.
- Security-definer functions are avoided by default. Any justified use belongs in a non-exposed schema, has an explicit identity check, a fixed empty search path, and revoked public execution.
- Logs never include raw evidence, API secrets, full identity data, or complete legal narratives.

## 7. Retrieval and generation

### 7.1 Query construction

The backend builds a query from:

- case category and sector;
- confirmed facts;
- disputed act or transaction;
- requested remedy;
- authority or counterparty type;
- event and receipt dates;
- unresolved facts that affect legal applicability.

The query does not include binary evidence.

### 7.2 Hybrid retrieval

The SQL retrieval function:

1. filters to Kazakhstan, requested language, category/sector, and a revision effective on the relevant date;
2. ranks Russian full-text matches;
3. ranks 768-dimensional cosine matches;
4. combines both rankings using reciprocal-rank fusion;
5. diversifies results across provisions and sources;
6. returns a bounded set of chunks with stable IDs and official metadata.

The initial target is 8–12 chunks. Thresholds are calibrated against an evaluation set rather than hardcoded from intuition.

### 7.3 Structured DeepSeek output

Analysis and document calls use provider JSON output and typed schemas. Generated structures include:

- case summary;
- recommended route and alternatives;
- missing questions;
- warnings and deadline risks;
- facts with provenance;
- demands;
- legal propositions with retrieved chunk IDs;
- recipient and delivery route;
- response period only when supported by a retrieved source or selected official process.

### 7.4 Citation validator

A generated result is rejected unless:

- every cited chunk was present in the retrieval context;
- the provision was effective on the relevant date;
- the official URL and source identity match the database;
- cited text supports the generated proposition;
- no unsupported article number or deadline appears;
- facts trace to confirmed fields, evidence text, or user answers.

One constrained repair attempt may remove or correct unsupported content. After that, the workflow returns to review and does not mark the document ready.

## 8. Product flow

### 8.1 Step 1 — Situation

The user selects a category, describes the problem, and adds optional evidence. The screen explains what evidence will strengthen the chosen category.

### 8.2 Step 2 — Adaptive interview

The app asks only missing playbook facts, at most five at once. Questions prefer choices, dates, amounts, and short values. Every sensitive question explains why it is needed.

### 8.3 Step 3 — Strategy and legal basis

The user sees:

- a plain-language issue summary;
- the recommended action;
- alternative routes;
- deadline risks;
- applicable official sources with provision labels, revision dates, and links;
- facts that would strengthen or weaken the position.

The screen never promises success.

### 8.4 Step 4 — Case completeness gate

Instead of “two places require attention,” the app displays a concrete checklist for recipient, transaction or decision identifier, amount, dates, dispute ground, desired remedy, evidence, and legal basis.

Required missing items block the ready state. Optional strengthening items do not.

### 8.5 Step 5 — Document and action

The document screen leads with the outcome and delivery choice, while the full document opens in an editable reader. It provides:

- recipient and sender details;
- chronology and confirmed facts;
- legal basis with source links;
- precise demands;
- supported response deadline;
- attachments;
- signature and date;
- source manifest for auditability.

Delivery options are contextual:

- iOS Share Sheet and email;
- PDF download;
- e-Tutynushy handoff for eligible consumer disputes;
- eOtinish handoff for government bodies;
- copyable portal-ready text;
- physical mail or fax only when a real provider exists.

eOtinish submission cannot be silently automated because the official flow requires user authentication and signature. BetterCallSaul prepares the content, opens the official destination, and records delivery only after user confirmation or provider proof.

### 8.6 Tracking

After confirmed delivery, the case moves to “Ожидается ответ.” The case timeline records the exact channel, sent time, expected response point, received answer, and available escalation route.

## 9. Document design

The tiny decorative paper card is replaced by a useful document workspace:

- a concise outcome summary on the main screen;
- a full-screen editable legal document;
- expandable citations next to supported paragraphs;
- a source sheet with official URL and revision date;
- field-level edit and confirmation;
- clear blocked, draft, ready, sent, and waiting states.

The approved warm editorial BetterCallSaul visual system remains. Saul is a guide, not the primary content. The legal document and next action are visually dominant.

## 10. Failure behavior

### 10.1 Source update failure

Keep the last validated active revision, record the failed ingestion run, and display the stored revision date. Never activate a partially parsed update.

### 10.2 Retrieval below confidence threshold

Ask for a missing discriminating fact or produce a factual non-legal draft. Do not manufacture a legal basis and do not mark the document ready.

### 10.3 Citation validation failure

Run one constrained repair using the same retrieved chunks. If it still fails, return to strategy review with a direct explanation and preserve all user data.

### 10.4 Provider timeout or outage

Preserve the case and answers. A local template may organize confirmed facts, but it remains explicitly incomplete in workflow state and cannot be presented as a legally supported final claim.

### 10.5 Supabase or network outage

Save the local draft and queue synchronization. The app may continue evidence review but does not claim that legal research or server-side validation completed.

### 10.6 Delivery failure

Keep the generated document, show the failed channel, offer another route, and never mark the case sent without user confirmation or provider evidence.

## 11. API boundaries

Versioned FastAPI endpoints include:

- `POST /v1/cases`
- `POST /v1/cases/{id}/evidence-analysis`
- `POST /v1/cases/{id}/analysis`
- `PUT /v1/cases/{id}/answers`
- `POST /v1/cases/{id}/strategy`
- `POST /v1/cases/{id}/documents`
- `GET /v1/cases/{id}/documents/{document_id}`
- `POST /v1/cases/{id}/delivery-events`
- `GET /v1/cases/{id}/timeline`

Requests and responses use explicit versioned schemas. Provider wire formats never leak into the iOS domain model.

## 12. Ingestion workflow

1. Load the allowlisted source registry.
2. Fetch each official page with bounded retries and an identifiable user agent.
3. Save fetch metadata and checksum.
4. Detect an unchanged source and skip re-embedding.
5. Parse title, hierarchy, provisions, links, and revision metadata.
6. Validate minimum structure, nonempty provision IDs, URL origin, and effective dates.
7. Chunk by legal hierarchy rather than arbitrary character windows.
8. Add context containing source title, article, and heading to every chunk.
9. Batch-generate Gemini embeddings.
10. Load the staged revision transactionally.
11. Run parser and retrieval tests.
12. Activate the new revision only when validation passes.

The worker supports a manual review mode before activation. Scheduled refresh may be added with Supabase Cron after the deterministic ingestion path works.

## 13. Verification

### 13.1 Database

- migration tests for clean creation and repeatable setup;
- constraints for effective intervals, statuses, and unique source identities;
- RLS tests proving users cannot access another user’s cases;
- security and performance advisor checks after schema changes;
- query plans for hybrid retrieval and owner-scoped case queries.

### 13.2 Ingestion

- HTML fixtures for every official source shape;
- unchanged-source, changed-revision, malformed-page, partial-fetch, and rollback tests;
- deterministic article IDs and checksums;
- no activation after parser or embedding failure.

### 13.3 Retrieval evaluation

- at least ten reviewed scenarios per category, fifty total for the initial suite;
- expected source/provision sets;
- recall-at-10 and mean reciprocal rank tracking;
- zero out-of-set citation IDs;
- temporal tests proving superseded provisions are excluded for current cases and retained for historical cases.

### 13.4 Generation

- schema validation for every provider response;
- fact-provenance tests;
- unsupported article, deadline, demand, and recipient rejection tests;
- timeout and provider-outage behavior;
- golden document structures for all five playbooks.

### 13.5 iOS

- state-transition unit tests;
- category-specific adaptive-question tests;
- ready-gate tests;
- document editing and delivery handoff tests;
- UI tests for the primary inflated-bill and subscription-refund paths;
- Dynamic Type, VoiceOver, Reduce Motion, and narrow-screen checks.

### 13.6 Live smoke test

One controlled test runs through the real Supabase project, Gemini embedding call, hybrid retrieval, DeepSeek generation, citation validation, and iOS Simulator. Synthetic facts and evidence are used.

## 14. Delivery phases

### Phase 1 — Supabase and backend foundation

- repository backend structure;
- environment templates without secrets;
- Supabase schema, vector extension, RLS, and retrieval function;
- authentication verification and health endpoint.

### Phase 2 — Legal ingestion and evaluation

- official source registry;
- parsers, versioning, chunking, embeddings, staged activation;
- initial Kazakhstan corpus;
- retrieval evaluation suite.

### Phase 3 — RAG analysis and document generation

- hybrid retrieval;
- strict DeepSeek schemas;
- citation and fact validators;
- category playbooks and quality gate.

### Phase 4 — iOS workflow replacement

- adaptive interview;
- legal strategy and sources;
- concrete completeness checklist;
- full document workspace;
- contextual delivery choices and tracking.

### Phase 5 — verification and launch hardening

- security/performance advisors;
- full backend and iOS suites;
- live smoke test;
- Simulator visual QA;
- documentation and demo script.

## 15. Definition of done

- All five categories use distinct required facts and retrieval filters.
- The Supabase project contains a versioned official Kazakhstan legal corpus and real 768-dimensional embeddings.
- Hybrid retrieval returns official sources with stable provision identifiers and effective dates.
- Every legal claim in a generated document is traceable to retrieved content.
- An incomplete fallback is never presented as a completed claim.
- The user sees exactly which fields block document readiness.
- The generated document is complete, editable, and includes source links.
- Delivery status changes only after a confirmed action.
- Raw evidence is never sent to DeepSeek or stored in the RAG corpus.
- API and service-role secrets are absent from the iOS bundle and repository.
- Supabase advisors have no unresolved critical security findings.
- Backend, retrieval, ingestion, and iOS test suites pass.
- The complete primary flow succeeds in the iPhone Simulator against the real RAG backend.
