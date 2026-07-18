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

    func testDocumentConfirmationShowsSuccessState() {
        app.buttons["caseType.subscription"].tap()
        app.buttons["continueToDocumentButton"].tap()

        XCTAssertTrue(app.staticTexts["Требование о возврате 24 900 ₸"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["2 места требуют внимания"].exists)

        app.buttons["sendDocumentButton"].tap()

        XCTAssertTrue(app.staticTexts["Документ подготовлен"].waitForExistence(timeout: 2))
    }

    func testToolsShowsHonestCapabilitiesAndSaulCallout() {
        app.buttons["tab.tools"].tap()

        XCTAssertTrue(app.staticTexts["Инструменты"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Временный номер"].exists)
        XCTAssertTrue(app.staticTexts["DEMO"].exists)
        XCTAssertTrue(app.staticTexts["КОНЦЕПТ"].exists)
        XCTAssertTrue(app.staticTexts["Нужен план?\nПозвони Солу."].exists)
    }

    func testCasesShowsActiveCaseAndDeadline() {
        app.buttons["tab.cases"].tap()

        XCTAssertTrue(app.staticTexts["Возврат за подписку"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["24 900 ₸"].exists)
        XCTAssertTrue(app.staticTexts["Ответ до 28 июля"].exists)
    }
}
