import SwiftUI

struct DocumentView: View {
    let legalCase: LegalCase
    @Environment(\.dismiss) private var dismiss
    @State private var showConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Label("Обращение", systemImage: "chevron.left")
                    }
                    Spacer()
                    BCSStatusBadge(title: "Готово", isActive: true)
                }
                .font(.bcsBody(15))
                .foregroundStyle(BCSColor.ink)
                .frame(minHeight: 44)

                BCSEditorialTitle(text: "Претензия готова")
                    .padding(.top, 22)
                Text("Проверьте данные перед отправкой.")
                    .font(.bcsBody())
                    .foregroundStyle(BCSColor.secondary)
                    .padding(.top, 8)

                documentPaper
                    .padding(.top, 22)

                reviewRow(icon: "checkmark", color: BCSColor.ink, title: "Данные подтверждены")
                    .padding(.top, 16)
                reviewRow(
                    icon: "exclamationmark",
                    color: BCSColor.yellow,
                    title: "2 места требуют внимания",
                    isWarning: true
                )
                .padding(.top, 10)

                BCSPrimaryButton("Подписать и отправить", systemImage: "signature") {
                    showConfirmation = true
                }
                .accessibilityIdentifier("sendDocumentButton")
                .padding(.top, 18)

                Button("Скачать PDF") {}
                    .font(.bcsBody(16, weight: .medium))
                    .foregroundStyle(BCSColor.ink)
                    .underline()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)

                HStack {
                    Label("Всё по закону.", systemImage: "phone")
                    Spacer()
                    Text("S’all good")
                        .italic()
                }
                .font(.system(size: 12, design: .serif))
                .foregroundStyle(BCSColor.secondary)
                .padding(.top, 14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(BCSColor.canvas.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .alert("Документ подготовлен", isPresented: $showConfirmation) {
            Button("Готово", role: .cancel) {}
        } message: {
            Text("На следующем этапе здесь появится системное меню отправки.")
        }
    }

    private var documentPaper: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "phone.fill")
                        .padding(8)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(BCSColor.ink))
                    Text("BetterCallSaul")
                        .font(.system(size: 13, design: .serif))
                    Text("Всё по закону.")
                        .font(.bcsBody(10))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Исх. № \(legalCase.number)")
                    Text("18 июля 2026 г.")
                }
                .font(.bcsMeta(9))
            }

            Rectangle()
                .fill(BCSColor.yellow)
                .frame(width: 34, height: 4)

            Text("Требование о возврате 24 900 ₸")
                .font(.bcsEditorial(26))

            Text("Кому: \(legalCase.counterparty)")
                .font(.bcsBody(12))

            BCSDivider()

            Text("Я подтверждаю, что с моего счёта была списана сумма 24 900 ₸ за продление подписки. Прошу рассмотреть требование о возврате после проверки обстоятельств и приложенных доказательств.")
                .font(.bcsBody(12))
                .lineSpacing(3)

            Text("Перед отправкой пользователь обязан проверить факты, получателя и применимые основания.")
                .font(.bcsBody(12))
                .lineSpacing(3)
                .padding(12)
                .background(BCSColor.paleYellow)

            Text("Приложение: копия подтверждения списания на 1 странице.")
                .font(.bcsBody(11))

            BCSDivider()

            HStack {
                Text("С уважением,\nАлим")
                    .font(.bcsBody(11))
                Spacer()
                Text("A. N.")
                    .font(.system(size: 22, design: .serif))
                    .italic()
            }
        }
        .padding(22)
        .background(BCSColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(BCSColor.divider))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
    }

    private func reviewRow(
        icon: String,
        color: Color,
        title: String,
        isWarning: Bool = false
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 34, height: 34)
                .background(color)
                .foregroundStyle(isWarning ? BCSColor.ink : Color.white)
                .clipShape(Circle())
            Text(title)
                .font(.bcsBody(15))
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(BCSColor.secondary)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 58)
        .background(BCSColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(BCSColor.divider))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
