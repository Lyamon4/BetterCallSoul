import SwiftUI

struct ProfileView: View {
    @Bindable var profile: UserProfileStore
    @FocusState private var isNameFocused: Bool
    @State private var draftName: String
    @State private var didSave = false

    init(profile: UserProfileStore) {
        self.profile = profile
        _draftName = State(initialValue: profile.name)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BCSEditorialTitle(text: "Профиль")

                Text(profile.name)
                    .font(.bcsEditorial(28))
                    .padding(.top, 24)
                    .accessibilityIdentifier("profileDisplayName")

                Text("Казахстан · Русский")
                    .font(.bcsBody(15))
                    .foregroundStyle(BCSColor.secondary)
                    .padding(.top, 4)

                BCSDivider()
                    .padding(.top, 24)

                nameEditor
                    .padding(.top, 18)

                if didSave {
                    Label("Имя сохранено", systemImage: "checkmark.circle.fill")
                        .font(.bcsBody(14, weight: .medium))
                        .foregroundStyle(BCSColor.greenText)
                        .padding(.top, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                BCSPrimaryButton("Сохранить имя", systemImage: "checkmark") {
                    saveName()
                }
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.35)
                .accessibilityIdentifier("saveProfileNameButton")
                .padding(.top, 16)

                BCSDivider()
                    .padding(.top, 24)

                Text("Документы создаются на основании указанных вами данных. Перед отправкой проверяйте факты и получателя.")
                    .font(.bcsBody(14))
                    .foregroundStyle(BCSColor.secondary)
                    .lineSpacing(3)
                    .padding(.top, 18)
            }
            .padding(20)
            .padding(.bottom, 112)
        }
        .background(BCSColor.canvas)
        .onChange(of: draftName) {
            if didSave {
                didSave = false
            }
        }
        .onChange(of: profile.name) { _, newName in
            guard !isNameFocused else { return }
            draftName = newName
        }
    }

    private var nameEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ИМЯ В ДОКУМЕНТАХ")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(BCSColor.secondary)

            HStack(spacing: 10) {
                TextField("Ваше имя", text: $draftName)
                    .font(.bcsBody(17))
                    .textContentType(.name)
                    .submitLabel(.done)
                    .focused($isNameFocused)
                    .onSubmit {
                        if canSave {
                            saveName()
                        }
                    }
                    .accessibilityIdentifier("profileNameField")

                if !draftName.isEmpty {
                    Button {
                        draftName = ""
                        isNameFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(BCSColor.secondary)
                    }
                    .accessibilityLabel("Очистить имя")
                    .accessibilityIdentifier("clearProfileNameButton")
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(BCSColor.surface)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(BCSColor.divider))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("Это имя будет указано в обращении, подписи и PDF.")
                .font(.bcsBody(12))
                .foregroundStyle(BCSColor.secondary)
        }
    }

    private var normalizedDraftName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !normalizedDraftName.isEmpty && normalizedDraftName != profile.name
    }

    private func saveName() {
        guard profile.updateName(draftName) else { return }
        draftName = profile.name
        isNameFocused = false
        withAnimation(.easeOut(duration: 0.2)) {
            didSave = true
        }
    }
}
