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

    func testHomeSaulRoutesProblemToEvidence() {
        let saul = app.buttons["saulMascotButton"]
        XCTAssertTrue(saul.waitForExistence(timeout: 3))

        saul.tap()
        XCTAssertTrue(app.descendants(matching: .any)["saulAssistantSheet"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Расскажите Солу"].exists)
        XCTAssertTrue(app.staticTexts["Что случилось? Опишите своими словами."].exists)

        let field = app.textFields["saulProblemField"]
        XCTAssertTrue(field.waitForExistence(timeout: 2))
        field.tap()
        field.typeText("Мне выписали штраф за парковку")
        app.buttons["saulSubmitButton"].tap()

        let narrative = app.textViews["caseNarrativeField"]
        XCTAssertTrue(narrative.waitForExistence(timeout: 3))
        XCTAssertEqual(narrative.value as? String, "Мне выписали штраф за парковку")
    }

    func testHomeSaulClarifiesThenRoutesToEvidence() {
        app.terminate()
        app.launchArguments = ["-ui-testing", "-saul-clarification-testing"]
        app.launch()

        app.buttons["saulMascotButton"].tap()
        let problemField = app.textFields["saulProblemField"]
        XCTAssertTrue(problemField.waitForExistence(timeout: 2))
        problemField.tap()
        problemField.typeText("Со мной случилась непонятная ситуация")
        app.buttons["saulSubmitButton"].tap()

        XCTAssertTrue(app.staticTexts["Это штраф от госоргана?"].waitForExistence(timeout: 3))
        let clarificationField = app.textFields["saulClarificationField"]
        XCTAssertTrue(clarificationField.waitForExistence(timeout: 2))
        clarificationField.tap()
        clarificationField.typeText("Да, штраф за парковку")
        app.buttons["saulSubmitButton"].tap()

        let narrative = app.textViews["caseNarrativeField"]
        XCTAssertTrue(narrative.waitForExistence(timeout: 4))
        XCTAssertEqual(
            narrative.value as? String,
            "Со мной случилась непонятная ситуация\nУточнение: Да, штраф за парковку"
        )
    }

    func testSubscriptionPathOpensEvidence() {
        app.buttons["caseType.subscription"].tap()

        XCTAssertTrue(app.staticTexts["Отмените\nподписку"].waitForExistence(timeout: 2))
    }

    func testFineAndSubscriptionShowDistinctEvidenceContent() {
        app.buttons["caseType.fine"].tap()

        XCTAssertTrue(app.staticTexts["Обжалуйте\nштраф"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Почему штраф несправедлив"].exists)
        XCTAssertTrue(app.staticTexts["Добавьте постановление"].exists)
        XCTAssertTrue(
            app.staticTexts[
                "Фото или PDF постановления, уведомления и подтверждающих материалов"
            ].exists
        )
        XCTAssertTrue(app.textFields["Орган"].exists)
        XCTAssertTrue(app.textFields["Номер постановления"].exists)

        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        app.buttons["caseType.subscription"].tap()

        XCTAssertTrue(app.staticTexts["Отмените\nподписку"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Что произошло с подпиской"].exists)
        XCTAssertTrue(app.staticTexts["Добавьте подтверждение подписки"].exists)
        XCTAssertTrue(
            app.staticTexts[
                "Скриншот списания, условий подписки или переписки с сервисом"
            ].exists
        )
        XCTAssertTrue(app.textFields["Сервис"].exists)
        XCTAssertTrue(app.textFields["Дата отмены"].exists)
    }

    func testEvidenceScreenShowsExtractedFieldsAndContinues() {
        app.buttons["caseType.subscription"].tap()

        XCTAssertTrue(app.textFields["Сервис"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["Сумма"].exists)
        XCTAssertTrue(app.textFields["Дата списания"].exists)
        XCTAssertTrue(app.textFields["Дата отмены"].exists)
        XCTAssertTrue(app.staticTexts["ПРОВЕРЬТЕ ДАННЫЕ"].exists)

        continueFromEvidenceToDocument()
    }

    func testEvidenceToAnalysisToDocumentFlow() {
        app.buttons["caseType.subscription"].tap()
        let narrative = app.textViews["caseNarrativeField"]
        XCTAssertTrue(narrative.waitForExistence(timeout: 2))
        narrative.tap()
        narrative.typeText("Подписка продлилась без предупреждения")

        tapContinueToAIAnalysis()

        XCTAssertTrue(app.staticTexts["Разберём ситуацию"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["ПРОВЕРЕННЫЕ ФАКТЫ"].exists)
        XCTAssertFalse(app.staticTexts["DeepSeek"].exists)
        XCTAssertFalse(app.staticTexts["Локальный режим"].exists)
        app.buttons["prepareAIDocumentButton"].tap()

        signPreparedDocument()
        XCTAssertTrue(app.staticTexts["Претензия готова"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.descendants(matching: .any)["documentCelebratingSaul"]
                .waitForExistence(timeout: 2)
        )
    }

    func testDocumentExportCreatesRealPDFReadyState() {
        app.buttons["caseType.subscription"].tap()
        continueFromEvidenceToDocument()

        XCTAssertTrue(
            app.staticTexts["Требование об отмене подписки и возврате средств"]
                .waitForExistence(timeout: 2)
        )
        XCTAssertTrue(app.staticTexts["4 места требуют внимания"].exists)

        app.buttons["sendDocumentButton"].tap()

        XCTAssertTrue(app.staticTexts["PDF создан"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Документ готов к отправке."].exists)
    }

    func testToolsShowsSupportedCapabilitiesAndSaulCallout() {
        app.buttons["tab.tools"].tap()

        XCTAssertTrue(app.staticTexts["Инструменты"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Отмена подписки"].exists)
        XCTAssertFalse(app.staticTexts["Временный номер"].exists)
        XCTAssertFalse(app.staticTexts["Trial Card"].exists)
        XCTAssertFalse(app.staticTexts["DEMO"].exists)
        XCTAssertFalse(app.staticTexts["КОНЦЕПТ"].exists)
        XCTAssertTrue(app.staticTexts["Нужен план?\nПозвони Солу."].exists)
    }

    func testCasesShowsActiveCaseAndDeadline() {
        app.buttons["tab.cases"].tap()

        XCTAssertTrue(app.staticTexts["Возврат за подписку"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["24 900 ₸"].exists)
        XCTAssertTrue(app.staticTexts["Ответ до 28 июля"].exists)
    }

    func testProductionSurfaceHidesImplementationAndPrototypeControls() {
        app.buttons["tab.profile"].tap()
        XCTAssertTrue(app.staticTexts["Профиль"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["AI-провайдеры"].exists)

        app.buttons["tab.tools"].tap()
        XCTAssertTrue(app.staticTexts["Инструменты"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Временный номер"].exists)
        XCTAssertFalse(app.staticTexts["Trial Card"].exists)
        XCTAssertFalse(app.staticTexts["DEMO"].exists)
        XCTAssertFalse(app.staticTexts["КОНЦЕПТ"].exists)
    }

    func testPrimaryScreensCaptureStableReferences() {
        capture(name: "01-home")

        app.buttons["caseType.subscription"].tap()
        capture(name: "02-evidence")

        tapContinueToAIAnalysis()
        XCTAssertTrue(app.staticTexts["Разберём ситуацию"].waitForExistence(timeout: 3))
        capture(name: "03-ai-analysis")
        app.buttons["prepareAIDocumentButton"].tap()
        XCTAssertTrue(app.staticTexts["Оставьте подпись"].waitForExistence(timeout: 3))
        capture(name: "04-signature")
        drawSignatureAndContinue()
        XCTAssertTrue(app.staticTexts["Претензия готова"].waitForExistence(timeout: 3))
        capture(name: "05-document")

        app.buttons["tab.tools"].tap()
        capture(name: "06-tools")
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
        tapContinueToAIAnalysis()
        XCTAssertTrue(app.staticTexts["Разберём ситуацию"].waitForExistence(timeout: 3))
        app.buttons["prepareAIDocumentButton"].tap()
        signPreparedDocument()
        XCTAssertTrue(app.staticTexts["Претензия готова"].waitForExistence(timeout: 3))
    }

    private func signPreparedDocument() {
        XCTAssertTrue(app.staticTexts["Оставьте подпись"].waitForExistence(timeout: 3))
        let confirmButton = app.buttons["confirmSignatureButton"]
        XCTAssertTrue(confirmButton.exists)
        XCTAssertFalse(confirmButton.isEnabled)
        drawSignatureAndContinue()
    }

    private func drawSignatureAndContinue() {
        let canvas = app.otherElements["signatureCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 2))
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.65))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.35))
        start.press(forDuration: 0.1, thenDragTo: end)

        let confirmButton = app.buttons["confirmSignatureButton"]
        XCTAssertTrue(confirmButton.isEnabled)
        confirmButton.tap()
    }

    private func tapContinueToAIAnalysis() {
        let button = app.buttons["continueToAIButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 2))
        app.swipeUp()
        XCTAssertTrue(button.isHittable)
        button.tap()
    }
}
