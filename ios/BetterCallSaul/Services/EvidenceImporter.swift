import Foundation
import PDFKit
import UIKit

struct ImportedEvidence {
    let image: CGImage
    let item: EvidenceItem
    let payload: EvidencePayload
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
    private static let maximumPayloadBytes = 10 * 1_024 * 1_024

    func importImageData(_ data: Data, fileName: String) throws -> ImportedEvidence {
        try validatePayloadSize(data)
        guard let image = UIImage(data: data)?.cgImage else {
            throw EvidenceImportError.unsupportedContent
        }
        guard let normalizedData = UIImage(cgImage: image).jpegData(compressionQuality: 0.88) else {
            throw EvidenceImportError.unreadableFile
        }
        try validatePayloadSize(normalizedData)
        let normalizedFileName = (fileName as NSString)
            .deletingPathExtension
            .appending(".jpg")
        return ImportedEvidence(
            image: image,
            item: EvidenceItem(fileName: fileName, fileSize: Self.fileSize(for: data.count)),
            payload: EvidencePayload(
                fileName: normalizedFileName,
                mimeType: "image/jpeg",
                data: normalizedData,
                previewImage: image
            )
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
        try validatePayloadSize(data)
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
            item: EvidenceItem(fileName: fileName, fileSize: Self.fileSize(for: data.count)),
            payload: EvidencePayload(
                fileName: fileName,
                mimeType: "application/pdf",
                data: data,
                previewImage: image
            )
        )
    }

    private func validatePayloadSize(_ data: Data) throws {
        guard data.count <= Self.maximumPayloadBytes else {
            throw AIProviderError.payloadTooLarge(maximumMB: 10)
        }
    }

    private static func fileSize(for byteCount: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(byteCount))
    }
}
