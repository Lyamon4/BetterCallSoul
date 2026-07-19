# Saul AI Problem Router Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Saul’s static Home tip with a bounded text assistant that classifies a user’s problem through DeepSeek first and Gemini only as fallback, asks at most one clarification, preserves the entered narrative, and opens the matching existing Evidence flow.

**Architecture:** Add a small provider-independent routing domain and strict wire decoder, two text-only provider adapters, and an ordered fallback classifier in `AIServiceContainer`. A `@MainActor @Observable` view model owns the five-state dialogue; a SwiftUI sheet renders it; `HomeView` remains the only layer that mutates `CaseWorkflowStore` and navigates.

**Tech Stack:** Swift 6, SwiftUI, Observation, async/await, XCTest, XCUITest, existing `HTTPTransport`, DeepSeek Chat Completions, Gemini Interactions, XcodeGen.

**Non-negotiable:** Automated tests use recording transports and deterministic stubs. Do not call either live provider while implementing or verifying this plan.

---

## Task 1: Define and validate the provider-independent routing contract

**Files:**

- Create: `ios/BetterCallSaul/AI/Routing/ProblemRoutingModels.swift`
- Create: `ios/BetterCallSaul/AI/Routing/ProblemRoutingPrompt.swift`
- Modify: `ios/BetterCallSaul/AI/Domain/AIProtocols.swift`
- Test: `ios/BetterCallSaulTests/ProblemRoutingModelsTests.swift`
- Test: `ios/BetterCallSaulTests/ProblemRoutingPromptTests.swift`

- [ ] **Step 1: Write failing model and decoder tests**

Cover all five identifiers (`charge`, `fine`, `subscription`, `product`, `bill`), a valid clarification, and rejection of unknown actions, missing or unknown case types, blank questions, mixed route/clarify fields, and clarification when `clarificationAllowed == false`.

The public domain should be:

```swift
struct ProblemRoutingRequest: Equatable, Sendable {
    let problem: String
    let clarificationQuestion: String?
    let clarificationAnswer: String?
    let clarificationAllowed: Bool
}

enum ProblemRoutingDecision: Equatable, Sendable {
    case route(caseType: CaseType)
    case clarify(question: String)
}

enum ProblemRoutingError: Error, Equatable {
    case invalidResponse
    case unavailable
}
```

The decoder entry point should accept provider JSON text plus `clarificationAllowed`, trim a fenced JSON response if necessary, and return only a validated domain decision.

- [ ] **Step 2: Run the focused tests and confirm RED**

Run:

```bash
cd ios
xcodegen generate
xcodebuild test -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulTests/ProblemRoutingModelsTests \
  -only-testing:BetterCallSaulTests/ProblemRoutingPromptTests
```

Expected: compile failure because the routing types do not exist.

- [ ] **Step 3: Implement the smallest strict routing domain**

Add `ProblemClassifying` to `AIProtocols.swift`:

```swift
protocol ProblemClassifying: Sendable {
    func classify(_ request: ProblemRoutingRequest) async throws -> ProblemRoutingDecision
}
```

Implement explicit `CaseType` wire mappings instead of deriving identifiers from Russian display strings. Decode a private `Codable` object with `action`, `case_type`, and `question`, then validate the permitted field combinations.

- [ ] **Step 4: Add one shared provider prompt builder**

`ProblemRoutingPrompt.make(request:)` must include:

- exactly the five supported English identifiers;
- the original problem and optional clarification pair;
- no legal advice or document generation;
- clarification only when at least two destinations are plausible;
- one sentence under 120 characters;
- `clarificationAllowed == false` forcing a route;
- JSON-only output examples that distinguish charge vs subscription, fine vs bill, refund vs cancellation, and product vs invoice.

Test that prompt content never contains binary evidence, MIME, OCR, PDF, or image payload instructions.

- [ ] **Step 5: Run focused tests and confirm GREEN**

Use the command from Step 2. Expected: all routing model and prompt tests pass.

- [ ] **Step 6: Commit**

```bash
git add ios/BetterCallSaul/AI ios/BetterCallSaulTests/ProblemRoutingModelsTests.swift ios/BetterCallSaulTests/ProblemRoutingPromptTests.swift
git commit -m "feat: define Saul problem routing contract"
```

## Task 2: Implement text-only DeepSeek and Gemini classifiers

**Files:**

- Create: `ios/BetterCallSaul/AI/DeepSeek/DeepSeekProblemClassifier.swift`
- Create: `ios/BetterCallSaul/AI/Gemini/GeminiProblemClassifier.swift`
- Test: `ios/BetterCallSaulTests/DeepSeekProblemClassifierTests.swift`
- Test: `ios/BetterCallSaulTests/GeminiProblemClassifierTests.swift`

- [ ] **Step 1: Write failing recording-transport tests**

DeepSeek tests must prove:

- request URL is `https://api.deepseek.com/chat/completions`;
- authorization is `Bearer <key>`;
- request uses `response_format.type == json_object`;
- body contains only routing text and no evidence/file fields;
- empty choices, non-`stop` finish, invalid JSON, invalid schema, and non-2xx responses throw.

Gemini tests must prove:

- request URL is `https://generativelanguage.googleapis.com/v1beta/interactions`;
- API key is supplied through `x-goog-api-key`;
- input contains one text item and no image/document/base64 input;
- response schema constrains action, case type, and question;
- missing completed text, invalid JSON/schema, and non-2xx responses throw.

- [ ] **Step 2: Run focused tests and confirm RED**

```bash
cd ios
xcodegen generate
xcodebuild test -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulTests/DeepSeekProblemClassifierTests \
  -only-testing:BetterCallSaulTests/GeminiProblemClassifierTests
```

- [ ] **Step 3: Implement `DeepSeekProblemClassifier`**

Reuse `DeepSeekChatRequest`, `ProblemRoutingPrompt`, `HTTPTransport`, and the existing provider error mapping. Decode the assistant’s content with the strict routing decoder. Do not add retries or fallback inside this client.

- [ ] **Step 4: Implement `GeminiProblemClassifier`**

Reuse `GeminiInteractionRequest` and send exactly one `input_text` entry. Provide a response schema whose enums list only valid actions and identifiers. Extract one completed output text and pass it through the same strict decoder. Do not attach evidence.

- [ ] **Step 5: Run focused tests and confirm GREEN**

Use the command from Step 2.

- [ ] **Step 6: Commit**

```bash
git add ios/BetterCallSaul/AI/DeepSeek ios/BetterCallSaul/AI/Gemini ios/BetterCallSaulTests/*ProblemClassifierTests.swift
git commit -m "feat: add DeepSeek and Gemini problem classifiers"
```

## Task 3: Enforce the exact DeepSeek-to-Gemini fallback order

**Files:**

- Create: `ios/BetterCallSaul/AI/Routing/FallbackProblemClassifier.swift`
- Modify: `ios/BetterCallSaul/AI/Infrastructure/AIServiceContainer.swift`
- Test: `ios/BetterCallSaulTests/FallbackProblemClassifierTests.swift`
- Test: `ios/BetterCallSaulTests/AIConfigurationTests.swift`

- [ ] **Step 1: Write failing ordered-fallback tests**

Use actor-based spies to prove:

1. DeepSeek is called first.
2. A DeepSeek success prevents any Gemini call.
3. Any DeepSeek error invokes Gemini exactly once.
4. Gemini’s valid response is returned unchanged.
5. A double failure becomes `ProblemRoutingError.unavailable`.
6. No third/local classifier exists.

- [ ] **Step 2: Run the focused tests and confirm RED**

```bash
cd ios
xcodegen generate
xcodebuild test -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulTests/FallbackProblemClassifierTests \
  -only-testing:BetterCallSaulTests/AIConfigurationTests
```

- [ ] **Step 3: Implement the fallback classifier**

```swift
struct FallbackProblemClassifier: ProblemClassifying {
    let primary: any ProblemClassifying
    let fallback: any ProblemClassifying

    func classify(_ request: ProblemRoutingRequest) async throws -> ProblemRoutingDecision {
        do {
            return try await primary.classify(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            do {
                return try await fallback.classify(request)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw ProblemRoutingError.unavailable
            }
        }
    }
}
```

- [ ] **Step 4: Wire all container modes**

Add `problemClassifier` to `AIServiceContainer`.

- `.live`: DeepSeek primary plus Gemini fallback, sharing the injected transport.
- `.uiTesting`: deterministic no-network classifier.
- `.localOnly`: `UnavailableProblemClassifier` that throws `.unavailable`; never guesses.

Provide two deterministic UI-test modes selected only by launch arguments:

- direct mode always routes to `.fine`;
- clarification mode returns one fixed question while clarification is allowed, then routes to `.fine`.

- [ ] **Step 5: Run focused tests and confirm GREEN**

Use the command from Step 2.

- [ ] **Step 6: Commit**

```bash
git add ios/BetterCallSaul/AI ios/BetterCallSaulTests/FallbackProblemClassifierTests.swift ios/BetterCallSaulTests/AIConfigurationTests.swift
git commit -m "feat: compose ordered Saul classifier fallback"
```

## Task 4: Build the cancellable one-clarification dialogue state machine

**Files:**

- Create: `ios/BetterCallSaul/Features/Home/SaulAssistantViewModel.swift`
- Test: `ios/BetterCallSaulTests/SaulAssistantViewModelTests.swift`

- [ ] **Step 1: Write failing view-model tests**

Cover:

- blank and whitespace input cannot submit;
- direct classification reaches `.routing(.fine)`;
- the first clarification is displayed and the next request contains original problem, question, answer, and `clarificationAllowed == false`;
- a repeated clarification is treated as failure;
- retry preserves all entered text and repeats the same request;
- cancellation prevents a late result from changing state;
- `composedNarrative` is original text plus `\nУточнение: ...` when present.

- [ ] **Step 2: Run the focused test and confirm RED**

```bash
cd ios
xcodegen generate
xcodebuild test -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulTests/SaulAssistantViewModelTests
```

- [ ] **Step 3: Implement the observable state machine**

```swift
enum SaulAssistantState: Equatable {
    case askingProblem
    case classifying
    case askingClarification(question: String)
    case routing(CaseType)
    case failed
}
```

The view model stores `problemText`, `clarificationText`, current clarification question, state, and a cancellable task. `submit()` snapshots trimmed input, builds `ProblemRoutingRequest`, and starts classification. It must not navigate, mutate the workflow, inspect keywords, or choose a default category.

If the second request returns `.clarify`, convert it to `.failed` even if a test double returns it; real provider clients already reject it through `clarificationAllowed == false`.

Expose `reset()`, `cancel()`, `retry()`, `canSubmit`, `visibleMessage`, `mascotState`, and `composedNarrative` for a presentation-only sheet.

- [ ] **Step 4: Run focused tests and confirm GREEN**

Use the command from Step 2.

- [ ] **Step 5: Commit**

```bash
git add ios/BetterCallSaul/Features/Home/SaulAssistantViewModel.swift ios/BetterCallSaulTests/SaulAssistantViewModelTests.swift
git commit -m "feat: add Saul assistant dialogue state machine"
```

## Task 5: Replace the static tip with the native assistant sheet

**Files:**

- Create: `ios/BetterCallSaul/Features/Home/SaulAssistantSheet.swift`
- Modify: `ios/BetterCallSaul/Features/Home/HomeView.swift`
- Modify: `ios/BetterCallSaul/App/AppRootView.swift`
- Modify: `ios/BetterCallSaul/App/BetterCallSaulApp.swift`
- Modify: `ios/BetterCallSaul/DesignSystem/SaulMascotView.swift`
- Modify: `ios/BetterCallSaulUITests/PrimaryFlowUITests.swift`
- Test: `ios/BetterCallSaulTests/CaseWorkflowStoreTests.swift`
- Test: `ios/BetterCallSaulTests/ProductionSurfaceTests.swift`

- [ ] **Step 1: Replace the obsolete mascot UI test with failing assistant-flow tests**

Direct-path UI test:

1. tap `saulMascotButton`;
2. assert `saulAssistantSheet`, title, prompt, and empty `saulProblemField`;
3. enter `Мне выписали штраф за парковку`;
4. tap `saulSubmitButton`;
5. observe the neutral routing line;
6. arrive at Evidence;
7. assert `caseNarrativeField` contains the exact original input.

Clarification-path UI test relaunches with `-saul-clarification-testing`, submits the original problem, answers the fixed clarification in `saulClarificationField`, and verifies Evidence narrative equals:

```text
Original problem
Уточнение: Clarification answer
```

Update production-surface tests to scan the new sheet source for forbidden provider/API/local/demo labels.

- [ ] **Step 2: Run focused unit/UI tests and confirm RED**

```bash
cd ios
xcodegen generate
xcodebuild test -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulTests/CaseWorkflowStoreTests \
  -only-testing:BetterCallSaulTests/ProductionSurfaceTests \
  -only-testing:BetterCallSaulUITests/PrimaryFlowUITests/testHomeSaulRoutesProblemToEvidence \
  -only-testing:BetterCallSaulUITests/PrimaryFlowUITests/testHomeSaulClarifiesThenRoutesToEvidence
```

- [ ] **Step 3: Inject only the classifier into Home**

Keep `AIServiceContainer` private to app construction. Store its `problemClassifier` in `BetterCallSaulApp`, pass `any ProblemClassifying` through `AppRootView`, and initialize `SaulAssistantViewModel` in `HomeView`. Do not expose provider names or the full service container to the sheet.

- [ ] **Step 4: Implement `SaulAssistantSheet`**

Use the existing warm editorial system and 8-bit Saul assets:

- talking pose for questions and routing;
- thinking pose during classification;
- scrollable content and multiline `TextField(axis: .vertical)`;
- initial focus via `@FocusState`;
- disabled input/actions while active;
- `Отправить`, `Повторить`, and `Закрыть` labels from the approved design;
- accessibility announcements for processing, clarification, and error;
- no chat bubbles, provider logos, implementation labels, gradients, or heavy shadows.

Required identifiers: `saulAssistantSheet`, `saulProblemField`, `saulClarificationField`, `saulSubmitButton`, `saulRetryButton`, `saulCloseButton`.

- [ ] **Step 5: Integrate routing in `HomeView`**

Tapping Saul resets the view model and presents `.sheet`. Remove the old `isSaulTipVisible`, rotating copy, and `SaulTipBubble`.

Observe the view model reaching `.routing(type)`. After `650 ms` (or immediately under Reduce Motion), verify the sheet session is still current, then perform exactly:

```swift
workflow.start(type: type)
workflow.updateNarrative(assistant.composedNarrative)
isSaulAssistantPresented = false
router.open(.evidence)
```

Closing the sheet calls `assistant.cancel()` and invalidates delayed routing. Direct category buttons keep their existing behavior.

- [ ] **Step 6: Run focused tests and confirm GREEN**

Use the command from Step 2.

- [ ] **Step 7: Commit**

```bash
git add ios/BetterCallSaul ios/BetterCallSaulTests ios/BetterCallSaulUITests/PrimaryFlowUITests.swift
git commit -m "feat: route Home problems through Saul assistant"
```

## Task 6: Verify the full app, simulator experience, and repository state

**Files:**

- Modify only if verification finds a scoped defect.

- [ ] **Step 1: Generate the Xcode project and run all unit tests**

```bash
cd ios
xcodegen generate
xcodebuild test -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulTests
```

- [ ] **Step 2: Run the full UI suite with deterministic services**

```bash
cd ios
xcodebuild test -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulUITests
```

- [ ] **Step 3: Build, install, and launch in iPhone 17 Pro simulator**

```bash
cd ios
xcodebuild build -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .derivedData
xcrun simctl install booted .derivedData/Build/Products/Debug-iphonesimulator/BetterCallSaul.app
xcrun simctl launch booted kz.techvision.bettercallsaul
```

Visually verify sheet layout, keyboard reachability, mascot state changes, transition copy, Evidence narrative, and no implementation/provider labels. Do not submit a live classification during this inspection.

- [ ] **Step 4: Inspect diff and secret exposure**

```bash
git diff --check
git status --short
git diff --stat origin/codex/ai-provider-flow...HEAD
git grep -n -E 'AQ\.|sk-[A-Za-z0-9]' -- ':!ios/Config/Secrets.xcconfig'
```

Expected: no credential is introduced outside the already ignored/configured secret file and no unrelated file changed.

- [ ] **Step 5: Commit any verification-only fix, then push**

```bash
git push origin codex/ai-provider-flow
```

Expected final state: clean branch, pushed commits, all unit/UI tests green, simulator showing the new Saul assistant entry point.
