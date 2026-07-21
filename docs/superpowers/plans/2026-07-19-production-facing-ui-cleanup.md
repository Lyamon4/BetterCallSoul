# BetterCallSaul Production-Facing UI Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove every user-facing provider, key, local/demo/concept hint and the yellow active-case phone tile while preserving the working document-analysis pipeline.

**Architecture:** Keep Gemini, DeepSeek, retry, fallback, PDF, and sharing behind the existing service protocols. Simplify the public surface to legal-service language, bundled startup configuration, supported tools only, and a neutral profile. Protect the production copy with source-surface unit tests plus end-to-end UI tests.

**Tech Stack:** Swift 6, SwiftUI, XCTest, XCUITest, XcodeGen, iOS 17+.

## Global Constraints

- Do not change provider request/response contracts or send live requests during verification.
- Do not expose `Gemini`, `DeepSeek`, `AI`, API keys, providers, local fallback, demo, or concept language in the UI.
- Do not present unavailable temporary-number or trial-card capabilities as working.
- Keep the existing warm editorial visual system and Saul brand references, except the yellow active-case phone tile explicitly requested for removal.
- Commit and push each green task to `codex/ai-provider-flow`.

---

### Task 1: Lock down the production surface with failing tests

**Files:**
- Create: `ios/BetterCallSaulTests/ProductionSurfaceTests.swift`
- Modify: `ios/BetterCallSaulUITests/PrimaryFlowUITests.swift`

**Interfaces:**
- Consumes: source files under `ios/BetterCallSaul/Features` and the `-ui-testing` application fixture.
- Produces: regression rules for forbidden public strings and removed UI controls.

- [ ] **Step 1: Add a failing source-surface unit test**

```swift
import Foundation
import XCTest

final class ProductionSurfaceTests: XCTestCase {
    func testUserFacingSourcesContainNoImplementationOrPrototypeLabels() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let sourceRoot = testsDirectory.deletingLastPathComponent().appendingPathComponent("BetterCallSaul")
        let paths = [
            "Features/Home/HomeView.swift",
            "Features/Evidence/EvidenceView.swift",
            "Features/AIAnalysis/AIAnalysisView.swift",
            "Features/Profile/ProfileView.swift",
            "Features/Tools/ToolsView.swift"
        ]
        let combined = try paths.map {
            try String(contentsOf: sourceRoot.appendingPathComponent($0), encoding: .utf8)
        }.joined(separator: "\n")
        for forbidden in ["Gemini", "DeepSeek", "Локальный режим", "Продолжаем локально", "AI-провайдеры", "DEMO", "КОНЦЕПТ", "SaulPhoneTile"] {
            XCTAssertFalse(combined.contains(forbidden), "Public surface contains \(forbidden)")
        }
    }
}
```

- [ ] **Step 2: Replace provider/demo UI assertions with production assertions**

```swift
func testProductionSurfaceHidesImplementationAndPrototypeControls() {
    app.buttons["tab.profile"].tap()
    XCTAssertTrue(app.staticTexts["Профиль"].waitForExistence(timeout: 2))
    XCTAssertFalse(app.buttons["AI-провайдеры"].exists)

    app.buttons["tab.tools"].tap()
    XCTAssertTrue(app.staticTexts["Инструменты"].waitForExistence(timeout: 2))
    XCTAssertFalse(app.staticTexts["Временный номер"].exists)
    XCTAssertFalse(app.staticTexts["Trial Card"].exists)
    XCTAssertFalse(app.staticTexts["DEMO"].exists)
    XCTAssertFalse(app.staticTexts["КОНЦЕПТ"].exists)
}
```

Update the main analysis-flow test to assert `Проверенные факты` and never assert a provider name.

- [ ] **Step 3: Run the focused tests and confirm RED**

Run:

```bash
cd ios
xcodegen generate
xcodebuild test -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulTests/ProductionSurfaceTests \
  -only-testing:BetterCallSaulUITests/PrimaryFlowUITests/testProductionSurfaceHidesImplementationAndPrototypeControls \
  CODE_SIGNING_ALLOWED=NO
```

Expected: the unit test reports the current provider/prototype strings and the UI test finds `AI-провайдеры`.

### Task 2: Remove manual configuration and technical workflow copy

**Files:**
- Delete: `ios/BetterCallSaul/Features/Profile/AISettingsView.swift`
- Delete: `ios/BetterCallSaulTests/AISettingsTests.swift`
- Delete: `ios/BetterCallSaul/AI/Infrastructure/KeychainSecretStore.swift`
- Modify: `ios/BetterCallSaul/AI/Infrastructure/AIConfiguration.swift`
- Modify: `ios/BetterCallSaul/AI/Infrastructure/AIProviderError.swift`
- Modify: `ios/BetterCallSaul/AI/Fallback/LocalLegalTextGenerator.swift`
- Modify: `ios/BetterCallSaul/Features/Profile/ProfileView.swift`
- Modify: `ios/BetterCallSaul/Features/Home/HomeView.swift`
- Modify: `ios/BetterCallSaul/Features/Evidence/EvidenceView.swift`
- Modify: `ios/BetterCallSaul/Features/AIAnalysis/AIAnalysisView.swift`
- Modify: `ios/BetterCallSaulTests/AIConfigurationTests.swift`

**Interfaces:**
- Consumes: the four bundled Info.plist values populated from `Secrets.xcconfig`.
- Produces: `AIConfiguration.bundled(bundle:)` with no runtime override and a provider-neutral consumer UI.

- [ ] **Step 1: Simplify bundled configuration**

Change the signature to:

```swift
static func bundled(bundle: Bundle = .main) throws -> Self
```

Read `GeminiAPIKey`, `GeminiModel`, `DeepSeekAPIKey`, and `DeepSeekModel` directly from `bundle.infoDictionary`, then call `AIConfiguration(values:)`. Remove masked-key properties and delete `KeychainSecretStore.swift` plus settings-specific tests.

- [ ] **Step 2: Replace the profile with a neutral real-user surface**

`ProfileView` retains the editorial title and shows only:

```swift
Text("Алим")
Text("Казахстан · Русский")
Text("Документы создаются на основании указанных вами данных. Перед отправкой проверяйте факты и получателя.")
```

There is no navigation link, key status, provider status, Keychain copy, or `S’all configured` line.

- [ ] **Step 3: Remove the active-case phone tile and technical copy**

- Delete the `SaulPhoneTile()` block from `HomeView.activeCase`.
- Replace the Evidence disclosure with `Загружая документ, вы разрешаете обработать его для извлечения данных и подготовки обращения.`
- Remove `providerLine` and `providerCaption` from the analysis view.
- Replace progress titles with `Проверяем документ` and `Разбираем ситуацию`.
- Do not render a fallback banner; render the resulting analysis normally.
- Replace the local generator warning with `Проверьте формулировки и факты перед отправкой.`
- Make `AIProviderError.errorDescription` neutral: configuration/auth/quota/response/transport errors mention only `сервис обработки`, never a provider or AI.

- [ ] **Step 4: Run focused unit and UI flow tests**

Expected: production-surface and configuration tests pass; evidence → analysis → document UI flow passes with no provider label.

- [ ] **Step 5: Commit and push**

```bash
git add ios/BetterCallSaul ios/BetterCallSaulTests ios/BetterCallSaulUITests
git commit -m "feat: hide implementation details from users"
git push
```

### Task 3: Show supported tools only and verify the simulator

**Files:**
- Modify: `ios/BetterCallSaul/Domain/LegalCase.swift`
- Modify: `ios/BetterCallSaul/Domain/DemoFixtures.swift`
- Modify: `ios/BetterCallSaul/Features/Tools/ToolsView.swift`
- Modify: `ios/BetterCallSaulUITests/PrimaryFlowUITests.swift`

**Interfaces:**
- Consumes: `ToolItem(id:title:)` values.
- Produces: a five-item tools list with no capability classification.

- [ ] **Step 1: Remove capability metadata and unavailable fixtures**

Use this model:

```swift
struct ToolItem: Identifiable, Equatable {
    let id: Int
    let title: String
}
```

Delete `ToolCapability`. Keep only complaint, fine appeal, subscription cancellation, refund, and bill negotiation in `DemoFixtures.tools`.

- [ ] **Step 2: Remove the status badge column from `ToolsView`**

Each row contains only its number, title, spacer, and chevron. Keep the yellow Saul editorial callout at the bottom.

- [ ] **Step 3: Run the full local suite**

```bash
cd ios
xcodegen generate
xcodebuild test -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO
```

Expected: all unit and UI tests pass with zero live provider requests.

- [ ] **Step 4: Build, install, launch, and inspect**

Build and install on the iPhone 17 Pro simulator. Capture Home, analysis, tools, and profile. Confirm the active-case yellow phone tile and every forbidden label are absent.

- [ ] **Step 5: Commit and push**

```bash
git add ios/BetterCallSaul ios/BetterCallSaulTests ios/BetterCallSaulUITests
git commit -m "feat: present supported tools as production features"
git push
```
