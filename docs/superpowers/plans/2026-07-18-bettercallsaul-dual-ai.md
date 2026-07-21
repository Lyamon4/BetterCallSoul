# BetterCallSaul Dual-AI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a direct iOS pipeline where Gemini analyzes image/PDF evidence, DeepSeek handles text-only case reasoning and document generation, and the existing local workflow remains the fallback.

**Architecture:** Provider-independent Swift protocols isolate two REST clients from `CaseWorkflowStore`. Evidence bytes live only in memory and can flow only to `GeminiVisionClient`; DeepSeek request types contain text-only reviewed facts and answers. The UI adds one structured analysis/questions screen between Evidence and Document while preserving local Vision OCR, local templates, PDF rendering, and Share Sheet behavior.

**Tech Stack:** Swift 6, SwiftUI, Observation, URLSession, Security/Keychain, Apple Vision, PDFKit, XCTest, XcodeGen, Gemini Interactions REST API, DeepSeek Chat Completions REST API.

## Global Constraints

- Target iOS 17.0 or newer and keep the existing warm editorial visual system.
- Do not add a backend, database, account system, or third-party Swift dependency.
- Gemini may receive image/PDF bytes only after an explicit disclosure.
- DeepSeek must receive text and JSON only; it must never receive `Data`, base64 evidence, MIME payloads, or file URLs.
- Provider JSON is decoded into typed models; unknown facts remain `nil` and cannot be invented.
- Retain Apple Vision OCR and deterministic `DocumentDraftGenerator` as automatic fallbacks.
- Do not make live Gemini or DeepSeek calls during implementation verification; the repository owner performs the real-provider workflow manually.
- Keep provider keys out of logs, test output, UI accessibility values, screenshots, and plan/spec files.
- Commit after every green task and push `codex/ai-provider-flow` after the final verification.

---

### Task 1: Provider configuration, Keychain override, and HTTP boundary

**Files:**
- Create: `ios/Config/Secrets.xcconfig`
- Create: `ios/BetterCallSaul/AI/Infrastructure/AIConfiguration.swift`
- Create: `ios/BetterCallSaul/AI/Infrastructure/AIProviderError.swift`
- Create: `ios/BetterCallSaul/AI/Infrastructure/HTTPTransport.swift`
- Create: `ios/BetterCallSaul/AI/Infrastructure/KeychainSecretStore.swift`
- Modify: `ios/project.yml`
- Test: `ios/BetterCallSaulTests/AIConfigurationTests.swift`
- Test: `ios/BetterCallSaulTests/HTTPTransportTests.swift`

**Interfaces:**
- Produces: `AIConfiguration`, `AIProvider`, `AIProviderError`, `HTTPTransport`, `URLSessionHTTPTransport`, and `KeychainSecretStore`.
- Consumes: bundled Info.plist settings generated from XcodeGen and optional Keychain overrides.

- [ ] **Step 1: Write failing configuration and error-mapping tests**

```swift
import XCTest
@testable import BetterCallSaul

final class AIConfigurationTests: XCTestCase {
    func testBundledConfigurationReportsBothProviders() throws {
        let values = [
            "GeminiAPIKey": "gemini-test-key",
            "GeminiModel": "gemini-3.5-flash",
            "DeepSeekAPIKey": "deepseek-test-key",
            "DeepSeekModel": "deepseek-v4-pro"
        ]
        let configuration = try AIConfiguration(values: values)

        XCTAssertEqual(configuration.geminiModel, "gemini-3.5-flash")
        XCTAssertEqual(configuration.deepSeekModel, "deepseek-v4-pro")
        XCTAssertEqual(configuration.maskedGeminiKey, "••••-key")
        XCTAssertEqual(configuration.maskedDeepSeekKey, "••••-key")
    }

    func testMissingKeyProducesConfigurationError() {
        XCTAssertThrowsError(try AIConfiguration(values: [:])) { error in
            XCTAssertEqual(error as? AIProviderError, .missingKey(.gemini))
        }
    }
}

final class HTTPTransportTests: XCTestCase {
    func testStatusMappingPreservesQuotaFailure() {
        XCTAssertEqual(AIProviderError.httpStatus(429, provider: .deepSeek), .quotaExceeded(.deepSeek))
        XCTAssertEqual(AIProviderError.httpStatus(401, provider: .gemini), .authenticationFailed(.gemini))
    }
}
```

- [ ] **Step 2: Run focused tests and confirm RED**

Run:

```bash
cd ios
xcodegen generate
xcodebuild test -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulTests/AIConfigurationTests \
  -only-testing:BetterCallSaulTests/HTTPTransportTests CODE_SIGNING_ALLOWED=NO
```

Expected: build failure because `AIConfiguration` and `AIProviderError` do not exist.

- [ ] **Step 3: Add the infrastructure types**

Implement these exact public-to-module interfaces:

```swift
enum AIProvider: String, Codable, Sendable { case gemini, deepSeek, local }

enum AIProviderError: Error, Equatable, LocalizedError, Sendable {
    case missingKey(AIProvider)
    case invalidConfiguration(String)
    case authenticationFailed(AIProvider)
    case quotaExceeded(AIProvider)
    case invalidResponse(AIProvider)
    case payloadTooLarge(maximumMB: Int)
    case transport(String)

    static func httpStatus(_ status: Int, provider: AIProvider) -> Self {
        switch status {
        case 401, 403: .authenticationFailed(provider)
        case 429: .quotaExceeded(provider)
        default: .invalidResponse(provider)
        }
    }
}

struct AIConfiguration: Equatable, Sendable {
    let geminiAPIKey: String
    let geminiModel: String
    let deepSeekAPIKey: String
    let deepSeekModel: String

    init(values: [String: String]) throws
    static func bundled(bundle: Bundle = .main, secrets: KeychainSecretStore = .init()) throws -> Self
    var maskedGeminiKey: String { get }
    var maskedDeepSeekKey: String { get }
}

protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionHTTPTransport: HTTPTransport {
    let session: URLSession
    init(session: URLSession = .shared)
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct KeychainSecretStore: Sendable {
    func read(account: String) -> String?
    func write(_ value: String, account: String) throws
    func delete(account: String) throws
}
```

`Secrets.xcconfig` receives the two owner-provided credentials exactly once during implementation and these non-secret model settings:

```xcconfig
GEMINI_MODEL = gemini-3.5-flash
DEEPSEEK_MODEL = deepseek-v4-pro
```

Do not duplicate credential values in this plan, tests, commit messages, or terminal output.

Update `project.yml` so both Debug and Release use `Config/Secrets.xcconfig`, and map settings to Info.plist:

```yaml
configFiles:
  Debug: Config/Secrets.xcconfig
  Release: Config/Secrets.xcconfig
settings:
  base:
    INFOPLIST_KEY_GeminiAPIKey: $(GEMINI_API_KEY)
    INFOPLIST_KEY_GeminiModel: $(GEMINI_MODEL)
    INFOPLIST_KEY_DeepSeekAPIKey: $(DEEPSEEK_API_KEY)
    INFOPLIST_KEY_DeepSeekModel: $(DEEPSEEK_MODEL)
```

- [ ] **Step 4: Run focused tests and confirm GREEN**

Expected: both test classes pass with 0 failures and no full key appears in output.

- [ ] **Step 5: Commit the configuration boundary**

```bash
git add ios/Config/Secrets.xcconfig ios/BetterCallSaul/AI/Infrastructure ios/BetterCallSaulTests/AIConfigurationTests.swift ios/BetterCallSaulTests/HTTPTransportTests.swift ios/project.yml
git commit -m "feat: add direct AI provider configuration"
```

### Task 2: Typed AI domain and in-memory evidence payload

**Files:**
- Create: `ios/BetterCallSaul/AI/Domain/AIModels.swift`
- Create: `ios/BetterCallSaul/AI/Domain/AIProtocols.swift`
- Modify: `ios/BetterCallSaul/Services/EvidenceImporter.swift`
- Test: `ios/BetterCallSaulTests/EvidencePayloadTests.swift`
- Test: `ios/BetterCallSaulTests/AIModelsTests.swift`

**Interfaces:**
- Produces: `EvidencePayload`, `EvidenceAnalysis`, `CaseAIRequest`, `CaseAIAnalysis`, `AIQuestion`, `AIAnswer`, `AIDocumentRequest`, `AIDocumentSections`, `EvidenceAnalyzing`, and `LegalTextGenerating`.
- Consumes: `CaseType`, `ExtractedField`, and `ImportedEvidence`.

- [ ] **Step 1: Write failing evidence isolation and Codable tests**

```swift
@MainActor
final class EvidencePayloadTests: XCTestCase {
    func testImageImporterProducesGeminiPayloadAndPreview() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let data = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 80), format: format)
            .jpegData(withCompressionQuality: 0.9) { _ in UIColor.white.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 120, height: 80)) }

        let imported = try EvidenceImporter().importImageData(data, fileName: "receipt.jpg")

        XCTAssertEqual(imported.payload.mimeType, "image/jpeg")
        XCTAssertFalse(imported.payload.data.isEmpty)
        XCTAssertEqual(imported.item.fileName, "receipt.jpg")
    }
}

final class AIModelsTests: XCTestCase {
    func testEvidenceAnalysisAllowsUnknownFacts() throws {
        let json = #"{"documentKind":"receipt","rawText":"Оплата","counterparty":null,"amount":null,"currency":"KZT","transactionDate":null,"evidenceSummary":"Чек","importantDetails":[],"warnings":[],"confidence":{}}"#.data(using: .utf8)!
        let result = try JSONDecoder().decode(EvidenceAnalysis.self, from: json)
        XCTAssertNil(result.counterparty)
        XCTAssertNil(result.amount)
    }
}
```

- [ ] **Step 2: Run the two test classes and confirm RED**

Expected: compiler cannot find `EvidencePayload` and `EvidenceAnalysis`.

- [ ] **Step 3: Implement the complete shared models and protocols**

```swift
struct EvidencePayload: @unchecked Sendable {
    let fileName: String
    let mimeType: String
    let data: Data
    let previewImage: CGImage
}

struct EvidenceAnalysis: Codable, Equatable, Sendable {
    let documentKind: String
    let rawText: String
    let counterparty: String?
    let amount: Decimal?
    let currency: String?
    let transactionDate: String?
    let evidenceSummary: String
    let importantDetails: [String]
    let warnings: [String]
    let confidence: [String: Double]
}

enum AIQuestionKind: String, Codable, Sendable { case text, choice, date, amount, boolean }

struct AIQuestion: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let kind: AIQuestionKind
    let prompt: String
    let whyNeeded: String
    let options: [String]
    let required: Bool
}

struct AIAnswer: Codable, Equatable, Sendable { let questionID: String; let value: String }

struct CaseAIRequest: Codable, Equatable, Sendable {
    let caseType: CaseType
    let narrative: String
    let reviewedFields: [String: String]
    let evidenceSummary: String?
    let answers: [AIAnswer]
}

struct CaseAIAnalysis: Codable, Equatable, Sendable {
    let summary: String
    let recommendedAction: String
    let warnings: [String]
    let questions: [AIQuestion]
}

struct AIDocumentRequest: Codable, Equatable, Sendable {
    let caseContext: CaseAIRequest
    let analysis: CaseAIAnalysis
}

struct AIDocumentSections: Codable, Equatable, Sendable {
    let recipient: String?
    let subject: String
    let facts: [String]
    let demands: [String]
    let responseDays: Int?
    let attachmentDescription: String
    let unresolvedIssues: [String]
}

protocol EvidenceAnalyzing: Sendable {
    func analyze(payload: EvidencePayload, caseType: CaseType, narrative: String) async throws -> EvidenceAnalysis
}

protocol LegalTextGenerating: Sendable {
    func analyzeCase(_ request: CaseAIRequest) async throws -> CaseAIAnalysis
    func generateDocument(_ request: AIDocumentRequest) async throws -> AIDocumentSections
}
```

Extend `ImportedEvidence` with `payload`, preserve its preview `image`, normalize images to JPEG, retain PDF bytes with `application/pdf`, and reject provider payloads over 10 MB with `AIProviderError.payloadTooLarge(maximumMB: 10)`.

- [ ] **Step 4: Run focused tests and all existing evidence tests**

Expected: `EvidencePayloadTests`, `AIModelsTests`, and `EvidenceImporterTests` pass.

- [ ] **Step 5: Commit the typed domain**

```bash
git add ios/BetterCallSaul/AI/Domain ios/BetterCallSaul/Services/EvidenceImporter.swift ios/BetterCallSaulTests/EvidencePayloadTests.swift ios/BetterCallSaulTests/AIModelsTests.swift ios/BetterCallSaulTests/EvidenceImporterTests.swift
git commit -m "feat: add typed AI workflow models"
```

### Task 3: Gemini Vision request, schema, and response decoder

**Files:**
- Create: `ios/BetterCallSaul/AI/Gemini/GeminiVisionClient.swift`
- Create: `ios/BetterCallSaul/AI/Gemini/GeminiEvidencePrompt.swift`
- Create: `ios/BetterCallSaul/AI/Gemini/GeminiWireModels.swift`
- Test: `ios/BetterCallSaulTests/GeminiVisionClientTests.swift`

**Interfaces:**
- Consumes: `EvidenceAnalyzing`, `EvidencePayload`, `EvidenceAnalysis`, `HTTPTransport`, and Gemini values from `AIConfiguration`.
- Produces: `GeminiVisionClient: EvidenceAnalyzing`.

- [ ] **Step 1: Write failing request-isolation and decoding tests with a stub transport**

```swift
actor StubHTTPTransport: HTTPTransport {
    let responseData: Data
    private(set) var lastRequest: URLRequest?
    init(responseData: Data) { self.responseData = responseData }
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (responseData, response)
    }
}

final class GeminiVisionClientTests: XCTestCase {
    func testRequestContainsInlineVisualDataAndSchema() async throws {
        let analysisJSON = #"{"documentKind":"receipt","rawText":"MEGAPLUS","counterparty":"MegaPlus","amount":24900,"currency":"KZT","transactionDate":"2026-07-17","evidenceSummary":"Списание","importantDetails":[],"warnings":[],"confidence":{"amount":0.99}}"#
        let envelope = try JSONSerialization.data(withJSONObject: [
            "status": "completed",
            "steps": [[
                "type": "model_output",
                "content": [["type": "text", "text": analysisJSON]]
            ]]
        ])
        let transport = StubHTTPTransport(responseData: envelope)
        let client = GeminiVisionClient(apiKey: "test-key", model: "gemini-3.5-flash", transport: transport)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let preview = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }.cgImage!
        let payload = EvidencePayload(fileName: "receipt.jpg", mimeType: "image/jpeg", data: Data([1, 2, 3]), previewImage: preview)

        let result = try await client.analyze(payload: payload, caseType: .subscription, narrative: "Верните списание")
        let request = try XCTUnwrap(await transport.lastRequest)
        let body = try XCTUnwrap(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })

        XCTAssertEqual(result.amount, 24_900)
        XCTAssertTrue(body.contains(payload.data.base64EncodedString()))
        XCTAssertTrue(body.contains("response_format"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-goog-api-key"), "test-key")
    }
}
```

- [ ] **Step 2: Run `GeminiVisionClientTests` and confirm RED**

Expected: compiler cannot find `GeminiVisionClient`.

- [ ] **Step 3: Implement the Gemini Interactions client**

Use this exact request contract:

```swift
struct GeminiVisionClient: EvidenceAnalyzing {
    let apiKey: String
    let model: String
    let transport: any HTTPTransport

    func analyze(payload: EvidencePayload, caseType: CaseType, narrative: String) async throws -> EvidenceAnalysis
}

struct GeminiInteractionRequest: Encodable {
    let model: String
    let input: [GeminiInput]
    let responseFormat: GeminiResponseFormat
    enum CodingKeys: String, CodingKey { case model, input; case responseFormat = "response_format" }
}

struct GeminiInput: Encodable {
    let type: String
    let text: String?
    let data: String?
    let mimeType: String?
    enum CodingKeys: String, CodingKey { case type, text, data; case mimeType = "mime_type" }
}
```

POST to `https://generativelanguage.googleapis.com/v1beta/interactions`, set `x-goog-api-key`, encode prompt first and visual input second (`type = image` or `document`), and include a JSON response schema whose required fields exactly match `EvidenceAnalysis`.

Decode the last `steps[type == "model_output"].content[type == "text"].text` value, then decode that string as `EvidenceAnalysis`. Reject non-`completed` status or missing text with `.invalidResponse(.gemini)`.

`GeminiEvidencePrompt.make(caseType:narrative:)` must state in Russian and English that only visible evidence may be extracted and missing facts must be JSON `null`.

- [ ] **Step 4: Run Gemini tests and confirm GREEN**

Expected: request body contains visual data/schema, response decodes, and no external network call occurs.

- [ ] **Step 5: Commit Gemini Vision**

```bash
git add ios/BetterCallSaul/AI/Gemini ios/BetterCallSaulTests/GeminiVisionClientTests.swift
git commit -m "feat: analyze evidence with Gemini Vision"
```

### Task 4: DeepSeek text-only analysis and document generation

**Files:**
- Create: `ios/BetterCallSaul/AI/DeepSeek/DeepSeekTextClient.swift`
- Create: `ios/BetterCallSaul/AI/DeepSeek/DeepSeekPrompts.swift`
- Create: `ios/BetterCallSaul/AI/DeepSeek/DeepSeekWireModels.swift`
- Test: `ios/BetterCallSaulTests/DeepSeekTextClientTests.swift`
- Test: `ios/BetterCallSaulTests/CasePromptCoverageTests.swift`

**Interfaces:**
- Consumes: `LegalTextGenerating`, `CaseAIRequest`, `CaseAIAnalysis`, `AIDocumentRequest`, `AIDocumentSections`, `HTTPTransport`, and DeepSeek configuration.
- Produces: `DeepSeekTextClient: LegalTextGenerating` and `DeepSeekPrompts` for five case types.

- [ ] **Step 1: Write failing tests proving DeepSeek receives text only**

```swift
final class DeepSeekTextClientTests: XCTestCase {
    private func responseData(content: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "choices": [[
                "finish_reason": "stop",
                "message": ["role": "assistant", "content": content]
            ]]
        ])
    }

    func testAnalysisRequestContainsTextJSONButNoBinaryFields() async throws {
        let analysis = #"{"summary":"Нежелательное продление","recommendedAction":"Запросить отмену и возврат","warnings":[],"questions":[]}"#
        let transport = StubHTTPTransport(responseData: try responseData(content: analysis))
        let client = DeepSeekTextClient(apiKey: "test-key", model: "deepseek-v4-pro", transport: transport)
        let requestModel = CaseAIRequest(caseType: .subscription, narrative: "Списали деньги", reviewedFields: ["Сумма":"24 900 ₸"], evidenceSummary: "Чек", answers: [])

        _ = try await client.analyzeCase(requestModel)
        let body = String(data: try XCTUnwrap(await transport.lastRequest?.httpBody), encoding: .utf8)!

        XCTAssertTrue(body.contains("24 900"))
        XCTAssertFalse(body.contains("base64"))
        XCTAssertFalse(body.contains("mime_type"))
        XCTAssertFalse(body.contains("fileName"))
    }

    func testRejectsMoreThanFiveQuestions() async throws {
        let questions = (1...6).map {
            [
                "id": "q\($0)", "kind": "text", "prompt": "Вопрос \($0)",
                "whyNeeded": "Нужно для документа", "options": [], "required": true
            ] as [String: Any]
        }
        let analysis = try JSONSerialization.data(withJSONObject: [
            "summary": "Итог", "recommendedAction": "Подать претензию",
            "warnings": [], "questions": questions
        ])
        let content = String(decoding: analysis, as: UTF8.self)
        let transport = StubHTTPTransport(responseData: try responseData(content: content))
        let client = DeepSeekTextClient(apiKey: "test-key", model: "deepseek-v4-pro", transport: transport)
        let request = CaseAIRequest(
            caseType: .subscription,
            narrative: "Списали деньги",
            reviewedFields: [:],
            evidenceSummary: nil,
            answers: []
        )

        do {
            _ = try await client.analyzeCase(request)
            XCTFail("Expected more than five questions to be rejected")
        } catch {
            XCTAssertEqual(error as? AIProviderError, .invalidResponse(.deepSeek))
        }
    }
}
```

- [ ] **Step 2: Run DeepSeek and prompt coverage tests and confirm RED**

Expected: compiler cannot find `DeepSeekTextClient` and `DeepSeekPrompts`.

- [ ] **Step 3: Implement the text-only DeepSeek client**

```swift
struct DeepSeekTextClient: LegalTextGenerating {
    let apiKey: String
    let model: String
    let transport: any HTTPTransport

    func analyzeCase(_ request: CaseAIRequest) async throws -> CaseAIAnalysis
    func generateDocument(_ request: AIDocumentRequest) async throws -> AIDocumentSections
}

struct DeepSeekChatRequest: Encodable {
    let model: String
    let messages: [DeepSeekMessage]
    let responseFormat: DeepSeekResponseFormat
    let stream: Bool
    enum CodingKeys: String, CodingKey { case model, messages, stream; case responseFormat = "response_format" }
}

struct DeepSeekMessage: Codable { let role: String; let content: String }
struct DeepSeekResponseFormat: Codable { let type = "json_object" }
```

POST to `https://api.deepseek.com/chat/completions`, set `Authorization: Bearer <key>`, set `stream = false`, and include explicit JSON shapes in the system prompt. Decode `choices[0].message.content`; accept only `finish_reason == "stop"` and reject an analysis containing more than five questions.

`DeepSeekPrompts.requiredFacts(for:)` must return a non-empty distinct list for every `CaseType`. Analysis prompts forbid citations and document prompts forbid facts not present in `CaseAIRequest`/answers.

- [ ] **Step 4: Run DeepSeek and five-case prompt tests and confirm GREEN**

Expected: both DeepSeek operations decode, the binary-field assertions remain false, and all five case types have prompt coverage.

- [ ] **Step 5: Commit DeepSeek Text**

```bash
git add ios/BetterCallSaul/AI/DeepSeek ios/BetterCallSaulTests/DeepSeekTextClientTests.swift ios/BetterCallSaulTests/CasePromptCoverageTests.swift
git commit -m "feat: generate legal text with DeepSeek"
```

### Task 5: Orchestrate AI states, one retry, and deterministic fallbacks

**Files:**
- Create: `ios/BetterCallSaul/AI/Infrastructure/AIServiceContainer.swift`
- Create: `ios/BetterCallSaul/AI/Fallback/LocalLegalTextGenerator.swift`
- Create: `ios/BetterCallSaul/AI/Domain/AIDocumentAdapter.swift`
- Modify: `ios/BetterCallSaul/Domain/CaseWorkflowStore.swift`
- Modify: `ios/BetterCallSaul/Domain/DocumentDraft.swift`
- Test: `ios/BetterCallSaulTests/AIWorkflowTests.swift`
- Test: `ios/BetterCallSaulTests/AIDocumentAdapterTests.swift`

**Interfaces:**
- Consumes: both provider protocols, local `ReceiptFieldParser`, local `DocumentDraftGenerator`, and typed AI models.
- Produces: async workflow operations used by Evidence/Analysis/Document views and `AIDocumentAdapter.makeDraft`.

- [ ] **Step 1: Write failing success/fallback workflow tests**

```swift
@MainActor
final class AIWorkflowTests: XCTestCase {
    func testVisualAnalysisUpdatesEditableCaseFacts() async {
        let fixture = AIWorkflowFixture.success()
        let store = CaseWorkflowStore(seed: DemoFixtures.activeCase, services: fixture.services)
        store.attachEvidence(fixture.importedEvidence)

        await store.runAIAnalysis()

        XCTAssertEqual(store.aiState, .questions)
        XCTAssertEqual(store.currentCase.counterparty, "MegaPlus")
        XCTAssertEqual(store.caseAnalysis?.questions.count, 1)
        XCTAssertEqual(store.activeProvider, .deepSeek)
    }

    func testProviderFailurePreservesCaseAndUsesLocalFallback() async {
        let fixture = AIWorkflowFixture.failure()
        let store = CaseWorkflowStore(seed: DemoFixtures.activeCase, services: fixture.services)
        let originalCase = store.currentCase

        await store.runAIAnalysis()

        XCTAssertEqual(store.currentCase.id, originalCase.id)
        XCTAssertEqual(store.activeProvider, .local)
        XCTAssertNotNil(store.caseAnalysis)
    }
}
```

In the same test file, implement `AIWorkflowFixture.success()` and `.failure()` as complete factories. Each factory creates a 1×1 JPEG-backed `ImportedEvidence`, an `EvidenceAnalyzing` actor stub, and `LegalTextGenerating` actor stubs. The success stubs return a `MegaPlus` evidence result plus exactly one question; the failure stubs throw `AIProviderError.transport("offline")`; the local stub always returns a deterministic zero-question analysis/document. Do not add force-unwrapped shared globals or any network-backed client to this fixture.

- [ ] **Step 2: Run the new tests and confirm RED**

Expected: `CaseWorkflowStore` has no AI state or injected services.

- [ ] **Step 3: Implement explicit workflow state and fallback**

```swift
enum AIWorkflowState: Equatable {
    case idle, analyzingEvidence, analyzingText, questions, generatingDocument, ready, fallback(String)
}

struct AIServiceContainer: Sendable {
    let evidenceAnalyzer: any EvidenceAnalyzing
    let legalTextGenerator: any LegalTextGenerating
    let localTextGenerator: any LegalTextGenerating
    static func live(configuration: AIConfiguration, transport: any HTTPTransport = URLSessionHTTPTransport()) -> Self
    static var uiTesting: Self { get }
}
```

Extend `CaseWorkflowStore` with these exact properties and operations:

```swift
private(set) var narrative = ""
private(set) var evidencePayload: EvidencePayload?
private(set) var evidenceAnalysis: EvidenceAnalysis?
private(set) var caseAnalysis: CaseAIAnalysis?
private(set) var answers: [String: String] = [:]
private(set) var aiDocumentSections: AIDocumentSections?
private(set) var aiState: AIWorkflowState = .idle
private(set) var activeProvider: AIProvider = .local

func updateNarrative(_ value: String)
func attachEvidence(_ imported: ImportedEvidence)
func setAnswer(questionID: String, value: String)
func runAIAnalysis() async
func generateAIDocument() async
func resolvedDocumentDraft(senderName: String, createdAt: Date) -> DocumentDraft
```

For each provider operation, attempt the exact same request at most twice. After the second failure, use `LocalLegalTextGenerator`, keep all current fields/answers, and set `.fallback(error.localizedDescription)`. `AIDocumentAdapter` joins AI facts/demands into `DocumentDraft.body` but marks every `unresolvedIssue` for review.

- [ ] **Step 4: Run workflow, adapter, store, and document tests**

Expected: provider success and fallback pass without external requests; all pre-existing store/PDF tests remain green.

- [ ] **Step 5: Commit orchestration**

```bash
git add ios/BetterCallSaul/AI/Infrastructure/AIServiceContainer.swift ios/BetterCallSaul/AI/Fallback ios/BetterCallSaul/AI/Domain/AIDocumentAdapter.swift ios/BetterCallSaul/Domain/CaseWorkflowStore.swift ios/BetterCallSaul/Domain/DocumentDraft.swift ios/BetterCallSaulTests/AIWorkflowTests.swift ios/BetterCallSaulTests/AIDocumentAdapterTests.swift
git commit -m "feat: orchestrate AI workflow with local fallback"
```

### Task 6: Evidence disclosure, analysis/questions UI, and AI document preview

**Files:**
- Create: `ios/BetterCallSaul/Features/AIAnalysis/AIAnalysisView.swift`
- Create: `ios/BetterCallSaul/Features/AIAnalysis/AIQuestionControl.swift`
- Modify: `ios/BetterCallSaul/App/AppRouter.swift`
- Modify: `ios/BetterCallSaul/App/AppRootView.swift`
- Modify: `ios/BetterCallSaul/App/BetterCallSaulApp.swift`
- Modify: `ios/BetterCallSaul/Features/Evidence/EvidenceView.swift`
- Modify: `ios/BetterCallSaul/Features/Document/DocumentView.swift`
- Modify: `ios/BetterCallSaulUITests/PrimaryFlowUITests.swift`

**Interfaces:**
- Consumes: the Task 5 `CaseWorkflowStore` operations and existing router/design system.
- Produces: route `.aiAnalysis`, structured questions UI, provider/fallback status, and AI-aware document preview.

- [ ] **Step 1: Add a failing deterministic UI-flow test**

```swift
func testEvidenceToAIQuestionsToDocumentFlow() {
    app.buttons["caseType.subscription"].tap()
    XCTAssertTrue(app.textViews["caseNarrativeField"].waitForExistence(timeout: 2))
    app.textViews["caseNarrativeField"].tap()
    app.textViews["caseNarrativeField"].typeText("Подписка продлилась без предупреждения")
    app.buttons["continueToAIButton"].tap()

    XCTAssertTrue(app.staticTexts["Разберём ситуацию"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["DeepSeek"].exists || app.staticTexts["Локальный режим"].exists)
    app.buttons["prepareAIDocumentButton"].tap()

    XCTAssertTrue(app.staticTexts["Претензия готова"].waitForExistence(timeout: 3))
}
```

- [ ] **Step 2: Run the single UI test and confirm RED**

Expected: `caseNarrativeField` does not exist.

- [ ] **Step 3: Implement routing and views**

Add `.aiAnalysis` to `AppRoute`. `EvidenceView` adds a `TextEditor` bound through `workflow.updateNarrative`, uses identifier `caseNarrativeField`, and changes the primary action to `Проанализировать ситуацию`/`continueToAIButton`.

Before a visual payload can be analyzed, show this disclosure:

```swift
Text("Выбранный документ будет передан Gemini для визуального анализа. DeepSeek получит только распознанный и подтверждённый текст.")
```

`AIAnalysisView` starts `await workflow.runAIAnalysis()` once, renders progress for `.analyzingEvidence`/`.analyzingText`, renders reviewed extracted fields, summary, warnings, and at most five `AIQuestionControl` values. Its primary action calls `await workflow.generateAIDocument()` and routes to `.document` only after the store reaches `.ready` or `.fallback` with a resolved local draft.

`AIQuestionControl` maps `.choice` to a `Picker`, `.boolean` to a two-choice segmented picker, and `.text`/`.date`/`.amount` to labeled text fields. Each value writes through `setAnswer(questionID:value:)`.

`DocumentView` replaces its computed local draft with:

```swift
private var draft: DocumentDraft {
    workflow.resolvedDocumentDraft(senderName: "Алим", createdAt: createdAt)
}
```

In `BetterCallSaulApp`, build `.uiTesting` services for `-ui-testing`; otherwise load `AIConfiguration.bundled()` and create `.live`. If configuration fails, create local-only services so the app still launches.

- [ ] **Step 4: Run the new UI test plus all unit tests**

Expected: deterministic fixture reaches Document without a provider request and all unit tests pass.

- [ ] **Step 5: Commit the AI user flow**

```bash
git add ios/BetterCallSaul/Features/AIAnalysis ios/BetterCallSaul/Features/Evidence/EvidenceView.swift ios/BetterCallSaul/Features/Document/DocumentView.swift ios/BetterCallSaul/App ios/BetterCallSaulUITests/PrimaryFlowUITests.swift
git commit -m "feat: add guided AI analysis flow"
```

### Task 7: Profile provider status and Keychain rotation

**Files:**
- Modify: `ios/BetterCallSaul/Features/Profile/ProfileView.swift`
- Create: `ios/BetterCallSaul/Features/Profile/AISettingsView.swift`
- Test: `ios/BetterCallSaulTests/AISettingsTests.swift`
- Modify: `ios/BetterCallSaulUITests/PrimaryFlowUITests.swift`

**Interfaces:**
- Consumes: `AIConfiguration`, masked key accessors, and `KeychainSecretStore`.
- Produces: configuration-only provider status and local credential override UI with no connectivity call.

- [ ] **Step 1: Write failing masking/status tests**

```swift
final class AISettingsTests: XCTestCase {
    func testStatusNeverExposesFullCredential() throws {
        let configuration = try AIConfiguration(values: [
            "GeminiAPIKey": "full-private-gemini-key",
            "GeminiModel": "gemini-3.5-flash",
            "DeepSeekAPIKey": "full-private-deepseek-key",
            "DeepSeekModel": "deepseek-v4-pro"
        ])

        XCTAssertFalse(configuration.maskedGeminiKey.contains("full-private"))
        XCTAssertFalse(configuration.maskedDeepSeekKey.contains("full-private"))
        XCTAssertTrue(configuration.maskedGeminiKey.hasPrefix("••••"))
    }
}
```

- [ ] **Step 2: Run `AISettingsTests` and confirm RED if masking is incomplete**

Expected: test fails until masking returns only the last four characters.

- [ ] **Step 3: Implement the settings UI without test requests**

`ProfileView` links to `AISettingsView`. The settings view shows provider, model, `ключ добавлен`, and masked suffix. Secure fields let the owner save/delete Keychain overrides under accounts `gemini.apiKey` and `deepseek.apiKey`. Saving displays only `Ключ сохранён локально`; it does not instantiate a provider client or make a request.

Add UI identifiers `geminiConfiguredStatus` and `deepSeekConfiguredStatus`. Add a UI assertion that both statuses exist, without checking secret values.

- [ ] **Step 4: Run settings unit/UI tests**

Expected: status is present, secrets are masked, and no network stub records a request.

- [ ] **Step 5: Commit provider settings**

```bash
git add ios/BetterCallSaul/Features/Profile ios/BetterCallSaulTests/AISettingsTests.swift ios/BetterCallSaulUITests/PrimaryFlowUITests.swift
git commit -m "feat: show and rotate AI provider keys"
```

### Task 8: Full local verification, simulator launch, and publish

**Files:**
- Modify only if verification identifies a concrete defect.

**Interfaces:**
- Consumes: the complete app.
- Produces: a clean pushed feature branch without making live provider calls.

- [ ] **Step 1: Verify no DeepSeek request model can encode evidence bytes**

Run:

```bash
rg -n "EvidencePayload|base64EncodedString|mimeType|mime_type" ios/BetterCallSaul/AI/DeepSeek
```

Expected: no matches for payload/base64/MIME symbols in the DeepSeek directory.

- [ ] **Step 2: Verify provider keys are not printed outside the authorized config file**

Run a path-only inspection that does not print matching lines:

```bash
git grep -l -E 'GEMINI_API_KEY|DEEPSEEK_API_KEY' -- ios
```

Expected: only `ios/Config/Secrets.xcconfig`, `ios/project.yml`, and configuration source references; no tests, prompts, or UI files.

- [ ] **Step 3: Run the full local suite**

```bash
cd ios
xcodegen generate
xcodebuild test -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO
```

Expected: every unit and UI test passes with 0 failures; provider transports are stubbed and no live API request is made.

- [ ] **Step 4: Build, install, and launch the non-testing app**

```bash
xcodebuild build -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO
xcrun simctl install booted "$HOME/Library/Developer/Xcode/DerivedData/BetterCallSaul-ftaqlpymzdfrrhbliffvtmcpbtle/Build/Products/Debug-iphonesimulator/BetterCallSaul.app"
xcrun simctl launch booted kz.techvision.bettercallsaul
```

Expected: the app reaches Home and waits for user action; no startup provider request occurs.

- [ ] **Step 5: Inspect and publish**

```bash
git diff --check
git status --short --branch
git push -u origin codex/ai-provider-flow
```

Expected: clean worktree and branch synchronized with `origin/codex/ai-provider-flow`.
