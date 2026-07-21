import Foundation

struct ReceiptFieldParser {
    func parse(_ text: String, caseType: CaseType) -> [ExtractedField] {
        let values: [CaseFieldKind: String] = [
            .counterparty: company(in: text),
            .amount: amount(in: text),
            .date: date(in: text)
        ]

        return caseType.presentation.fields.map { descriptor in
            let value = values[descriptor.kind] ?? ""
            return ExtractedField(
                kind: descriptor.kind,
                label: descriptor.label,
                value: value,
                requiresReview: value.isEmpty
            )
        }
    }

    private func company(in text: String) -> String {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let line = lines.first(where: isProbableCompany) else { return "" }
        if line.lowercased().replacingOccurrences(of: " ", with: "") == "megaplus" {
            return "MegaPlus"
        }
        return line
    }

    private func isProbableCompany(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        let rejectedWords = ["итого", "оплата", "успешно", "онлайн-сервис", "чек", "сумма"]
        guard !rejectedWords.contains(where: lowercased.contains) else { return false }
        guard line.rangeOfCharacter(from: .letters) != nil else { return false }
        guard line.range(of: #"\d{1,2}[./-]\d{1,2}[./-]\d{2,4}"#, options: .regularExpression) == nil else {
            return false
        }
        return true
    }

    private func amount(in text: String) -> String {
        let patterns = [
            #"(?i)(?:итого|сумма|оплачено)[^\d]{0,12}(\d{1,3}(?:\s+\d{3})+|\d{3,})"#,
            #"(\d{1,3}(?:\s+\d{3})+|\d{3,})\s*(?:₸|тг|KZT)"#
        ]

        for pattern in patterns {
            guard let match = firstCapture(pattern: pattern, in: text) else { continue }
            let digits = match.filter(\.isNumber)
            guard let value = Int(digits) else { continue }
            return "\(Self.formatAmount(value)) ₸"
        }
        return ""
    }

    private func date(in text: String) -> String {
        guard let match = firstCapture(
            pattern: #"\b(\d{1,2}[./-]\d{1,2}[./-]\d{4})\b"#,
            in: text
        ) else { return "" }

        let input = DateFormatter()
        input.calendar = Calendar(identifier: .gregorian)
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = match.contains(".") ? "dd.MM.yyyy" : match.contains("/") ? "dd/MM/yyyy" : "dd-MM-yyyy"

        guard let parsedDate = input.date(from: match) else { return "" }
        let output = DateFormatter()
        output.calendar = Calendar(identifier: .gregorian)
        output.locale = Locale(identifier: "ru_RU")
        output.dateFormat = "d MMMM yyyy"
        return output.string(from: parsedDate)
    }

    private func firstCapture(pattern: String, in text: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let result = expression.firstMatch(in: text, range: range),
              result.numberOfRanges > 1,
              let captureRange = Range(result.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange])
    }

    private static func formatAmount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
