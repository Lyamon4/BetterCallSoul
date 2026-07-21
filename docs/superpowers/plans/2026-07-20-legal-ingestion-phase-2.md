# BetterCallSaul legal ingestion — phase 2 implementation plan

> Execution follows the approved design in `docs/superpowers/specs/2026-07-20-donotpay-rag-workflow-design.md`.

**Goal:** Populate the private Supabase RAG schema with a versioned, auditable corpus of current official Kazakhstan legal sources and real 768-dimensional Gemini embeddings, then prove that hybrid retrieval returns category-relevant provisions.

**Architecture:** A backend-only ingestion package loads a curated JSON registry, fetches allowlisted official HTTPS pages, parses legal hierarchy into deterministic provisions, chunks within article boundaries, generates `gemini-embedding-2` embeddings, and uploads a staged revision through service-only Supabase RPCs. Activation is a separate validated transaction, so a failed refresh cannot replace the last active revision. Raw user evidence is outside this pipeline.

**Tech stack:** Python 3.12, FastAPI repository package, `httpx`, Beautiful Soup, Pydantic, pytest, Gemini REST API, Supabase PostgREST RPC, PostgreSQL 17, pgvector 0.8.x.

**Official corpus v1:**

- Consumer Protection Law — `https://adilet.zan.kz/rus/docs/Z100000274_`
- Civil Code, Special Part — `https://adilet.zan.kz/rus/docs/K990000409_`
- Law on Payments and Payment Systems — `https://adilet.zan.kz/rus/docs/Z1600000011`
- Payment Card Rules — `https://adilet.zan.kz/rus/docs/V1600014299`
- Code of Administrative Offences — `https://adilet.zan.kz/rus/docs/K1400000235`
- Administrative Procedural and Process-Related Code — `https://adilet.zan.kz/rus/docs/K2000000350`
- eGov eOtinish instructions — `https://egov.kz/cms/ru/mobile-services/e_app`
- Consumer Protection Committee guidance — `https://www.gov.kz/memleket/entities/mti-kzpp/press/news/details/678401?lang=ru`

The registry stores source-to-category mappings explicitly. Search results and third-party summaries are never ingested.

---

## Task 1: Ingestion domain and curated source registry

**Files:**

- Create: `backend/src/bettercallsaul_api/ingestion/__init__.py`
- Create: `backend/src/bettercallsaul_api/ingestion/models.py`
- Create: `backend/src/bettercallsaul_api/ingestion/source_registry.py`
- Create: `backend/src/bettercallsaul_api/ingestion/sources.json`
- Create: `backend/tests/ingestion/test_source_registry.py`

**TDD cycle:**

1. Write tests proving that all eight source codes are unique, URLs are HTTPS and belong to the exact official allowlist, categories are supported case categories, and disabled/unofficial sources are rejected.
2. Run `uv run pytest tests/ingestion/test_source_registry.py -q` and confirm RED because the ingestion package does not exist.
3. Add typed immutable models for source definitions, parsed provisions, chunks, revisions, ingestion state, and validation errors.
4. Add a package-resource JSON loader with strict Pydantic validation and no arbitrary path or URL override in the production CLI.
5. Run the focused test and the existing backend suite.
6. Commit and push the registry/domain checkpoint.

## Task 2: Bounded fetcher and official-page parsers

**Files:**

- Modify: `backend/pyproject.toml`
- Modify: `backend/uv.lock`
- Create: `backend/src/bettercallsaul_api/ingestion/fetcher.py`
- Create: `backend/src/bettercallsaul_api/ingestion/parser.py`
- Create: `backend/tests/fixtures/adilet_consumer_excerpt.html`
- Create: `backend/tests/fixtures/egov_guidance_excerpt.html`
- Create: `backend/tests/ingestion/test_fetcher.py`
- Create: `backend/tests/ingestion/test_parser.py`

**TDD cycle:**

1. Write fetcher tests for allowlisted hosts, redirects that remain on the allowlist, response size limits, HTML content type, bounded retries, timeout handling, checksum stability, and generic sanitized errors that do not leak secrets.
2. Run the focused tests and confirm RED.
3. Implement an injectable async fetcher with an identifiable user agent, conditional request support, maximum response size, strict HTTPS host checks before and after redirects, and retry only for transient failures.
4. Write parser tests using small representative fixtures: chapter and article extraction, paragraph preservation, note/explanatory-text exclusion, anchor retention, deterministic provision codes, normalized whitespace, and minimum-structure rejection.
5. Run parser tests and confirm RED.
6. Implement an Adilet parser around the semantic `<article>` container and a conservative official-guidance parser for eGov/gov.kz pages. The parser must never infer article numbers that are absent.
7. Run focused and full backend tests.
8. Commit and push the fetch/parser checkpoint.

## Task 3: Legal-hierarchy chunking

**Files:**

- Create: `backend/src/bettercallsaul_api/ingestion/chunker.py`
- Create: `backend/tests/ingestion/test_chunker.py`

**TDD cycle:**

1. Write tests proving short articles remain intact; long articles split only at paragraph boundaries; source title/article/heading context appears in every chunk; sequence numbers and checksums are deterministic; no empty chunk is produced; and category/sector metadata survives.
2. Confirm RED.
3. Implement deterministic, paragraph-aware chunking targeting 350–700 estimated tokens and never crossing provision boundaries.
4. Run focused and full backend tests.
5. Commit and push the chunking checkpoint.

## Task 4: Gemini Embedding 2 client

**Files:**

- Modify: `backend/src/bettercallsaul_api/config.py`
- Create: `backend/src/bettercallsaul_api/ingestion/embeddings.py`
- Create: `backend/tests/ingestion/test_embeddings.py`
- Modify: `backend/.env.example`

**TDD cycle:**

1. Write HTTP-contract tests for `models/gemini-embedding-2:batchEmbedContents`, document prefixes (`title: … | text: …`), 768 output dimensions, batch ordering, bounded retry, dimension validation, and safe provider errors.
2. Confirm RED.
3. Add backend-only Gemini settings and implement the async batch client using the existing `httpx` stack. The API key is sent only in the request header and never logged.
4. Validate every returned vector is finite and exactly 768 values before database upload.
5. Run focused and full tests.
6. Commit and push the embeddings checkpoint.

## Task 5: Transactional Supabase ingestion boundary

**Files:**

- Create with Supabase CLI: `supabase/migrations/<timestamp>_legal_ingestion_rpc.sql`
- Modify: `supabase/tests/rag_foundation.sql`
- Create: `backend/tests/ingestion/test_supabase_ingestion_gateway.py`
- Modify: `backend/src/bettercallsaul_api/supabase_gateway.py`

**TDD cycle and migration:**

1. Write gateway tests for the four allowlisted service RPCs: start, append batch, finalize, and fail. Verify arbitrary service RPC names remain blocked.
2. Confirm RED.
3. Use `supabase migration new legal_ingestion_rpc` to create the migration filename.
4. Add service-only, fixed-search-path functions that:
   - create or identify a source and ingestion run;
   - return `unchanged` when the active checksum already matches;
   - stage a revision without altering the current active revision;
   - append validated provision/chunk batches and cast only 768-element numeric vectors;
   - atomically activate only when expected counts and invariants match;
   - mark failures without deleting the last active revision.
5. Revoke execution from `PUBLIC`, `anon`, and `authenticated`; grant only `service_role`. Enable RLS without permissive policies on all private `rag` tables as defense in depth.
6. Extend SQL assertions for privileges, RLS, status transitions, invalid dimensions, duplicate batches, count mismatch rollback, unchanged-source behavior, and last-active preservation.
7. Apply the migration to project `mhrxtqhuzyckfsthvjoq`, run live SQL assertions, then run Supabase security and performance advisors.
8. Run gateway and full backend tests.
9. Commit and push the database boundary checkpoint.

## Task 6: End-to-end ingestion pipeline and CLI

**Files:**

- Create: `backend/src/bettercallsaul_api/ingestion/pipeline.py`
- Create: `backend/src/bettercallsaul_api/ingestion/cli.py`
- Create: `backend/tests/ingestion/test_pipeline.py`
- Modify: `backend/pyproject.toml`
- Modify: `README.md`

**TDD cycle:**

1. Write orchestration tests for success, unchanged source, parser failure, embedding failure, upload failure, manual-review staging, and final activation. Assert no finalize call occurs after any upstream failure.
2. Confirm RED.
3. Implement dependency-injected orchestration and a console command with `--source`, `--all`, `--dry-run`, and `--activate` modes. Production source selection is by registry code only.
4. Upload provisions in bounded batches; on errors, call the fail RPC with structured non-sensitive diagnostics.
5. Document required backend environment variables and exact dry-run/live commands without including any real secret.
6. Run focused and full backend tests.
7. Commit and push the pipeline/CLI checkpoint.

## Task 7: Retrieval evaluation suite

**Files:**

- Create: `backend/src/bettercallsaul_api/retrieval.py`
- Create: `backend/src/bettercallsaul_api/evaluation.py`
- Create: `backend/evaluation/kz_legal_retrieval_v1.json`
- Create: `backend/tests/test_retrieval.py`
- Create: `backend/tests/test_evaluation.py`

**TDD cycle:**

1. Write tests for query embedding prefixes, category/date filters, stable result parsing, recall-at-k, reciprocal rank, zero-result reporting, and zero out-of-set citation IDs.
2. Confirm RED.
3. Implement the backend retrieval wrapper using the existing protected `search_legal_chunks` RPC and the same Gemini model/dimension as ingestion.
4. Add at least two reviewed seed scenarios per category now (ten total), structured so the suite can grow to the fifty-scenario launch target.
5. Add a CLI evaluation report that fails when required source families are completely absent, while recording metrics without inventing a confidence threshold.
6. Run focused and full backend tests.
7. Commit and push the evaluation checkpoint.

## Task 8: Live corpus load and verification

**Files:**

- Data changes only in the connected Supabase project; no legal text snapshots or API keys are committed.
- Modify documentation only if live behavior reveals a necessary operator instruction.

**Steps:**

1. Run registry validation and dry-run parsing for every source.
2. Run live ingestion with the local ignored Gemini key and the backend-only Supabase secret environment. If a required server secret is unavailable locally, use the connected Supabase administrative channel only for database verification and report the exact remaining runtime credential requirement; never copy a service secret into iOS or Git.
3. Query counts and sample active revisions/provisions/chunks in the private schema.
4. Execute one real Gemini query embedding and protected hybrid retrieval for each of the five categories.
5. Run the ten-scenario retrieval evaluation and record actual metrics.
6. Run Supabase security/performance advisors and include remediation links for any remaining notices.
7. Commit and push any documentation-only follow-up.

## Task 9: Final verification and iOS Simulator

**Steps:**

1. Run `uv run pytest --cov=bettercallsaul_api --cov-report=term-missing` from `backend/`.
2. Run the full SQL assertion set against the live Supabase project.
3. Run the repository’s existing iOS unit and UI test commands.
4. Run a clean iOS build with the local ignored secrets configuration.
5. Boot the target iPhone Simulator, install the newly built app, launch `com.bettercallsaul.app`, and verify the process is running.
6. Review `git diff`, confirm no secrets or generated DerivedData are tracked, commit the final verified state, and push `codex/ai-provider-flow`.

## Done criteria for phase 2

- All eight registry entries pass strict official-host validation.
- Changed, unchanged, malformed, partial, and provider-failure paths are tested.
- Current legal revisions activate only after full validation; a failed refresh leaves the last active revision untouched.
- Active chunks contain real `gemini-embedding-2` vectors with exactly 768 finite values.
- The corpus is inaccessible to `anon` and `authenticated`; only narrowly scoped service RPCs can mutate it.
- Hybrid retrieval returns official Kazakhstan sources for each of the five case categories.
- Backend, database, and iOS tests pass from a clean state.
- The latest app build is installed and running in iOS Simulator.
