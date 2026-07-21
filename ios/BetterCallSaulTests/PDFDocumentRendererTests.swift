import PDFKit
import XCTest
@testable import BetterCallSaul

@MainActor
final class PDFDocumentRendererTests: XCTestCase {
    func testRendererCreatesReadableSinglePagePDF() throws {
        let draft = DocumentDraftGenerator().makeDraft(
            from: DemoFixtures.activeCase,
            senderName: "Алим",
            createdAt: Date(timeIntervalSince1970: 1_774_000_000)
        )

        let data = try PDFDocumentRenderer().render(draft)
        let document = PDFDocument(data: data)

        XCTAssertTrue(data.starts(with: Data("%PDF".utf8)))
        XCTAssertEqual(document?.pageCount, 1)
        XCTAssertTrue(document?.string?.contains("MegaPlus Kazakhstan") == true)
        XCTAssertTrue(document?.string?.contains("24 900 ₸") == true)
    }

    func testRendererWritesShareableFile() throws {
        let draft = DocumentDraftGenerator().makeDraft(from: DemoFixtures.activeCase)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = try PDFDocumentRenderer().write(draft, to: directory)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(url.pathExtension, "pdf")
        XCTAssertGreaterThan((try Data(contentsOf: url)).count, 1_000)
    }
}
