import Foundation

struct AIServiceContainer: Sendable {
    let evidenceAnalyzer: any EvidenceAnalyzing
    let legalTextGenerator: any LegalTextGenerating
    let localTextGenerator: any LegalTextGenerating

    static func live(
        configuration: AIConfiguration,
        transport: any HTTPTransport = URLSessionHTTPTransport()
    ) -> Self {
        Self(
            evidenceAnalyzer: GeminiVisionClient(
                apiKey: configuration.geminiAPIKey,
                model: configuration.geminiModel,
                transport: transport
            ),
            legalTextGenerator: DeepSeekTextClient(
                apiKey: configuration.deepSeekAPIKey,
                model: configuration.deepSeekModel,
                transport: transport
            ),
            localTextGenerator: LocalLegalTextGenerator()
        )
    }

    static var localOnly: Self {
        Self(
            evidenceAnalyzer: UnavailableEvidenceAnalyzer(),
            legalTextGenerator: LocalLegalTextGenerator(),
            localTextGenerator: LocalLegalTextGenerator()
        )
    }

    static var uiTesting: Self {
        Self(
            evidenceAnalyzer: UITestingEvidenceAnalyzer(),
            legalTextGenerator: UITestingLegalTextGenerator(),
            localTextGenerator: LocalLegalTextGenerator()
        )
    }
}

private struct UnavailableEvidenceAnalyzer: EvidenceAnalyzing {
    func analyze(
        payload: EvidencePayload,
        caseType: CaseType,
        narrative: String
    ) async throws -> EvidenceAnalysis {
        throw AIProviderError.missingKey(.gemini)
    }
}

private struct UITestingEvidenceAnalyzer: EvidenceAnalyzing {
    func analyze(
        payload: EvidencePayload,
        caseType: CaseType,
        narrative: String
    ) async throws -> EvidenceAnalysis {
        EvidenceAnalysis(
            documentKind: "receipt",
            rawText: "MEGAPLUS 24 900 KZT",
            counterparty: "MegaPlus",
            amount: Decimal(24_900),
            currency: "KZT",
            transactionDate: "17 июля 2026",
            evidenceSummary: "Чек подтверждает списание 24 900 ₸",
            importantDetails: [],
            warnings: [],
            confidence: ["amount": 0.99]
        )
    }
}

private struct UITestingLegalTextGenerator: LegalTextGenerating {
    func analyzeCase(_ request: CaseAIRequest) async throws -> CaseAIAnalysis {
        CaseAIAnalysis(
            summary: "Подписка могла продлиться без явного предупреждения.",
            recommendedAction: "Запросить отмену продления и возврат списания.",
            warnings: [],
            questions: []
        )
    }

    func generateDocument(_ request: AIDocumentRequest) async throws -> AIDocumentSections {
        AIDocumentSections(
            recipient: request.caseContext.reviewedFields["Компания"],
            subject: "Требование об отмене подписки и возврате средств",
            facts: [request.caseContext.narrative].filter { !$0.isEmpty },
            demands: ["Отменить дальнейшее продление", "Рассмотреть возврат списанных средств"],
            responseDays: nil,
            attachmentDescription: request.caseContext.evidenceSummary ?? "Подтверждающие материалы",
            unresolvedIssues: []
        )
    }
}
