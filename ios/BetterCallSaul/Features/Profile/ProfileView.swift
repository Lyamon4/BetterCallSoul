import SwiftUI

struct ProfileView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BCSEditorialTitle(text: "Профиль")

                Text("Настройки локального приложения")
                    .font(.bcsBody())
                    .foregroundStyle(BCSColor.secondary)
                    .padding(.top, 8)

                NavigationLink {
                    AISettingsView()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .background(BCSColor.paleYellow)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("AI-провайдеры")
                                .font(.bcsBody(16, weight: .medium))
                            Text("Gemini · DeepSeek · Keychain")
                                .font(.bcsBody(12))
                                .foregroundStyle(BCSColor.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(BCSColor.secondary)
                    }
                    .padding(14)
                    .foregroundStyle(BCSColor.ink)
                    .background(BCSColor.surface)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(BCSColor.divider))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityIdentifier("AI-провайдеры")
                .padding(.top, 20)

                HStack {
                    Label("S’all configured", systemImage: "phone.fill")
                    Spacer()
                    Text("BCS / 2026")
                        .font(.bcsMeta(10))
                }
                .font(.system(size: 12, design: .serif))
                .foregroundStyle(BCSColor.secondary)
                .padding(.top, 14)
            }
            .padding(20)
            .padding(.bottom, 96)
        }
        .background(BCSColor.canvas)
    }
}
