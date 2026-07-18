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
                        Text("24 900 ₸")
                            .font(.bcsEditorial(24))
                    }

                    BCSDivider()

                    BCSStatusBadge(title: legalCase.status.rawValue, isActive: true)
                    Text("Ответ до 28 июля")
                        .font(.bcsBody(14, weight: .medium))

                    timelineRow(title: "Документ подготовлен", detail: "18 июля, 09:41", active: false)
                    timelineRow(title: "Ожидается отправка", detail: "Подтвердите действие", active: true)
                }
                .padding(.top, 30)

                Spacer(minLength: 120)
            }
            .padding(24)
            .padding(.bottom, 80)
        }
        .background(BCSColor.canvas)
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
