import UIKit
import XCTest
@testable import BetterCallSaul

@MainActor
final class EvidencePayloadTests: XCTestCase {
    func testImageImporterNormalizesGeminiPayloadToJPEG() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 80), format: format)
        let sourceData = renderer.pngData { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 80))
        }

        let imported = try EvidenceImporter().importImageData(sourceData, fileName: "receipt.png")

        XCTAssertEqual(imported.payload.mimeType, "image/jpeg")
        XCTAssertEqual(imported.payload.fileName, "receipt.jpg")
        XCTAssertFalse(imported.payload.data.isEmpty)
        XCTAssertEqual(imported.payload.previewImage.width, 120)
        XCTAssertEqual(imported.item.fileName, "receipt.png")
    }

    func testImporterRejectsPayloadOverTenMegabytesBeforeDecoding() {
        let oversized = Data(repeating: 0, count: 10 * 1_024 * 1_024 + 1)

        XCTAssertThrowsError(
            try EvidenceImporter().importImageData(oversized, fileName: "oversized.png")
        ) { error in
            XCTAssertEqual(error as? AIProviderError, .payloadTooLarge(maximumMB: 10))
        }
    }
}
