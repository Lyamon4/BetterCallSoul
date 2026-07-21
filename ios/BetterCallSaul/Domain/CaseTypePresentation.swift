import Foundation

enum CaseFieldKind: String, Codable, Sendable {
    case counterparty
    case amount
    case date
    case reference
    case detail
}

struct CaseFieldDescriptor: Equatable, Sendable {
    let kind: CaseFieldKind
    let label: String
}

struct CaseTypePresentation: Equatable, Sendable {
    let title: String
    let explanation: String
    let narrativeLabel: String
    let narrativePlaceholder: String
    let uploadTitle: String
    let uploadHint: String
    let fields: [CaseFieldDescriptor]
}

extension CaseType {
    var presentation: CaseTypePresentation {
        switch self {
        case .charge:
            CaseTypePresentation(
                title: "Оспорьте\nсписание",
                explanation: "Укажите, кто и когда списал деньги — подготовим требование о возврате.",
                narrativeLabel: "Как произошло списание",
                narrativePlaceholder: "Например: не узнаю операцию, услугу не получил, деньги списали дважды…",
                uploadTitle: "Добавьте подтверждение списания",
                uploadHint: "Скриншот операции, чек или банковская выписка",
                fields: [
                    .init(kind: .counterparty, label: "Компания или сервис"),
                    .init(kind: .amount, label: "Сумма"),
                    .init(kind: .date, label: "Дата"),
                    .init(kind: .detail, label: "Способ оплаты")
                ]
            )

        case .fine:
            CaseTypePresentation(
                title: "Обжалуйте\nштраф",
                explanation: "Проверьте постановление и объясните, почему штраф нужно отменить.",
                narrativeLabel: "Почему штраф несправедлив",
                narrativePlaceholder: "Например: знак был закрыт, автомобилем управлял другой человек…",
                uploadTitle: "Добавьте постановление",
                uploadHint: "Фото или PDF постановления, уведомления и подтверждающих материалов",
                fields: [
                    .init(kind: .counterparty, label: "Орган"),
                    .init(kind: .reference, label: "Номер постановления"),
                    .init(kind: .amount, label: "Сумма"),
                    .init(kind: .date, label: "Дата")
                ]
            )

        case .subscription:
            CaseTypePresentation(
                title: "Отмените\nподписку",
                explanation: "Укажите сервис и спорное списание — подготовим отмену и запрос на возврат.",
                narrativeLabel: "Что произошло с подпиской",
                narrativePlaceholder: "Например: отменил подписку, но деньги снова списали…",
                uploadTitle: "Добавьте подтверждение подписки",
                uploadHint: "Скриншот списания, условий подписки или переписки с сервисом",
                fields: [
                    .init(kind: .counterparty, label: "Сервис"),
                    .init(kind: .amount, label: "Сумма"),
                    .init(kind: .date, label: "Дата списания"),
                    .init(kind: .detail, label: "Дата отмены")
                ]
            )

        case .product:
            CaseTypePresentation(
                title: "Решите проблему\nс товаром",
                explanation: "Опишите недостаток товара и желаемый результат: возврат, замену или ремонт.",
                narrativeLabel: "Что не так с товаром",
                narrativePlaceholder: "Например: товар сломался через три дня, продавец отказал в возврате…",
                uploadTitle: "Добавьте чек и фото товара",
                uploadHint: "Чек, фотографии недостатка, гарантия или переписка с продавцом",
                fields: [
                    .init(kind: .counterparty, label: "Продавец"),
                    .init(kind: .detail, label: "Товар"),
                    .init(kind: .amount, label: "Стоимость"),
                    .init(kind: .date, label: "Дата покупки")
                ]
            )

        case .bill:
            CaseTypePresentation(
                title: "Добейтесь\nперерасчёта",
                explanation: "Покажите спорный счёт и укажите, какие начисления считаете неверными.",
                narrativeLabel: "Что неверно в счёте",
                narrativePlaceholder: "Например: начислили лишнюю услугу или применили неверный тариф…",
                uploadTitle: "Добавьте спорный счёт",
                uploadHint: "Фото или PDF счёта, детализация и предыдущие квитанции",
                fields: [
                    .init(kind: .counterparty, label: "Поставщик"),
                    .init(kind: .detail, label: "Период"),
                    .init(kind: .amount, label: "Сумма"),
                    .init(kind: .reference, label: "Номер счёта")
                ]
            )
        }
    }
}
