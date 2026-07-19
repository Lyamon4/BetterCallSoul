# 8-Bit Saul Mascot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a consistent four-state 8-bit Saul helper, contextual SwiftUI animation, and a matching production app icon to BetterCallSaul.

**Architecture:** Generated raster artwork lives in the existing asset catalog. A focused `SaulMascotView` maps semantic states to asset names, nearest-neighbor rendering, accessibility, and Reduce Motion-aware transforms; feature screens only choose the relevant semantic state. Home owns a local deterministic help bubble, while analysis and document screens use decorative contextual states without changing the legal workflow.

**Tech Stack:** Swift 6, SwiftUI, XCTest/XCUITest, Xcode asset catalogs, built-in image generation, local chroma-key removal, XcodeGen, iOS 17+.

## Global Constraints

- Create exactly four in-app states: `idle`, `thinking`, `talking`, and `celebrating`.
- Preserve one recognizable 8-bit Saul identity across all states: sandy side-parted hair, expressive eyebrows, lawyer smile, light suit, colorful shirt, and bright striped tie.
- Keep the existing paper cream, charcoal, Saul yellow, muted blue, and restrained red palette; no gradients, 3D rendering, watermark, or baked-in text.
- In-app sprites must be transparent PNGs and use nearest-neighbor interpolation.
- The app icon must be one opaque `1024 × 1024` PNG with no text and safe padding for iOS masking.
- Use SwiftUI transforms only; add no GIF, video, sprite-animation, or third-party dependency.
- Respect `accessibilityReduceMotion`; repeated movement stops when it is enabled.
- Do not add a chatbot, persistence, networking, analytics, or changes to the legal/AI workflow.
- Keep all provider and implementation terminology hidden from the user.

---

### Task 1: Generate and validate the Saul artwork

**Files:**
- Create: `ios/BetterCallSaul/Resources/Assets.xcassets/SaulIdle.imageset/saul-idle.png`
- Create: `ios/BetterCallSaul/Resources/Assets.xcassets/SaulIdle.imageset/Contents.json`
- Create: `ios/BetterCallSaul/Resources/Assets.xcassets/SaulThinking.imageset/saul-thinking.png`
- Create: `ios/BetterCallSaul/Resources/Assets.xcassets/SaulThinking.imageset/Contents.json`
- Create: `ios/BetterCallSaul/Resources/Assets.xcassets/SaulTalking.imageset/saul-talking.png`
- Create: `ios/BetterCallSaul/Resources/Assets.xcassets/SaulTalking.imageset/Contents.json`
- Create: `ios/BetterCallSaul/Resources/Assets.xcassets/SaulCelebrating.imageset/saul-celebrating.png`
- Create: `ios/BetterCallSaul/Resources/Assets.xcassets/SaulCelebrating.imageset/Contents.json`
- Create: `ios/BetterCallSaul/Resources/Assets.xcassets/AppIcon.appiconset/BetterCallSaul-AppIcon.png`
- Modify: `ios/BetterCallSaul/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`

**Interfaces:**
- Consumes: approved mascot specification and the existing `Assets.xcassets` catalog.
- Produces: named catalog images `SaulIdle`, `SaulThinking`, `SaulTalking`, `SaulCelebrating`, and `AppIcon` for Task 2.

- [ ] **Step 1: Generate the idle master sprite**

Use the built-in image generator with this production prompt:

```text
Use case: stylized-concept
Asset type: iOS in-app mascot master sprite
Primary request: create a charming 8-bit pixel-art lawyer mascot named Saul, recognizable as a theatrical TV-style American lawyer through sandy side-parted comb-over hair, expressive dark eyebrows, confident friendly grin, light cream suit, muted blue shirt, bright red-and-yellow striped tie, and one hand touching his jacket lapel
Composition/framing: centered three-quarter full-body character, square canvas, generous even padding, readable at 96 points
Style/medium: deliberate hand-authored 16-bit-era pixel art using a controlled pixel grid, crisp block clusters, consistent charcoal outline, no antialiasing
Color palette: paper cream, charcoal, Saul yellow, warm skin, muted blue, restrained red
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background
Constraints: one character only; full silhouette separated from background; no cast shadow; no floor; no text; no logo; no watermark; do not use #00ff00 in the subject
Avoid: photorealism, 3D, vector-smooth curves, painterly edges, extra fingers, phone, speech bubble, scenery
```

- [ ] **Step 2: Generate the other states from the master reference**

Use the generated idle sprite as the only identity/style reference and issue one built-in generation call per state. Repeat all identity, palette, pixel-grid, padding, chroma-key, and avoid constraints; change only the pose:

```text
SaulThinking: same character and proportions, looking thoughtfully at a small cream case file held in both hands, focused but reassuring expression.
SaulTalking: same character and proportions, open speaking smile, one small persuasive pointing gesture, no speech bubble.
SaulCelebrating: same character and proportions, broad friendly smile, one clear thumbs-up, contained celebratory pose.
```

- [ ] **Step 3: Remove chroma-key backgrounds and create image sets**

Copy the four selected built-in results into `tmp/imagegen/saul-idle-chroma.png`, `tmp/imagegen/saul-thinking-chroma.png`, `tmp/imagegen/saul-talking-chroma.png`, and `tmp/imagegen/saul-celebrating-chroma.png`. Then run:

```bash
python "${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/scripts/remove_chroma_key.py" \
  --input tmp/imagegen/saul-idle-chroma.png \
  --out ios/BetterCallSaul/Resources/Assets.xcassets/SaulIdle.imageset/saul-idle.png \
  --auto-key border \
  --soft-matte \
  --transparent-threshold 12 \
  --opaque-threshold 220 \
  --despill
python "${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/scripts/remove_chroma_key.py" \
  --input tmp/imagegen/saul-thinking-chroma.png \
  --out ios/BetterCallSaul/Resources/Assets.xcassets/SaulThinking.imageset/saul-thinking.png \
  --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill
python "${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/scripts/remove_chroma_key.py" \
  --input tmp/imagegen/saul-talking-chroma.png \
  --out ios/BetterCallSaul/Resources/Assets.xcassets/SaulTalking.imageset/saul-talking.png \
  --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill
python "${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/scripts/remove_chroma_key.py" \
  --input tmp/imagegen/saul-celebrating-chroma.png \
  --out ios/BetterCallSaul/Resources/Assets.xcassets/SaulCelebrating.imageset/saul-celebrating.png \
  --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill
```

Each image-set `Contents.json` must use the matching filename:

```json
{
  "images" : [
    { "filename" : "saul-idle.png", "idiom" : "universal", "scale" : "1x" },
    { "idiom" : "universal", "scale" : "2x" },
    { "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

Substitute only the filename in the other three image sets.

- [ ] **Step 4: Generate the matching application icon**

Use the approved idle sprite as the identity reference:

```text
Use case: logo-brand
Asset type: finished iOS application icon, 1024 by 1024, opaque
Primary request: close 8-bit pixel-art portrait of the exact same Saul mascot, confident friendly lawyer grin, sandy side-parted hair, cream suit, muted blue shirt, red-and-yellow striped tie
Composition/framing: head and upper torso centered, generous 14 percent safe padding, bold readable silhouette for a small home-screen icon
Scene/backdrop: opaque warm paper-cream square with a strong Saul-yellow rectangular field and restrained charcoal border details
Style/medium: crisp hand-authored pixel art on one consistent grid, no antialiasing
Constraints: fill the complete square; no transparency; no text; no letters; no watermark; no rounded-corner mask baked into the artwork
Avoid: photorealism, 3D, gradients, tiny decorative clutter, extra people, phone, speech bubble
```

Save the selected output as `BetterCallSaul-AppIcon.png` and set the existing universal AppIcon entry to:

```json
{
  "images" : [
    {
      "filename" : "BetterCallSaul-AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

Strip the alpha channel from the icon while preserving PNG output:

```bash
python -c 'from PIL import Image; p="ios/BetterCallSaul/Resources/Assets.xcassets/AppIcon.appiconset/BetterCallSaul-AppIcon.png"; Image.open(p).convert("RGB").save(p)'
```

- [ ] **Step 5: Validate all raster deliverables**

Run:

```bash
sips -g pixelWidth -g pixelHeight -g hasAlpha \
  ios/BetterCallSaul/Resources/Assets.xcassets/Saul*.imageset/*.png \
  ios/BetterCallSaul/Resources/Assets.xcassets/AppIcon.appiconset/BetterCallSaul-AppIcon.png
```

Expected: all images are square; all four sprites report `hasAlpha: yes`; the icon reports `1024 × 1024` and `hasAlpha: no`. Inspect each image at original resolution for one consistent character, transparent corners, clean edges, no green fringe, no text, and no watermark.

- [ ] **Step 6: Commit the approved assets**

```bash
git add ios/BetterCallSaul/Resources/Assets.xcassets
git commit -m "feat: add 8-bit Saul artwork"
```

---

### Task 2: Add the reusable mascot model and view

**Files:**
- Create: `ios/BetterCallSaul/DesignSystem/SaulMascotView.swift`
- Create: `ios/BetterCallSaulTests/SaulMascotTests.swift`

**Interfaces:**
- Consumes: image names `SaulIdle`, `SaulThinking`, `SaulTalking`, and `SaulCelebrating` from Task 1.
- Produces: `SaulMascotState`, `SaulHelpCopy`, `SaulMascotView.init(state:size:isDecorative:)`, and `SaulTipBubble.init(text:)` for Tasks 3 and 4.

- [ ] **Step 1: Write failing state, copy, and asset tests**

```swift
import UIKit
import XCTest
@testable import BetterCallSaul

final class SaulMascotTests: XCTestCase {
    func testEveryStateMapsToExpectedBundledAsset() {
        XCTAssertEqual(
            SaulMascotState.allCases.map(\.assetName),
            ["SaulIdle", "SaulThinking", "SaulTalking", "SaulCelebrating"]
        )
        for state in SaulMascotState.allCases {
            XCTAssertNotNil(UIImage(named: state.assetName), state.assetName)
        }
    }

    func testHelpCopyIsDeterministicAndProductSafe() {
        XCTAssertEqual(SaulHelpCopy.line(at: 0), "Расскажите как было — я помогу собрать главное.")
        XCTAssertEqual(SaulHelpCopy.line(at: 3), SaulHelpCopy.line(at: 0))
        XCTAssertFalse(SaulHelpCopy.lines.joined().contains("AI"))
    }
}
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
xcodegen generate
xcodebuild test -quiet -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulTests/SaulMascotTests
```

Expected: compilation fails because `SaulMascotState` and `SaulHelpCopy` do not exist.

- [ ] **Step 3: Implement the semantic model, reusable view, and bubble**

Create `SaulMascotView.swift` with:

```swift
import SwiftUI

enum SaulMascotState: String, CaseIterable {
    case idle
    case thinking
    case talking
    case celebrating

    var assetName: String {
        switch self {
        case .idle: "SaulIdle"
        case .thinking: "SaulThinking"
        case .talking: "SaulTalking"
        case .celebrating: "SaulCelebrating"
        }
    }
}

enum SaulHelpCopy {
    static let lines = [
        "Расскажите как было — я помогу собрать главное.",
        "Чеки и скриншоты сделают обращение сильнее.",
        "Перед отправкой всё можно проверить."
    ]

    static func line(at index: Int) -> String {
        lines[index % lines.count]
    }
}

struct SaulMascotView: View {
    let state: SaulMascotState
    let size: CGFloat
    var isDecorative = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimated = false

    var body: some View {
        Image(state.assetName)
            .resizable()
            .interpolation(.none)
            .scaledToFit()
            .frame(width: size, height: size)
            .offset(y: verticalOffset)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .accessibilityHidden(isDecorative)
            .accessibilityLabel(isDecorative ? "" : "Сол, помощник")
            .accessibilityIdentifier("saulMascot.\(state.rawValue)")
            .onAppear(perform: startAnimation)
    }

    private var verticalOffset: CGFloat {
        state == .idle && isAnimated && !reduceMotion ? -2 : 0
    }

    private var rotation: Double {
        state == .thinking && isAnimated && !reduceMotion ? 1 : 0
    }

    private var scale: CGFloat {
        (state == .talking || state == .celebrating) && isAnimated && !reduceMotion ? 1.04 : 1
    }

    private func startAnimation() {
        guard !reduceMotion else { return }
        switch state {
        case .idle:
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { isAnimated = true }
        case .thinking:
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { isAnimated = true }
        case .talking, .celebrating:
            withAnimation(.spring(response: 0.36, dampingFraction: 0.68)) { isAnimated = true }
        }
    }
}

struct SaulTipBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.bcsBody(14, weight: .medium))
            .foregroundStyle(BCSColor.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BCSColor.paleYellow)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(BCSColor.divider))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityIdentifier("saulTipBubble")
    }
}
```

- [ ] **Step 4: Run the focused tests to verify GREEN**

Run the Task 2 command again. Expected: `SaulMascotTests` passes with zero failures.

- [ ] **Step 5: Commit the component**

```bash
git add ios/BetterCallSaul/DesignSystem/SaulMascotView.swift ios/BetterCallSaulTests/SaulMascotTests.swift
git commit -m "feat: add animated Saul mascot component"
```

---

### Task 3: Put interactive Saul on Home

**Files:**
- Modify: `ios/BetterCallSaul/Features/Home/HomeView.swift`
- Modify: `ios/BetterCallSaulUITests/PrimaryFlowUITests.swift`

**Interfaces:**
- Consumes: `SaulMascotView(state:size:isDecorative:)`, `SaulTipBubble(text:)`, and `SaulHelpCopy` from Task 2.
- Produces: interactive Home control `saulMascotButton`, bubble `saulTipBubble`, and deterministic tap behavior.

- [ ] **Step 1: Write the failing Home interaction UI test**

```swift
func testHomeSaulRevealsAndDismissesHelpfulCopy() {
    let saul = app.buttons["saulMascotButton"]
    XCTAssertTrue(saul.waitForExistence(timeout: 3))

    saul.tap()
    XCTAssertTrue(app.staticTexts["Расскажите как было — я помогу собрать главное."].waitForExistence(timeout: 2))
    XCTAssertTrue(app.descendants(matching: .any)["saulTipBubble"].exists)

    saul.tap()
    XCTAssertFalse(app.staticTexts["Расскажите как было — я помогу собрать главное."].exists)
}
```

- [ ] **Step 2: Run the UI test to verify RED**

```bash
xcodebuild test -quiet -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulUITests/PrimaryFlowUITests/testHomeSaulRevealsAndDismissesHelpfulCopy
```

Expected: failure because `saulMascotButton` does not exist.

- [ ] **Step 3: Replace the Home payphone and add local bubble state**

Add to `HomeView`:

```swift
@State private var isSaulTipVisible = false
@State private var saulTipIndex = 0
```

Place this immediately after `brandHeader`:

```swift
if isSaulTipVisible {
    SaulTipBubble(text: SaulHelpCopy.line(at: saulTipIndex))
        .padding(.bottom, 14)
        .transition(.opacity.combined(with: .move(edge: .top)))
}
```

Replace the payphone in `brandHeader` with:

```swift
Button {
    withAnimation(BCSMotion.spring(reduceMotion: reduceMotion)) {
        if isSaulTipVisible {
            isSaulTipVisible = false
            saulTipIndex = (saulTipIndex + 1) % SaulHelpCopy.lines.count
        } else {
            isSaulTipVisible = true
        }
    }
} label: {
    SaulMascotView(
        state: isSaulTipVisible ? .talking : .idle,
        size: 96,
        isDecorative: false
    )
}
.buttonStyle(.plain)
.frame(minWidth: 44, minHeight: 44)
.accessibilityLabel("Сол, помощник")
.accessibilityHint("Показывает короткую подсказку")
.accessibilityIdentifier("saulMascotButton")
```

Set `isSaulTipVisible = false` at the beginning of `beginCase(_:)`, and also dismiss it in `.onDisappear`.

- [ ] **Step 4: Run the focused Home UI test to verify GREEN**

Run the Task 3 command again. Expected: the test passes and the first line appears and dismisses deterministically.

- [ ] **Step 5: Commit Home integration**

```bash
git add ios/BetterCallSaul/Features/Home/HomeView.swift ios/BetterCallSaulUITests/PrimaryFlowUITests.swift
git commit -m "feat: add Saul helper to Home"
```

---

### Task 4: Add contextual thinking and celebration states

**Files:**
- Modify: `ios/BetterCallSaul/Features/Evidence/EvidenceView.swift`
- Modify: `ios/BetterCallSaul/Features/AIAnalysis/AIAnalysisView.swift`
- Modify: `ios/BetterCallSaul/Features/Document/DocumentView.swift`
- Modify: `ios/BetterCallSaulUITests/PrimaryFlowUITests.swift`

**Interfaces:**
- Consumes: `SaulMascotView` and semantic states from Task 2.
- Produces: stable containers `evidenceThinkingSaul`, `analysisThinkingSaul`, and `documentCelebratingSaul` without changing workflow state.

- [ ] **Step 1: Write the failing stable document-state UI assertion**

Extend `testEvidenceToAnalysisToDocumentFlow()` after the document title assertion:

```swift
XCTAssertTrue(app.descendants(matching: .any)["documentCelebratingSaul"].waitForExistence(timeout: 2))
```

- [ ] **Step 2: Run the focused flow to verify RED**

```bash
xcodebuild test -quiet -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulUITests/PrimaryFlowUITests/testEvidenceToAnalysisToDocumentFlow
```

Expected: failure because `documentCelebratingSaul` does not exist.

- [ ] **Step 3: Add thinking Saul to processing surfaces**

In `EvidenceView.processingState`, replace the `ProgressView` with:

```swift
SaulMascotView(state: .thinking, size: 52)
```

Keep the current neutral `Проверяем документ…` copy and add `.accessibilityIdentifier("evidenceThinkingSaul")` to the enclosing `HStack`.

In `AIAnalysisView.progressPanel`, replace the `ProgressView` with:

```swift
SaulMascotView(state: .thinking, size: 58)
```

Keep both existing progress strings and add `.accessibilityIdentifier("analysisThinkingSaul")` to the enclosing `HStack`.

- [ ] **Step 4: Add a contained document-ready celebration**

Insert below the document subtitle and before `documentPaper`:

```swift
HStack(spacing: 12) {
    SaulMascotView(state: .celebrating, size: 72)
    Text("Готово. Осталось проверить данные и отправить документ.")
        .font(.bcsBody(14, weight: .medium))
        .foregroundStyle(BCSColor.ink)
        .fixedSize(horizontal: false, vertical: true)
    Spacer(minLength: 0)
}
.padding(.top, 10)
.accessibilityElement(children: .combine)
.accessibilityIdentifier("documentCelebratingSaul")
```

The mascot remains decorative inside the combined container; the adjacent sentence carries the accessible meaning.

- [ ] **Step 5: Run focused unit and UI tests to verify GREEN**

Run:

```bash
xcodebuild test -quiet -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulTests/SaulMascotTests \
  -only-testing:BetterCallSaulUITests/PrimaryFlowUITests/testEvidenceToAnalysisToDocumentFlow
```

Expected: both focused suites pass with zero failures.

- [ ] **Step 6: Commit contextual states**

```bash
git add ios/BetterCallSaul/Features/Evidence/EvidenceView.swift \
  ios/BetterCallSaul/Features/AIAnalysis/AIAnalysisView.swift \
  ios/BetterCallSaul/Features/Document/DocumentView.swift \
  ios/BetterCallSaulUITests/PrimaryFlowUITests.swift
git commit -m "feat: show Saul throughout the legal workflow"
```

---

### Task 5: Verify the production experience and publish the branch

**Files:**
- Modify only if verification exposes a mascot-scoped defect.

**Interfaces:**
- Consumes: all deliverables from Tasks 1–4.
- Produces: a verified simulator build and synchronized remote branch.

- [ ] **Step 1: Regenerate the project and run the complete suite**

```bash
cd ios
xcodegen generate
xcodebuild test -quiet -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -resultBundlePath /tmp/BetterCallSaulMascotFinal.xcresult
```

Expected: every unit and UI test passes; zero failures and zero unexpected skips.

- [ ] **Step 2: Verify source hygiene and raster metadata**

```bash
git diff --check
rg -n 'Gemini|DeepSeek|AI-провайдер|API.?ключ|Локальн|DEMO|КОНЦЕПТ' \
  BetterCallSaul/Features BetterCallSaul/DesignSystem/SaulMascotView.swift || true
sips -g pixelWidth -g pixelHeight -g hasAlpha \
  BetterCallSaul/Resources/Assets.xcassets/Saul*.imageset/*.png \
  BetterCallSaul/Resources/Assets.xcassets/AppIcon.appiconset/BetterCallSaul-AppIcon.png
```

Expected: no source-hygiene matches, no whitespace errors, transparent sprites, and one opaque `1024 × 1024` icon.

- [ ] **Step 3: Install and launch the exact verified build**

```bash
xcodebuild build -quiet -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/BetterCallSaulMascotProduction
xcrun simctl install booted \
  /tmp/BetterCallSaulMascotProduction/Build/Products/Debug-iphonesimulator/BetterCallSaul.app
xcrun simctl launch booted kz.techvision.bettercallsaul
```

Inspect Home, the opened help bubble, analysis progress, document completion, and the simulator Home Screen icon. Confirm Saul is consistent, crisp, restrained, and never overlaps primary copy or controls.

- [ ] **Step 4: Push all implementation commits**

```bash
git status --short --branch
git push origin codex/ai-provider-flow
```

Expected: local `HEAD` equals `origin/codex/ai-provider-flow`; the worktree remains available for the next iteration.
