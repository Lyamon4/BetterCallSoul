import SwiftUI

struct AIProviderStatus: Identifiable, Equatable {
    let provider: AIProvider
    let model: String
    let maskedKey: String
    let isConfigured: Bool

    var id: AIProvider { provider }

    static func make(from configuration: AIConfiguration) -> [Self] {
        [
            AIProviderStatus(
                provider: .gemini,
                model: configuration.geminiModel,
                maskedKey: configuration.maskedGeminiKey,
                isConfigured: !configuration.geminiAPIKey.isEmpty
            ),
            AIProviderStatus(
                provider: .deepSeek,
                model: configuration.deepSeekModel,
                maskedKey: configuration.maskedDeepSeekKey,
                isConfigured: !configuration.deepSeekAPIKey.isEmpty
            )
        ]
    }
}

struct AISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    private let secretStore: KeychainSecretStore
    @State private var configuration: AIConfiguration?
    @State private var geminiInput = ""
    @State private var deepSeekInput = ""
    @State private var notice: String?

    init(
        configuration: AIConfiguration? = nil,
        secretStore: KeychainSecretStore = .init()
    ) {
        self.secretStore = secretStore
        _configuration = State(
            initialValue: configuration ?? (try? AIConfiguration.bundled(secrets: secretStore))
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar

                BCSEditorialTitle(text: "AI-провайдеры", size: 42)
                    .padding(.top, 12)
                Text("Gemini читает изображения и PDF. DeepSeek работает только с подтверждённым текстом.")
                    .font(.bcsBody(16))
                    .foregroundStyle(BCSColor.secondary)
                    .lineSpacing(3)
                    .padding(.top, 10)

                transferRule
                    .padding(.top, 18)

                providerCard(
                    status: status(for: .gemini),
                    input: $geminiInput,
                    account: KeychainSecretStore.geminiAccount,
                    identifier: "geminiConfiguredStatus"
                )
                .padding(.top, 14)

                providerCard(
                    status: status(for: .deepSeek),
                    input: $deepSeekInput,
                    account: KeychainSecretStore.deepSeekAccount,
                    identifier: "deepSeekConfiguredStatus"
                )
                .padding(.top, 12)

                if let notice {
                    Text(notice)
                        .font(.bcsBody(13, weight: .medium))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BCSColor.paleGreen)
                        .foregroundStyle(BCSColor.greenText)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.top, 12)
                }

                Text("Сохранение меняет только локальную копию в Keychain и не отправляет тестовый запрос. Новый ключ используется после перезапуска приложения.")
                    .font(.bcsBody(12))
                    .foregroundStyle(BCSColor.secondary)
                    .lineSpacing(2)
                    .padding(.top, 14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 112)
        }
        .background(BCSColor.canvas.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Label("Профиль", systemImage: "chevron.left")
                    .font(.bcsBody(15))
            }
            Spacer()
            Text("ЛОКАЛЬНО")
                .font(.bcsMeta(10))
                .tracking(0.8)
                .foregroundStyle(BCSColor.secondary)
        }
        .foregroundStyle(BCSColor.ink)
        .frame(minHeight: 44)
    }

    private var transferRule: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 17, weight: .semibold))
            VStack(alignment: .leading, spacing: 4) {
                Text("Разделение данных")
                    .font(.bcsBody(15, weight: .semibold))
                Text("Файл → Gemini · Проверенный текст → DeepSeek")
                    .font(.bcsBody(13))
                    .foregroundStyle(BCSColor.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(BCSColor.paleYellow)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(BCSColor.divider))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func providerCard(
        status: AIProviderStatus,
        input: Binding<String>,
        account: String,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(status.provider.displayName)
                        .font(.bcsEditorial(24))
                    Text(status.model)
                        .font(.bcsMeta(11))
                        .foregroundStyle(BCSColor.secondary)
                }
                Spacer()
                Text(status.isConfigured ? "Ключ добавлен · \(status.maskedKey)" : "Ключ не добавлен")
                    .font(.bcsBody(11, weight: .medium))
                    .foregroundStyle(status.isConfigured ? BCSColor.greenText : BCSColor.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(status.isConfigured ? BCSColor.paleGreen : BCSColor.canvas)
                    .clipShape(Capsule())
                    .accessibilityIdentifier(identifier)
            }

            BCSDivider()

            SecureField("Новый API-ключ", text: input)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.bcsBody(15))
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(BCSColor.canvas)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(BCSColor.divider))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack(spacing: 16) {
                Button("Сохранить") {
                    save(input.wrappedValue, account: account)
                    input.wrappedValue = ""
                }
                .font(.bcsBody(14, weight: .semibold))
                .disabled(input.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Удалить замену") {
                    delete(account: account)
                    input.wrappedValue = ""
                }
                .font(.bcsBody(14))
                .foregroundStyle(BCSColor.secondary)
            }
            .foregroundStyle(BCSColor.ink)
        }
        .padding(16)
        .background(BCSColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(BCSColor.divider))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func status(for provider: AIProvider) -> AIProviderStatus {
        guard let configuration,
              let status = AIProviderStatus.make(from: configuration).first(where: { $0.provider == provider }) else {
            return AIProviderStatus(
                provider: provider,
                model: "Не настроено",
                maskedKey: "—",
                isConfigured: false
            )
        }
        return status
    }

    private func save(_ value: String, account: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try secretStore.write(trimmed, account: account)
            reloadConfiguration()
            notice = "Ключ сохранён локально."
        } catch {
            notice = "Не удалось сохранить ключ в Keychain."
        }
    }

    private func delete(account: String) {
        do {
            try secretStore.delete(account: account)
            reloadConfiguration()
            notice = "Локальная замена удалена."
        } catch {
            notice = "Не удалось изменить Keychain."
        }
    }

    private func reloadConfiguration() {
        configuration = try? AIConfiguration.bundled(secrets: secretStore)
    }
}
