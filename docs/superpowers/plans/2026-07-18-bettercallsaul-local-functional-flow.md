# BetterCallSaul Local Functional Flow — Implementation Plan

**Goal:** Turn the approved visual MVP into one honest end-to-end local workflow: select evidence, recognize receipt text on-device, review extracted facts, generate a real PDF, and share it with the iOS share sheet.

**Architecture:** A main-actor observable `CaseWorkflowStore` owns the mutable case. Small deterministic services handle receipt parsing, document drafting, Vision OCR, and PDF rendering. SwiftUI views receive the shared store and never call Gemini or contain secret keys. UI-testing mode keeps the approved fixture so screenshot tests remain stable.

**Tech:** Swift 6, SwiftUI, Observation, PhotosUI, UniformTypeIdentifiers, Vision, PDFKit/UIKit, XCTest, XcodeGen.

---

## Task 1: Case workflow and deterministic receipt parsing

**Files:**
- Create: `ios/BetterCallSaul/Domain/CaseWorkflowStore.swift`
- Create: `ios/BetterCallSaul/Services/ReceiptFieldParser.swift`
- Test: `ios/BetterCallSaulTests/CaseWorkflowStoreTests.swift`
- Test: `ios/BetterCallSaulTests/ReceiptFieldParserTests.swift`

1. Write tests for starting each case type, applying extraction, editing a field, and status transitions.
2. Write parser tests using synthetic OCR text containing `MegaPlus`, `24 900 ₸`, and `17.07.2026`.
3. Run the focused tests and confirm they fail because the types do not exist.
4. Implement the minimum store and parser required by the tests.
5. Run all unit tests and commit.

## Task 2: Safe document draft and real PDF

**Files:**
- Create: `ios/BetterCallSaul/Domain/DocumentDraft.swift`
- Create: `ios/BetterCallSaul/Services/DocumentDraftGenerator.swift`
- Create: `ios/BetterCallSaul/Services/PDFDocumentRenderer.swift`
- Test: `ios/BetterCallSaulTests/DocumentDraftGeneratorTests.swift`
- Test: `ios/BetterCallSaulTests/PDFDocumentRendererTests.swift`

1. Test that confirmed values appear in the claim and missing values are not invented.
2. Test that rendered data is a readable one-page PDF.
3. Confirm the focused tests fail.
4. Implement deterministic Russian claim copy and an A4-style PDF renderer.
5. Run all unit tests and commit.

## Task 3: On-device evidence import and OCR

**Files:**
- Create: `ios/BetterCallSaul/Services/VisionTextRecognizer.swift`
- Create: `ios/BetterCallSaul/Services/EvidenceImporter.swift`
- Modify: `ios/BetterCallSaul/Features/Evidence/EvidenceView.swift`
- Modify: `ios/project.yml`

1. Add an importer that accepts image data and the first page of a PDF.
2. Add Vision text recognition with Russian and English recognition languages.
3. Wire `PhotosPicker` and `fileImporter` into the existing dashed upload control.
4. Show honest idle, processing, success, and failure states; preserve manual editing.
5. Verify compilation and unit tests, then commit.

## Task 4: Wire shared workflow, PDF export, and sharing

**Files:**
- Create: `ios/BetterCallSaul/Components/ShareSheet.swift`
- Modify: `ios/BetterCallSaul/App/BetterCallSaulApp.swift`
- Modify: `ios/BetterCallSaul/App/AppRootView.swift`
- Modify: `ios/BetterCallSaul/Features/Home/HomeView.swift`
- Modify: `ios/BetterCallSaul/Features/Document/DocumentView.swift`
- Modify: `ios/BetterCallSaul/Features/Cases/CasesView.swift`
- Modify: `ios/BetterCallSaulUITests/PrimaryFlowUITests.swift`

1. Add a UI test for the deterministic test-mode flow reaching a real PDF-ready state.
2. Confirm the new UI assertion fails.
3. Inject one store from the app root and start the selected case type from Home.
4. Generate a PDF into the temporary directory and open `UIActivityViewController` from both document actions.
5. Update case status after export and display live case facts in Home/Cases/Document.
6. Run all unit and UI tests, build, boot the simulator, install, launch, and commit.

## Task 5: Final verification and publish

1. Confirm no API key or secret is present with `rg`.
2. Run a clean full test suite on iPhone 17 Pro.
3. Inspect `git diff --check` and working-tree status.
4. Push `codex/local-functional-flow` to origin.

## Deliberate boundary

Gemini remains a separate backend task. The previously shared key is compromised and must be revoked; no Gemini credential is embedded in the iOS binary. This slice works offline and produces a user-reviewed document without inventing legal facts.
