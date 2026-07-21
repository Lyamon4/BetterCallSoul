import XCTest
@testable import BetterCallSaul

final class CasePromptCoverageTests: XCTestCase {
    func testEveryCaseTypeHasDistinctRequiredFacts() {
        let facts = CaseType.allCases.map { DeepSeekPrompts.requiredFacts(for: $0) }

        XCTAssertTrue(facts.allSatisfy { !$0.isEmpty })
        XCTAssertEqual(Set(facts.map { $0.joined(separator: "|") }).count, CaseType.allCases.count)
    }

    func testPromptsForbidInventedFactsAndCitations() throws {
        let request = CaseAIRequest(
            caseType: .fine,
            narrative: "Штраф пришёл ошибочно",
            reviewedFields: ["Дата": "18.07.2026"],
            evidenceSummary: nil,
            answers: []
        )

        let analysisPrompt = DeepSeekPrompts.analysisSystem(for: request.caseType)
            + (try DeepSeekPrompts.analysis(request: request))
        let documentPrompt = DeepSeekPrompts.documentSystem(for: request.caseType)
            + (try DeepSeekPrompts.document(
            request: AIDocumentRequest(
                caseContext: request,
                analysis: CaseAIAnalysis(
                    summary: "Возможна ошибка",
                    recommendedAction: "Обжаловать",
                    warnings: [],
                    questions: []
                )
            )
        ))

        XCTAssertTrue(analysisPrompt.contains("не выдумывай"))
        XCTAssertTrue(analysisPrompt.contains("Не цитируй"))
        XCTAssertTrue(documentPrompt.contains("только факты"))
    }

    func testDocumentPromptRequiresCompleteKazakhstanLegalClaim() {
        let consumerPrompt = DeepSeekPrompts.documentSystem(for: .subscription)
        let finePrompt = DeepSeekPrompts.documentSystem(for: .fine)
        let normalizedConsumerPrompt = consumerPrompt.lowercased()
        let normalizedFinePrompt = finePrompt.lowercased()

        XCTAssertTrue(consumerPrompt.contains("Республики Казахстан"))
        XCTAssertTrue(normalizedConsumerPrompt.contains("полноценный готовый документ"))
        XCTAssertTrue(consumerPrompt.contains("legalGrounds"))
        XCTAssertTrue(consumerPrompt.contains("nonComplianceActions"))
        XCTAssertTrue(normalizedConsumerPrompt.contains("статьи 42-4"))
        XCTAssertTrue(normalizedConsumerPrompt.contains("десяти календарных дней"))
        XCTAssertTrue(normalizedConsumerPrompt.contains("не выдумывай норму"))
        XCTAssertTrue(normalizedFinePrompt.contains("не применяй автоматически закон республики казахстан «о защите прав потребителей»"))
    }
}
