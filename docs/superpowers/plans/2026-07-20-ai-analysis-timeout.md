# Bounded AI Analysis Timeout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cap every DeepSeek request at 15 seconds and immediately use the existing local fallback when that deadline expires.

**Architecture:** Represent request timeouts as a typed provider error instead of a generic transport string. DeepSeek applies a 15-second `URLRequest` deadline, while `CaseWorkflowStore` preserves one retry for other transient failures but never retries the typed timeout.

**Tech Stack:** Swift 6, Foundation `URLSession`, Swift Concurrency, Observation, XCTest, XcodeGen, iOS 17+

## Global Constraints

- Set the DeepSeek request timeout to exactly 15 seconds for analysis and document generation.
- Never retry `AIProviderError.timedOut`.
- Preserve one retry for authentication, quota, invalid-response, and generic transport failures.
- Preserve the existing Gemini evidence request, local fallback generators, workflow states, evidence, OCR fields, and reviewed user values.
- Add no provider, timeout, local-processing, demo, or API-key labels to the public interface.
- Verify on the iPhone 17 Pro Simulator running iOS 26.5.

---

### Task 1: Typed Network Timeout and DeepSeek Deadline

**Files:**
- Modify: `ios/BetterCallSaul/AI/Infrastructure/AIProviderError.swift`
- Modify: `ios/BetterCallSaul/AI/Infrastructure/HTTPTransport.swift`
- Modify: `ios/BetterCallSaul/AI/DeepSeek/DeepSeekTextClient.swift`
- Modify: `ios/BetterCallSaulTests/HTTPTransportTests.swift`
- Modify: `ios/BetterCallSaulTests/DeepSeekTextClientTests.swift`

**Interfaces:**
- Consumes: `URLError.Code.timedOut`, `URLRequest.timeoutInterval`, and existing `AIProviderError` handling.
- Produces: `AIProviderError.timedOut`, `URLSessionHTTPTransport.mapError(_:)`, and a 15-second deadline on every request made by `DeepSeekTextClient.complete(messages:)`.

- [ ] **Step 1: Write failing timeout-mapping and request-deadline tests**

Add to `HTTPTransportTests`:

```swift
func testTimedOutURLErrorMapsToTypedTimeout() {
    XCTAssertEqual(
        URLSessionHTTPTransport.mapError(URLError(.timedOut)),
        .timedOut
    )
}
```

In `DeepSeekTextClientTests.testAnalysisRequestContainsReviewedTextButNoBinaryEvidenceFields`, add:

```swift
XCTAssertEqual(request.timeoutInterval, 15)
```

In `DeepSeekTextClientTests.testGeneratesTypedDocumentSections`, record and unwrap the request after generation, then add:

```swift
let recordedRequest = await transport.recordedRequest()
let request = try XCTUnwrap(recordedRequest)
XCTAssertEqual(request.timeoutInterval, 15)
```

- [ ] **Step 2: Run focused tests and verify RED**

```bash
cd ios
xcodegen generate
xcodebuild test -quiet -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -derivedDataPath .derivedData \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulTests/HTTPTransportTests \
  -only-testing:BetterCallSaulTests/DeepSeekTextClientTests
```

Expected: compilation fails because `AIProviderError.timedOut` and `URLSessionHTTPTransport.mapError(_:)` do not exist. The request-timeout assertions also fail against the default 60-second interval once compilation reaches them.

- [ ] **Step 3: Add the typed timeout error and mapping**

Add this case to `AIProviderError` after `payloadTooLarge`:

```swift
case timedOut
```

Add this neutral description to `errorDescription` before `.transport`:

```swift
case .timedOut:
    "Сервис обработки отвечает слишком долго."
```

Change the generic catch in `URLSessionHTTPTransport.data(for:)` and add the mapper:

```swift
        } catch let error as AIProviderError {
            throw error
        } catch {
            throw Self.mapError(error)
        }
    }

    static func mapError(_ error: Error) -> AIProviderError {
        if let urlError = error as? URLError, urlError.code == .timedOut {
            return .timedOut
        }
        return .transport(error.localizedDescription)
    }
}
```

- [ ] **Step 4: Apply the 15-second deadline to DeepSeek requests**

Add the constant beside `endpoint` in `DeepSeekTextClient`:

```swift
private static let timeoutInterval: TimeInterval = 15
```

Set it immediately after creating the request in `complete(messages:)`:

```swift
var request = URLRequest(url: Self.endpoint)
request.timeoutInterval = Self.timeoutInterval
request.httpMethod = "POST"
```

- [ ] **Step 5: Run focused tests and verify GREEN**

Run the command from Step 2.

Expected: all `HTTPTransportTests` and `DeepSeekTextClientTests` pass with zero failures.

- [ ] **Step 6: Commit the transport deadline**

```bash
git add ios/BetterCallSaul/AI/Infrastructure/AIProviderError.swift \
  ios/BetterCallSaul/AI/Infrastructure/HTTPTransport.swift \
  ios/BetterCallSaul/AI/DeepSeek/DeepSeekTextClient.swift \
  ios/BetterCallSaulTests/HTTPTransportTests.swift \
  ios/BetterCallSaulTests/DeepSeekTextClientTests.swift
git commit -m "fix: bound DeepSeek request duration"
```

---

### Task 2: Timeout-Aware Retry and Immediate Local Fallback

**Files:**
- Modify: `ios/BetterCallSaul/Domain/CaseWorkflowStore.swift`
- Modify: `ios/BetterCallSaulTests/AIWorkflowTests.swift`

**Interfaces:**
- Consumes: `AIProviderError.timedOut` from Task 1 and the existing local text generator.
- Produces: `retryOnceUnlessTimedOut(_:)`, which retries non-timeout failures once and rethrows a timeout immediately.

- [ ] **Step 1: Write failing workflow fallback tests**

Add to `AIWorkflowTests`:

```swift
func testTextTimeoutFallsBackLocallyWithoutRetry() async throws {
    let evidence = WorkflowEvidenceStub(.success(Self.evidenceAnalysis))
    let legal = WorkflowLegalStub(
        analysis: .failure(.timedOut),
        document: .success(Self.documentSections)
    )
    let local = WorkflowLegalStub(
        analysis: .success(Self.localAnalysis),
        document: .success(Self.documentSections)
    )
    let store = CaseWorkflowStore(
        seed: DemoFixtures.activeCase,
        services: AIServiceContainer(
            evidenceAnalyzer: evidence,
            legalTextGenerator: legal,
            localTextGenerator: local
        )
    )

    await store.runAIAnalysis()

    XCTAssertEqual(store.activeProvider, .local)
    XCTAssertEqual(store.caseAnalysis, Self.localAnalysis)
    if case .fallback = store.aiState {} else {
        XCTFail("Expected fallback state")
    }
    let legalAttempts = await legal.analysisAttemptCount()
    let localAttempts = await local.analysisAttemptCount()
    XCTAssertEqual(legalAttempts, 1)
    XCTAssertEqual(localAttempts, 1)
}

func testDocumentTimeoutFallsBackLocallyWithoutRetry() async throws {
    let evidence = WorkflowEvidenceStub(.success(Self.evidenceAnalysis))
    let legal = WorkflowLegalStub(
        analysis: .success(Self.caseAnalysis),
        document: .failure(.timedOut)
    )
    let local = WorkflowLegalStub(
        analysis: .success(Self.localAnalysis),
        document: .success(Self.documentSections)
    )
    let store = CaseWorkflowStore(
        seed: DemoFixtures.activeCase,
        services: AIServiceContainer(
            evidenceAnalyzer: evidence,
            legalTextGenerator: legal,
            localTextGenerator: local
        )
    )
    await store.runAIAnalysis()

    await store.generateAIDocument()

    XCTAssertEqual(store.activeProvider, .local)
    XCTAssertEqual(store.aiDocumentSections, Self.documentSections)
    if case .fallback = store.aiState {} else {
        XCTFail("Expected fallback state")
    }
    let legalAttempts = await legal.documentAttemptCount()
    let localAttempts = await local.documentAttemptCount()
    XCTAssertEqual(legalAttempts, 1)
    XCTAssertEqual(localAttempts, 1)
}
```

- [ ] **Step 2: Run the focused workflow tests and verify RED**

```bash
cd ios
xcodebuild test -quiet -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -derivedDataPath .derivedData \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulTests/AIWorkflowTests
```

Expected: the two new tests fail because the current `retryOnce` makes two legal-provider attempts after `.timedOut`.

- [ ] **Step 3: Replace unconditional retries with timeout-aware retries**

Rename all three `retryOnce` call sites in `runAIAnalysis()` and `generateAIDocument()` to `retryOnceUnlessTimedOut`.

Replace the helper with:

```swift
private func retryOnceUnlessTimedOut<T>(
    _ operation: () async throws -> T
) async throws -> T {
    do {
        return try await operation()
    } catch let error as AIProviderError where error == .timedOut {
        throw error
    } catch {
        return try await operation()
    }
}
```

- [ ] **Step 4: Run focused workflow tests and verify GREEN**

Run the command from Step 2.

Expected: all `AIWorkflowTests` pass. The existing generic transport-failure test still reports two provider attempts, while both timeout tests report exactly one.

- [ ] **Step 5: Run the complete automated suite**

```bash
cd ios
RESULT='/tmp/BetterCallSaulAITimeout.xcresult'
if [ -e "$RESULT" ]; then mv "$RESULT" "${RESULT}.previous.$(date +%s)"; fi
xcodebuild test -quiet -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -derivedDataPath .derivedData \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -resultBundlePath "$RESULT"
xcrun xcresulttool get test-results summary --path "$RESULT"
```

Expected: `result` is `Passed`, `failedTests` is `0`, and `skippedTests` is `0`.

- [ ] **Step 6: Install and manually verify the receipt workflow**

```bash
cd ios
xcrun simctl bootstatus 'iPhone 17 Pro' -b
xcrun simctl install 'iPhone 17 Pro' \
  .derivedData/Build/Products/Debug-iphonesimulator/BetterCallSaul.app
xcrun simctl terminate 'iPhone 17 Pro' kz.techvision.bettercallsaul || true
xcrun simctl launch 'iPhone 17 Pro' kz.techvision.bettercallsaul
```

Manual assertion: select the existing receipt, open step 3, and measure the progress state. Gemini may use its measured image-analysis duration, but after DeepSeek begins, the application must leave the progress state within 15 seconds and display either DeepSeek analysis or the local fallback. Confirm `Подготовить документ` is enabled.

- [ ] **Step 7: Commit and push the workflow fix**

```bash
git add ios/BetterCallSaul/Domain/CaseWorkflowStore.swift \
  ios/BetterCallSaulTests/AIWorkflowTests.swift
git commit -m "fix: skip retry after AI timeout"
git push origin codex/ai-provider-flow
```
