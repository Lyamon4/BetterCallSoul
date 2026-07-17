# BetterCallSaul — Product and Experience Design

**Date:** 2026-07-17  
**Status:** Approved visual direction; implementation pending  
**Hackathon track:** Social & Human Capital / Civic Rights & Literacy

## 1. Product thesis

BetterCallSaul is a native iOS legal-automation assistant for young people in Kazakhstan. It helps a user turn an unfair charge, fine, unwanted subscription, defective purchase, or inflated bill into a structured action: collect evidence, answer a short guided interview, generate a document, confirm it, send or export it, and track the response deadline.

The product is not positioned as a lawyer and not designed as a generic chatbot. Its central promise is:

> Describe the problem → add evidence → prepare the document → take action → track the result.

The hackathon's “one user — one acute pain” requirement is satisfied as follows:

- **Primary user:** a 16–23-year-old in Kazakhstan handling a consumer or administrative problem for the first time.
- **Acute pain:** the user loses money or accepts an unfair decision because the required procedure and official language are difficult to understand.

## 2. Scope

### 2.1 Working MVP capabilities

The MVP uses one shared intake and document-generation engine for these case types:

1. Automatic complaints and formal demands.
2. Fine appeal preparation.
3. Subscription cancellation and disputed renewal requests.
4. Refund and compensation requests.
5. Bill analysis and negotiation requests.
6. PDF generation, editing, export, and iOS Share Sheet/email handoff.
7. Local case history, statuses, deadlines, and reminders.

At least one scenario — an unwanted subscription charge — must work end to end in the final demo. The other working scenarios reuse the same engine with different structured questionnaires and templates.

### 2.2 Honest demo and concept capabilities

- **Temporary phone number:** complete UI and a provider abstraction. It runs with a clearly marked demo provider until real telephony credentials are configured.
- **Trial Card:** concept-only flow marked `КОНЦЕПТ`; it does not issue a real banking product or imply that a card exists.
- **Fax and physical mail:** shown as `Integration Preview`; the working MVP exports the same document as PDF and supports email/share handoff.

### 2.3 Explicit non-goals

- No autonomous submission without the user's final confirmation.
- No claim that the app replaces a licensed lawyer.
- No automatic access to bank accounts or subscription history.
- No real card issuance, payment processing, SMS interception, or identity verification.
- No fabricated legal citations or guarantees of a successful outcome.
- No production storage of evidence on the backend during the hackathon MVP.

## 3. Primary demo journey

The user notices a `24 900 ₸` subscription charge and opens BetterCallSaul.

1. On Home, the user selects `Списали деньги`.
2. They describe the situation in text or by voice.
3. They add a bank screenshot or receipt.
4. On-device OCR extracts the company, amount, date, and transaction context.
5. The app asks only the missing structured questions.
6. The backend produces a schema-constrained document draft.
7. The app highlights uncertain fields and requires confirmation.
8. The user reviews and signs off on the document.
9. The app generates a PDF and opens a real iOS share/email action.
10. The case moves to `Ожидается ответ`, with a visible response date and reminder.

This is the complete three-minute presentation path. Other tools are shown after the main flow to demonstrate that they are templates on the same engine rather than disconnected prototypes.

## 4. Information architecture

The bottom navigation contains four destinations:

- **Главная:** start a case and see the current case.
- **Обращения:** case history, filters, statuses, and deadlines.
- **Инструменты:** supported case templates plus demo/concept integrations.
- **Профиль:** language, personal details used in documents, privacy, and legal disclaimer.

The app avoids a chat-first structure. Conversation is used only when a missing fact needs clarification. The main experience is a guided form, evidence workspace, document editor, and status timeline.

## 5. Screen design

### 5.1 Home

- Greeting, editorial headline `Что случилось?`, and a short concrete explanation.
- Primary action `Создать обращение`.
- Hairline-separated issue list rather than a grid of generic cards.
- One current-case row with amount, status, and deadline.
- Small payphone drawing and yellow phone tile as thematic accents.

### 5.2 Case intake

- Case category is preselected from Home or Tools.
- Text and voice description are equal entry points.
- Progress is visible but quiet.
- Questions use labels above fields and plain Russian copy.
- The draft is saved locally after every step.

### 5.3 Evidence and OCR review

- The user can add photos, screenshots, PDFs, and camera scans.
- Each file has an upload/processing/ready/error state.
- Extracted fields appear as an editable document table.
- Low-confidence values receive a pale-yellow `ПРОВЕРЬТЕ ДАННЫЕ` label.
- The user can continue with manual entry if OCR fails.

### 5.4 Clarifying questions

- Maximum of five questions in the primary flow.
- Prefer binary choices, dates, amounts, and short fields over free-form chat.
- Explain why a sensitive field is required.
- The user can return to earlier answers without losing evidence.

### 5.5 Document preview

- The document, not an AI avatar, is the visual hero.
- Show recipient, subject, facts, demand, deadline, attachments, and signature data.
- Separate `confirmed`, `requires attention`, and `unverified legal basis` states.
- Provide `Редактировать`, `Скачать PDF`, and `Подписать и отправить` actions.
- Sending is blocked until required uncertain values are resolved.

### 5.6 Cases and tracking

- Statuses: `Черновик`, `Документ готов`, `Отправлено`, `Ожидается ответ`, `Требуется действие`, `Завершено`.
- Each case shows the counterparty, amount where relevant, last action, and next deadline.
- A vertical timeline records user-confirmed actions. The app never claims external delivery unless a real provider returns confirmation.

### 5.7 Tools

- Editorial numbered list, not a dense card dashboard.
- Tools: complaint, fine appeal, subscription cancellation, refund, bill negotiation, temporary number, Trial Card.
- Capability labels are explicit: `РАБОТАЕТ`, `DEMO`, or `КОНЦЕПТ`.
- A yellow callout with a payphone illustration contains `Нужен план? Позвони Солу.`

## 6. Visual system

The approved concept is premium utilitarian minimalism inspired by document editors such as Notion, adapted to native iOS.

### 6.1 Palette

- Canvas: warm paper `#F7F6F1`.
- Surface: `#FFFFFF`.
- Primary text: charcoal `#2F3437`.
- Secondary text: `#787774`.
- Divider: `#E7E5DF`.
- Singular brand accent: Saul yellow `#F2D44B`.
- Success and error colors appear only when semantically necessary and remain desaturated.

No gradients, neon, purple AI styling, heavy shadows, or glassmorphism are used.

### 6.2 Typography

- Native SF Pro for navigation, controls, labels, and body copy.
- An editorial serif similar to Newsreader for selected page titles and document-led moments.
- SF Mono for case numbers, timestamps, and technical metadata.
- Large titles remain left-aligned and readable; hierarchy comes from weight and spacing rather than extreme size.

### 6.3 Shape and spacing

- Hairline dividers organize information before containers are introduced.
- Cards are used only for uploaded evidence, documents, or functionally elevated content.
- Radius is 8–12 points; primary buttons use a crisp 6-point radius.
- Controls meet the 44-point minimum touch target.
- Layout supports long Russian and Kazakh strings without truncating essential actions.

### 6.4 Thematic references

References are intentional but restrained:

- Saul-yellow accent and business-card strip.
- Continuous-line payphone illustrations.
- Stacked `Better / Call / Saul` wordmark treatment.
- Case-file numbering such as `BCS-2026-0717-0017`.
- Microcopy `Всё по закону.`, `Не советуем. Делаем.`, and one discreet `S’all good` easter egg.

The app does not use actor likenesses, television stills, or direct copies of series artwork.

### 6.5 Approved visual references

- `design-concepts/01-home.png`
- `design-concepts/02-evidence.png`
- `design-concepts/03-document.png`
- `design-concepts/04-tools.png`

Generated legal text inside these images is illustrative and must not be treated as validated product content.

## 7. Motion system

Motion is quiet and functional:

- Screen content enters with an 8-point upward translation and opacity transition over roughly 280–420 ms.
- Buttons compress to 0.98 on press and return with a restrained spring.
- Lists reveal with an 60–80 ms stagger.
- Uploaded evidence expands into extracted fields using a shared-element transition.
- OCR highlights appear sequentially to explain what the system recognized.
- The draft transforms into the final paper document through a matched geometry transition.
- A small yellow status dot breathes only while processing or waiting.
- Success uses haptic feedback and a single checkmark draw, not confetti.

All animation respects Reduce Motion and uses only opacity and transform where possible.

## 8. Technical architecture

### 8.1 iOS client

- Native SwiftUI application targeting iOS 17 or newer.
- Feature-oriented modules with MVVM-style observable state.
- `NavigationStack` for flows and sheets for focused actions.
- Apple Vision performs OCR on-device when possible.
- PDFKit or native Core Graphics renders the final PDF.
- SwiftData stores cases and drafts locally.
- Keychain stores non-secret session identifiers; the Gemini API key is never stored in the app.

### 8.2 Backend

- Small stateless API service with explicit request/response schemas.
- The server reads `GEMINI_API_KEY` from its environment and a configurable `GEMINI_MODEL` value.
- It accepts extracted text and structured answers rather than raw evidence by default.
- It returns schema-constrained analysis, follow-up questions, and document sections.
- Templates and legal-source metadata are versioned separately from prompts.
- Logs redact names, phone numbers, document identifiers, and evidence text.

### 8.3 AI safety boundary

- The model organizes user-provided facts; it may not invent missing facts.
- All model responses are validated against strict JSON schemas.
- Legal citations are displayed only if they come from a reviewed local source record.
- An unverified citation is omitted or marked for review, never presented as authoritative.
- The user sees and confirms the final document before any external action.
- Deterministic template fallback remains available when the model fails or the network is unavailable.

### 8.4 Data flow

1. Evidence is selected on the device.
2. OCR runs locally and produces editable extracted text.
3. The client sends the minimum structured context to the backend.
4. The backend requests schema-constrained analysis from Gemini.
5. The client presents questions and collects answers.
6. The backend produces document sections using a selected template.
7. The client validates required fields and renders the PDF locally.
8. The user performs the final share/send action.
9. The local case timeline records only confirmed actions.

## 9. Core data model

`LegalCase` contains:

- Identifier and case number.
- Case type and status.
- User narrative.
- Counterparty and contact channel.
- Amount, transaction date, and response deadline where relevant.
- Evidence metadata and locally stored file references.
- Extracted fields with confidence and confirmation state.
- Structured questions and answers.
- Generated document sections and revision number.
- Delivery method, user-confirmed events, and reminder dates.

Evidence binaries remain local in the MVP unless the user explicitly chooses an integration that requires upload.

## 10. Error and empty states

- **No network:** save progress and offer deterministic template mode.
- **OCR failed:** preserve the file and switch to manual field entry.
- **Invalid AI response:** retry once with the same schema, then use the template fallback.
- **Missing evidence:** explain which fact cannot be verified; do not block a draft if the template allows it.
- **Unsafe or unsupported request:** explain the boundary and recommend professional or emergency help where appropriate.
- **Export failed:** retain the completed document and offer a retry or plain-text copy.
- **No cases:** show one clear action and a payphone line illustration, not an empty dashboard.

## 11. Verification strategy

- Unit tests for case-state transitions, required-field rules, status deadlines, and prompt-response decoding.
- Backend contract tests for every JSON schema and deterministic fallback.
- OCR fixture tests using synthetic receipts and screenshots with no real personal data.
- UI tests for the primary unwanted-subscription flow.
- Snapshot checks for Home, Evidence, Document, Tools, loading, empty, and error states.
- Manual accessibility pass for Dynamic Type, VoiceOver labels, contrast, Reduce Motion, and 44-point targets.
- Demo rehearsal in airplane mode to confirm the fallback path works.

## 12. Definition of success

The MVP is ready for hackathon submission when:

- The unwanted-subscription scenario works end to end without a crash.
- At least five case templates reuse the same intake and generation engine.
- The app can create a readable PDF and open a real iOS share action.
- Every uncertain AI-extracted value is visibly reviewable.
- No API secret is present in the iOS bundle or repository.
- Demo and concept features are labeled honestly.
- The three-minute demo can be completed with a prepared local fixture even without network access.
- The interface matches the approved warm editorial visual system and supports Reduce Motion.

