import UIKit
import XCTest
@testable import BetterCallSaul

private actor WorkflowEvidenceStub: EvidenceAnalyzing {
    private let result: Result<EvidenceAnalysis, AIProviderError>
    private var attempts = 0

    init(_ result: Result<EvidenceAnalysis, AIProviderError>) {
        self.result = result
    }

    func analyze(
        payload: EvidencePayload,
        caseType: CaseType,
        narrative: String
    ) async throws -> EvidenceAnalysis {
        attempts += 1
        return try result.get()
    }

    func attemptCount() -> Int { attempts }
}

private actor WorkflowLegalStub: LegalTextGenerating {
    private let analysisResult: Result<CaseAIAnalysis, AIProviderError>
    private let documentResult: Result<AIDocumentSections, AIProviderError>
    private var analysisAttempts = 0
    private var documentAttempts = 0

    init(
        analysis: Result<CaseAIAnalysis, AIProviderError>,
        document: Result<AIDocumentSections, AIProviderError>
    ) {
        analysisResult = analysis
        documentResult = document
    }

    func analyzeCase(_ request: CaseAIRequest) async throws -> CaseAIAnalysis {
        analysisAttempts += 1
        return try analysisResult.get()
    }

    func generateDocument(_ request: AIDocumentRequest) async throws -> AIDocumentSections {
        documentAttempts += 1
        return try documentResult.get()
    }

    func analysisAttemptCount() -> Int { analysisAttempts }
    func documentAttemptCount() -> Int { documentAttempts }
}

@MainActor
final class AIWorkflowTests: XCTestCase {
    func testAnalyzeAttachedEvidenceUsesGeminiAndAppliesEditableFields() async throws {
        let evidence = WorkflowEvidenceStub(.success(Self.evidenceAnalysis))
        let legal = WorkflowLegalStub(
            analysis: .success(Self.caseAnalysis),
            document: .success(Self.documentSections)
        )
        let store = CaseWorkflowStore(
            seed: DemoFixtures.activeCase,
            services: AIServiceContainer(
                evidenceAnalyzer: evidence,
                legalTextGenerator: legal,
                localTextGenerator: legal
            )
        )
        store.attachEvidence(Self.importedEvidence())

        try await store.analyzeAttachedEvidence()

        XCTAssertEqual(store.evidenceAnalysis, Self.evidenceAnalysis)
        XCTAssertEqual(store.currentCase.counterparty, "MegaPlus")
        XCTAssertEqual(store.currentCase.amount, 24_900)
        XCTAssertEqual(store.activeProvider, .gemini)
        let evidenceAttempts = await evidence.attemptCount()
        let legalAttempts = await legal.analysisAttemptCount()
        XCTAssertEqual(evidenceAttempts, 1)
        XCTAssertEqual(legalAttempts, 0)
    }

    func testRunAIAnalysisReusesExistingEvidenceAnalysis() async throws {
        let evidence = WorkflowEvidenceStub(.success(Self.evidenceAnalysis))
        let legal = WorkflowLegalStub(
            analysis: .success(Self.caseAnalysis),
            document: .success(Self.documentSections)
        )
        let local = WorkflowLegalStub(
            analysis: .success(Self.localAnalysis),
            document: .success(Self.documentSections)
        )
        let store = CaseWorkflowStore(
            seed: DemoFixtures.activeCase,
            services: AIServiceContainer(
                evidenceAnalyzer: evidence,
                legalTextGenerator: legal,
                localTextGenerator: local
            )
        )
        store.attachEvidence(Self.importedEvidence())

        try await store.analyzeAttachedEvidence()
        await store.runAIAnalysis()

        let evidenceAttempts = await evidence.attemptCount()
        let legalAttempts = await legal.analysisAttemptCount()
        XCTAssertEqual(evidenceAttempts, 1)
        XCTAssertEqual(legalAttempts, 1)
        XCTAssertEqual(store.aiState, .questions)
    }

    func testVisualAndTextAnalysisUpdateEditableCaseFacts() async throws {
        let evidence = WorkflowEvidenceStub(.success(Self.evidenceAnalysis))
        let legal = WorkflowLegalStub(
            analysis: .success(Self.caseAnalysis),
            document: .success(Self.documentSections)
        )
        let local = WorkflowLegalStub(
            analysis: .success(Self.localAnalysis),
            document: .success(Self.documentSections)
        )
        let store = CaseWorkflowStore(
            seed: DemoFixtures.activeCase,
            services: AIServiceContainer(
                evidenceAnalyzer: evidence,
                legalTextGenerator: legal,
                localTextGenerator: local
            )
        )
        store.attachEvidence(Self.importedEvidence())
        store.updateNarrative("Подписка продлилась без предупреждения")

        await store.runAIAnalysis()

        XCTAssertEqual(store.aiState, .questions)
        XCTAssertEqual(store.currentCase.counterparty, "MegaPlus")
        XCTAssertEqual(store.currentCase.amount, 24_900)
        XCTAssertEqual(
            store.currentCase.extractedFields.map(\.label),
            ["Сервис", "Сумма", "Дата списания", "Дата отмены"]
        )
        XCTAssertEqual(
            store.currentCase.extractedFields.first(where: { $0.kind == .detail })?.value,
            ""
        )
        XCTAssertEqual(store.caseAnalysis?.questions.count, 1)
        XCTAssertEqual(store.activeProvider, .deepSeek)
        let evidenceAttempts = await evidence.attemptCount()
        let legalAttempts = await legal.analysisAttemptCount()
        XCTAssertEqual(evidenceAttempts, 1)
        XCTAssertEqual(legalAttempts, 1)
    }

    func testProviderFailuresRetryOnceAndPreserveCaseWithLocalFallback() async throws {
        let evidence = WorkflowEvidenceStub(.failure(.transport("offline")))
        let legal = WorkflowLegalStub(
            analysis: .failure(.transport("offline")),
            document: .failure(.transport("offline"))
        )
        let local = WorkflowLegalStub(
            analysis: .success(Self.localAnalysis),
            document: .success(Self.documentSections)
        )
        let store = CaseWorkflowStore(
            seed: DemoFixtures.activeCase,
            services: AIServiceContainer(
                evidenceAnalyzer: evidence,
                legalTextGenerator: legal,
                localTextGenerator: local
            )
        )
        store.attachEvidence(Self.importedEvidence())
        let originalID = store.currentCase.id

        await store.runAIAnalysis()

        XCTAssertEqual(store.currentCase.id, originalID)
        XCTAssertEqual(store.activeProvider, .local)
        XCTAssertNotNil(store.caseAnalysis)
        if case .fallback = store.aiState {} else {
            XCTFail("Expected fallback state")
        }
        let evidenceAttempts = await evidence.attemptCount()
        let legalAttempts = await legal.analysisAttemptCount()
        XCTAssertEqual(evidenceAttempts, 2)
        XCTAssertEqual(legalAttempts, 2)
    }

    func testTextTimeoutFallsBackLocallyWithoutRetry() async throws {
        let evidence = WorkflowEvidenceStub(.success(Self.evidenceAnalysis))
        let legal = WorkflowLegalStub(
            analysis: .failure(.timedOut),
            document: .success(Self.documentSections)
        )
        let local = WorkflowLegalStub(
            analysis: .success(Self.localAnalysis),
            document: .success(Self.documentSections)
        )
        let store = CaseWorkflowStore(
            seed: DemoFixtures.activeCase,
            services: AIServiceContainer(
                evidenceAnalyzer: evidence,
                legalTextGenerator: legal,
                localTextGenerator: local
            )
        )

        await store.runAIAnalysis()

        XCTAssertEqual(store.activeProvider, .local)
        XCTAssertEqual(store.caseAnalysis, Self.localAnalysis)
        if case .fallback = store.aiState {} else {
            XCTFail("Expected fallback state")
        }
        let legalAttempts = await legal.analysisAttemptCount()
        let localAttempts = await local.analysisAttemptCount()
        XCTAssertEqual(legalAttempts, 1)
        XCTAssertEqual(localAttempts, 1)
    }

    func testDocumentTimeoutFallsBackLocallyWithoutRetry() async throws {
        let evidence = WorkflowEvidenceStub(.success(Self.evidenceAnalysis))
        let legal = WorkflowLegalStub(
            analysis: .success(Self.caseAnalysis),
            document: .failure(.timedOut)
        )
        let local = WorkflowLegalStub(
            analysis: .success(Self.localAnalysis),
            document: .success(Self.documentSections)
        )
        let store = CaseWorkflowStore(
            seed: DemoFixtures.activeCase,
            services: AIServiceContainer(
                evidenceAnalyzer: evidence,
                legalTextGenerator: legal,
                localTextGenerator: local
            )
        )
        await store.runAIAnalysis()

        await store.generateAIDocument()

        XCTAssertEqual(store.activeProvider, .local)
        XCTAssertEqual(store.aiDocumentSections, Self.documentSections)
        if case .fallback = store.aiState {} else {
            XCTFail("Expected fallback state")
        }
        let legalAttempts = await legal.documentAttemptCount()
        let localAttempts = await local.documentAttemptCount()
        XCTAssertEqual(legalAttempts, 1)
        XCTAssertEqual(localAttempts, 1)
    }

    func testDocumentGenerationRetriesAndFallsBackLocally() async throws {
        let evidence = WorkflowEvidenceStub(.success(Self.evidenceAnalysis))
        let legal = WorkflowLegalStub(
            analysis: .success(Self.caseAnalysis),
            document: .failure(.transport("offline"))
        )
        let local = WorkflowLegalStub(
            analysis: .success(Self.localAnalysis),
            document: .success(Self.documentSections)
        )
        let store = CaseWorkflowStore(
            seed: DemoFixtures.activeCase,
            services: AIServiceContainer(
                evidenceAnalyzer: evidence,
                legalTextGenerator: legal,
                localTextGenerator: local
            )
        )
        await store.runAIAnalysis()

        await store.generateAIDocument()

        XCTAssertEqual(store.activeProvider, .local)
        XCTAssertNotNil(store.aiDocumentSections)
        let legalAttempts = await legal.documentAttemptCount()
        let localAttempts = await local.documentAttemptCount()
        XCTAssertEqual(legalAttempts, 2)
        XCTAssertEqual(localAttempts, 1)
    }

    private static func importedEvidence() -> ImportedEvidence {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }.cgImage!
        return ImportedEvidence(
            image: image,
            item: EvidenceItem(fileName: "receipt.jpg", fileSize: "1 КБ"),
            payload: EvidencePayload(
                fileName: "receipt.jpg",
                mimeType: "image/jpeg",
                data: Data([1]),
                previewImage: image
            )
        )
    }

    private static let evidenceAnalysis = EvidenceAnalysis(
        documentKind: "receipt",
        rawText: "MEGAPLUS 24 900 KZT",
        counterparty: "MegaPlus",
        amount: Decimal(24_900),
        currency: "KZT",
        transactionDate: "2026-07-17",
        evidenceSummary: "Чек подтверждает списание",
        importantDetails: [],
        warnings: [],
        confidence: ["amount": 0.99]
    )

    private static let caseAnalysis = CaseAIAnalysis(
        summary: "Подписка продлена без предупреждения",
        recommendedAction: "Запросить отмену и возврат",
        warnings: [],
        questions: [
            AIQuestion(
                id: "cancelled",
                kind: .boolean,
                prompt: "Вы отменяли подписку?",
                whyNeeded: "Это уточнит требование",
                options: ["Да", "Нет"],
                required: true
            )
        ]
    )

    private static let localAnalysis = CaseAIAnalysis(
        summary: "Локальный анализ обращения",
        recommendedAction: "Проверьте факты и подготовьте претензию",
        warnings: ["AI-сервис недоступен"],
        questions: []
    )

    private static let documentSections = AIDocumentSections(
        recipient: "MegaPlus",
        subject: "Требование о возврате",
        facts: ["Списано 24 900 ₸"],
        legalGrounds: ["Пункты 1 и 2 статьи 42-4 Закона Республики Казахстан «О защите прав потребителей»"],
        demands: ["Вернуть денежные средства"],
        responseDays: 10,
        nonComplianceActions: ["Обратиться в уполномоченный орган"],
        attachmentDescription: "Копия чека",
        unresolvedIssues: []
    )
}
