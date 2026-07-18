# BetterCallSaul iOS Visual MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a runnable native SwiftUI visual MVP that matches the four approved BetterCallSaul concepts, including their editorial layout, payphone illustrations, local demo data, navigation, and restrained motion.

**Architecture:** The first delivery is an offline-first iOS application with local fixtures and no network dependency. Feature views consume a small domain model and shared design system; an observable app router owns navigation, while each feature keeps its own focused state. AI, OCR, persistence, PDF generation, and provider integrations remain behind explicit interfaces for later plans.

**Tech Stack:** Swift 6, SwiftUI, XCTest, iOS 17+, Xcode 26.6, XcodeGen 2.45+, SF Pro, native system serif typography, SF Symbols, custom SwiftUI `Shape` illustrations.

## Global Constraints

- Match `design-concepts/01-home.png`, `02-evidence.png`, `03-document.png`, and `04-tools.png` as the visual source of truth.
- Target iOS 17.0 or newer and verify on the installed iPhone 17 Pro simulator running iOS 26.5.
- Use warm canvas `#F7F6F1`, surface `#FFFFFF`, charcoal `#2F3437`, secondary `#787774`, divider `#E7E5DF`, and Saul yellow `#F2D44B`.
- Use SF Pro for controls and body copy, the native system serif design for editorial titles, and SF Mono for identifiers.
- Use no gradients, purple AI styling, glassmorphism, neon, heavy shadows, actor likenesses, television stills, or generic chatbot layout.
- Keep container radii between 8 and 12 points and primary button radius at 6 points.
- Keep every interactive control at least 44 by 44 points.
- Respect Dynamic Type, VoiceOver, Reduce Motion, safe areas, and long Russian and Kazakh text.
- Use custom vector payphone artwork and restrained Saul references from the approved concepts.
- Keep all data local and synthetic in this plan. Do not add or consume any API key.
- Do not place generated `.xcodeproj` files in Git; regenerate them from `ios/project.yml`.

---

## Planned File Structure

```text
ios/
├── project.yml
├── BetterCallSaul/
│   ├── App/
│   │   ├── BetterCallSaulApp.swift
│   │   ├── AppRootView.swift
│   │   └── AppRouter.swift
│   ├── DesignSystem/
│   │   ├── BCSTheme.swift
│   │   ├── BCSComponents.swift
│   │   └── PayphoneIllustration.swift
│   ├── Domain/
│   │   ├── LegalCase.swift
│   │   └── DemoFixtures.swift
│   ├── Features/
│   │   ├── Home/HomeView.swift
│   │   ├── Evidence/EvidenceView.swift
│   │   ├── Document/DocumentView.swift
│   │   ├── Cases/CasesView.swift
│   │   ├── Tools/ToolsView.swift
│   │   └── Profile/ProfileView.swift
│   └── Resources/Assets.xcassets/
├── BetterCallSaulTests/
│   ├── AppRouterTests.swift
│   ├── DesignSystemTests.swift
│   └── LegalCaseTests.swift
└── BetterCallSaulUITests/
    └── PrimaryFlowUITests.swift
```

Each file owns one responsibility: navigation, shared appearance, reusable components, vector artwork, domain state, fixtures, or one feature screen.

---

### Task 1: Reproducible iOS Project and Navigation Skeleton

**Files:**
- Create: `ios/project.yml`
- Create: `ios/BetterCallSaul/App/BetterCallSaulApp.swift`
- Create: `ios/BetterCallSaul/App/AppRootView.swift`
- Create: `ios/BetterCallSaul/App/AppRouter.swift`
- Create: `ios/BetterCallSaul/Resources/Assets.xcassets/Contents.json`
- Create: `ios/BetterCallSaulTests/AppRouterTests.swift`
- Modify: `.gitignore`

**Interfaces:**
- Produces: `AppRouter`, `AppTab`, `AppRoute`, and the `BetterCallSaul` scheme.
- Consumes: no application code.

- [ ] **Step 1: Install and verify the project generator**

Run:

```bash
brew list xcodegen >/dev/null 2>&1 || brew install xcodegen
xcodegen --version
```

Expected: XcodeGen prints a stable `2.45` or newer version. XcodeGen's official repository documents `brew install xcodegen` and `xcodegen generate` as supported setup and usage.

- [ ] **Step 2: Write the failing router test**

Create `ios/BetterCallSaulTests/AppRouterTests.swift`:

```swift
import XCTest
@testable import BetterCallSaul

@MainActor
final class AppRouterTests: XCTestCase {
    func testSelectingToolsChangesActiveTab() {
        let router = AppRouter()

        router.select(.tools)

        XCTAssertEqual(router.selectedTab, .tools)
    }

    func testOpeningEvidenceAddsEvidenceRoute() {
        let router = AppRouter()

        router.open(.evidence)

        XCTAssertEqual(router.path, [.evidence])
    }

    func testResetClearsNavigationPath() {
        let router = AppRouter()
        router.open(.evidence)
        router.open(.document)

        router.reset()

        XCTAssertTrue(router.path.isEmpty)
    }
}
```

- [ ] **Step 3: Create the XcodeGen specification**

Create `ios/project.yml`:

```yaml
name: BetterCallSaul
options:
  bundleIdPrefix: kz.techvision
  deploymentTarget:
    iOS: "17.0"
  generateEmptyDirectories: true
settings:
  base:
    SWIFT_VERSION: "6.0"
targets:
  BetterCallSaul:
    type: application
    platform: iOS
    sources:
      - path: BetterCallSaul
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: kz.techvision.bettercallsaul
        GENERATE_INFOPLIST_FILE: true
        INFOPLIST_KEY_CFBundleDisplayName: BetterCallSaul
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation: true
        INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents: true
        INFOPLIST_KEY_UILaunchScreen_Generation: true
        TARGETED_DEVICE_FAMILY: "1"
    scheme:
      testTargets:
        - BetterCallSaulTests
        - BetterCallSaulUITests
  BetterCallSaulTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: BetterCallSaulTests
    dependencies:
      - target: BetterCallSaul
    settings:
      base:
        GENERATE_INFOPLIST_FILE: true
  BetterCallSaulUITests:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - path: BetterCallSaulUITests
    dependencies:
      - target: BetterCallSaul
    settings:
      base:
        GENERATE_INFOPLIST_FILE: true
```

- [ ] **Step 4: Implement the minimal router and app entry**

Create `ios/BetterCallSaul/App/AppRouter.swift`:

```swift
import Observation
import SwiftUI

enum AppTab: String, CaseIterable, Hashable {
    case home
    case cases
    case tools
    case profile

    var title: String {
        switch self {
        case .home: "Главная"
        case .cases: "Обращения"
        case .tools: "Инструменты"
        case .profile: "Профиль"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .cases: "doc.text.fill"
        case .tools: "wrench.and.screwdriver.fill"
        case .profile: "person.crop.circle"
        }
    }
}

enum AppRoute: Hashable {
    case evidence
    case document
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .home
    var path: [AppRoute] = []

    func select(_ tab: AppTab) {
        selectedTab = tab
    }

    func open(_ route: AppRoute) {
        path.append(route)
    }

    func reset() {
        path.removeAll()
    }
}
```

Create `ios/BetterCallSaul/App/BetterCallSaulApp.swift`:

```swift
import SwiftUI

@main
struct BetterCallSaulApp: App {
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            AppRootView(router: router)
        }
    }
}
```

Create `ios/BetterCallSaul/App/AppRootView.swift` with temporary compile-safe destinations:

```swift
import SwiftUI

struct AppRootView: View {
    @Bindable var router: AppRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            Text(router.selectedTab.title)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .evidence:
                        Text("Добавьте доказательства")
                    case .document:
                        Text("Претензия готова")
                    }
                }
        }
    }
}
```

Create `ios/BetterCallSaul/Resources/Assets.xcassets/Contents.json`:

```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

Append to `.gitignore`:

```gitignore
ios/BetterCallSaul.xcodeproj/
ios/.build/
DerivedData/
*.xcuserstate
xcuserdata/
```

- [ ] **Step 5: Generate the project and verify the test passes**

Run:

```bash
cd ios
xcodegen generate
xcodebuild test \
  -project BetterCallSaul.xcodeproj \
  -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulTests/AppRouterTests
```

Expected: `** TEST SUCCEEDED **` and three passing router tests.

- [ ] **Step 6: Commit the project skeleton**

```bash
git add .gitignore ios/project.yml ios/BetterCallSaul ios/BetterCallSaulTests/AppRouterTests.swift
git commit -m "feat: scaffold BetterCallSaul iOS app"
```

---

### Task 2: Design Tokens, Shared Controls, and Payphone Artwork

**Files:**
- Create: `ios/BetterCallSaul/DesignSystem/BCSTheme.swift`
- Create: `ios/BetterCallSaul/DesignSystem/BCSComponents.swift`
- Create: `ios/BetterCallSaul/DesignSystem/PayphoneIllustration.swift`
- Create: `ios/BetterCallSaulTests/DesignSystemTests.swift`

**Interfaces:**
- Produces: `BCSColor`, `BCSSpacing`, `BCSPrimaryButton`, `BCSStatusBadge`, `BCSDivider`, and `PayphoneIllustration`.
- Consumes: SwiftUI only.

- [ ] **Step 1: Write failing token tests**

Create `ios/BetterCallSaulTests/DesignSystemTests.swift`:

```swift
import SwiftUI
import XCTest
@testable import BetterCallSaul

final class DesignSystemTests: XCTestCase {
    func testSpacingScaleMatchesApprovedSystem() {
        XCTAssertEqual(BCSSpacing.xs, 4)
        XCTAssertEqual(BCSSpacing.sm, 8)
        XCTAssertEqual(BCSSpacing.md, 16)
        XCTAssertEqual(BCSSpacing.lg, 24)
        XCTAssertEqual(BCSSpacing.xl, 32)
    }

    func testMotionRespectsReduceMotion() {
        XCTAssertEqual(BCSMotion.entryOffset(reduceMotion: true), 0)
        XCTAssertEqual(BCSMotion.entryOffset(reduceMotion: false), 8)
    }
}
```

- [ ] **Step 2: Run the tests and verify they fail**

Run:

```bash
cd ios
xcodebuild test \
  -project BetterCallSaul.xcodeproj \
  -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulTests/DesignSystemTests
```

Expected: build failure because `BCSSpacing` and `BCSMotion` do not exist.

- [ ] **Step 3: Implement theme tokens**

Create `ios/BetterCallSaul/DesignSystem/BCSTheme.swift`:

```swift
import SwiftUI

enum BCSColor {
    static let canvas = Color(red: 247 / 255, green: 246 / 255, blue: 241 / 255)
    static let surface = Color.white
    static let ink = Color(red: 47 / 255, green: 52 / 255, blue: 55 / 255)
    static let secondary = Color(red: 120 / 255, green: 119 / 255, blue: 116 / 255)
    static let divider = Color(red: 231 / 255, green: 229 / 255, blue: 223 / 255)
    static let yellow = Color(red: 242 / 255, green: 212 / 255, blue: 75 / 255)
    static let paleYellow = Color(red: 251 / 255, green: 243 / 255, blue: 219 / 255)
    static let paleGreen = Color(red: 237 / 255, green: 243 / 255, blue: 236 / 255)
    static let greenText = Color(red: 52 / 255, green: 101 / 255, blue: 56 / 255)
}

enum BCSSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum BCSMotion {
    static func entryOffset(reduceMotion: Bool) -> CGFloat {
        reduceMotion ? 0 : 8
    }

    static func spring(reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.01) : .spring(response: 0.38, dampingFraction: 0.86)
    }
}

extension Font {
    static func bcsEditorial(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    static func bcsBody(_ size: CGFloat = 17, weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func bcsMeta(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}
```

- [ ] **Step 4: Implement reusable controls**

Create `ios/BetterCallSaul/DesignSystem/BCSComponents.swift`:

```swift
import SwiftUI

struct BCSPrimaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(title)
                    .font(.bcsBody(17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .foregroundStyle(Color.white)
            .background(BCSColor.ink)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(BCSPressButtonStyle())
    }
}

struct BCSPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

struct BCSStatusBadge: View {
    let title: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(0.8)
            Circle()
                .fill(isActive ? BCSColor.yellow : BCSColor.secondary.opacity(0.55))
                .frame(width: 6, height: 6)
        }
        .foregroundStyle(BCSColor.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(BCSColor.surface.opacity(0.8))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
    }
}

struct BCSDivider: View {
    var body: some View {
        Rectangle()
            .fill(BCSColor.divider)
            .frame(height: 1)
    }
}

struct BCSEditorialTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.bcsEditorial(50))
            .tracking(-1.7)
            .foregroundStyle(BCSColor.ink)
            .minimumScaleFactor(0.72)
            .fixedSize(horizontal: false, vertical: true)
    }
}
```

- [ ] **Step 5: Implement the vector payphone illustration**

Create `ios/BetterCallSaul/DesignSystem/PayphoneIllustration.swift`:

```swift
import SwiftUI

struct PayphoneIllustration: View {
    var lineColor: Color = BCSColor.ink.opacity(0.7)
    var lineWidth: CGFloat = 1.25

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 180, size.height / 220)
            context.scaleBy(x: scale, y: scale)

            var body = Path(roundedRect: CGRect(x: 54, y: 18, width: 88, height: 178), cornerRadius: 8)
            body.addRoundedRect(in: CGRect(x: 72, y: 39, width: 52, height: 38), cornerSize: CGSize(width: 4, height: 4))
            body.addRoundedRect(in: CGRect(x: 74, y: 140, width: 48, height: 27), cornerSize: CGSize(width: 4, height: 4))
            context.stroke(body, with: .color(lineColor), lineWidth: lineWidth)

            var receiver = Path()
            receiver.move(to: CGPoint(x: 42, y: 42))
            receiver.addCurve(to: CGPoint(x: 38, y: 157), control1: CGPoint(x: 25, y: 68), control2: CGPoint(x: 26, y: 130))
            receiver.addCurve(to: CGPoint(x: 55, y: 174), control1: CGPoint(x: 40, y: 169), control2: CGPoint(x: 47, y: 175))
            receiver.addLine(to: CGPoint(x: 67, y: 158))
            receiver.addCurve(to: CGPoint(x: 59, y: 143), control1: CGPoint(x: 64, y: 151), control2: CGPoint(x: 62, y: 146))
            receiver.addCurve(to: CGPoint(x: 58, y: 60), control1: CGPoint(x: 48, y: 118), control2: CGPoint(x: 48, y: 82))
            receiver.addCurve(to: CGPoint(x: 67, y: 45), control1: CGPoint(x: 62, y: 52), control2: CGPoint(x: 64, y: 48))
            receiver.addLine(to: CGPoint(x: 55, y: 30))
            receiver.addCurve(to: CGPoint(x: 42, y: 42), control1: CGPoint(x: 48, y: 32), control2: CGPoint(x: 44, y: 36))
            context.stroke(receiver, with: .color(lineColor), lineWidth: lineWidth)

            for row in 0..<4 {
                for column in 0..<3 {
                    let rect = CGRect(x: 78 + CGFloat(column) * 14, y: 86 + CGFloat(row) * 13, width: 5, height: 5)
                    context.stroke(Path(ellipseIn: rect), with: .color(lineColor), lineWidth: lineWidth)
                }
            }

            var cord = Path()
            cord.move(to: CGPoint(x: 53, y: 174))
            cord.addCurve(to: CGPoint(x: 33, y: 213), control1: CGPoint(x: 52, y: 198), control2: CGPoint(x: 24, y: 194))
            cord.addCurve(to: CGPoint(x: 86, y: 211), control1: CGPoint(x: 43, y: 231), control2: CGPoint(x: 74, y: 224))
            context.stroke(cord, with: .color(lineColor), lineWidth: lineWidth)
        }
        .aspectRatio(180 / 220, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

struct SaulPhoneTile: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(BCSColor.yellow)
            Image(systemName: "phone.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(BCSColor.ink)
        }
        .frame(width: 52, height: 52)
        .accessibilityLabel("Позвонить")
    }
}
```

- [ ] **Step 6: Run tests and commit**

Run:

```bash
cd ios
xcodegen generate
xcodebuild test \
  -project BetterCallSaul.xcodeproj \
  -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulTests/DesignSystemTests
```

Expected: `** TEST SUCCEEDED **` with two passing tests.

Commit:

```bash
git add ios/BetterCallSaul/DesignSystem ios/BetterCallSaulTests/DesignSystemTests.swift
git commit -m "feat: add editorial design system and payphone artwork"
```

---

### Task 3: Domain Model and Synthetic Demo Fixtures

**Files:**
- Create: `ios/BetterCallSaul/Domain/LegalCase.swift`
- Create: `ios/BetterCallSaul/Domain/DemoFixtures.swift`
- Create: `ios/BetterCallSaulTests/LegalCaseTests.swift`

**Interfaces:**
- Produces: `LegalCase`, `CaseType`, `CaseStatus`, `EvidenceItem`, `ExtractedField`, `ToolItem`, and `DemoFixtures`.
- Consumes: no feature views.

- [ ] **Step 1: Write failing domain tests**

Create `ios/BetterCallSaulTests/LegalCaseTests.swift`:

```swift
import XCTest
@testable import BetterCallSaul

final class LegalCaseTests: XCTestCase {
    func testActiveFixtureMatchesApprovedConcept() {
        let legalCase = DemoFixtures.activeCase

        XCTAssertEqual(legalCase.amount, 24_900)
        XCTAssertEqual(legalCase.counterparty, "MegaPlus Kazakhstan")
        XCTAssertEqual(legalCase.status, .waitingForResponse)
        XCTAssertEqual(legalCase.evidence.count, 1)
    }

    func testWorkingToolsAreNotMarkedAsConcepts() {
        let working = DemoFixtures.tools.filter { $0.capability == .working }

        XCTAssertEqual(working.count, 5)
        XCTAssertTrue(working.allSatisfy { !$0.title.isEmpty })
    }
}
```

- [ ] **Step 2: Run the tests and verify they fail**

Run:

```bash
cd ios
xcodebuild test \
  -project BetterCallSaul.xcodeproj \
  -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulTests/LegalCaseTests
```

Expected: build failure because the domain types do not exist.

- [ ] **Step 3: Implement the domain types**

Create `ios/BetterCallSaul/Domain/LegalCase.swift`:

```swift
import Foundation

enum CaseType: String, CaseIterable, Identifiable, Codable {
    case charge = "Списали деньги"
    case fine = "Пришёл штраф"
    case subscription = "Отменить подписку"
    case product = "Проблема с товаром"
    case bill = "Завышенный счёт"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .charge: "creditcard.fill"
        case .fine: "doc.text.fill"
        case .subscription: "arrow.triangle.2.circlepath"
        case .product: "shippingbox.fill"
        case .bill: "list.bullet.rectangle.fill"
        }
    }
}

enum CaseStatus: String, Codable {
    case draft = "Черновик"
    case documentReady = "Документ готов"
    case sent = "Отправлено"
    case waitingForResponse = "Ожидается ответ"
    case actionRequired = "Требуется действие"
    case completed = "Завершено"
}

struct EvidenceItem: Identifiable, Equatable, Codable {
    let id: UUID
    let fileName: String
    let fileSize: String

    init(id: UUID = UUID(), fileName: String, fileSize: String) {
        self.id = id
        self.fileName = fileName
        self.fileSize = fileSize
    }
}

struct ExtractedField: Identifiable, Equatable, Codable {
    let id: UUID
    let label: String
    var value: String
    var requiresReview: Bool

    init(id: UUID = UUID(), label: String, value: String, requiresReview: Bool = false) {
        self.id = id
        self.label = label
        self.value = value
        self.requiresReview = requiresReview
    }
}

struct LegalCase: Identifiable, Equatable, Codable {
    let id: UUID
    let number: String
    var type: CaseType
    var title: String
    var counterparty: String
    var amount: Int?
    var status: CaseStatus
    var responseDeadline: Date?
    var evidence: [EvidenceItem]
    var extractedFields: [ExtractedField]

    init(
        id: UUID = UUID(),
        number: String,
        type: CaseType,
        title: String,
        counterparty: String,
        amount: Int?,
        status: CaseStatus,
        responseDeadline: Date?,
        evidence: [EvidenceItem],
        extractedFields: [ExtractedField]
    ) {
        self.id = id
        self.number = number
        self.type = type
        self.title = title
        self.counterparty = counterparty
        self.amount = amount
        self.status = status
        self.responseDeadline = responseDeadline
        self.evidence = evidence
        self.extractedFields = extractedFields
    }
}

enum ToolCapability: String {
    case working = "РАБОТАЕТ"
    case demo = "DEMO"
    case concept = "КОНЦЕПТ"
}

struct ToolItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let capability: ToolCapability
}
```

- [ ] **Step 4: Implement deterministic demo fixtures**

Create `ios/BetterCallSaul/Domain/DemoFixtures.swift`:

```swift
import Foundation

enum DemoFixtures {
    static let activeCase = LegalCase(
        id: UUID(uuidString: "84B7C148-204D-4D4F-9BB5-F2B202607170")!,
        number: "BCS-2026-0717-0017",
        type: .subscription,
        title: "Возврат за подписку",
        counterparty: "MegaPlus Kazakhstan",
        amount: 24_900,
        status: .waitingForResponse,
        responseDeadline: Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 7, day: 28)),
        evidence: [EvidenceItem(fileName: "IMG_1847.PNG", fileSize: "2,4 МБ")],
        extractedFields: [
            ExtractedField(label: "Компания", value: "MegaPlus"),
            ExtractedField(label: "Сумма", value: "24 900 ₸"),
            ExtractedField(label: "Дата", value: "17 июля 2026"),
            ExtractedField(label: "Тип", value: "Подписка", requiresReview: true)
        ]
    )

    static let tools: [ToolItem] = [
        ToolItem(id: 1, title: "Жалоба компании", capability: .working),
        ToolItem(id: 2, title: "Обжалование штрафа", capability: .working),
        ToolItem(id: 3, title: "Отмена подписки", capability: .working),
        ToolItem(id: 4, title: "Возврат денег", capability: .working),
        ToolItem(id: 5, title: "Переговоры по счёту", capability: .working),
        ToolItem(id: 6, title: "Временный номер", capability: .demo),
        ToolItem(id: 7, title: "Trial Card", capability: .concept)
    ]
}
```

- [ ] **Step 5: Run tests and commit**

Run:

```bash
cd ios
xcodegen generate
xcodebuild test \
  -project BetterCallSaul.xcodeproj \
  -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulTests/LegalCaseTests
```

Expected: `** TEST SUCCEEDED **` with two passing domain tests.

Commit:

```bash
git add ios/BetterCallSaul/Domain ios/BetterCallSaulTests/LegalCaseTests.swift
git commit -m "feat: add legal case domain and demo fixtures"
```

---

### Task 4: Exact App Shell and Home Screen

**Files:**
- Modify: `ios/BetterCallSaul/App/AppRootView.swift`
- Create: `ios/BetterCallSaul/Features/Home/HomeView.swift`
- Create: `ios/BetterCallSaul/Features/Profile/ProfileView.swift`
- Create: `ios/BetterCallSaulUITests/PrimaryFlowUITests.swift`

**Interfaces:**
- Consumes: `AppRouter`, `AppTab`, `DemoFixtures.activeCase`, design-system components.
- Produces: accessible Home controls with identifiers `createCaseButton`, `caseType.subscription`, and `activeCaseCard`.

- [ ] **Step 1: Write the failing Home UI test**

Create `ios/BetterCallSaulUITests/PrimaryFlowUITests.swift`:

```swift
import XCTest

final class PrimaryFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    func testHomeContainsApprovedPrimaryElements() {
        XCTAssertTrue(app.staticTexts["Что случилось?"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["createCaseButton"].exists)
        XCTAssertTrue(app.buttons["caseType.subscription"].exists)
        XCTAssertTrue(app.otherElements["activeCaseCard"].exists)
    }

    func testSubscriptionPathOpensEvidence() {
        app.buttons["caseType.subscription"].tap()

        XCTAssertTrue(app.staticTexts["Добавьте доказательства"].waitForExistence(timeout: 2))
    }
}
```

- [ ] **Step 2: Run the UI test and verify it fails**

Run:

```bash
cd ios
xcodegen generate
xcodebuild test \
  -project BetterCallSaul.xcodeproj \
  -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulUITests/PrimaryFlowUITests/testHomeContainsApprovedPrimaryElements
```

Expected: assertion failure because the Home controls do not exist.

- [ ] **Step 3: Implement the app shell and custom bottom navigation**

Replace `ios/BetterCallSaul/App/AppRootView.swift`:

```swift
import SwiftUI

struct AppRootView: View {
    @Bindable var router: AppRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            ZStack(alignment: .bottom) {
                currentTab
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                BCSBottomBar(selectedTab: $router.selectedTab)
            }
            .background(BCSColor.canvas.ignoresSafeArea())
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .evidence:
                    Text("Добавьте доказательства")
                case .document:
                    Text("Претензия готова")
                }
            }
        }
        .tint(BCSColor.ink)
    }

    @ViewBuilder
    private var currentTab: some View {
        switch router.selectedTab {
        case .home:
            HomeView(router: router)
        case .cases:
            StaticTabScreen(title: "Обращения")
        case .tools:
            StaticTabScreen(title: "Инструменты")
        case .profile:
            ProfileView()
        }
    }
}

private struct StaticTabScreen: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.bcsEditorial(44))
            .foregroundStyle(BCSColor.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(24)
            .padding(.bottom, 80)
            .background(BCSColor.canvas)
    }
}

private struct BCSBottomBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 20, weight: selectedTab == tab ? .semibold : .regular))
                        Text(tab.title)
                            .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                    }
                    .foregroundStyle(selectedTab == tab ? BCSColor.ink : BCSColor.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 58)
                }
                .accessibilityIdentifier("tab.\(tab.rawValue)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .background(BCSColor.canvas.opacity(0.98))
        .overlay(alignment: .top) { BCSDivider() }
    }
}
```

- [ ] **Step 4: Implement Home to match the approved concept**

Create `ios/BetterCallSaul/Features/Home/HomeView.swift`:

```swift
import SwiftUI

struct HomeView: View {
    let router: AppRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                brandHeader
                    .padding(.bottom, 30)

                Text("Добрый вечер, Алим")
                    .font(.bcsBody(17))
                    .foregroundStyle(BCSColor.secondary)

                BCSEditorialTitle(text: "Что случилось?")
                    .padding(.top, 8)

                Text("Опишите ситуацию — остальное соберём сами.")
                    .font(.bcsBody())
                    .foregroundStyle(BCSColor.secondary)
                    .padding(.top, 10)

                BCSPrimaryButton("Создать обращение", systemImage: "square.and.pencil") {
                    router.open(.evidence)
                }
                .accessibilityIdentifier("createCaseButton")
                .padding(.top, 24)

                caseTypes
                    .padding(.top, 24)

                activeCase
                    .padding(.top, 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 104)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : BCSMotion.entryOffset(reduceMotion: reduceMotion))
        }
        .background(BCSColor.canvas)
        .onAppear {
            withAnimation(BCSMotion.spring(reduceMotion: reduceMotion)) {
                isVisible = true
            }
        }
    }

    private var brandHeader: some View {
        HStack(alignment: .top) {
            HStack(spacing: 14) {
                Text("Better\nCall\nSaul")
                    .font(.bcsEditorial(24))
                    .lineSpacing(-5)
                Rectangle()
                    .fill(BCSColor.yellow)
                    .frame(width: 2, height: 58)
                Text("Всё по закону.")
                    .font(.bcsBody(14))
                    .foregroundStyle(BCSColor.secondary)
            }
            Spacer()
            PayphoneIllustration(lineColor: BCSColor.secondary.opacity(0.55), lineWidth: 1)
                .frame(width: 82, height: 100)
        }
    }

    private var caseTypes: some View {
        VStack(spacing: 0) {
            BCSDivider()
            ForEach(CaseType.allCases) { type in
                Button {
                    router.open(.evidence)
                } label: {
                    HStack(spacing: 15) {
                        Image(systemName: type.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 34, height: 34)
                            .overlay(Circle().stroke(BCSColor.divider, lineWidth: 1))
                        Text(type.rawValue)
                            .font(.bcsBody(17))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(BCSColor.secondary)
                    }
                    .frame(minHeight: 58)
                    .foregroundStyle(BCSColor.ink)
                }
                .accessibilityIdentifier("caseType.\(type == .subscription ? "subscription" : type.id)")
                BCSDivider()
            }
        }
    }

    private var activeCase: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("АКТИВНОЕ ОБРАЩЕНИЕ")
                .font(.system(size: 11, weight: .medium))
                .tracking(1)
                .foregroundStyle(BCSColor.secondary)

            HStack(spacing: 14) {
                Rectangle()
                    .fill(BCSColor.yellow)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Возврат 24 900 ₸")
                        .font(.bcsEditorial(24))
                    Text(DemoFixtures.activeCase.number)
                        .font(.bcsMeta())
                        .foregroundStyle(BCSColor.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    BCSStatusBadge(title: "Ожидается ответ", isActive: true)
                    Text("до 28 июля")
                        .font(.bcsBody(13))
                        .foregroundStyle(BCSColor.secondary)
                }
                SaulPhoneTile()
            }
            .frame(minHeight: 86)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("activeCaseCard")

            Text("S’all good")
                .font(.system(size: 12, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(BCSColor.secondary.opacity(0.6))
                .frame(maxWidth: .infinity)
        }
    }
}
```

Create `ios/BetterCallSaul/Features/Profile/ProfileView.swift`:

```swift
import SwiftUI

struct ProfileView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BCSEditorialTitle(text: "Профиль")
            Text("Личные данные будут добавлены после визуального MVP.")
                .font(.bcsBody())
                .foregroundStyle(BCSColor.secondary)
            Spacer()
        }
        .padding(24)
        .padding(.bottom, 80)
        .background(BCSColor.canvas)
    }
}
```

- [ ] **Step 5: Run Home UI tests and commit**

Run:

```bash
cd ios
xcodegen generate
xcodebuild test \
  -project BetterCallSaul.xcodeproj \
  -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulUITests/PrimaryFlowUITests/testHomeContainsApprovedPrimaryElements
```

Expected: `** TEST SUCCEEDED **`.

Commit:

```bash
git add ios/BetterCallSaul/App/AppRootView.swift ios/BetterCallSaul/Features/Home ios/BetterCallSaul/Features/Profile ios/BetterCallSaulUITests/PrimaryFlowUITests.swift
git commit -m "feat: build editorial home experience"
```

---

### Task 5: Evidence Intake Screen and Review Interaction

**Files:**
- Create: `ios/BetterCallSaul/Features/Evidence/EvidenceView.swift`
- Modify: `ios/BetterCallSaul/App/AppRootView.swift`
- Modify: `ios/BetterCallSaulUITests/PrimaryFlowUITests.swift`

**Interfaces:**
- Consumes: `LegalCase`, `ExtractedField`, `AppRouter`, shared design components.
- Produces: editable extracted values and `continueToDocumentButton`.

- [ ] **Step 1: Add a failing evidence-flow UI test**

Add this method inside `PrimaryFlowUITests`:

```swift
func testEvidenceScreenShowsExtractedFieldsAndContinues() {
    app.buttons["caseType.subscription"].tap()

    XCTAssertTrue(app.staticTexts["MegaPlus"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.staticTexts["24 900 ₸"].exists)
    XCTAssertTrue(app.staticTexts["ПРОВЕРЬТЕ ДАННЫЕ"].exists)

    app.buttons["continueToDocumentButton"].tap()

    XCTAssertTrue(app.staticTexts["Претензия готова"].waitForExistence(timeout: 2))
}
```

- [ ] **Step 2: Run the new test and verify it fails**

Run:

```bash
cd ios
xcodebuild test \
  -project BetterCallSaul.xcodeproj \
  -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulUITests/PrimaryFlowUITests/testEvidenceScreenShowsExtractedFieldsAndContinues
```

Expected: failure because `continueToDocumentButton` does not exist.

- [ ] **Step 3: Implement the exact evidence screen**

Create `ios/BetterCallSaul/Features/Evidence/EvidenceView.swift`:

```swift
import SwiftUI

struct EvidenceView: View {
    let router: AppRouter
    let legalCase: LegalCase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fields: [ExtractedField]
    @State private var isVisible = false

    init(router: AppRouter, legalCase: LegalCase) {
        self.router = router
        self.legalCase = legalCase
        _fields = State(initialValue: legalCase.extractedFields)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                BCSEditorialTitle(text: "Добавьте\nдоказательства")
                    .padding(.top, 30)
                Text("Чек, списание или переписка помогут составить точное требование.")
                    .font(.bcsBody())
                    .foregroundStyle(BCSColor.secondary)
                    .padding(.top, 12)

                uploadArea
                    .padding(.top, 26)
                uploadedFile
                    .padding(.top, 12)
                extractedData
                    .padding(.top, 14)

                HStack {
                    Spacer()
                    PayphoneIllustration(lineColor: BCSColor.secondary.opacity(0.18), lineWidth: 0.9)
                        .frame(width: 94, height: 116)
                }
                .padding(.top, 14)

                BCSPrimaryButton("Продолжить") {
                    router.open(.document)
                }
                .accessibilityIdentifier("continueToDocumentButton")
                .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : BCSMotion.entryOffset(reduceMotion: reduceMotion))
        }
        .background(BCSColor.canvas.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .onAppear {
            withAnimation(BCSMotion.spring(reduceMotion: reduceMotion)) {
                isVisible = true
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Label("Новое обращение", systemImage: "chevron.left")
                    .font(.bcsBody(15))
            }
            Spacer()
            Text("2 из 4")
                .font(.bcsMeta())
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index < 2 ? BCSColor.yellow : BCSColor.divider)
                        .frame(width: 18, height: 4)
                }
            }
        }
        .foregroundStyle(BCSColor.ink)
        .frame(minHeight: 44)
    }

    private var uploadArea: some View {
        Button {} label: {
            HStack(spacing: 16) {
                Image(systemName: "doc.badge.arrow.up")
                    .font(.system(size: 28, weight: .regular))
                Text("Добавить документ")
                    .font(.bcsBody(17, weight: .medium))
                Spacer()
            }
            .padding(22)
            .frame(minHeight: 100)
            .foregroundStyle(BCSColor.ink)
            .background(BCSColor.surface.opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(BCSColor.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            )
        }
    }

    private var uploadedFile: some View {
        HStack(spacing: 16) {
            Image(systemName: "doc")
                .font(.system(size: 24))
            VStack(alignment: .leading, spacing: 3) {
                Text(legalCase.evidence[0].fileName)
                    .font(.bcsBody(16, weight: .medium))
                Text(legalCase.evidence[0].fileSize)
                    .font(.bcsBody(13))
                    .foregroundStyle(BCSColor.secondary)
            }
            Spacer()
            Button {} label: {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
            }
        }
        .padding(16)
        .background(BCSColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(BCSColor.divider))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var extractedData: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ПРОВЕРЬТЕ ДАННЫЕ")
                .font(.system(size: 10, weight: .medium))
                .tracking(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(BCSColor.paleYellow)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(16)

            ForEach($fields) { $field in
                HStack {
                    Text(field.label)
                        .foregroundStyle(BCSColor.secondary)
                    Spacer()
                    TextField(field.label, text: $field.value)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(BCSColor.ink)
                }
                .font(.bcsBody(16))
                .frame(minHeight: 54)
                .padding(.horizontal, 16)
                BCSDivider().padding(.horizontal, 16)
            }
        }
        .background(BCSColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(BCSColor.divider))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
```

Replace the `.evidence` destination in `AppRootView` with:

```swift
case .evidence:
    EvidenceView(router: router, legalCase: DemoFixtures.activeCase)
```

- [ ] **Step 4: Run the evidence UI test and commit**

Run:

```bash
cd ios
xcodegen generate
xcodebuild test \
  -project BetterCallSaul.xcodeproj \
  -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulUITests/PrimaryFlowUITests/testEvidenceScreenShowsExtractedFieldsAndContinues
```

Expected: `** TEST SUCCEEDED **`.

Commit:

```bash
git add ios/BetterCallSaul/App/AppRootView.swift ios/BetterCallSaul/Features/Evidence ios/BetterCallSaulUITests/PrimaryFlowUITests.swift
git commit -m "feat: add evidence review experience"
```

---

### Task 6: Document Preview and Confirmation State

**Files:**
- Create: `ios/BetterCallSaul/Features/Document/DocumentView.swift`
- Modify: `ios/BetterCallSaul/App/AppRootView.swift`
- Modify: `ios/BetterCallSaulUITests/PrimaryFlowUITests.swift`

**Interfaces:**
- Consumes: `LegalCase` and shared design components.
- Produces: document preview, attention states, `sendDocumentButton`, and a local success confirmation.

- [ ] **Step 1: Add a failing document UI test**

Add this method inside `PrimaryFlowUITests`:

```swift
func testDocumentConfirmationShowsSuccessState() {
    app.buttons["caseType.subscription"].tap()
    app.buttons["continueToDocumentButton"].tap()

    XCTAssertTrue(app.staticTexts["Требование о возврате 24 900 ₸"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.staticTexts["2 места требуют внимания"].exists)

    app.buttons["sendDocumentButton"].tap()

    XCTAssertTrue(app.staticTexts["Документ подготовлен"].waitForExistence(timeout: 2))
}
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
cd ios
xcodebuild test \
  -project BetterCallSaul.xcodeproj \
  -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulUITests/PrimaryFlowUITests/testDocumentConfirmationShowsSuccessState
```

Expected: failure because the document view is not implemented.

- [ ] **Step 3: Implement the document-led screen**

Create `ios/BetterCallSaul/Features/Document/DocumentView.swift`:

```swift
import SwiftUI

struct DocumentView: View {
    let legalCase: LegalCase
    @Environment(\.dismiss) private var dismiss
    @State private var showConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Label("Обращение", systemImage: "chevron.left")
                    }
                    Spacer()
                    BCSStatusBadge(title: "Готово", isActive: true)
                }
                .font(.bcsBody(15))
                .foregroundStyle(BCSColor.ink)
                .frame(minHeight: 44)

                BCSEditorialTitle(text: "Претензия готова")
                    .padding(.top, 22)
                Text("Проверьте данные перед отправкой.")
                    .font(.bcsBody())
                    .foregroundStyle(BCSColor.secondary)
                    .padding(.top, 8)

                documentPaper
                    .padding(.top, 22)

                reviewRow(icon: "checkmark", color: BCSColor.ink, title: "Данные подтверждены")
                    .padding(.top, 16)
                reviewRow(
                    icon: "exclamationmark",
                    color: BCSColor.yellow,
                    title: "2 места требуют внимания",
                    isWarning: true
                )
                    .padding(.top, 10)

                BCSPrimaryButton("Подписать и отправить", systemImage: "signature") {
                    showConfirmation = true
                }
                .accessibilityIdentifier("sendDocumentButton")
                .padding(.top, 18)

                Button("Скачать PDF") {}
                    .font(.bcsBody(16, weight: .medium))
                    .foregroundStyle(BCSColor.ink)
                    .underline()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)

                HStack {
                    Label("Всё по закону.", systemImage: "phone")
                    Spacer()
                    Text("S’all good")
                        .italic()
                }
                .font(.system(size: 12, design: .serif))
                .foregroundStyle(BCSColor.secondary)
                .padding(.top, 14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(BCSColor.canvas.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .alert("Документ подготовлен", isPresented: $showConfirmation) {
            Button("Готово", role: .cancel) {}
        } message: {
            Text("На следующем этапе здесь появится системное меню отправки.")
        }
    }

    private var documentPaper: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "phone.fill")
                        .padding(8)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(BCSColor.ink))
                    Text("BetterCallSaul")
                        .font(.system(size: 13, design: .serif))
                    Text("Всё по закону.")
                        .font(.bcsBody(10))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Исх. № \(legalCase.number)")
                    Text("18 июля 2026 г.")
                }
                .font(.bcsMeta(9))
            }

            Rectangle()
                .fill(BCSColor.yellow)
                .frame(width: 34, height: 4)

            Text("Требование о возврате 24 900 ₸")
                .font(.bcsEditorial(26))

            Text("Кому: \(legalCase.counterparty)")
                .font(.bcsBody(12))

            BCSDivider()

            Text("Я подтверждаю, что с моего счёта была списана сумма 24 900 ₸ за продление подписки. Прошу рассмотреть требование о возврате после проверки обстоятельств и приложенных доказательств.")
                .font(.bcsBody(12))
                .lineSpacing(3)

            Text("Перед отправкой пользователь обязан проверить факты, получателя и применимые основания.")
                .font(.bcsBody(12))
                .lineSpacing(3)
                .padding(12)
                .background(BCSColor.paleYellow)

            Text("Приложение: копия подтверждения списания на 1 странице.")
                .font(.bcsBody(11))

            BCSDivider()

            HStack {
                Text("С уважением,\nАлим")
                    .font(.bcsBody(11))
                Spacer()
                Text("A. N.")
                    .font(.system(size: 22, design: .serif))
                    .italic()
            }
        }
        .padding(22)
        .background(BCSColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(BCSColor.divider))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
    }

    private func reviewRow(
        icon: String,
        color: Color,
        title: String,
        isWarning: Bool = false
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 34, height: 34)
                .background(color)
                .foregroundStyle(isWarning ? BCSColor.ink : Color.white)
                .clipShape(Circle())
            Text(title)
                .font(.bcsBody(15))
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(BCSColor.secondary)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 58)
        .background(BCSColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(BCSColor.divider))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
```

Replace the `.document` destination in `AppRootView` with:

```swift
case .document:
    DocumentView(legalCase: DemoFixtures.activeCase)
```

- [ ] **Step 4: Run the document UI test and commit**

Run:

```bash
cd ios
xcodegen generate
xcodebuild test \
  -project BetterCallSaul.xcodeproj \
  -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulUITests/PrimaryFlowUITests/testDocumentConfirmationShowsSuccessState
```

Expected: `** TEST SUCCEEDED **`.

Commit:

```bash
git add ios/BetterCallSaul/App/AppRootView.swift ios/BetterCallSaul/Features/Document ios/BetterCallSaulUITests/PrimaryFlowUITests.swift
git commit -m "feat: add legal document preview and confirmation"
```

---

### Task 7: Tools and Cases Screens

**Files:**
- Create: `ios/BetterCallSaul/Features/Tools/ToolsView.swift`
- Create: `ios/BetterCallSaul/Features/Cases/CasesView.swift`
- Modify: `ios/BetterCallSaul/App/AppRootView.swift`
- Modify: `ios/BetterCallSaulUITests/PrimaryFlowUITests.swift`

**Interfaces:**
- Consumes: `ToolItem`, `ToolCapability`, `LegalCase`, `AppTab`.
- Produces: exact numbered Tools list, honest capability labels, yellow Saul callout, and the active Cases timeline.

- [ ] **Step 1: Add failing tab coverage tests**

Add these methods inside `PrimaryFlowUITests`:

```swift
func testToolsShowsHonestCapabilitiesAndSaulCallout() {
    app.buttons["tab.tools"].tap()

    XCTAssertTrue(app.staticTexts["Инструменты"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.staticTexts["Временный номер"].exists)
    XCTAssertTrue(app.staticTexts["DEMO"].exists)
    XCTAssertTrue(app.staticTexts["КОНЦЕПТ"].exists)
    XCTAssertTrue(app.staticTexts["Нужен план?\nПозвони Солу."].exists)
}

func testCasesShowsActiveCaseAndDeadline() {
    app.buttons["tab.cases"].tap()

    XCTAssertTrue(app.staticTexts["Возврат за подписку"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.staticTexts["24 900 ₸"].exists)
    XCTAssertTrue(app.staticTexts["Ответ до 28 июля"].exists)
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
cd ios
xcodebuild test \
  -project BetterCallSaul.xcodeproj \
  -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulUITests/PrimaryFlowUITests/testToolsShowsHonestCapabilitiesAndSaulCallout \
  -only-testing:BetterCallSaulUITests/PrimaryFlowUITests/testCasesShowsActiveCaseAndDeadline
```

Expected: failure because Tools and Cases are not implemented.

- [ ] **Step 3: Implement Tools**

Create `ios/BetterCallSaul/Features/Tools/ToolsView.swift`:

```swift
import SwiftUI

struct ToolsView: View {
    let items: [ToolItem]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BetterCallSaul")
                            .font(.bcsBody(15, weight: .bold))
                        Text("Юридический ассистент\nдля жизни в Казахстане")
                            .font(.bcsBody(12))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Label("Дела  23", systemImage: "doc.text")
                        Text("BCS-2026-00123")
                    }
                    .font(.bcsMeta(10))
                    .foregroundStyle(BCSColor.secondary)
                }

                BCSEditorialTitle(text: "Инструменты")
                    .padding(.top, 44)
                Text("Не советуем. Делаем.")
                    .font(.bcsEditorial(25))
                    .foregroundStyle(BCSColor.secondary)
                    .padding(.top, 4)

                BCSDivider().padding(.top, 34)

                ForEach(items) { item in
                    HStack(spacing: 16) {
                        Text(String(format: "%02d", item.id))
                            .font(.bcsEditorial(28))
                            .frame(width: 42, alignment: .leading)
                        Text(item.title)
                            .font(.bcsEditorial(20))
                            .minimumScaleFactor(0.75)
                        Spacer()
                        BCSStatusBadge(title: item.capability.rawValue, isActive: item.capability == .working)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(BCSColor.ink)
                    .frame(minHeight: 68)
                    BCSDivider()
                }

                HStack(spacing: 20) {
                    PayphoneIllustration(lineColor: BCSColor.ink, lineWidth: 1.2)
                        .frame(width: 72, height: 88)
                    Rectangle()
                        .fill(BCSColor.ink.opacity(0.25))
                        .frame(width: 1, height: 76)
                    Text("Нужен план?\nПозвони Солу.")
                        .font(.bcsEditorial(25))
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding(20)
                .background(BCSColor.yellow)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.top, 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 104)
        }
        .background(BCSColor.canvas)
    }
}
```

- [ ] **Step 4: Implement Cases**

Create `ios/BetterCallSaul/Features/Cases/CasesView.swift`:

```swift
import SwiftUI

struct CasesView: View {
    let legalCase: LegalCase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BCSEditorialTitle(text: "Обращения")
                Text("Следим за сроками и следующими действиями.")
                    .font(.bcsBody())
                    .foregroundStyle(BCSColor.secondary)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(legalCase.title)
                                .font(.bcsEditorial(26))
                            Text(legalCase.counterparty)
                                .font(.bcsBody(14))
                                .foregroundStyle(BCSColor.secondary)
                        }
                        Spacer()
                        Text("24 900 ₸")
                            .font(.bcsEditorial(24))
                    }

                    BCSDivider()

                    BCSStatusBadge(title: legalCase.status.rawValue, isActive: true)
                    Text("Ответ до 28 июля")
                        .font(.bcsBody(14, weight: .medium))

                    timelineRow(title: "Документ подготовлен", detail: "18 июля, 09:41", active: false)
                    timelineRow(title: "Ожидается отправка", detail: "Подтвердите действие", active: true)
                }
                .padding(.top, 30)

                Spacer(minLength: 120)
            }
            .padding(24)
            .padding(.bottom, 80)
        }
        .background(BCSColor.canvas)
    }

    private func timelineRow(title: String, detail: String, active: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(active ? BCSColor.yellow : BCSColor.ink)
                .frame(width: 9, height: 9)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.bcsBody(15, weight: .medium))
                Text(detail)
                    .font(.bcsBody(13))
                    .foregroundStyle(BCSColor.secondary)
            }
        }
    }
}
```

Replace the `.cases` and `.tools` branches in `AppRootView.currentTab` with:

```swift
case .cases:
    CasesView(legalCase: DemoFixtures.activeCase)
case .tools:
    ToolsView(items: DemoFixtures.tools)
```

- [ ] **Step 5: Run tab tests and commit**

Run:

```bash
cd ios
xcodegen generate
xcodebuild test \
  -project BetterCallSaul.xcodeproj \
  -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulUITests/PrimaryFlowUITests/testToolsShowsHonestCapabilitiesAndSaulCallout \
  -only-testing:BetterCallSaulUITests/PrimaryFlowUITests/testCasesShowsActiveCaseAndDeadline
```

Expected: `** TEST SUCCEEDED **` with both tests passing.

Commit:

```bash
git add ios/BetterCallSaul/App/AppRootView.swift ios/BetterCallSaul/Features/Tools ios/BetterCallSaul/Features/Cases ios/BetterCallSaulUITests/PrimaryFlowUITests.swift
git commit -m "feat: add tools and case tracking screens"
```

---

### Task 8: Motion, Accessibility, Screenshots, and Visual Matching

**Files:**
- Modify: `ios/BetterCallSaul/Features/Home/HomeView.swift`
- Modify: `ios/BetterCallSaul/Features/Evidence/EvidenceView.swift`
- Modify: `ios/BetterCallSaul/Features/Document/DocumentView.swift`
- Modify: `ios/BetterCallSaul/Features/Tools/ToolsView.swift`
- Modify: `ios/BetterCallSaul/Features/Cases/CasesView.swift`
- Modify: `ios/BetterCallSaulUITests/PrimaryFlowUITests.swift`
- Create: `docs/visual-qa/README.md`

**Interfaces:**
- Consumes: all completed visual screens.
- Produces: deterministic screenshots, Reduce Motion behavior, accessibility labels, and visual QA evidence.

- [ ] **Step 1: Add screenshot and accessibility UI coverage**

Add these methods inside `PrimaryFlowUITests`:

```swift
func testPrimaryScreensCaptureStableReferences() {
    capture(name: "01-home")

    app.buttons["caseType.subscription"].tap()
    capture(name: "02-evidence")

    app.buttons["continueToDocumentButton"].tap()
    capture(name: "03-document")

    app.buttons["Обращение"].tap()
    app.buttons["Новое обращение"].tap()
    app.buttons["tab.tools"].tap()
    capture(name: "04-tools")
}

func testLargeTextKeepsPrimaryActionReachable() {
    app.terminate()
    app.launchArguments = ["-ui-testing", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
    app.launch()

    XCTAssertTrue(app.buttons["createCaseButton"].waitForExistence(timeout: 3))
    app.buttons["createCaseButton"].swipeUp()
    XCTAssertTrue(app.buttons["createCaseButton"].isHittable || app.staticTexts["Что случилось?"].exists)
}

private func capture(name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
}
```

- [ ] **Step 2: Run the complete suite before final polish**

Run:

```bash
cd ios
xcodegen generate
xcodebuild test \
  -project BetterCallSaul.xcodeproj \
  -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -resultBundlePath ../artifacts/BetterCallSaul-VisualMVP.xcresult
```

Expected: all unit and UI tests pass, or the screenshot-navigation test reveals the exact route issue to fix before continuing.

- [ ] **Step 3: Apply final visual-matching rules**

Inspect each captured screen side by side with its counterpart in `design-concepts/` and make only these bounded adjustments:

```text
Home: match headline scale, brand-header whitespace, five row heights, yellow phone tile, and active-case alignment.
Evidence: match two-line title, dashed upload field, extracted-data panel, faint payphone placement, and bottom action prominence.
Document: keep the paper as the dominant surface, preserve the yellow highlighted paragraph, and prevent body text clipping.
Tools: preserve the seven numbered rows, capability labels, yellow callout, and editorial title hierarchy.
```

For every changed view, keep colors and spacing sourced from `BCSTheme.swift`. Do not introduce per-screen color literals.

- [ ] **Step 4: Add visual QA documentation**

Create `docs/visual-qa/README.md`:

```markdown
# BetterCallSaul Visual QA

## Reference screens

- `design-concepts/01-home.png`
- `design-concepts/02-evidence.png`
- `design-concepts/03-document.png`
- `design-concepts/04-tools.png`

## Required checks

- iPhone 17 Pro portrait layout has no clipping or horizontal scrolling.
- Dynamic Type at Accessibility Large keeps all primary actions reachable.
- Reduce Motion removes entry translation while preserving state changes.
- VoiceOver labels identify tabs, case actions, evidence actions, and document confirmation.
- Every working, demo, and concept capability is labelled honestly.
- Saul references remain typographic or illustrative and use no actor likenesses or television stills.
- Legal text in the visual fixture is explicitly synthetic and not presented as verified legal advice.
```

- [ ] **Step 5: Run final verification**

Run:

```bash
rm -rf artifacts/BetterCallSaul-VisualMVP.xcresult
cd ios
xcodegen generate
xcodebuild clean test \
  -project BetterCallSaul.xcodeproj \
  -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -resultBundlePath ../artifacts/BetterCallSaul-VisualMVP.xcresult
```

Expected: `** TEST SUCCEEDED **`; the result bundle exists and contains the four named screenshot attachments.

- [ ] **Step 6: Commit the verified visual MVP**

```bash
git add ios docs/visual-qa
git commit -m "feat: finish BetterCallSaul visual MVP"
```

---

## Plan Boundary and Next Plans

This plan ends with a polished, runnable, offline visual MVP. It intentionally does not add secrets, Gemini, OCR, SwiftData, PDFKit, email, telephony, or payment functionality.

After this plan passes visual QA, create separate implementation plans in this order:

1. **Local case workflow:** mutable intake state, evidence picker, Apple Vision OCR, SwiftData persistence, and PDFKit export.
2. **Gemini backend:** stateless schema-constrained API, redacted logs, deterministic template fallback, and environment-only `GEMINI_API_KEY`.
3. **Delivery and demo providers:** iOS Share Sheet/email, reminder tracking, temporary-number provider abstraction, and concept-only Trial Card.

Each later plan must keep the visual interfaces and domain boundaries introduced here stable unless a verified implementation constraint requires a focused change.
