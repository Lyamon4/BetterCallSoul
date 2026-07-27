import Foundation
import Observation

@MainActor
@Observable
final class DocumentArchiveStore {
    private(set) var documents: [ArchivedDocument] = []

    let rootDirectory: URL

    private let fileManager: FileManager
    private let renderer: PDFDocumentRenderer

    init(
        rootDirectory: URL = DocumentArchiveStore.defaultRootDirectory,
        fileManager: FileManager = .default,
        renderer: PDFDocumentRenderer = PDFDocumentRenderer()
    ) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
        self.renderer = renderer
        loadManifest()
    }

    @discardableResult
    func save(
        draft: DocumentDraft,
        signature: HandwrittenSignature,
        caseID: UUID,
        savedAt: Date = Date()
    ) throws -> ArchivedDocument {
        guard !signature.isEmpty else {
            throw DocumentArchiveError.missingSignature
        }

        try createDirectories()

        let existing = documents.first(where: { $0.caseID == caseID })
        let id = existing?.id ?? UUID()
        let pdfFileName = "\(id.uuidString).pdf"
        let pdfURL = pdfDirectory.appendingPathComponent(pdfFileName)
        let pdfData = try renderer.render(draft, signature: signature)
        try pdfData.write(to: pdfURL, options: .atomic)

        let document = ArchivedDocument(
            id: id,
            caseID: caseID,
            caseNumber: draft.caseNumber,
            title: draft.title,
            recipient: draft.recipient,
            senderName: draft.senderName,
            createdAt: draft.createdAt,
            savedAt: savedAt,
            pdfFileName: pdfFileName
        )

        if let index = documents.firstIndex(where: { $0.caseID == caseID }) {
            documents[index] = document
        } else {
            documents.append(document)
        }
        sortDocuments()

        do {
            try writeManifest()
        } catch {
            if existing == nil {
                try? fileManager.removeItem(at: pdfURL)
            }
            loadManifest()
            throw error
        }

        return document
    }

    func document(id: UUID) -> ArchivedDocument? {
        documents.first(where: { $0.id == id })
    }

    func fileURL(for document: ArchivedDocument) -> URL? {
        let url = pdfDirectory.appendingPathComponent(document.pdfFileName)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    static var defaultRootDirectory: URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        return applicationSupport
            .appendingPathComponent("BetterCallSaul", isDirectory: true)
            .appendingPathComponent("DocumentArchive", isDirectory: true)
    }

    private var pdfDirectory: URL {
        rootDirectory.appendingPathComponent("pdf", isDirectory: true)
    }

    private var manifestURL: URL {
        rootDirectory.appendingPathComponent("manifest.json")
    }

    private func createDirectories() throws {
        try fileManager.createDirectory(
            at: pdfDirectory,
            withIntermediateDirectories: true
        )
    }

    private func loadManifest() {
        guard let data = try? Data(contentsOf: manifestURL),
              let storedDocuments = try? Self.decoder.decode(
                [ArchivedDocument].self,
                from: data
              ) else {
            documents = []
            return
        }

        documents = storedDocuments.filter { document in
            fileManager.fileExists(
                atPath: pdfDirectory
                    .appendingPathComponent(document.pdfFileName)
                    .path
            )
        }
        sortDocuments()
    }

    private func writeManifest() throws {
        try createDirectories()
        let data = try Self.encoder.encode(documents)
        try data.write(to: manifestURL, options: .atomic)
    }

    private func sortDocuments() {
        documents.sort {
            if $0.savedAt == $1.savedAt {
                return $0.id.uuidString > $1.id.uuidString
            }
            return $0.savedAt > $1.savedAt
        }
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
