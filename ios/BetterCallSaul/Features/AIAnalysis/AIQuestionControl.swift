import SwiftUI

struct AIQuestionControl: View {
    let question: AIQuestion
    @Binding var answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(question.prompt)
                    .font(.bcsBody(16, weight: .medium))
                    .foregroundStyle(BCSColor.ink)
                if question.required {
                    Text("НУЖНО")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.7)
                        .foregroundStyle(BCSColor.greenText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(BCSColor.paleGreen)
                        .clipShape(Capsule())
                }
            }

            Text(question.whyNeeded)
                .font(.bcsBody(13))
                .foregroundStyle(BCSColor.secondary)

            control
        }
        .padding(14)
        .background(BCSColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(BCSColor.divider))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var control: some View {
        switch question.kind {
        case .choice:
            Picker("Ответ", selection: $answer) {
                Text("Выберите ответ").tag("")
                ForEach(question.options, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(BCSColor.ink)
        case .boolean:
            Picker("Ответ", selection: $answer) {
                ForEach(booleanOptions, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
        case .text, .date, .amount:
            TextField(placeholder, text: $answer)
                .font(.bcsBody(16))
                .textInputAutocapitalization(question.kind == .text ? .sentences : .never)
                .keyboardType(question.kind == .amount ? .decimalPad : .default)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(BCSColor.canvas)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(BCSColor.divider))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var booleanOptions: [String] {
        question.options.isEmpty ? ["Да", "Нет"] : question.options
    }

    private var placeholder: String {
        switch question.kind {
        case .date: "Например, 17 июля 2026"
        case .amount: "Сумма"
        default: "Ваш ответ"
        }
    }
}
