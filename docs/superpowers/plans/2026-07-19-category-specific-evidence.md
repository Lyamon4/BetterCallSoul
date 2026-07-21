# Category-Specific Evidence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make all five BetterCallSaul categories display distinct evidence copy, narrative guidance, upload guidance, and structured fields without duplicating the SwiftUI flow.

**Architecture:** Add typed presentation metadata to `CaseType` and stable semantic identities to extracted fields. The shared screen, OCR, Gemini merging, local fallback, and document facts consume the same metadata while AI requests continue carrying `CaseType` separately.

**Tech Stack:** Swift 6, SwiftUI, Observation, XCTest/XCUITest, XcodeGen, iOS 17+

## Global Constraints

- Keep one reusable `EvidenceView`; do not create five screens.
- Preserve the existing visual system, animation, navigation, and four-step workflow.
- Keep DeepSeek as the primary text provider and Gemini as image analysis/fallback.
- Do not show provider, local-processing, demo, or API-key language in UI.
- Keep photo, PNG, JPG, and PDF importing unchanged.
- Unknown values remain empty and editable; automated tests make no live API calls.

---

### Task 1: Typed Category Presentation

**Files:**
- Create: `ios/BetterCallSaul/Domain/CaseTypePresentation.swift`
- Create: `ios/BetterCallSaulTests/CaseTypePresentationTests.swift`

**Interfaces:**
- Consumes: `CaseType` from `Domain/LegalCase.swift`.
- Produces: `CaseFieldKind`, `CaseFieldDescriptor`, `CaseTypePresentation`, and `CaseType.presentation`.

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import BetterCallSaul

final class CaseTypePresentationTests: XCTestCase {
    func testEveryCategoryHasDistinctPresentationCopy() {
        let fingerprints = CaseType.allCases.map { type in
            let value = type.presentation
            return [value.title, value.explanation, value.narrativeLabel,
                    value.narrativePlaceholder, value.uploadTitle, value.uploadHint]
                .joined(separator: "|")
        }
        XCTAssertEqual(Set(fingerprints).count, CaseType.allCases.count)
    }

    func testEveryCategoryHasExpectedOrderedFields() {
        XCTAssertEqual(CaseType.charge.presentation.fields.map(\.label),
                       ["Компания или сервис", "Сумма", "Дата", "Способ оплаты"])
        XCTAssertEqual(CaseType.fine.presentation.fields.map(\.label),
                       ["Орган", "Номер постановления", "Сумма", "Дата"])
        XCTAssertEqual(CaseType.subscription.presentation.fields.map(\.label),
                       ["Сервис", "Сумма", "Дата списания", "Дата отмены"])
        XCTAssertEqual(CaseType.product.presentation.fields.map(\.label),
                       ["Продавец", "Товар", "Стоимость", "Дата покупки"])
        XCTAssertEqual(CaseType.bill.presentation.fields.map(\.label),
                       ["Поставщик", "Период", "Сумма", "Номер счёта"])
        XCTAssertEqual(CaseType.charge.presentation.fields.map(\.kind),
                       [.counterparty, .amount, .date, .detail])
        XCTAssertEqual(CaseType.fine.presentation.fields.map(\.kind),
                       [.counterparty, .reference, .amount, .date])
        XCTAssertEqual(CaseType.subscription.presentation.fields.map(\.kind),
                       [.counterparty, .amount, .date, .detail])
        XCTAssertEqual(CaseType.product.presentation.fields.map(\.kind),
                       [.counterparty, .detail, .amount, .date])
        XCTAssertEqual(CaseType.bill.presentation.fields.map(\.kind),
                       [.counterparty, .detail, .amount, .reference])
    }
}
```

- [ ] **Step 2: Verify RED**

```bash
cd ios
xcodegen generate
xcodebuild test -quiet -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -derivedDataPath .derivedData \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulTests/CaseTypePresentationTests
```

Expected: compilation fails because the presentation types do not exist.

- [ ] **Step 3: Add the presentation types and exact content**

```swift
import Foundation

enum CaseFieldKind: String, Codable, Sendable {
    case counterparty, amount, date, reference, detail
}

struct CaseFieldDescriptor: Equatable, Sendable {
    let kind: CaseFieldKind
    let label: String
}

struct CaseTypePresentation: Equatable, Sendable {
    let title: String
    let explanation: String
    let narrativeLabel: String
    let narrativePlaceholder: String
    let uploadTitle: String
    let uploadHint: String
    let fields: [CaseFieldDescriptor]
}

extension CaseType {
    var presentation: CaseTypePresentation {
        switch self {
        case .charge:
            CaseTypePresentation(
                title: "Оспорьте\nсписание",
                explanation: "Укажите, кто и когда списал деньги — подготовим требование о возврате.",
                narrativeLabel: "Как произошло списание",
                narrativePlaceholder: "Например: не узнаю операцию, услугу не получил, деньги списали дважды…",
                uploadTitle: "Добавьте подтверждение списания",
                uploadHint: "Скриншот операции, чек или банковская выписка",
                fields: [
                    .init(kind: .counterparty, label: "Компания или сервис"),
                    .init(kind: .amount, label: "Сумма"),
                    .init(kind: .date, label: "Дата"),
                    .init(kind: .detail, label: "Способ оплаты")
                ])
        case .fine:
            CaseTypePresentation(
                title: "Обжалуйте\nштраф",
                explanation: "Проверьте постановление и объясните, почему штраф нужно отменить.",
                narrativeLabel: "Почему штраф несправедлив",
                narrativePlaceholder: "Например: знак был закрыт, автомобилем управлял другой человек…",
                uploadTitle: "Добавьте постановление",
                uploadHint: "Фото или PDF постановления, уведомления и подтверждающих материалов",
                fields: [
                    .init(kind: .counterparty, label: "Орган"),
                    .init(kind: .reference, label: "Номер постановления"),
                    .init(kind: .amount, label: "Сумма"),
                    .init(kind: .date, label: "Дата")
                ])
        case .subscription:
            CaseTypePresentation(
                title: "Отмените\nподписку",
                explanation: "Укажите сервис и спорное списание — подготовим отмену и запрос на возврат.",
                narrativeLabel: "Что произошло с подпиской",
                narrativePlaceholder: "Например: отменил подписку, но деньги снова списали…",
                uploadTitle: "Добавьте подтверждение подписки",
                uploadHint: "Скриншот списания, условий подписки или переписки с сервисом",
                fields: [
                    .init(kind: .counterparty, label: "Сервис"),
                    .init(kind: .amount, label: "Сумма"),
                    .init(kind: .date, label: "Дата списания"),
                    .init(kind: .detail, label: "Дата отмены")
                ])
        case .product:
            CaseTypePresentation(
                title: "Решите проблему\nс товаром",
                explanation: "Опишите недостаток товара и желаемый результат: возврат, замену или ремонт.",
                narrativeLabel: "Что не так с товаром",
                narrativePlaceholder: "Например: товар сломался через три дня, продавец отказал в возврате…",
                uploadTitle: "Добавьте чек и фото товара",
                uploadHint: "Чек, фотографии недостатка, гарантия или переписка с продавцом",
                fields: [
                    .init(kind: .counterparty, label: "Продавец"),
                    .init(kind: .detail, label: "Товар"),
                    .init(kind: .amount, label: "Стоимость"),
                    .init(kind: .date, label: "Дата покупки")
                ])
        case .bill:
            CaseTypePresentation(
                title: "Добейтесь\nперерасчёта",
                explanation: "Покажите спорный счёт и укажите, какие начисления считаете неверными.",
                narrativeLabel: "Что неверно в счёте",
                narrativePlaceholder: "Например: начислили лишнюю услугу или применили неверный тариф…",
                uploadTitle: "Добавьте спорный счёт",
                uploadHint: "Фото или PDF счёта, детализация и предыдущие квитанции",
                fields: [
                    .init(kind: .counterparty, label: "Поставщик"),
                    .init(kind: .detail, label: "Период"),
                    .init(kind: .amount, label: "Сумма"),
                    .init(kind: .reference, label: "Номер счёта")
                ])
        }
    }
}
```

- [ ] **Step 4: Verify GREEN and commit**

Run the Step 2 command; expect both tests to pass. Then:

```bash
git add ios/BetterCallSaul/Domain/CaseTypePresentation.swift \
  ios/BetterCallSaulTests/CaseTypePresentationTests.swift
git commit -m "feat: define category-specific evidence content"
```

---

### Task 2: Semantic Fields, OCR, and Gemini Merge

**Files:**
- Modify: `ios/BetterCallSaul/Domain/LegalCase.swift`
- Modify: `ios/BetterCallSaul/Domain/CaseWorkflowStore.swift`
- Modify: `ios/BetterCallSaul/Domain/DemoFixtures.swift`
- Modify: `ios/BetterCallSaul/Services/ReceiptFieldParser.swift`
- Modify: `ios/BetterCallSaulTests/ReceiptFieldParserTests.swift`
- Modify: `ios/BetterCallSaulTests/CaseWorkflowStoreTests.swift`
- Modify: `ios/BetterCallSaulTests/AIWorkflowTests.swift`

**Interfaces:**
- Consumes: field descriptors from Task 1.
- Produces: `ExtractedField.kind`, category-aware OCR, semantic fact synchronization, and non-destructive Gemini merging.

- [ ] **Step 1: Write failing tests**

Update the subscription parser assertions to:

```swift
XCTAssertEqual(fields.map(\.label), ["Сервис", "Сумма", "Дата списания", "Дата отмены"])
XCTAssertEqual(fields.map(\.kind), [.counterparty, .amount, .date, .detail])
XCTAssertEqual(fields.value(for: "Сервис"), "MegaPlus")
XCTAssertEqual(fields.value(for: "Сумма"), "24 900 ₸")
XCTAssertEqual(fields.value(for: "Дата списания"), "17 июля 2026")
XCTAssertEqual(fields.value(for: "Дата отмены"), "")
```

In `testMissingValuesStayEmptyAndRequireReview`, replace `Компания` with `Компания или сервис` in both the value and `requiresReview` assertions.

Add to `CaseWorkflowStoreTests`:

```swift
func testStartingFineCreatesFineSpecificFields() {
    let store = CaseWorkflowStore()
    store.start(type: .fine)
    XCTAssertEqual(store.currentCase.extractedFields.map(\.label),
                   ["Орган", "Номер постановления", "Сумма", "Дата"])
    XCTAssertEqual(store.currentCase.extractedFields.map(\.kind),
                   [.counterparty, .reference, .amount, .date])
}
```

Add to the existing successful Gemini workflow test:

```swift
XCTAssertEqual(store.currentCase.extractedFields.map(\.label),
               ["Сервис", "Сумма", "Дата списания", "Дата отмены"])
XCTAssertEqual(store.currentCase.extractedFields.first(where: { $0.kind == .detail })?.value, "")
```

- [ ] **Step 2: Verify RED**

```bash
cd ios
xcodegen generate
xcodebuild test -quiet -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -derivedDataPath .derivedData \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulTests/ReceiptFieldParserTests \
  -only-testing:BetterCallSaulTests/CaseWorkflowStoreTests \
  -only-testing:BetterCallSaulTests/AIWorkflowTests
```

Expected: compilation fails because `ExtractedField.kind` is absent.

- [ ] **Step 3: Add semantic identity to `ExtractedField` and fixtures**

```swift
struct ExtractedField: Identifiable, Equatable, Codable {
    let id: UUID
    let kind: CaseFieldKind
    let label: String
    var value: String
    var requiresReview: Bool

    init(id: UUID = UUID(), kind: CaseFieldKind, label: String,
         value: String, requiresReview: Bool = false) {
        self.id = id
        self.kind = kind
        self.label = label
        self.value = value
        self.requiresReview = requiresReview
    }
}
```

Use these exact subscription fields at existing fixture and test call sites:

```swift
[
    ExtractedField(kind: .counterparty, label: "Сервис", value: "MegaPlus"),
    ExtractedField(kind: .amount, label: "Сумма", value: "24 900 ₸"),
    ExtractedField(kind: .date, label: "Дата списания", value: "17 июля 2026"),
    ExtractedField(kind: .detail, label: "Дата отмены", value: "", requiresReview: true)
]
```

In `CaseWorkflowStoreTests.testEditingFieldKeepsCaseFactsInSync`, edit and assert `Сервис` instead of `Компания`; keep `Сумма` unchanged.

- [ ] **Step 4: Make OCR build fields from category descriptors**

```swift
func parse(_ text: String, caseType: CaseType) -> [ExtractedField] {
    let values: [CaseFieldKind: String] = [
        .counterparty: company(in: text),
        .amount: amount(in: text),
        .date: date(in: text)
    ]
    return caseType.presentation.fields.map { descriptor in
        let value = values[descriptor.kind] ?? ""
        return ExtractedField(kind: descriptor.kind, label: descriptor.label,
                              value: value, requiresReview: value.isEmpty)
    }
}
```

Delete `ReceiptFieldParser.displayName(for:)`; `LegalCase.type` already stores the selected type.

- [ ] **Step 5: Make workflow facts semantic and merge Gemini values**

```swift
private func synchronizeCaseFacts() {
    currentCase.counterparty = value(for: .counterparty)
    currentCase.amount = Self.integerAmount(from: value(for: .amount))
    currentCase.title = Self.title(for: currentCase.type, amount: currentCase.amount)
}

private func value(for kind: CaseFieldKind) -> String {
    currentCase.extractedFields.first(where: { $0.kind == kind })?.value
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

private static func emptyFields(for type: CaseType) -> [ExtractedField] {
    type.presentation.fields.map {
        ExtractedField(kind: $0.kind, label: $0.label, value: "", requiresReview: true)
    }
}

private func applyEvidenceAnalysis(_ analysis: EvidenceAnalysis) {
    updateRecognizedValue(analysis.counterparty, for: .counterparty)
    updateRecognizedValue(analysis.amount.map(Self.formatDecimalAmount), for: .amount)
    updateRecognizedValue(analysis.transactionDate, for: .date)
    synchronizeCaseFacts()
}

private func updateRecognizedValue(_ value: String?, for kind: CaseFieldKind) {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty,
          let index = currentCase.extractedFields.firstIndex(where: { $0.kind == kind }) else { return }
    currentCase.extractedFields[index].value = value
    currentCase.extractedFields[index].requiresReview = false
}
```

- [ ] **Step 6: Verify GREEN and commit**

Run the Step 2 command; expect all focused tests to pass. Then:

```bash
git add ios/BetterCallSaul/Domain/LegalCase.swift \
  ios/BetterCallSaul/Domain/CaseWorkflowStore.swift \
  ios/BetterCallSaul/Domain/DemoFixtures.swift \
  ios/BetterCallSaul/Services/ReceiptFieldParser.swift \
  ios/BetterCallSaulTests/ReceiptFieldParserTests.swift \
  ios/BetterCallSaulTests/CaseWorkflowStoreTests.swift \
  ios/BetterCallSaulTests/AIWorkflowTests.swift
git commit -m "feat: preserve category-specific evidence fields"
```

---

### Task 3: Category-Aware Local Fallback

**Files:**
- Create: `ios/BetterCallSaulTests/LocalLegalTextGeneratorTests.swift`
- Modify: `ios/BetterCallSaul/AI/Fallback/LocalLegalTextGenerator.swift`

**Interfaces:**
- Consumes: visible descriptors from `CaseType.presentation.fields`.
- Produces: local questions, recipient selection, and unresolved issues using category labels.

- [ ] **Step 1: Write failing fallback tests**

```swift
import XCTest
@testable import BetterCallSaul

final class LocalLegalTextGeneratorTests: XCTestCase {
    func testFineAnalysisAsksForFineSpecificMissingFields() async throws {
        let request = CaseAIRequest(
            caseType: .fine,
            narrative: "Штраф выписан ошибочно",
            reviewedFields: ["Орган": "", "Номер постановления": "",
                             "Сумма": "12 000 ₸", "Дата": ""],
            evidenceSummary: nil,
            answers: []
        )
        let analysis = try await LocalLegalTextGenerator().analyzeCase(request)
        XCTAssertEqual(analysis.questions.map(\.prompt), [
            "Укажите: орган", "Укажите: номер постановления", "Укажите: дата"
        ])
        XCTAssertEqual(analysis.questions.map(\.kind), [.text, .text, .date])
    }

    func testBillDocumentUsesSupplierAndReportsMissingFields() async throws {
        let context = CaseAIRequest(
            caseType: .bill,
            narrative: "Начисление не соответствует тарифу",
            reviewedFields: ["Поставщик": "KazNet", "Период": "Июнь 2026",
                             "Сумма": "", "Номер счёта": ""],
            evidenceSummary: nil,
            answers: []
        )
        let analysis = try await LocalLegalTextGenerator().analyzeCase(context)
        let document = try await LocalLegalTextGenerator().generateDocument(
            AIDocumentRequest(caseContext: context, analysis: analysis)
        )
        XCTAssertEqual(document.recipient, "KazNet")
        XCTAssertEqual(document.unresolvedIssues,
                       ["Уточнить поле «Сумма»", "Уточнить поле «Номер счёта»"])
    }
}
```

- [ ] **Step 2: Verify RED**

```bash
cd ios
xcodegen generate
xcodebuild test -quiet -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -derivedDataPath .derivedData \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulTests/LocalLegalTextGeneratorTests
```

Expected: the generic fallback asks for `Компания`, and the bill recipient is `nil`.

- [ ] **Step 3: Replace hard-coded fallback field names**

In `analyzeCase(_:)`, build questions from descriptors:

```swift
let missingFields = request.caseType.presentation.fields.filter { descriptor in
    request.reviewedFields[descriptor.label]?
        .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
}
let questions = Array(missingFields.prefix(5)).map { descriptor in
    AIQuestion(
        id: "local.\(descriptor.kind.rawValue).\(descriptor.label)",
        kind: questionKind(for: descriptor.kind),
        prompt: "Укажите: \(descriptor.label.lowercased())",
        whyNeeded: "Поле нужно для точного обращения",
        options: [],
        required: true
    )
}

private func questionKind(for fieldKind: CaseFieldKind) -> AIQuestionKind {
    switch fieldKind {
    case .amount: .amount
    case .date: .date
    case .counterparty, .reference, .detail: .text
    }
}
```

In `generateDocument(_:)`, use:

```swift
let descriptors = context.caseType.presentation.fields
let missing = descriptors.filter { descriptor in
    context.reviewedFields[descriptor.label]?
        .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
}
let recipientLabel = descriptors.first(where: { $0.kind == .counterparty })?.label
let recipient = recipientLabel.flatMap { nonEmpty(context.reviewedFields[$0]) }
```

Pass `recipient` to `AIDocumentSections` and set:

```swift
unresolvedIssues: missing.map { "Уточнить поле «\($0.label)»" }
```

- [ ] **Step 4: Verify GREEN and commit**

Run the Step 2 command; expect both tests to pass. Then:

```bash
git add ios/BetterCallSaul/AI/Fallback/LocalLegalTextGenerator.swift \
  ios/BetterCallSaulTests/LocalLegalTextGeneratorTests.swift
git commit -m "feat: use category fields in local legal fallback"
```

---

### Task 4: Dynamic Evidence UI and UI Coverage

**Files:**
- Modify: `ios/BetterCallSaul/Features/Evidence/EvidenceView.swift`
- Modify: `ios/BetterCallSaul/Features/Home/HomeView.swift`
- Modify: `ios/BetterCallSaulUITests/PrimaryFlowUITests.swift`

**Interfaces:**
- Consumes: `workflow.currentCase.type.presentation` and category fields.
- Produces: distinct copy, a narrative placeholder, upload guidance, and stable category accessibility identifiers.

- [ ] **Step 1: Write the failing UI test**

```swift
func testFineAndSubscriptionShowDistinctEvidenceContent() {
    app.buttons["caseType.fine"].tap()
    XCTAssertTrue(app.staticTexts["Обжалуйте\nштраф"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.staticTexts["Почему штраф несправедлив"].exists)
    XCTAssertTrue(app.staticTexts["Добавьте постановление"].exists)
    XCTAssertTrue(app.staticTexts[
        "Фото или PDF постановления, уведомления и подтверждающих материалов"
    ].exists)
    XCTAssertTrue(app.textFields["Орган"].exists)
    XCTAssertTrue(app.textFields["Номер постановления"].exists)

    app.terminate()
    app.launchArguments = ["-ui-testing"]
    app.launch()
    app.buttons["caseType.subscription"].tap()
    XCTAssertTrue(app.staticTexts["Отмените\nподписку"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.staticTexts["Что произошло с подпиской"].exists)
    XCTAssertTrue(app.staticTexts["Добавьте подтверждение подписки"].exists)
    XCTAssertTrue(app.staticTexts[
        "Скриншот списания, условий подписки или переписки с сервисом"
    ].exists)
    XCTAssertTrue(app.textFields["Сервис"].exists)
    XCTAssertTrue(app.textFields["Дата отмены"].exists)
}
```

Update old assertions:

```swift
// testSubscriptionPathOpensEvidence
XCTAssertTrue(app.staticTexts["Отмените\nподписку"].waitForExistence(timeout: 2))

// testEvidenceScreenShowsExtractedFieldsAndContinues
XCTAssertTrue(app.textFields["Сервис"].waitForExistence(timeout: 2))
XCTAssertTrue(app.textFields["Сумма"].exists)
XCTAssertTrue(app.textFields["Дата списания"].exists)
XCTAssertTrue(app.textFields["Дата отмены"].exists)

// testDocumentExportCreatesRealPDFReadyState
XCTAssertTrue(app.staticTexts["4 места требуют внимания"].exists)
```

- [ ] **Step 2: Verify RED**

```bash
cd ios
xcodegen generate
xcodebuild test -quiet -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -derivedDataPath .derivedData \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulUITests/PrimaryFlowUITests/testFineAndSubscriptionShowDistinctEvidenceContent
```

Expected: `caseType.fine` or fine-specific content is absent.

- [ ] **Step 3: Always start the selected category**

Use:

```swift
.accessibilityIdentifier("caseType.\(type.routingIdentifier)")

private func beginCase(_ type: CaseType) {
    closeSaulAssistant()
    workflow.start(type: type)
    router.open(.evidence)
}
```

- [ ] **Step 4: Render presentation data in `EvidenceView`**

Add:

```swift
private var presentation: CaseTypePresentation {
    workflow.currentCase.type.presentation
}
```

Replace the static header:

```swift
BCSEditorialTitle(text: presentation.title, size: 42)
    .padding(.top, 14)
Text(presentation.explanation)
    .font(.bcsBody(16))
    .foregroundStyle(BCSColor.secondary)
    .padding(.top, 12)
```

Replace `narrativeField`:

```swift
private var narrativeField: some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(presentation.narrativeLabel).font(.bcsBody(15, weight: .medium))
        ZStack(alignment: .topLeading) {
            TextEditor(text: Binding(
                get: { workflow.narrative },
                set: { workflow.updateNarrative($0) }
            ))
            .font(.bcsBody(16))
            .scrollContentBackground(.hidden)
            .padding(10)
            .accessibilityIdentifier("caseNarrativeField")

            if workflow.narrative.isEmpty {
                Text(presentation.narrativePlaceholder)
                    .font(.bcsBody(16))
                    .foregroundStyle(BCSColor.secondary.opacity(0.72))
                    .padding(.horizontal, 15)
                    .padding(.vertical, 18)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 112)
        .background(BCSColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(BCSColor.divider))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
```

Replace upload copy:

```swift
Text(workflow.currentCase.evidence.isEmpty ? presentation.uploadTitle : "Заменить документ")
    .font(.bcsBody(17, weight: .medium))
Text(presentation.uploadHint)
    .font(.bcsBody(12))
    .foregroundStyle(BCSColor.secondary)
```

- [ ] **Step 5: Verify GREEN, run the complete suite, and commit**

Run the focused command from Step 2, then:

```bash
RESULT_ROOT=$(mktemp -d)
xcodebuild test -quiet -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -derivedDataPath .derivedData \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -resultBundlePath "$RESULT_ROOT/CategoryEvidence.xcresult"
xcrun xcresulttool get test-results summary \
  --path "$RESULT_ROOT/CategoryEvidence.xcresult" --format json
```

Expected: `result` is `Passed`, with `failedTests: 0` and `skippedTests: 0`.

```bash
git add ios/BetterCallSaul/Features/Evidence/EvidenceView.swift \
  ios/BetterCallSaul/Features/Home/HomeView.swift \
  ios/BetterCallSaulUITests/PrimaryFlowUITests.swift
git commit -m "feat: personalize evidence flow by category"
```

---

### Task 5: Simulator Verification and Push

**Files:**
- Verify: `ios/.derivedData/Build/Products/Debug-iphonesimulator/BetterCallSaul.app`
- Verify: the committed files from Tasks 1–4.

**Interfaces:**
- Consumes: the passing full test result.
- Produces: a launched simulator build, clean worktree, and pushed branch.

- [ ] **Step 1: Check repository scope**

```bash
git diff --check
git status --short
git log --oneline -5
```

Expected: no whitespace errors and no uncommitted implementation files.

- [ ] **Step 2: Install and launch**

```bash
cd ios
if ! xcrun simctl list devices booted | rg -q 'iPhone 17 Pro'; then
  xcrun simctl boot 'iPhone 17 Pro'
fi
open -a Simulator
xcrun simctl bootstatus 'iPhone 17 Pro' -b
xcrun simctl install 'iPhone 17 Pro' \
  .derivedData/Build/Products/Debug-iphonesimulator/BetterCallSaul.app
xcrun simctl terminate 'iPhone 17 Pro' kz.techvision.bettercallsaul >/dev/null 2>&1 || true
xcrun simctl launch 'iPhone 17 Pro' kz.techvision.bettercallsaul
```

Expected: `simctl launch` prints a BetterCallSaul process identifier.

- [ ] **Step 3: Push the implementation**

```bash
git push origin codex/ai-provider-flow
```

Expected: GitHub advances `codex/ai-provider-flow` to the final implementation commit.
