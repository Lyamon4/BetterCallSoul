# Handwritten Signature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Require a drawn signature before preview/export and keep internal review guidance outside the legal document and PDF.

**Architecture:** Store normalized vector strokes in `CaseWorkflowStore`, render them through one reusable SwiftUI component, and draw the same vectors with Core Graphics in the PDF renderer. Insert a dedicated signature route between AI generation and the final document.

**Tech Stack:** Swift 6, SwiftUI, Observation, Core Graphics, UIGraphicsPDFRenderer, XCTest, XCUITest, XcodeGen.

## Global Constraints

- iOS deployment target remains 17.0.
- No third-party drawing dependency.
- Review guidance must not appear inside the document preview or exported PDF.
- A non-empty handwritten signature is mandatory before the document screen.
- New case or changed upstream evidence clears the stored signature.

---

### Task 1: Signature Domain and Workflow State

**Files:**
- Create: `ios/BetterCallSaul/Domain/HandwrittenSignature.swift`
- Modify: `ios/BetterCallSaul/Domain/CaseWorkflowStore.swift`
- Test: `ios/BetterCallSaulTests/HandwrittenSignatureTests.swift`
- Test: `ios/BetterCallSaulTests/CaseWorkflowStoreTests.swift`

**Interfaces:**
- Produces: `HandwrittenSignature(strokes:)`, `HandwrittenSignature.empty`, `isEmpty`, `confirmSignature(_:)`.
- Consumes: normalized `CGPoint` values in the closed range `0...1`.

- [ ] **Step 1: Write failing signature and workflow tests**

```swift
func testNormalizedSignatureRejectsEmptyStrokes() {
    XCTAssertTrue(HandwrittenSignature(strokes: [[]]).isEmpty)
}

@MainActor
func testConfirmSignatureStoresDrawnStrokes() {
    let store = CaseWorkflowStore()
    let signature = HandwrittenSignature(strokes: [[.init(x: 0.1, y: 0.2), .init(x: 0.8, y: 0.7)]])
    store.confirmSignature(signature)
    XCTAssertEqual(store.signature, signature)
}
```

- [ ] **Step 2: Run focused tests and verify missing types fail**

Run:

```bash
xcodebuild test -project ios/BetterCallSaul.xcodeproj -scheme BetterCallSaul -destination 'platform=iOS Simulator,id=8FEAC48D-83DB-4ED3-9870-D48969787A2D' -only-testing:BetterCallSaulTests/HandwrittenSignatureTests -only-testing:BetterCallSaulTests/CaseWorkflowStoreTests
```

Expected: compile failure because `HandwrittenSignature` and `confirmSignature` do not exist.

- [ ] **Step 3: Implement normalized vector signature state**

Create the immutable domain value and add a resettable signature property plus confirmation method to the workflow store.

- [ ] **Step 4: Run focused tests and verify they pass**

Run the command from Step 2. Expected: all focused tests pass.

### Task 2: Signature Route and Drawing Screen

**Files:**
- Create: `ios/BetterCallSaul/Features/Signature/SignatureCanvasView.swift`
- Create: `ios/BetterCallSaul/Features/Signature/SignatureView.swift`
- Modify: `ios/BetterCallSaul/App/AppRouter.swift`
- Modify: `ios/BetterCallSaul/App/AppRootView.swift`
- Modify: `ios/BetterCallSaul/Features/AIAnalysis/AIAnalysisView.swift`
- Test: `ios/BetterCallSaulTests/AppRouterTests.swift`
- Test: `ios/BetterCallSaulUITests/PrimaryFlowUITests.swift`

**Interfaces:**
- Consumes: `Binding<HandwrittenSignature>` and `CaseWorkflowStore.confirmSignature(_:)`.
- Produces: `AppRoute.signature`, `signatureCanvas`, `clearSignatureButton`, `confirmSignatureButton`.

- [ ] **Step 1: Add failing route and UI-flow tests**

```swift
func testSignatureRouteCanPrecedeDocument() {
    let router = AppRouter()
    router.open(.signature)
    router.open(.document)
    XCTAssertEqual(router.path, [.signature, .document])
}
```

Update UI assertions so preparing the document opens “Оставьте подпись”, the confirm action begins disabled, a drag enables it, and confirmation opens “Претензия готова”.

- [ ] **Step 2: Run tests and verify signature route/screen failures**

Run focused unit and UI tests. Expected: missing route and missing signature screen assertions fail.

- [ ] **Step 3: Implement canvas, screen, and navigation**

Use `DragGesture(minimumDistance: 0)` but only commit strokes containing at least two distinct points. Normalize locations against the drawing bounds. Confirm into the workflow and open `.document`.

- [ ] **Step 4: Run focused route and UI tests**

Expected: route and signature-flow tests pass.

### Task 3: Preview and PDF Rendering

**Files:**
- Create: `ios/BetterCallSaul/Features/Signature/DocumentSignatureView.swift`
- Modify: `ios/BetterCallSaul/Features/Document/DocumentView.swift`
- Modify: `ios/BetterCallSaul/Services/PDFDocumentRenderer.swift`
- Test: `ios/BetterCallSaulTests/PDFDocumentRendererTests.swift`

**Interfaces:**
- Consumes: `HandwrittenSignature`.
- Produces: `PDFDocumentRenderer.render(_:signature:)` and `write(_:signature:to:)`.

- [ ] **Step 1: Add failing PDF content tests**

```swift
func testRendererExcludesInternalReviewNoticeFromPDF() throws {
    let data = try PDFDocumentRenderer().render(draft, signature: signature)
    XCTAssertFalse(PDFDocument(data: data)?.string?.contains(draft.reviewNotice) == true)
}

func testRendererDrawsSignatureInk() throws {
    let signed = try PDFDocumentRenderer().render(draft, signature: signature)
    let unsigned = try PDFDocumentRenderer().render(draft, signature: .empty)
    XCTAssertGreaterThan(signed.count, unsigned.count)
}
```

- [ ] **Step 2: Run focused PDF tests and verify failure**

Expected: old API has no signature parameter and current PDF contains `reviewNotice`.

- [ ] **Step 3: Remove review note from paper/PDF and draw vector signature**

Render the warning below the paper as interface-only content. Scale normalized stroke points into a stable preview/PDF signature rectangle.

- [ ] **Step 4: Run focused PDF tests and verify pass**

Expected: review notice is absent from PDF text and signature ink changes rendered output.

### Task 4: Integration Verification and Delivery

**Files:**
- Regenerate: `ios/BetterCallSaul.xcodeproj`

**Interfaces:**
- Consumes: all previous tasks.
- Produces: a tested simulator build on the active iPhone 17 Pro.

- [ ] **Step 1: Regenerate Xcode project**

Run:

```bash
cd ios && xcodegen generate
```

- [ ] **Step 2: Run the full unit and UI suite**

Run:

```bash
xcodebuild test -project ios/BetterCallSaul.xcodeproj -scheme BetterCallSaul -destination 'platform=iOS Simulator,id=8FEAC48D-83DB-4ED3-9870-D48969787A2D'
```

Expected: zero failures.

- [ ] **Step 3: Build, install, and launch**

Build Debug for the active simulator, install `BetterCallSaul.app`, and launch `kz.techvision.bettercallsaul`.

- [ ] **Step 4: Commit and push**

Stage only feature, test, generated project, and design/plan files. Commit on `codex/handwritten-signature` and push that branch.
