import SwiftUI

struct ProfileView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BCSEditorialTitle(text: "Профиль")
            Text("Личные данные будут добавлены после визуального MVP.")
                .font(.bcsBody())
                .foregroundStyle(BCSColor.secondary)
            Spacer()
        }
        .padding(24)
        .padding(.bottom, 80)
        .background(BCSColor.canvas)
    }
}
