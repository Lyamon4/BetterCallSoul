import SwiftUI
import UIKit

struct SaulAssistantSheet: View {
    @Bindable var assistant: SaulAssistantViewModel
    let onClose: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case problem
        case clarification
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                HStack(alignment: .top, spacing: 16) {
                    SaulMascotView(
                        state: assistant.mascotState,
                        size: 108,
                        isDecorative: false
                    )
                    .frame(width: 108, height: 108)

                    Text(assistant.visibleMessage)
                        .font(.bcsEditorial(24))
                        .foregroundStyle(BCSColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                }
                .padding(.top, 18)

                if showsInput {
                    inputField
                        .padding(.top, 18)
                }

                Text("Ответ нужен только для выбора подходящего сценария.")
                    .font(.bcsBody(12))
                    .foregroundStyle(BCSColor.secondary)
                    .padding(.top, 10)

                actions
                    .padding(.top, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(BCSColor.canvas.ignoresSafeArea())
        .accessibilityIdentifier("saulAssistantSheet")
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(assistant.state == .classifying)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") { focusedField = nil }
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            focusedField = .problem
        }
        .onChange(of: assistant.state) { _, state in
            handleStateChange(state)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Расскажите Солу")
                    .font(.bcsEditorial(32))
                    .foregroundStyle(BCSColor.ink)
                Text("S’all good, man")
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(BCSColor.secondary)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BCSColor.ink)
                    .frame(width: 40, height: 40)
                    .background(BCSColor.surface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(BCSColor.divider))
            }
            .accessibilityLabel("Закрыть")
            .accessibilityIdentifier("saulCloseButton")
        }
    }

    @ViewBuilder
    private var inputField: some View {
        if usesClarificationField {
            styledTextField(
                placeholder: "Напишите короткий ответ…",
                text: $assistant.clarificationText,
                field: .clarification,
                identifier: "saulClarificationField"
            )
        } else {
            styledTextField(
                placeholder: "Например, мне выписали штраф…",
                text: $assistant.problemText,
                field: .problem,
                identifier: "saulProblemField"
            )
        }
    }

    private func styledTextField(
        placeholder: String,
        text: Binding<String>,
        field: Field,
        identifier: String
    ) -> some View {
        TextField(placeholder, text: text, axis: .vertical)
            .lineLimit(3...6)
            .font(.bcsBody(16))
            .foregroundStyle(BCSColor.ink)
            .padding(14)
            .frame(minHeight: 96, alignment: .topLeading)
            .background(BCSColor.surface)
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(BCSColor.divider))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .focused($focusedField, equals: field)
            .submitLabel(.send)
            .onSubmit { assistant.submit() }
            .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private var actions: some View {
        switch assistant.state {
        case .askingProblem, .askingClarification:
            BCSPrimaryButton("Отправить", systemImage: "arrow.up") {
                focusedField = nil
                assistant.submit()
            }
            .disabled(!assistant.canSubmit)
            .opacity(assistant.canSubmit ? 1 : 0.42)
            .accessibilityIdentifier("saulSubmitButton")

        case .failed:
            BCSPrimaryButton("Повторить", systemImage: "arrow.clockwise") {
                focusedField = nil
                assistant.retry()
            }
            .accessibilityIdentifier("saulRetryButton")

        case .classifying:
            HStack(spacing: 10) {
                ProgressView()
                    .tint(BCSColor.ink)
                Text("Разбираюсь…")
                    .font(.bcsBody(15, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .accessibilityLabel("Разбираюсь в ситуации")

        case .routing:
            HStack(spacing: 8) {
                Rectangle()
                    .fill(BCSColor.yellow)
                    .frame(width: 3, height: 34)
                Text("Открываю нужный сценарий")
                    .font(.bcsBody(15, weight: .medium))
                Spacer()
            }
            .frame(minHeight: 48)
        }
    }

    private var showsInput: Bool {
        switch assistant.state {
        case .askingProblem, .askingClarification, .failed:
            true
        case .classifying, .routing:
            false
        }
    }

    private var usesClarificationField: Bool {
        if case .askingClarification = assistant.state {
            return true
        }
        return assistant.state == .failed && assistant.clarificationQuestion != nil
    }

    private func handleStateChange(_ state: SaulAssistantState) {
        switch state {
        case .askingProblem:
            focusedField = .problem
        case .askingClarification:
            focusedField = .clarification
            announce(assistant.visibleMessage)
        case .classifying:
            focusedField = nil
            announce("Разбираюсь в ситуации")
        case .routing:
            focusedField = nil
            announce(assistant.visibleMessage)
        case .failed:
            focusedField = nil
            announce(assistant.visibleMessage)
        }
    }

    private func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
