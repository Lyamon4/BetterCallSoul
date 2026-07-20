# Reliable Photo Picker Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `Выбрать фото` reliably open the iOS photo library while preserving the existing receipt processing and PDF import flows.

**Architecture:** Introduce a small value-type presentation coordinator that owns the mutually exclusive photo and file picker states. `EvidenceView` will trigger that coordinator from ordinary menu buttons and present `PhotosPicker` through the view-level `.photosPicker` modifier, decoupling system presentation from the menu lifecycle.

**Tech Stack:** Swift 6, SwiftUI, PhotosUI, XCTest, XcodeGen, iOS 17+

## Global Constraints

- Preserve the existing upload card, menu wording, visual design, animations, and category-specific content.
- Keep photo selection connected to the existing `selectedPhoto` and `processPhoto(_:)` flow.
- Keep `Выбрать файл или PDF` connected to the existing file importer and `processFile(at:)` flow.
- Do not change OCR, Gemini analysis, API configuration, or document generation.
- Build and manually verify on the iPhone 17 Pro Simulator running iOS 26.5.

---

### Task 1: Decouple System Pickers From the Upload Menu

**Files:**
- Create: `ios/BetterCallSaul/Features/Evidence/EvidencePickerPresentation.swift`
- Create: `ios/BetterCallSaulTests/EvidencePickerPresentationTests.swift`
- Modify: `ios/BetterCallSaul/Features/Evidence/EvidenceView.swift`

**Interfaces:**
- Consumes: SwiftUI `Binding<Bool>`, PhotosUI `PhotosPickerItem`, and the existing `selectedPhoto` processing flow.
- Produces: `EvidencePickerPresentation`, with `isPhotoPickerPresented`, `isFileImporterPresented`, `presentPhotoPicker()`, `presentFileImporter()`, `setPhotoPickerPresented(_:)`, and `setFileImporterPresented(_:)`.

- [ ] **Step 1: Write the failing presentation-state tests**

Create `ios/BetterCallSaulTests/EvidencePickerPresentationTests.swift`:

```swift
import XCTest
@testable import BetterCallSaul

final class EvidencePickerPresentationTests: XCTestCase {
    func testPresentPhotoPickerSelectsOnlyPhotoDestination() {
        var presentation = EvidencePickerPresentation()

        presentation.presentPhotoPicker()

        XCTAssertTrue(presentation.isPhotoPickerPresented)
        XCTAssertFalse(presentation.isFileImporterPresented)
    }

    func testPresentFileImporterSelectsOnlyFileDestination() {
        var presentation = EvidencePickerPresentation()
        presentation.presentPhotoPicker()

        presentation.presentFileImporter()

        XCTAssertFalse(presentation.isPhotoPickerPresented)
        XCTAssertTrue(presentation.isFileImporterPresented)
    }

    func testSystemDismissalClearsPresentedDestination() {
        var presentation = EvidencePickerPresentation()
        presentation.presentPhotoPicker()
        presentation.setPhotoPickerPresented(false)
        XCTAssertFalse(presentation.isPhotoPickerPresented)

        presentation.presentFileImporter()
        presentation.setFileImporterPresented(false)
        XCTAssertFalse(presentation.isFileImporterPresented)
    }
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

```bash
cd ios
xcodegen generate
xcodebuild test -quiet -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -derivedDataPath .derivedData \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BetterCallSaulTests/EvidencePickerPresentationTests
```

Expected: compilation fails with `cannot find 'EvidencePickerPresentation' in scope` because the coordinator does not exist yet.

- [ ] **Step 3: Add the minimal presentation coordinator**

Create `ios/BetterCallSaul/Features/Evidence/EvidencePickerPresentation.swift`:

```swift
struct EvidencePickerPresentation: Equatable {
    private(set) var isPhotoPickerPresented = false
    private(set) var isFileImporterPresented = false

    mutating func presentPhotoPicker() {
        isFileImporterPresented = false
        isPhotoPickerPresented = true
    }

    mutating func presentFileImporter() {
        isPhotoPickerPresented = false
        isFileImporterPresented = true
    }

    mutating func setPhotoPickerPresented(_ isPresented: Bool) {
        isPhotoPickerPresented = isPresented
    }

    mutating func setFileImporterPresented(_ isPresented: Bool) {
        isFileImporterPresented = isPresented
    }
}
```

- [ ] **Step 4: Drive both picker modifiers from the coordinator**

In `ios/BetterCallSaul/Features/Evidence/EvidenceView.swift`, replace `isFileImporterPresented` with:

```swift
@State private var pickerPresentation = EvidencePickerPresentation()
```

Add these bindings inside `EvidenceView`:

```swift
private var photoPickerPresented: Binding<Bool> {
    Binding(
        get: { pickerPresentation.isPhotoPickerPresented },
        set: { pickerPresentation.setPhotoPickerPresented($0) }
    )
}

private var fileImporterPresented: Binding<Bool> {
    Binding(
        get: { pickerPresentation.isFileImporterPresented },
        set: { pickerPresentation.setFileImporterPresented($0) }
    )
}
```

Present the system photo picker at view level immediately before `.fileImporter`:

```swift
.photosPicker(
    isPresented: photoPickerPresented,
    selection: $selectedPhoto,
    matching: .images
)
.fileImporter(
    isPresented: fileImporterPresented,
    allowedContentTypes: [.image, .pdf]
) { result in
    guard case let .success(url) = result else {
        if case let .failure(error) = result {
            errorMessage = error.localizedDescription
        }
        return
    }
    Task { await processFile(at: url) }
}
```

Replace the two menu items with ordinary buttons:

```swift
Button {
    pickerPresentation.presentPhotoPicker()
} label: {
    Label("Выбрать фото", systemImage: "photo")
}
Button {
    pickerPresentation.presentFileImporter()
} label: {
    Label("Выбрать файл или PDF", systemImage: "folder")
}
```

- [ ] **Step 5: Run focused and complete automated tests**

Run the focused command from Step 2. Expected: all three `EvidencePickerPresentationTests` pass.

Then run:

```bash
cd ios
xcodebuild test -quiet -project BetterCallSaul.xcodeproj -scheme BetterCallSaul \
  -derivedDataPath .derivedData \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: all unit and UI tests pass with zero failures.

- [ ] **Step 6: Install and manually verify the imported receipt**

```bash
cd ios
xcrun simctl bootstatus 'iPhone 17 Pro' -b
xcrun simctl install 'iPhone 17 Pro' \
  .derivedData/Build/Products/Debug-iphonesimulator/BetterCallSaul.app
xcrun simctl launch 'iPhone 17 Pro' kz.techvision.bettercallsaul
```

Manual assertion: open any category, tap the upload card, tap `Выбрать фото`, confirm the system photo library opens and displays the imported receipt. Select it and confirm the evidence screen enters its existing processing state. Re-open the menu and confirm `Выбрать файл или PDF` still opens Files.

- [ ] **Step 7: Commit and push the implementation**

```bash
git add ios/BetterCallSaul/Features/Evidence/EvidencePickerPresentation.swift \
  ios/BetterCallSaul/Features/Evidence/EvidenceView.swift \
  ios/BetterCallSaulTests/EvidencePickerPresentationTests.swift
git commit -m "fix: reliably present receipt photo picker"
git push origin codex/ai-provider-flow
```
