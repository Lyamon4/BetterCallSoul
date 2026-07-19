# BetterCallSaul — Saul AI Problem Router

**Date:** 2026-07-19  
**Status:** Approved direction; implementation pending

## Goal

Turn the Home mascot into a short, task-focused assistant. Saul asks what happened, uses text classification to select the correct supported legal scenario, asks at most one clarification when necessary, preserves the user's description, and opens the matching intake screen automatically.

This specification supersedes the earlier mascot design's `No free-form mascot chatbot` non-goal only for this bounded routing dialogue. Saul remains a router, not a general legal chat or document-generation interface.

## Supported destinations

Every successful dialogue ends in exactly one existing `CaseType`:

1. `charge` — `Списали деньги`
2. `fine` — `Пришёл штраф`
3. `subscription` — `Отменить подписку`
4. `product` — `Проблема с товаром`
5. `bill` — `Завышенный счёт`

Saul opens the existing `EvidenceView` after calling `workflow.start(type:)`. No additional destination screens are introduced.

## User experience

Tapping Saul on Home opens a native bottom sheet instead of the current static tip bubble.

### Initial state

- Saul uses the `talking` pose.
- Title: `Расскажите Солу`
- Message: `Что случилось? Опишите своими словами.`
- Multiline text field placeholder: `Например, мне выписали штраф…`
- Primary action: `Отправить`
- Secondary action: `Закрыть`
- The primary action is disabled for blank or whitespace-only input.

### Processing state

- Saul switches to the `thinking` pose.
- Copy: `Разбираюсь в ситуации…`
- The text field and primary action are disabled while a request is active.
- Dismissing the sheet cancels the active task and prevents delayed navigation.

### Direct routing

When a provider returns a valid destination, Saul switches to `talking` and shows one concise transition line derived from the destination:

- `charge`: `Похоже, нужно разобраться со списанием. Открываю обращение.`
- `fine`: `Похоже, нужно обжаловать штраф. Открываю обращение.`
- `subscription`: `Помогу отменить подписку. Открываю обращение.`
- `product`: `Похоже, проблема связана с товаром. Открываю обращение.`
- `bill`: `Похоже, нужно проверить счёт. Открываю обращение.`

After a short `650 ms` transition, the sheet closes and the app opens `EvidenceView` with the selected type.

### One clarification

The first provider response may request clarification instead of choosing a destination. Saul shows the provider-generated short question and enables the same text field for one more answer.

- Only one clarification is permitted.
- The second classification request includes both the original problem and clarification answer.
- On the second request, a valid provider must return a destination. Another clarification response is treated as an invalid response and triggers provider fallback.
- If the fallback provider also fails to return a destination, the dialogue enters the error state.

### Error state

If both providers fail, Saul shows no provider names or technical information:

- Message: `Не удалось разобраться в ситуации. Попробуйте ещё раз.`
- Primary action: `Повторить`
- Secondary action: `Закрыть`

Retry preserves the original problem and clarification answer. It repeats the same DeepSeek-first pipeline; it does not use local rules or silently select a category.

## Provider architecture

Introduce a dedicated text-only classification boundary independent from legal analysis and evidence recognition:

```swift
protocol ProblemClassifying: Sendable {
    func classify(_ request: ProblemRoutingRequest) async throws -> ProblemRoutingDecision
}
```

`ProblemRoutingRequest` contains:

- `problem: String`
- `clarificationQuestion: String?`
- `clarificationAnswer: String?`
- `clarificationAllowed: Bool`

`ProblemRoutingDecision` has exactly two cases:

- `route(caseType: CaseType)`
- `clarify(question: String)`

Provider wire responses use constrained JSON:

```json
{
  "action": "route",
  "case_type": "fine",
  "question": null
}
```

or:

```json
{
  "action": "clarify",
  "case_type": null,
  "question": "Это разовый платёж или продление подписки?"
}
```

The decoder rejects unknown actions, unsupported case types, empty questions, a route without `case_type`, and clarification when `clarificationAllowed` is `false`.

## Provider order and fallback

`AIServiceContainer` receives a `problemClassifier` composed from two real classifiers:

1. `DeepSeekProblemClassifier` is always attempted first.
2. `GeminiProblemClassifier` is attempted only when DeepSeek throws a transport, HTTP, decoding, empty-response, or schema-validation error.
3. If Gemini also throws or returns an invalid response, the composed classifier throws a neutral service error for the sheet.

There is no keyword matcher, local classifier, hard-coded intent routing, confidence threshold, random selection, or silent default category.

Gemini remains the evidence/image provider elsewhere in the app. For this feature it also exposes a separate text-only classification request. The assistant dialogue sends no photo, PDF, OCR text, evidence file, or extracted document field.

## Prompt rules

Both provider prompts contain the same routing contract:

- Classify only into the five supported destination identifiers.
- Do not give legal advice, quote laws, predict outcomes, or create documents.
- Ask for clarification only when two or more supported destinations remain genuinely plausible.
- Keep a clarification question to one sentence and under `120` characters.
- When `clarificationAllowed` is false, return the most appropriate supported destination and never return `clarify`.
- Return only the required JSON object.

The prompt includes concise examples that distinguish:

- an unknown card charge from subscription renewal;
- a government/traffic fine from an inflated service bill;
- subscription cancellation from a one-time refund;
- a defective product from an incorrect invoice.

## UI state and component boundaries

Create `SaulAssistantViewModel` as a `@MainActor @Observable` state owner. It consumes only `ProblemClassifying` and exposes:

- the initial problem text;
- the optional clarification answer;
- the visible Saul message;
- the current presentation state;
- whether submission is allowed;
- the final `CaseType` when routing succeeds.

The state enum is limited to:

- `askingProblem`
- `classifying`
- `askingClarification(question: String)`
- `routing(CaseType)`
- `failed`

`SaulAssistantSheet` renders these states and mascot poses. It does not perform HTTP requests, mutate `CaseWorkflowStore`, or navigate directly.

`HomeView` owns sheet presentation. When the view model emits a final type, Home performs the existing application actions in order:

1. `workflow.start(type: selectedType)`
2. `workflow.updateNarrative(composedNarrative)`
3. dismiss the sheet
4. `router.open(.evidence)`

`composedNarrative` contains the original problem. When clarification was used, append a new line in the format `Уточнение: <answer>` so no user input is lost.

## Configuration and test services

- Live mode builds the DeepSeek-primary/Gemini-fallback classifier from the existing bundled credentials and shared `HTTPTransport`.
- UI-testing mode uses a deterministic stub classifier and makes no network requests.
- Missing or rejected credentials are treated as provider failures and follow the same provider order.
- Local-only startup exposes a classifier that returns the neutral error; it does not infer a destination.

## Accessibility and motion

- The sheet has an accessible title and focuses the problem field after presentation.
- Processing state is announced as `Разбираюсь в ситуации`.
- Error and clarification messages are announced when they appear.
- The keyboard has a visible `Готово` or send action.
- The sheet supports Dynamic Type and scrolls when the keyboard or large text reduces available space.
- `SaulMascotView` continues to respect Reduce Motion.
- Routing never depends on animation completion; the `650 ms` delay is skipped when Reduce Motion is enabled.

## Privacy and user-facing language

- No visible string contains `AI`, `DeepSeek`, `Gemini`, provider, API key, fallback, model, or local mode.
- Neutral helper copy may state: `Ответ нужен только для выбора подходящего сценария.`
- The dialogue stores nothing in a database and introduces no conversation history beyond the current sheet session.
- Closing the sheet discards the in-progress dialogue unless routing has already populated the existing case workflow.

## Verification

- Decoder tests cover both valid actions and every rejected schema combination.
- Client tests use recording transports to verify DeepSeek and Gemini request structure without live calls.
- Fallback tests prove DeepSeek is first, Gemini runs only after failure, successful DeepSeek prevents Gemini calls, and double failure produces an error.
- View-model tests cover direct routing, one clarification, forced route on the second request, retry preservation, cancellation, and blank-input rejection.
- Workflow tests verify the original problem plus clarification are copied into `narrative` before navigation.
- UI tests open Saul, submit a fine description, observe the transition, arrive on Evidence, and verify `caseNarrativeField` contains the original description.
- A second UI test exercises the one-clarification path through a deterministic stub.
- Production-surface tests continue to reject provider and implementation labels.
- The full unit/UI suite runs on iPhone 17 Pro without live provider requests.

## Non-goals

- No open-ended legal chat.
- No more than one clarification.
- No voice input, speech output, conversation persistence, streaming tokens, typing simulation, or chat history screen.
- No image/PDF upload inside the Saul sheet.
- No new legal categories or destination screens.
- No autonomous submission, document creation, or external communication from the assistant sheet.
