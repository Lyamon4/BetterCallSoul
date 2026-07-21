import Foundation

struct AIServiceContainer: Sendable {
    let evidenceAnalyzer: any EvidenceAnalyzing
    let legalTextGenerator: any LegalTextGenerating
    let localTextGenerator: any LegalTextGenerating
    let problemClassifier: any ProblemClassifying

    init(
        evidenceAnalyzer: any EvidenceAnalyzing,
        legalTextGenerator: any LegalTextGenerating,
        localTextGenerator: any LegalTextGenerating,
        problemClassifier: any ProblemClassifying = UnavailableProblemClassifier()
    ) {
        self.evidenceAnalyzer = evidenceAnalyzer
        self.legalTextGenerator = legalTextGenerator
        self.localTextGenerator = localTextGenerator
        self.problemClassifier = problemClassifier
    }

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
            localTextGenerator: LocalLegalTextGenerator(),
            problemClassifier: FallbackProblemClassifier(
                primary: DeepSeekProblemClassifier(
                    apiKey: configuration.deepSeekAPIKey,
                    model: configuration.deepSeekModel,
                    transport: transport
                ),
                fallback: GeminiProblemClassifier(
                    apiKey: configuration.geminiAPIKey,
                    model: configuration.geminiModel,
                    transport: transport
                )
            )
        )
    }

    static func bundled(
        bundle: Bundle = .main,
        transport: any HTTPTransport = URLSessionHTTPTransport()
    ) -> Self {
        let info = bundle.infoDictionary ?? [:]
        let values = ["GeminiAPIKey", "GeminiModel", "DeepSeekAPIKey", "DeepSeekModel"]
            .reduce(into: [String: String]()) { result, key in
                if let value = info[key] as? String {
                    result[key] = value
                }
            }
        return runtime(values: values, transport: transport)
    }

    static func runtime(
        values: [String: String],
        transport: any HTTPTransport = URLSessionHTTPTransport()
    ) -> Self {
        let geminiKey = configuredValue("GeminiAPIKey", in: values)
        let geminiModel = configuredValue("GeminiModel", in: values)
        let deepSeekKey = configuredValue("DeepSeekAPIKey", in: values)
        let deepSeekModel = configuredValue("DeepSeekModel", in: values)

        let evidenceAnalyzer: any EvidenceAnalyzing
        let fallbackClassifier: any ProblemClassifying
        if let geminiKey, let geminiModel {
            evidenceAnalyzer = GeminiVisionClient(
                apiKey: geminiKey,
                model: geminiModel,
                transport: transport
            )
            fallbackClassifier = GeminiProblemClassifier(
                apiKey: geminiKey,
                model: geminiModel,
                transport: transport
            )
        } else {
            evidenceAnalyzer = UnavailableEvidenceAnalyzer()
            fallbackClassifier = UnavailableProblemClassifier()
        }

        let legalTextGenerator: any LegalTextGenerating
        let primaryClassifier: any ProblemClassifying
        if let deepSeekKey, let deepSeekModel {
            legalTextGenerator = DeepSeekTextClient(
                apiKey: deepSeekKey,
                model: deepSeekModel,
                transport: transport
            )
            primaryClassifier = DeepSeekProblemClassifier(
                apiKey: deepSeekKey,
                model: deepSeekModel,
                transport: transport
            )
        } else {
            legalTextGenerator = LocalLegalTextGenerator()
            primaryClassifier = UnavailableProblemClassifier()
        }

        return Self(
            evidenceAnalyzer: evidenceAnalyzer,
            legalTextGenerator: legalTextGenerator,
            localTextGenerator: LocalLegalTextGenerator(),
            problemClassifier: FallbackProblemClassifier(
                primary: primaryClassifier,
                fallback: fallbackClassifier
            )
        )
    }

    static var localOnly: Self {
        Self(
            evidenceAnalyzer: UnavailableEvidenceAnalyzer(),
            legalTextGenerator: LocalLegalTextGenerator(),
            localTextGenerator: LocalLegalTextGenerator(),
            problemClassifier: UnavailableProblemClassifier()
        )
    }

    static var uiTesting: Self {
        Self(
            evidenceAnalyzer: UITestingEvidenceAnalyzer(),
            legalTextGenerator: UITestingLegalTextGenerator(),
            localTextGenerator: LocalLegalTextGenerator(),
            problemClassifier: UITestingProblemClassifier(asksForClarification: false)
        )
    }

    static var uiTestingWithClarification: Self {
        Self(
            evidenceAnalyzer: UITestingEvidenceAnalyzer(),
            legalTextGenerator: UITestingLegalTextGenerator(),
            localTextGenerator: LocalLegalTextGenerator(),
            problemClassifier: UITestingProblemClassifier(asksForClarification: true)
        )
    }

    private static func configuredValue(
        _ key: String,
        in values: [String: String]
    ) -> String? {
        guard let value = values[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
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
            legalGrounds: [
                "Согласно пунктам 1 и 2 статьи 42-4 Закона Республики Казахстан «О защите прав потребителей» потребитель вправе направить претензию, а получатель при несогласии обязан предоставить мотивированный письменный ответ."
            ],
            demands: ["Отменить дальнейшее продление", "Рассмотреть возврат списанных средств"],
            responseDays: 10,
            nonComplianceActions: [
                "При отказе или отсутствии ответа обратиться в уполномоченный орган в сфере защиты прав потребителей."
            ],
            attachmentDescription: request.caseContext.evidenceSummary ?? "Подтверждающие материалы",
            unresolvedIssues: []
        )
    }
}
