import XCTest
@testable import BetterCallSaul

final class ReceiptFieldParserTests: XCTestCase {
    func testParsesRecognizedValuesIntoSubscriptionFields() {
        let text = """
        MEGAPLUS
        Онлайн-сервис
        17.07.2026
        ИТОГО 24 900 ₸
        Оплата успешно
        """

        let fields = ReceiptFieldParser().parse(text, caseType: .subscription)

        XCTAssertEqual(fields.map(\.label), ["Сервис", "Сумма", "Дата списания", "Дата отмены"])
        XCTAssertEqual(fields.map(\.kind), [.counterparty, .amount, .date, .detail])
        XCTAssertEqual(fields.value(for: "Сервис"), "MegaPlus")
        XCTAssertEqual(fields.value(for: "Сумма"), "24 900 ₸")
        XCTAssertEqual(fields.value(for: "Дата списания"), "17 июля 2026")
        XCTAssertEqual(fields.value(for: "Дата отмены"), "")
    }

    func testMissingValuesStayEmptyAndRequireReview() {
        let fields = ReceiptFieldParser().parse("Оплата успешно", caseType: .charge)

        XCTAssertEqual(fields.value(for: "Компания или сервис"), "")
        XCTAssertEqual(fields.value(for: "Сумма"), "")
        XCTAssertTrue(fields.first(where: { $0.label == "Компания или сервис" })?.requiresReview == true)
        XCTAssertTrue(fields.first(where: { $0.label == "Сумма" })?.requiresReview == true)
    }
}

private extension Array where Element == ExtractedField {
    func value(for label: String) -> String? {
        first(where: { $0.label == label })?.value
    }
}
