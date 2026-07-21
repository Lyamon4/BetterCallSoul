import Foundation

enum DemoFixtures {
    static let activeCase = LegalCase(
        id: UUID(uuidString: "84B7C148-204D-4D4F-9BB5-F2B202607170")!,
        number: "BCS-2026-0717-0017",
        type: .subscription,
        title: "Возврат за подписку",
        counterparty: "MegaPlus Kazakhstan",
        amount: 24_900,
        status: .waitingForResponse,
        responseDeadline: Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 7, day: 28)
        ),
        evidence: [
            EvidenceItem(fileName: "IMG_1847.PNG", fileSize: "2,4 МБ")
        ],
        extractedFields: [
            ExtractedField(kind: .counterparty, label: "Сервис", value: "MegaPlus"),
            ExtractedField(kind: .amount, label: "Сумма", value: "24 900 ₸"),
            ExtractedField(kind: .date, label: "Дата списания", value: "17 июля 2026"),
            ExtractedField(kind: .detail, label: "Дата отмены", value: "", requiresReview: true)
        ]
    )

    static let tools: [ToolItem] = [
        ToolItem(id: 1, title: "Жалоба компании"),
        ToolItem(id: 2, title: "Обжалование штрафа"),
        ToolItem(id: 3, title: "Отмена подписки"),
        ToolItem(id: 4, title: "Возврат денег"),
        ToolItem(id: 5, title: "Переговоры по счёту")
    ]
}
