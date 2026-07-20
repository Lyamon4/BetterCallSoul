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
