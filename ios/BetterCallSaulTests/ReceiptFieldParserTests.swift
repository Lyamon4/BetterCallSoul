import XCTest
@testable import BetterCallSaul

final class ReceiptFieldParserTests: XCTestCase {
    func testParsesCompanyAmountDateAndSelectedCaseType() {
        let text = """
        MEGAPLUS
        Онлайн-сервис
        17.07.2026
        ИТОГО 24 900 ₸
        Оплата успешно
        """

        let fields = ReceiptFieldParser().parse(text, caseType: .subscription)

        XCTAssertEqual(fields.value(for: "Компания"), "MegaPlus")
        XCTAssertEqual(fields.value(for: "Сумма"), "24 900 ₸")
        XCTAssertEqual(fields.value(for: "Дата"), "17 июля 2026")
        XCTAssertEqual(fields.value(for: "Тип"), "Подписка")
    }

    func testMissingValuesStayEmptyAndRequireReview() {
        let fields = ReceiptFieldParser().parse("Оплата успешно", caseType: .charge)

        XCTAssertEqual(fields.value(for: "Компания"), "")
        XCTAssertEqual(fields.value(for: "Сумма"), "")
        XCTAssertTrue(fields.first(where: { $0.label == "Компания" })?.requiresReview == true)
        XCTAssertTrue(fields.first(where: { $0.label == "Сумма" })?.requiresReview == true)
    }
}

private extension Array where Element == ExtractedField {
    func value(for label: String) -> String? {
        first(where: { $0.label == label })?.value
    }
}
