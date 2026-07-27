# Handwritten Signature Flow Design

## Goal

Move internal review guidance outside the legal document and require a real handwritten signature before the user can see, export, or share the finished claim.

## User Flow

1. The user finishes AI analysis and taps “Подготовить документ”.
2. BetterCallSaul generates the legal text and opens a dedicated final step titled “Оставьте подпись”.
3. The user draws inside a large signature area with a finger or pointer.
4. “Продолжить” stays disabled until at least one meaningful stroke exists.
5. The user may clear and redraw the signature.
6. After confirmation, the app stores the signature in the current case workflow and opens “Претензия готова”.
7. The preview and exported PDF display the same handwritten signature.

## Document and Review Separation

`DocumentDraft.body` remains the legal document content. `DocumentDraft.reviewNotice` remains internal review metadata for the app interface only.

The review notice:

- appears below the document preview in the warning row/detail panel;
- does not appear inside the white document paper;
- is never drawn into the exported PDF.

## Architecture

`HandwrittenSignature` is a small domain value containing normalized vector strokes. Normalized coordinates make the signature independent of screen and PDF dimensions.

`SignatureCanvasView` owns drawing gestures and renders strokes with SwiftUI `Canvas`. `SignatureView` provides the dedicated last-step experience, writes the confirmed value into `CaseWorkflowStore`, and then routes to `DocumentView`.

`DocumentSignatureView` renders the stored vector value in the document preview. `PDFDocumentRenderer` draws the same vectors into the signature box using Core Graphics.

## Navigation

`AppRoute.signature` is inserted between `.aiAnalysis` and `.document`. AI generation opens `.signature`; only successful signature confirmation opens `.document`.

The progress copy changes from four to five steps:

- Evidence: 2 of 5
- AI analysis: 3 of 5
- Signature: 4 of 5
- Ready document: final result

## State and Reset Rules

`CaseWorkflowStore` owns `private(set) var signature = .empty`.

- Starting a new case clears the signature.
- Attaching/removing evidence or editing upstream input clears any previously confirmed signature.
- Confirming the signature replaces the stored value.
- Export requires the stored signature.

## Error and Accessibility Behavior

- A tap without a drag does not count as a signature.
- The drawing area has an accessibility identifier and descriptive label.
- Clear and continue actions have stable identifiers for UI tests.
- The document view shows a neutral error if export is attempted without a signature due to unexpected navigation/state restoration.

## Testing

- Unit tests cover normalization, emptiness, store reset/confirmation, router ordering, PDF review-note exclusion, and signature inclusion.
- UI tests cover the full analysis → signature → document flow and verify the continue button is initially disabled.
- A full simulator build and test run validates integration.
