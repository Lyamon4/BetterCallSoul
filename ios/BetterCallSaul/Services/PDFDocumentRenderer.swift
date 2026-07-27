import Foundation
import UIKit

@MainActor
struct PDFDocumentRenderer {
    private let pageBounds = CGRect(x: 0, y: 0, width: 595, height: 842)

    func render(
        _ draft: DocumentDraft,
        signature: HandwrittenSignature
    ) throws -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: draft.title,
            kCGPDFContextAuthor as String: "BetterCallSaul"
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds, format: format)
        return renderer.pdfData { context in
            context.beginPage()
            draw(draft, signature: signature, in: context.cgContext)
        }
    }

    func write(
        _ draft: DocumentDraft,
        signature: HandwrittenSignature,
        to directory: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let safeNumber = draft.caseNumber
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
        let url = directory.appendingPathComponent("BetterCallSaul-\(safeNumber).pdf")
        try render(draft, signature: signature).write(to: url, options: .atomic)
        return url
    }

    private func draw(
        _ draft: DocumentDraft,
        signature: HandwrittenSignature,
        in context: CGContext
    ) {
        UIColor(red: 0.98, green: 0.97, blue: 0.93, alpha: 1).setFill()
        context.fill(pageBounds)

        let margin: CGFloat = 54
        let contentWidth = pageBounds.width - (margin * 2)
        var y: CGFloat = 54

        drawText(
            "BETTER CALL SAUL",
            frame: CGRect(x: margin, y: y, width: 250, height: 26),
            font: .systemFont(ofSize: 17, weight: .bold),
            color: .black
        )
        drawText(
            "Всё по закону.",
            frame: CGRect(x: margin, y: y + 25, width: 250, height: 18),
            font: .systemFont(ofSize: 10, weight: .regular),
            color: .darkGray
        )

        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "ru_RU")
        dateFormatter.dateFormat = "d MMMM yyyy г."
        drawText(
            "Исх. № \(draft.caseNumber)\n\(dateFormatter.string(from: draft.createdAt))",
            frame: CGRect(x: pageBounds.width - margin - 220, y: y, width: 220, height: 42),
            font: .monospacedSystemFont(ofSize: 9, weight: .regular),
            color: .darkGray,
            alignment: .right
        )

        y += 68
        UIColor(red: 0.98, green: 0.75, blue: 0.08, alpha: 1).setFill()
        context.fill(CGRect(x: margin, y: y, width: 42, height: 5))

        y += 28
        drawText(
            draft.title,
            frame: CGRect(x: margin, y: y, width: contentWidth, height: 70),
            font: .systemFont(ofSize: 24, weight: .bold),
            color: .black
        )

        y += 72
        drawText(
            "Кому: \(draft.recipient)",
            frame: CGRect(x: margin, y: y, width: contentWidth, height: 30),
            font: .systemFont(ofSize: 12, weight: .semibold),
            color: .black
        )

        y += 42
        UIColor(white: 0.78, alpha: 1).setFill()
        context.fill(CGRect(x: margin, y: y, width: contentWidth, height: 1))

        y += 30
        drawText(
            draft.body,
            frame: CGRect(x: margin, y: y, width: contentWidth, height: 150),
            font: .systemFont(ofSize: 13, weight: .regular),
            color: .black,
            lineSpacing: 5
        )

        y += 174
        let attachmentText = draft.attachmentCount == 0
            ? "Приложения: отсутствуют."
            : "Приложение: подтверждающие материалы — \(draft.attachmentCount) файл(а)."
        drawText(
            attachmentText,
            frame: CGRect(x: margin, y: y, width: contentWidth, height: 28),
            font: .systemFont(ofSize: 10, weight: .regular),
            color: .darkGray
        )

        y += 54
        UIColor(white: 0.78, alpha: 1).setFill()
        context.fill(CGRect(x: margin, y: y, width: contentWidth, height: 1))
        y += 24
        drawText(
            "С уважением,\n\(draft.senderName)",
            frame: CGRect(x: margin, y: y, width: contentWidth / 2, height: 42),
            font: .systemFont(ofSize: 11, weight: .regular),
            color: .black
        )

        draw(
            signature,
            in: CGRect(
                x: pageBounds.width - margin - 160,
                y: y - 6,
                width: 160,
                height: 52
            ),
            context: context
        )

        drawText(
            "S’all good",
            frame: CGRect(x: pageBounds.width - margin - 160, y: pageBounds.height - 52, width: 160, height: 20),
            font: .italicSystemFont(ofSize: 10),
            color: .darkGray,
            alignment: .right
        )
    }

    private func draw(
        _ signature: HandwrittenSignature,
        in rect: CGRect,
        context: CGContext
    ) {
        context.saveGState()
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(2)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        for points in signature.points(in: rect.size) where points.count > 1 {
            context.beginPath()
            context.move(
                to: CGPoint(x: rect.minX + points[0].x, y: rect.minY + points[0].y)
            )
            for point in points.dropFirst() {
                context.addLine(
                    to: CGPoint(x: rect.minX + point.x, y: rect.minY + point.y)
                )
            }
            context.strokePath()
        }
        context.restoreGState()
    }

    private func drawText(
        _ text: String,
        frame: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left,
        lineSpacing: CGFloat = 0
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineSpacing = lineSpacing
        paragraph.lineBreakMode = .byWordWrapping
        (text as NSString).draw(
            in: frame,
            withAttributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
    }
}
