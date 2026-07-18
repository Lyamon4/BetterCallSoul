import SwiftUI

struct CasesView: View {
    let legalCase: LegalCase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BCSEditorialTitle(text: "Обращения")
                Text("Следим за сроками и следующими действиями.")
                    .font(.bcsBody())
                    .foregroundStyle(BCSColor.secondary)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(legalCase.title)
                                .font(.bcsEditorial(26))
                            Text(legalCase.counterparty)
                                .font(.bcsBody(14))
                                .foregroundStyle(BCSColor.secondary)
                        }
                        Spacer()
                        Text(amountText)
                            .font(.bcsEditorial(24))
                    }

                    BCSDivider()

                    BCSStatusBadge(title: legalCase.status.rawValue, isActive: true)
                    Text(deadlineText)
                        .font(.bcsBody(14, weight: .medium))

                    timelineRow(
                        title: legalCase.status == .draft ? "Черновик создан" : "Документ подготовлен",
                        detail: legalCase.number,
                        active: legalCase.status == .draft
                    )
                    timelineRow(
                        title: legalCase.status == .sent ? "Отправлено пользователем" : "Ожидается отправка",
                        detail: legalCase.status == .sent ? "Следим за ответом" : "Подтвердите действие",
                        active: legalCase.status != .sent
                    )
                }
                .padding(.top, 30)

                Spacer(minLength: 120)
            }
            .padding(24)
            .padding(.bottom, 80)
        }
        .background(BCSColor.canvas)
    }

    private var amountText: String {
        guard let amount = legalCase.amount else { return "—" }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = " "
        return "\(formatter.string(from: NSNumber(value: amount)) ?? String(amount)) ₸"
    }

    private var deadlineText: String {
        guard let deadline = legalCase.responseDeadline else {
            return "Срок появится после отправки"
        }
        return "Ответ до \(deadline.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "ru_RU"))))"
    }

    private func timelineRow(title: String, detail: String, active: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(active ? BCSColor.yellow : BCSColor.ink)
                .frame(width: 9, height: 9)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.bcsBody(15, weight: .medium))
                Text(detail)
                    .font(.bcsBody(13))
                    .foregroundStyle(BCSColor.secondary)
            }
        }
    }
}
