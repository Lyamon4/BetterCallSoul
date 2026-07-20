# Photo Picker Presentation Fix Design

## Goal

Make the `Выбрать фото` action reliably open the system photo library so a receipt imported into Simulator Photos can be selected and processed.

## Root Cause

`EvidenceView` currently places `PhotosPicker` directly inside a SwiftUI `Menu`. On the current iOS 26.5 Simulator, selecting that menu item dismisses the menu without presenting the picker. The separate `Выбрать файл или PDF` action works, but it opens the Files document picker, which cannot see images stored only in Photos.

## Chosen Design

Keep the existing upload card and two-item menu. Replace the menu-embedded `PhotosPicker` with a normal `Button` that sets a dedicated `isPhotoPickerPresented` state. Attach the system `.photosPicker(isPresented:selection:matching:)` presentation modifier to `EvidenceView` and continue storing the result in the existing `selectedPhoto` state.

The visible design, wording, animations, PDF import path, evidence processing, OCR, and Gemini analysis remain unchanged.

## Data Flow

1. The user opens the existing evidence upload menu.
2. `Выбрать фото` changes `isPhotoPickerPresented` to `true`.
3. SwiftUI presents the system photo library independently of the menu lifecycle.
4. The selected `PhotosPickerItem` is written to `selectedPhoto`.
5. The existing `onChange` handler calls `processPhoto(_:)`.
6. The existing importer, OCR, Gemini analysis, editable fields, and error handling continue unchanged.

`Выбрать файл или PDF` continues to set `isFileImporterPresented` and present the document picker.

## Testing

- Add a testable presentation-state helper that distinguishes the photo and file actions without depending on the system picker UI.
- First verify that the new photo action test fails against the current implementation.
- Verify unit tests after the minimal state-driven change.
- Build and launch the app on the iPhone 17 Pro Simulator.
- Manually confirm that `Добавьте спорный счёт` → `Выбрать фото` opens Photos and shows the previously imported receipt.

## Success Criteria

- `Выбрать фото` opens the system photo picker every time.
- The imported receipt appears and can be selected.
- `Выбрать файл или PDF` still opens Files.
- Selecting an image continues into the existing receipt-processing flow.
- No visible redesign or unrelated behavior change is introduced.
