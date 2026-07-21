# BetterCallSaul — Gemini Vision + DeepSeek Text Design

**Date:** 2026-07-18  
**Status:** Approved for implementation  
**Scope:** Direct provider integration in the iOS hackathon app, without backend or database

## 1. Goal

Add a real AI-assisted case workflow to BetterCallSaul while preserving the existing local OCR and deterministic document fallback:

1. The user describes a problem and selects an image or PDF.
2. Gemini analyzes visual evidence and returns structured facts.
3. The user reviews and corrects those facts.
4. DeepSeek receives text only, asks missing questions, and produces structured document sections.
5. The app renders the final PDF locally and lets the user share it.

The AI layer supports all five working case types: disputed charge, fine appeal, subscription cancellation/refund, defective product, and inflated bill.

## 2. Deliberate constraints

- No backend, database, account system, or remote case history in this phase.
- Provider calls go directly from the iOS app.
- Evidence is sent only to Gemini, never to DeepSeek.
- DeepSeek receives text and structured JSON only.
- No autonomous submission and no claim that the app replaces a lawyer.
- No provider request is made during automated local verification; the owner performs real-provider checks manually in the app.
- The existing Apple Vision OCR and deterministic Russian templates remain available when either provider fails.

## 3. Provider responsibilities

### 3.1 Gemini Vision

Gemini handles images and PDF documents. The app sends one in-memory evidence payload plus a short extraction prompt. Gemini returns an `EvidenceAnalysis` JSON object containing:

- `documentKind`
- `rawText`
- `counterparty`
- `amount`
- `currency`
- `transactionDate`
- `evidenceSummary`
- `importantDetails`
- `warnings`
- per-field confidence values

Gemini may extract only information visible in the submitted evidence. Unknown values must be returned as `null`, never inferred.

The REST integration uses the Gemini `generateContent` endpoint with inline base64 data and `application/json` structured output. Images are normalized to JPEG with a maximum long edge of 2048 pixels. PDFs are sent inline when their original size is at most 10 MB; larger PDFs remain available for local OCR/manual entry and show a clear size error.

Default model: `gemini-3.5-flash`. The model identifier is configurable without changing client code.

Official references:

- https://ai.google.dev/gemini-api/docs/image-understanding
- https://ai.google.dev/gemini-api/docs/document-processing
- https://ai.google.dev/gemini-api/docs/structured-output

### 3.2 DeepSeek Text

DeepSeek receives:

- selected case type;
- the user's written description;
- the reviewed `EvidenceAnalysis` fields;
- answers to earlier questions;
- the supported document template identifier;
- safety instructions and the required JSON shape.

It never receives image or PDF bytes.

DeepSeek performs two text-only operations:

1. `analyzeCase` returns a plain-language summary, missing facts, up to five structured questions, cautions, and a recommended demand.
2. `generateDocument` returns recipient, subject, fact paragraphs, demand paragraphs, requested response deadline, attachment description, and unresolved review issues.

The REST integration uses `POST https://api.deepseek.com/chat/completions`, bearer authentication, non-streaming responses, and JSON Output. Every response is decoded into a strict Swift model and rejected when required fields are missing or `finish_reason` indicates truncation.

Default model: `deepseek-v4-pro`. The model identifier is configurable without changing client code.

Official reference:

- https://api-docs.deepseek.com/api/create-chat-completion

## 4. Key handling

The repository owner explicitly accepted the risk of direct provider credentials in a private repository and distributable app binary.

- `ios/Config/Secrets.xcconfig` is tracked and contains the two provider keys and model identifiers.
- XcodeGen maps these settings into generated Info.plist values.
- `AIConfiguration` reads the bundled values once and validates that they are non-empty.
- Profile provides an optional local override stored in Keychain so a key can be rotated without rebuilding.
- No screen, error, analytics event, test output, or debug log displays a full key.
- Network errors expose HTTP status and provider-safe messages but redact request authorization data.

The app shows an explicit disclosure before the first visual analysis: the selected document will be transferred to Gemini. Continuing records only an in-memory consent flag for the current app session.

## 5. iOS architecture

### 5.1 Provider-independent contracts

`EvidenceAnalyzing` exposes one asynchronous operation that accepts `EvidencePayload` and returns `EvidenceAnalysis`.

`LegalTextGenerating` exposes `analyzeCase` and `generateDocument`, both accepting text-only request models.

Views and `CaseWorkflowStore` depend on these protocols rather than concrete provider clients. This keeps fallback behavior and unit testing independent from the network implementation.

### 5.2 Provider clients

`GeminiVisionClient` owns Gemini request encoding, inline-data preparation, HTTP validation, response extraction, and schema decoding.

`DeepSeekTextClient` owns chat message construction, JSON Output configuration, HTTP validation, finish-reason validation, and response decoding.

`AIServiceContainer` creates the concrete clients from `AIConfiguration` and injects them into the app workflow.

### 5.3 Evidence state

The current `EvidenceImporter` is extended to return an `EvidencePayload` containing:

- original file name;
- MIME type;
- normalized bytes used for the provider request;
- local preview image;
- display size metadata.

The payload exists only in memory because this phase has no database. The existing `EvidenceItem` remains Codable and contains metadata only.

### 5.4 Workflow state

`CaseWorkflowStore` gains:

- user narrative;
- current evidence payload;
- Gemini analysis state;
- reviewed evidence analysis;
- DeepSeek case analysis;
- answers to structured questions;
- AI-generated document sections;
- provider and fallback status messages.

State transitions are explicit:

`draft → evidenceSelected → visualAnalysis → factsReview → textAnalysis → questions → documentReady → sent`

Failures return to a reviewable state rather than clearing user data.

## 6. User experience

### 6.1 Evidence screen

The existing visual design remains intact. The screen adds:

- a multiline `Опишите ситуацию` field;
- the Gemini transfer disclosure shown before the first upload analysis;
- a provider status row: `Анализируем в Gemini`, `Gemini готов`, or `Локальный режим`;
- editable facts populated from Gemini when available;
- the existing Apple Vision path as automatic fallback.

The primary action becomes `Проанализировать ситуацию`. It remains available with text only when no evidence is attached.

### 6.2 AI analysis and questions screen

A new editorial screen appears between Evidence and Document. It contains:

- a short case summary;
- the recommended next action;
- visible cautions;
- zero to five questions using choice, date, amount, or short-text controls;
- a provider label that states whether DeepSeek or local fallback produced the analysis;
- `Подготовить документ` as the primary action.

There is no generic chat interface. Questions are structured and answers remain editable.

### 6.3 Document screen

The existing paper preview uses DeepSeek sections only after local validation. It highlights unresolved fields and refuses to imply that a missing recipient, amount, date, or legal source was confirmed.

If DeepSeek is unavailable or its response is invalid, `DocumentDraftGenerator` creates the current deterministic draft and the screen labels it `Локальный шаблон`.

PDF rendering and iOS sharing remain fully local.

### 6.4 Profile connection status

Profile shows configuration state without sending a test request:

- `Gemini: ключ добавлен` or `ключ отсутствует`
- `DeepSeek: ключ добавлен` or `ключ отсутствует`
- masked suffix only, never the full value
- editable Keychain override fields

No automatic connectivity test is performed. The first real workflow call is the functional check.

## 7. Case-type behavior

All scenarios use one shared AI pipeline with different instructions and required facts:

- **Disputed charge:** merchant, amount, date, authorization, previous contact, requested refund.
- **Fine appeal:** issuing authority, decision number, date, alleged violation, reason for appeal, deadline concern.
- **Subscription:** provider, amount, renewal date, cancellation attempt, service usage after renewal, refund/cancellation demand.
- **Product:** seller, item, purchase date, amount, defect, attempted resolution, desired remedy.
- **Inflated bill:** provider, billing period, billed amount, expected amount, disputed line items, requested recalculation.

DeepSeek is instructed to ask only for missing facts required by the selected scenario and never more than five questions.

## 8. Validation and safety

- All provider responses are decoded into typed `Codable` models.
- Amounts, dates, and counterparties from AI remain marked unconfirmed until the user reviews them.
- Generated document facts must be traceable to narrative, reviewed evidence, or question answers.
- Unsupported citations are omitted. The model cannot insert a legal citation into the final document unless it matches a reviewed local source record; no such records are included in this phase.
- Empty or malformed responses retry once, then fall back locally.
- HTTP 401/403 produces a key configuration message.
- HTTP 429 produces a quota message and preserves the local workflow.
- Offline and timeout errors activate local analysis/document templates.
- Provider payloads and responses are never written to logs.

## 9. Verification strategy

Automated verification does not call external providers or spend quota:

- request-encoding tests verify that Gemini receives visual bytes while DeepSeek receives text only;
- decoding tests cover valid, null-field, malformed, truncated, and provider-error responses;
- workflow tests cover success, retry, and fallback state transitions;
- prompt tests ensure each of the five case types maps to the correct required facts;
- UI tests cover the prepared offline fixture and deterministic analysis path;
- a build and full local test suite run before every commit/push.

The repository owner manually verifies real provider behavior by running the app and selecting evidence. No hidden test call or startup request contacts Gemini or DeepSeek.

## 10. Definition of done

This phase is complete when:

- an image or PDF can be sent to Gemini after explicit disclosure;
- Gemini results populate editable evidence fields;
- text-only cases can proceed directly to DeepSeek;
- DeepSeek produces at most five structured questions for every supported case type;
- reviewed answers produce typed document sections;
- invalid or unavailable provider responses fall back without losing the case;
- the existing local PDF and share flow works with AI-generated sections;
- DeepSeek never receives binary evidence;
- no automatic live-provider verification runs;
- the app builds and all local automated tests pass.
