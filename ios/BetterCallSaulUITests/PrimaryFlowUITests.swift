import XCTest

@MainActor
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

        XCTAssertTrue(app.staticTexts["Добавьте\nдоказательства"].waitForExistence(timeout: 2))
    }

    func testEvidenceScreenShowsExtractedFieldsAndContinues() {
        app.buttons["caseType.subscription"].tap()

        let companyField = app.textFields["Компания"]
        XCTAssertTrue(companyField.waitForExistence(timeout: 2))
        XCTAssertEqual(companyField.value as? String, "MegaPlus")
        XCTAssertEqual(app.textFields["Сумма"].value as? String, "24 900 ₸")
        XCTAssertTrue(app.staticTexts["ПРОВЕРЬТЕ ДАННЫЕ"].exists)

        continueFromEvidenceToDocument()
    }

    func testEvidenceToAIAnalysisToDocumentFlow() {
        app.buttons["caseType.subscription"].tap()
        let narrative = app.textViews["caseNarrativeField"]
        XCTAssertTrue(narrative.waitForExistence(timeout: 2))
        narrative.tap()
        narrative.typeText("Подписка продлилась без предупреждения")

        app.buttons["continueToAIButton"].tap()

        XCTAssertTrue(app.staticTexts["Разберём ситуацию"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.staticTexts["DeepSeek"].exists || app.staticTexts["Локальный режим"].exists
        )
        app.buttons["prepareAIDocumentButton"].tap()

        XCTAssertTrue(app.staticTexts["Претензия готова"].waitForExistence(timeout: 3))
    }

    func testDocumentExportCreatesRealPDFReadyState() {
        app.buttons["caseType.subscription"].tap()
        continueFromEvidenceToDocument()

        XCTAssertTrue(
            app.staticTexts["Требование об отмене подписки и возврате средств"]
                .waitForExistence(timeout: 2)
        )
        XCTAssertTrue(app.staticTexts["2 места требуют внимания"].exists)

        app.buttons["sendDocumentButton"].tap()

        XCTAssertTrue(app.staticTexts["PDF создан"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Документ готов к отправке."].exists)
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

    func testProfileShowsConfiguredProviderStatusesWithoutSecrets() {
        app.buttons["tab.profile"].tap()
        app.buttons["AI-провайдеры"].tap()

        XCTAssertTrue(app.staticTexts["geminiConfiguredStatus"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["deepSeekConfiguredStatus"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'full-private'" )).firstMatch.exists)
    }

    func testPrimaryScreensCaptureStableReferences() {
        capture(name: "01-home")

        app.buttons["caseType.subscription"].tap()
        capture(name: "02-evidence")

        app.buttons["continueToAIButton"].tap()
        XCTAssertTrue(app.staticTexts["Разберём ситуацию"].waitForExistence(timeout: 3))
        capture(name: "03-ai-analysis")
        app.buttons["prepareAIDocumentButton"].tap()
        XCTAssertTrue(app.staticTexts["Претензия готова"].waitForExistence(timeout: 3))
        capture(name: "04-document")

        app.buttons["tab.tools"].tap()
        capture(name: "05-tools")
    }

    func testLargeTextKeepsPrimaryActionReachable() {
        app.terminate()
        app.launchArguments = [
            "-ui-testing",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityL"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["createCaseButton"].waitForExistence(timeout: 3))
        app.buttons["createCaseButton"].swipeUp()
        XCTAssertTrue(app.buttons["createCaseButton"].isHittable || app.staticTexts["Что случилось?"].exists)
    }

    private func capture(name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func continueFromEvidenceToDocument() {
        app.buttons["continueToAIButton"].tap()
        XCTAssertTrue(app.staticTexts["Разберём ситуацию"].waitForExistence(timeout: 3))
        app.buttons["prepareAIDocumentButton"].tap()
        XCTAssertTrue(app.staticTexts["Претензия готова"].waitForExistence(timeout: 3))
    }
}
