import XCTest
@testable import BetterCallSaul

@MainActor
final class DocumentArchiveStoreTests: XCTestCase {
    func testSignedDocumentIsWrittenAndReloadedFromDisk() throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let caseID = UUID()
        let savedAt = Date(timeIntervalSince1970: 1_774_100_000)
        let store = DocumentArchiveStore(rootDirectory: directory)

        let archived = try store.save(
            draft: makeDraft(caseNumber: "BCS-001", title: "Требование о возврате"),
            signature: Self.signature,
            caseID: caseID,
            savedAt: savedAt
        )

        XCTAssertEqual(store.documents, [archived])
        XCTAssertEqual(archived.caseID, caseID)
        XCTAssertEqual(archived.title, "Требование о возврате")
        let pdfURL = try XCTUnwrap(store.fileURL(for: archived))
        XCTAssertTrue(try Data(contentsOf: pdfURL).starts(with: Data("%PDF".utf8)))

        let reloaded = DocumentArchiveStore(rootDirectory: directory)
        XCTAssertEqual(reloaded.documents, [archived])
        XCTAssertEqual(reloaded.fileURL(for: archived), pdfURL)
    }

    func testSavingSameCaseUpdatesOneStableArchiveRecord() throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DocumentArchiveStore(rootDirectory: directory)
        let caseID = UUID()
        let first = try store.save(
            draft: makeDraft(caseNumber: "BCS-002", title: "Первый вариант"),
            signature: Self.signature,
            caseID: caseID,
            savedAt: Date(timeIntervalSince1970: 100)
        )

        let updated = try store.save(
            draft: makeDraft(caseNumber: "BCS-002", title: "Финальный вариант"),
            signature: Self.signature,
            caseID: caseID,
            savedAt: Date(timeIntervalSince1970: 200)
        )

        XCTAssertEqual(store.documents.count, 1)
        XCTAssertEqual(updated.id, first.id)
        XCTAssertEqual(updated.title, "Финальный вариант")
        XCTAssertEqual(store.documents.first, updated)
    }

    func testDifferentCasesAreSortedNewestFirst() throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DocumentArchiveStore(rootDirectory: directory)
        let older = try store.save(
            draft: makeDraft(caseNumber: "BCS-OLD", title: "Старое обращение"),
            signature: Self.signature,
            caseID: UUID(),
            savedAt: Date(timeIntervalSince1970: 100)
        )
        let newer = try store.save(
            draft: makeDraft(caseNumber: "BCS-NEW", title: "Новое обращение"),
            signature: Self.signature,
            caseID: UUID(),
            savedAt: Date(timeIntervalSince1970: 200)
        )

        XCTAssertEqual(store.documents.map(\.id), [newer.id, older.id])
    }

    func testUnsignedDocumentIsRejectedWithoutCreatingArchiveEntry() {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DocumentArchiveStore(rootDirectory: directory)

        XCTAssertThrowsError(
            try store.save(
                draft: makeDraft(caseNumber: "BCS-003", title: "Без подписи"),
                signature: .empty,
                caseID: UUID()
            )
        ) { error in
            XCTAssertEqual(error as? DocumentArchiveError, .missingSignature)
        }
        XCTAssertTrue(store.documents.isEmpty)
    }

    private func makeTemporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("DocumentArchiveStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeDraft(caseNumber: String, title: String) -> DocumentDraft {
        DocumentDraft(
            caseNumber: caseNumber,
            createdAt: Date(timeIntervalSince1970: 1_774_000_000),
            recipient: "ТОО Example",
            title: title,
            body: "Прошу рассмотреть требования и предоставить письменный ответ.",
            reviewNotice: "Проверьте данные.",
            attachmentCount: 1,
            senderName: "Алим",
            requiresReview: false
        )
    }

    private static let signature = HandwrittenSignature(
        strokes: [[
            CGPoint(x: 0.1, y: 0.7),
            CGPoint(x: 0.4, y: 0.2),
            CGPoint(x: 0.9, y: 0.6)
        ]]
    )
}
