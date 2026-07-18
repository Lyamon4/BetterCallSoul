import CoreGraphics
import Foundation
@preconcurrency import Vision

enum TextRecognitionError: LocalizedError {
    case noTextFound

    var errorDescription: String? {
        "Текст не найден. Можно заполнить данные вручную."
    }
}

struct VisionTextRecognizer: Sendable {
    func recognizeText(in image: CGImage) async throws -> String {
        let text = try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ru-RU", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])

            return (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
        }.value

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TextRecognitionError.noTextFound
        }
        return text
    }
}
