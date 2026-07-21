import Foundation

enum GeminiEvidenceResponseDecoder {
    static func decode(_ text: String, caseType: CaseType) throws -> EvidenceAnalysis {
        let jsonText = try extractedJSONObject(from: text)
        let data = Data(jsonText.utf8)

        if let analysis = try? JSONDecoder().decode(EvidenceAnalysis.self, from: data) {
            return analysis
        }

        let object = try JSONSerialization.jsonObject(with: data)
        guard object is [String: Any] else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Gemini evidence must be a JSON object")
            )
        }

        let index = ScalarIndex(object)
        guard !index.entries.isEmpty else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Gemini evidence JSON is empty")
            )
        }

        let documentKind = index.firstValue(for: [
            "documentKind", "documentType", "documentCategory", "kind"
        ]) ?? caseType.rawValue
        let counterparty = index.firstValue(for: [
            "counterparty", "serviceProvider", "provider", "merchantName", "merchant",
            "companyName", "company", "seller", "vendor", "payee", "issuer", "organization"
        ])
        let amountText = index.firstValue(for: [
            "amount", "totalAmount", "total", "paymentAmount", "chargedAmount",
            "amountDue", "payableAmount", "invoiceAmount", "sum"
        ])
        let rawText = index.transcription
        let currency = index.firstValue(for: ["currency", "currencyCode"])
            .flatMap { normalizedCurrency(in: $0) }
            ?? normalizedCurrency(in: [amountText, rawText].compactMap { $0 }.joined(separator: "\n"))
        let transactionDate = index.firstValue(for: [
            "transactionDate", "paymentDate", "invoiceDate", "receiptDate", "issueDate", "date"
        ])
        let summary = index.firstValue(for: ["evidenceSummary", "summary"])
            ?? generatedSummary(documentKind: documentKind, counterparty: counterparty)

        return EvidenceAnalysis(
            documentKind: documentKind,
            rawText: rawText,
            counterparty: counterparty,
            amount: amountText.flatMap(decimalAmount),
            currency: currency,
            transactionDate: transactionDate,
            evidenceSummary: summary,
            importantDetails: index.values(under: ["importantDetails", "details", "keyDetails"]),
            warnings: index.values(under: ["warnings", "warning"]),
            confidence: index.confidence
        )
    }

    private static func extractedJSONObject(from text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}"),
              start <= end else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Gemini response does not contain JSON")
            )
        }
        return String(trimmed[start...end])
    }

    private static func decimalAmount(_ value: String) -> Decimal? {
        var normalized = value
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .filter { $0.isNumber || $0 == "," || $0 == "." || $0 == "-" }

        guard normalized.contains(where: \.isNumber) else { return nil }

        let commaCount = normalized.filter { $0 == "," }.count
        let dotCount = normalized.filter { $0 == "." }.count
        if commaCount > 0, dotCount > 0 {
            if normalized.lastIndex(of: ",")! > normalized.lastIndex(of: ".")! {
                normalized = normalized.replacingOccurrences(of: ".", with: "")
                normalized = normalized.replacingOccurrences(of: ",", with: ".")
            } else {
                normalized = normalized.replacingOccurrences(of: ",", with: "")
            }
        } else if commaCount > 0 {
            normalized = normalized.replacingOccurrences(of: ",", with: decimalSeparator(in: normalized, separator: ","))
        } else if dotCount > 0 {
            normalized = normalized.replacingOccurrences(of: ".", with: decimalSeparator(in: normalized, separator: "."))
        }

        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func decimalSeparator(in value: String, separator: Character) -> String {
        guard value.filter({ $0 == separator }).count == 1,
              let separatorIndex = value.lastIndex(of: separator) else { return "" }
        let fractionLength = value.distance(from: value.index(after: separatorIndex), to: value.endIndex)
        return (1...2).contains(fractionLength) ? "." : ""
    }

    private static func normalizedCurrency(in value: String) -> String? {
        let uppercased = value.uppercased()
        if uppercased.contains("KZT") || uppercased.contains("₸") || uppercased.contains(" ТГ") {
            return "KZT"
        }
        if uppercased.contains("RUB") || uppercased.contains("₽") {
            return "RUB"
        }
        if uppercased.contains("USD") || uppercased.contains("$") {
            return "USD"
        }
        if uppercased.contains("EUR") || uppercased.contains("€") {
            return "EUR"
        }
        let code = uppercased.trimmingCharacters(in: .whitespacesAndNewlines)
        return code.count == 3 ? code : nil
    }

    private static func generatedSummary(documentKind: String, counterparty: String?) -> String {
        if let counterparty {
            return "Распознан документ «\(documentKind)» от \(counterparty)."
        }
        return "Распознан документ «\(documentKind)»."
    }
}

private struct ScalarIndex {
    struct Entry {
        let path: [String]
        let value: String
    }

    let entries: [Entry]

    init(_ object: Any) {
        var collected: [Entry] = []
        Self.collect(object, path: [], into: &collected)
        entries = collected
    }

    var transcription: String {
        let rawTextEntries = entries.filter { entry in
            entry.path.last.map(Self.normalizedKey) == "rawtext"
        }
        var values = rawTextEntries.map(\.value)
        values.append(contentsOf: entries.map(\.value))
        return unique(values).joined(separator: "\n")
    }

    var confidence: [String: Double] {
        var result: [String: Double] = [:]
        for entry in entries where entry.path.map(Self.normalizedKey).contains("confidence") {
            guard let key = entry.path.dropLast().last ?? entry.path.last,
                  let value = Double(entry.value) else { continue }
            result[key] = value
        }
        return result
    }

    func firstValue(for aliases: [String]) -> String? {
        let normalizedAliases = Set(aliases.map(Self.normalizedKey))
        return entries.enumerated().compactMap { offset, entry -> (Int, Int, String)? in
            let path = entry.path.map(Self.normalizedKey)
            guard let leaf = path.last else { return nil }

            if normalizedAliases.contains(leaf) {
                return (0, offset, entry.value)
            }
            if path.count > 1, normalizedAliases.contains(path[path.count - 2]) {
                let wrapperPriority = switch leaf {
                case "value": 1
                case "name": 2
                case "text": 3
                case "rawtext": 4
                default: 5
                }
                return (wrapperPriority, offset, entry.value)
            }
            if path.contains(where: normalizedAliases.contains) {
                return (6, offset, entry.value)
            }
            return nil
        }
        .sorted { lhs, rhs in
            lhs.0 == rhs.0 ? lhs.1 < rhs.1 : lhs.0 < rhs.0
        }
        .first?
        .2
    }

    func values(under aliases: [String]) -> [String] {
        let normalizedAliases = Set(aliases.map(Self.normalizedKey))
        return unique(entries.compactMap { entry in
            entry.path.map(Self.normalizedKey).contains(where: normalizedAliases.contains)
                ? entry.value
                : nil
        })
    }

    private func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { return false }
            return true
        }
    }

    private static func collect(_ value: Any, path: [String], into entries: inout [Entry]) {
        if let dictionary = value as? [String: Any] {
            for key in dictionary.keys.sorted() {
                if let child = dictionary[key] {
                    collect(child, path: path + [key], into: &entries)
                }
            }
            return
        }
        if let array = value as? [Any] {
            for (index, child) in array.enumerated() {
                collect(child, path: path + [String(index)], into: &entries)
            }
            return
        }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                entries.append(Entry(path: path, value: trimmed))
            }
            return
        }
        if let number = value as? NSNumber {
            entries.append(Entry(path: path, value: number.stringValue))
        }
    }

    private static func normalizedKey(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
