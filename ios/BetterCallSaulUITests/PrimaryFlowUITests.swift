import XCTest

final class PrimaryFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    func testHomeContainsApprovedPrimaryElements() {
        XCTAssertTrue(app.staticTexts["Что случилось?"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["createCaseButton"].exists)
        XCTAssertTrue(app.buttons["caseType.subscription"].exists)
        XCTAssertTrue(app.staticTexts["activeCaseCard"].exists)
    }

    func testSubscriptionPathOpensEvidence() {
        app.buttons["caseType.subscription"].tap()

        XCTAssertTrue(app.staticTexts["Добавьте доказательства"].waitForExistence(timeout: 2))
    }

    func testEvidenceScreenShowsExtractedFieldsAndContinues() {
        app.buttons["caseType.subscription"].tap()

        let companyField = app.textFields["Компания"]
        XCTAssertTrue(companyField.waitForExistence(timeout: 2))
        XCTAssertEqual(companyField.value as? String, "MegaPlus")
        XCTAssertEqual(app.textFields["Сумма"].value as? String, "24 900 ₸")
        XCTAssertTrue(app.staticTexts["ПРОВЕРЬТЕ ДАННЫЕ"].exists)

        app.buttons["continueToDocumentButton"].tap()

        XCTAssertTrue(app.staticTexts["Претензия готова"].waitForExistence(timeout: 2))
    }
}
