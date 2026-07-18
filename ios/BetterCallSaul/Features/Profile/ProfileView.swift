import SwiftUI

struct ProfileView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BCSEditorialTitle(text: "Профиль")

                Text("Алим")
                    .font(.bcsEditorial(28))
                    .padding(.top, 24)

                Text("Казахстан · Русский")
                    .font(.bcsBody(15))
                    .foregroundStyle(BCSColor.secondary)
                    .padding(.top, 4)

                BCSDivider()
                    .padding(.top, 24)

                Text("Документы создаются на основании указанных вами данных. Перед отправкой проверяйте факты и получателя.")
                    .font(.bcsBody(14))
                    .foregroundStyle(BCSColor.secondary)
                    .lineSpacing(3)
                    .padding(.top, 18)
            }
            .padding(20)
            .padding(.bottom, 96)
        }
        .background(BCSColor.canvas)
    }
}
