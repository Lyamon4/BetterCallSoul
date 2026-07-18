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

                BCSEditorialTitle(text: "Претензия готова", size: 42)
                    .padding(.top, 10)
                Text("Проверьте данные перед отправкой.")
                    .font(.bcsBody())
                    .foregroundStyle(BCSColor.secondary)
                    .padding(.top, 8)

                documentPaper
                    .padding(.top, 16)

                reviewRow(icon: "checkmark", color: BCSColor.ink, title: "Данные подтверждены")
                    .padding(.top, 8)
                reviewRow(
                    icon: "exclamationmark",
                    color: BCSColor.yellow,
                    title: "2 места требуют внимания",
                    isWarning: true
                )
                .padding(.top, 6)

                BCSPrimaryButton("Подписать и отправить", systemImage: "signature") {
                    showConfirmation = true
                }
                .accessibilityIdentifier("sendDocumentButton")
                .padding(.top, 8)

                Button("Скачать PDF") {}
                    .font(.bcsBody(16, weight: .medium))
                    .foregroundStyle(BCSColor.ink)
                    .underline()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 36)

                HStack {
                    Label("Всё по закону.", systemImage: "phone")
                    Spacer()
                    Text("S’all good")
                        .italic()
                }
                .font(.system(size: 12, design: .serif))
                .foregroundStyle(BCSColor.secondary)
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 112)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "phone.fill")
                        .padding(8)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(BCSColor.ink))
                    Text("BetterCallSaul")
                        .font(.system(size: 11, design: .serif))
                    Text("Всё по закону.")
                        .font(.bcsBody(9))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Исх. № \(legalCase.number)")
                    Text("18 июля 2026 г.")
                }
                .font(.bcsMeta(8))
            }

            Rectangle()
                .fill(BCSColor.yellow)
                .frame(width: 34, height: 4)

            Text("Требование о возврате 24 900 ₸")
                .font(.bcsEditorial(20))

            Text("Кому: \(legalCase.counterparty)")
                .font(.bcsBody(10))

            BCSDivider()

            Text("Я подтверждаю, что с моего счёта была списана сумма 24 900 ₸ за продление подписки. Прошу рассмотреть требование о возврате после проверки обстоятельств и приложенных доказательств.")
                .font(.bcsBody(10))
                .lineSpacing(2)

            Text("Перед отправкой пользователь обязан проверить факты, получателя и применимые основания.")
                .font(.bcsBody(10))
                .lineSpacing(2)
                .padding(10)
                .background(BCSColor.paleYellow)

            Text("Приложение: копия подтверждения списания на 1 странице.")
                .font(.bcsBody(9))

            BCSDivider()

            HStack {
                Text("С уважением,\nАлим")
                    .font(.bcsBody(9))
                Spacer()
                Text("A. N.")
                    .font(.system(size: 19, design: .serif))
                    .italic()
            }
        }
        .padding(16)
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
                .frame(width: 28, height: 28)
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
        .frame(minHeight: 44)
        .background(BCSColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(BCSColor.divider))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
