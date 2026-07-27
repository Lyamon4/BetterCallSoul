# Persistent Document Archive Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist every signed PDF and make the “Обращения” tab a browsable, downloadable document archive.

**Architecture:** A root-owned observable store writes Codable metadata and signed PDF files under Application Support. SwiftUI list/detail screens consume the store, while `DocumentView` archives automatically and exports the durable file URL.

**Tech Stack:** Swift 6, SwiftUI, Observation, Foundation FileManager/JSONEncoder, UIKit PDF renderer, PDFKit, XCTest, XCUITest.

## Global Constraints

- Only documents with a non-empty handwritten signature are archived.
- Saving the same legal case updates one record instead of duplicating it.
- Saved PDFs survive app restart.
- UI tests use an isolated temporary archive.
- The standard iOS share sheet remains the download/save mechanism.

---

### Task 1: Archive Domain and Persistence

**Files:**
- Create: `ios/BetterCallSaul/Domain/ArchivedDocument.swift`
- Create: `ios/BetterCallSaul/Services/DocumentArchiveStore.swift`
- Create: `ios/BetterCallSaulTests/DocumentArchiveStoreTests.swift`

**Interfaces:**
- Produces: `ArchivedDocument`, `DocumentArchiveStore.documents`, `save(draft:signature:caseID:savedAt:)`, `document(id:)`, `fileURL(for:)`.
- Consumes: `DocumentDraft`, `HandwrittenSignature`, injected root directory.

- [ ] Write unit tests for create/reload, update, ordering, and signature validation.
- [ ] Run focused tests and confirm missing archive types fail.
- [ ] Implement metadata and atomic PDF/manifest persistence.
- [ ] Run focused tests and confirm they pass.

### Task 2: Archive List and Detail

**Files:**
- Replace: `ios/BetterCallSaul/Features/Cases/CasesView.swift`
- Create: `ios/BetterCallSaul/Features/Cases/ArchivedDocumentView.swift`
- Create: `ios/BetterCallSaul/Components/PDFPreview.swift`
- Modify: `ios/BetterCallSaul/App/AppRouter.swift`
- Modify: `ios/BetterCallSaul/App/AppRootView.swift`

**Interfaces:**
- Produces: `archiveEmptyState`, `archivedDocument.<uuid>`, `archiveDownloadButton`, and route `.archivedDocument(UUID)`.
- Consumes: the root `DocumentArchiveStore`.

- [ ] Update UI tests to expect an empty archive before document creation.
- [ ] Add a UI test that opens a newly archived PDF.
- [ ] Run UI tests and confirm the placeholder behavior fails.
- [ ] Implement the archive list, PDF preview detail, and share action.

### Task 3: Automatic Archiving and App Wiring

**Files:**
- Modify: `ios/BetterCallSaul/App/BetterCallSaulApp.swift`
- Modify: `ios/BetterCallSaul/Features/Document/DocumentView.swift`
- Modify: `ios/BetterCallSaulUITests/PrimaryFlowUITests.swift`

**Interfaces:**
- Consumes: signed `DocumentDraft`, `LegalCase.id`, and profile name.
- Produces: automatic durable archive entry on final document appearance.

- [ ] Inject standard or isolated archive storage at app launch.
- [ ] Archive once on the final document screen and reuse that URL for export.
- [ ] Run focused archive UI tests.

### Task 4: Verification and Delivery

- [ ] Regenerate the Xcode project.
- [ ] Run all unit and UI tests with zero failures.
- [ ] Build, install, and launch the normal app on iPhone 17 Pro Simulator.
- [ ] Commit, push, create a pull request, and merge into `main`.
