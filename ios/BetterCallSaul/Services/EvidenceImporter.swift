import Foundation
import PDFKit
import UIKit

struct ImportedEvidence {
    let image: CGImage
    let item: EvidenceItem
}

enum EvidenceImportError: LocalizedError {
    case unreadableFile
    case unsupportedContent
    case emptyPDF

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            "Не удалось прочитать выбранный файл."
        case .unsupportedContent:
            "Выберите изображение или PDF-документ."
        case .emptyPDF:
            "В PDF нет страницы для распознавания."
        }
    }
}

@MainActor
struct EvidenceImporter {
    func importImageData(_ data: Data, fileName: String) throws -> ImportedEvidence {
        guard let image = UIImage(data: data)?.cgImage else {
            throw EvidenceImportError.unsupportedContent
        }
        return ImportedEvidence(
            image: image,
            item: EvidenceItem(fileName: fileName, fileSize: Self.fileSize(for: data.count))
        )
    }

    func importFile(at url: URL) throws -> ImportedEvidence {
        let hasScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url) else {
            throw EvidenceImportError.unreadableFile
        }

        if url.pathExtension.lowercased() == "pdf" {
            return try importPDFData(data, fileName: url.lastPathComponent)
        }
        return try importImageData(data, fileName: url.lastPathComponent)
    }

    private func importPDFData(_ data: Data, fileName: String) throws -> ImportedEvidence {
        guard let document = PDFDocument(data: data), let page = document.page(at: 0) else {
            throw EvidenceImportError.emptyPDF
        }
        let pageBounds = page.bounds(for: .mediaBox)
        let targetWidth: CGFloat = 1_600
        let aspectRatio = max(pageBounds.height / max(pageBounds.width, 1), 1)
        let thumbnail = page.thumbnail(
            of: CGSize(width: targetWidth, height: targetWidth * aspectRatio),
            for: .mediaBox
        )
        guard let image = thumbnail.cgImage else {
            throw EvidenceImportError.unreadableFile
        }
        return ImportedEvidence(
            image: image,
            item: EvidenceItem(fileName: fileName, fileSize: Self.fileSize(for: data.count))
        )
    }

    private static func fileSize(for byteCount: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(byteCount))
    }
}
