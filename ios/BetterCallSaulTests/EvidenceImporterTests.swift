import UIKit
import XCTest
@testable import BetterCallSaul

@MainActor
final class EvidenceImporterTests: XCTestCase {
    func testImportsImageDataAndBuildsEvidenceMetadata() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 80), format: format)
        let data = renderer.pngData { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 80))
            ("MEGAPLUS" as NSString).draw(
                at: CGPoint(x: 8, y: 20),
                withAttributes: [.font: UIFont.systemFont(ofSize: 16)]
            )
        }

        let imported = try EvidenceImporter().importImageData(data, fileName: "receipt.png")

        XCTAssertEqual(imported.item.fileName, "receipt.png")
        XCTAssertFalse(imported.item.fileSize.isEmpty)
        XCTAssertEqual(imported.image.width, 120)
        XCTAssertEqual(imported.image.height, 80)
        XCTAssertEqual(imported.payload.mimeType, "image/jpeg")
        XCTAssertFalse(imported.payload.data.isEmpty)
    }

    func testRejectsInvalidImageData() {
        XCTAssertThrowsError(
            try EvidenceImporter().importImageData(Data("not an image".utf8), fileName: "broken.png")
        )
    }
}
