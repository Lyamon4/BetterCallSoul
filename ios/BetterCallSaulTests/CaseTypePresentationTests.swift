import XCTest
@testable import BetterCallSaul

final class CaseTypePresentationTests: XCTestCase {
    func testEveryCategoryHasDistinctPresentationCopy() {
        let fingerprints = CaseType.allCases.map { type in
            let value = type.presentation
            return [
                value.title,
                value.explanation,
                value.narrativeLabel,
                value.narrativePlaceholder,
                value.uploadTitle,
                value.uploadHint
            ].joined(separator: "|")
        }

        XCTAssertEqual(Set(fingerprints).count, CaseType.allCases.count)
    }

    func testEveryCategoryHasExpectedOrderedFields() {
        XCTAssertEqual(
            CaseType.charge.presentation.fields.map(\.label),
            ["Компания или сервис", "Сумма", "Дата", "Способ оплаты"]
        )
        XCTAssertEqual(
            CaseType.fine.presentation.fields.map(\.label),
            ["Орган", "Номер постановления", "Сумма", "Дата"]
        )
        XCTAssertEqual(
            CaseType.subscription.presentation.fields.map(\.label),
            ["Сервис", "Сумма", "Дата списания", "Дата отмены"]
        )
        XCTAssertEqual(
            CaseType.product.presentation.fields.map(\.label),
            ["Продавец", "Товар", "Стоимость", "Дата покупки"]
        )
        XCTAssertEqual(
            CaseType.bill.presentation.fields.map(\.label),
            ["Поставщик", "Период", "Сумма", "Номер счёта"]
        )

        XCTAssertEqual(
            CaseType.charge.presentation.fields.map(\.kind),
            [.counterparty, .amount, .date, .detail]
        )
        XCTAssertEqual(
            CaseType.fine.presentation.fields.map(\.kind),
            [.counterparty, .reference, .amount, .date]
        )
        XCTAssertEqual(
            CaseType.subscription.presentation.fields.map(\.kind),
            [.counterparty, .amount, .date, .detail]
        )
        XCTAssertEqual(
            CaseType.product.presentation.fields.map(\.kind),
            [.counterparty, .detail, .amount, .date]
        )
        XCTAssertEqual(
            CaseType.bill.presentation.fields.map(\.kind),
            [.counterparty, .detail, .amount, .reference]
        )
    }
}
