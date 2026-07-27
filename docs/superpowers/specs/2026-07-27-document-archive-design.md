# Persistent Document Archive Design

## Goal

Replace the placeholder “Обращения” tab with a durable archive of every signed document the user has prepared. Each archive item must open its saved PDF and expose the iOS share sheet so the user can save it to Files or send it again.

## User Flow

1. The user completes analysis and adds a handwritten signature.
2. When the final document screen opens, BetterCallSaul automatically renders and archives the signed PDF.
3. “Обращения” shows all archived documents, newest first.
4. Each row shows title, recipient, case number, save date, and a ready status.
5. Tapping a row opens a detail screen with an embedded PDF preview.
6. “Скачать PDF” opens the standard iOS share sheet, including “Save to Files”.

## Persistence

The archive lives under the app’s Application Support directory:

- `manifest.json` contains Codable document metadata.
- `pdf/<archive-id>.pdf` contains the immutable rendered document.

The archive survives app termination and device restart. UI-testing uses a separate temporary directory that is cleared at test launch, so automated runs never modify real user documents.

## Identity and Updates

An archive record stores both its own stable UUID and the originating `LegalCase.id`.

- Saving the same case again updates the existing record and PDF.
- Saving another case creates a new record.
- Records are sorted by `savedAt` descending.

## Architecture

`DocumentArchiveStore` is a main-actor observable store owned by `BetterCallSaulApp`. It owns filesystem persistence and exposes `documents`, `save`, `document(id:)`, and `fileURL(for:)`.

`DocumentView` receives the store and archives on first appearance. Export reuses the durable archived URL.

`CasesView` renders archive metadata and routes to `ArchivedDocumentView`. The detail view embeds `PDFKit.PDFView` and shares the stored URL through the existing `ShareSheet`.

## Error Handling

- Unsigned drafts cannot be archived.
- Missing PDF files show a neutral unavailable state.
- Archive failures do not destroy the in-memory workflow; the final document screen shows an alert and still allows retry through export.
- A corrupt manifest yields an empty archive rather than crashing the app.

## Testing

- Unit tests verify create, reload, same-case update, distinct-case ordering, signed PDF existence, and missing-signature rejection.
- UI tests verify the initial empty state, automatic archive creation, opening the archived document, and availability of the download action.
- The complete unit and UI suites run before delivery.
