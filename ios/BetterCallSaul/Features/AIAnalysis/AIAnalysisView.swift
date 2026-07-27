import SwiftUI

struct AIAnalysisView: View {
    let router: AppRouter
    @Bindable var workflow: CaseWorkflowStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasStarted = false
    @State private var isPreparingDocument = false
    @State private var isVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar

                BCSEditorialTitle(text: "Разберём ситуацию", size: 42)
                    .padding(.top, 12)
                Text("Сначала сверим факты, затем подготовим обращение.")
                    .font(.bcsBody(16))
                    .foregroundStyle(BCSColor.secondary)
                    .padding(.top, 10)

                if isAnalyzing {
                    progressPanel
                        .padding(.top, 12)
                } else {
                    analysisContent
                        .padding(.top, 12)
                }

                BCSPrimaryButton(
                    isPreparingDocument ? "Готовим документ…" : "Подготовить документ",
                    systemImage: "doc.text"
                ) {
                    prepareDocument()
                }
                .disabled(isAnalyzing || isPreparingDocument || workflow.caseAnalysis == nil)
                .opacity(isAnalyzing || workflow.caseAnalysis == nil ? 0.45 : 1)
                .accessibilityIdentifier("prepareAIDocumentButton")
                .padding(.top, 18)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 112)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : BCSMotion.entryOffset(reduceMotion: reduceMotion))
        }
        .background(BCSColor.canvas.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            await workflow.runAIAnalysis()
        }
        .onAppear {
            withAnimation(BCSMotion.spring(reduceMotion: reduceMotion)) {
                isVisible = true
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Label("Доказательства", systemImage: "chevron.left")
                    .font(.bcsBody(15))
            }
            Spacer()
            Text("3 из 5")
                .font(.bcsMeta())
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(index < 3 ? BCSColor.yellow : BCSColor.divider)
                        .frame(width: 18, height: 4)
                }
            }
        }
        .foregroundStyle(BCSColor.ink)
        .frame(minHeight: 44)
    }

    private var progressPanel: some View {
        HStack(spacing: 14) {
            SaulMascotView(state: .thinking, size: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text(progressTitle)
                    .font(.bcsBody(16, weight: .medium))
                Text("Обычно это занимает несколько секунд.")
                    .font(.bcsBody(13))
                    .foregroundStyle(BCSColor.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(BCSColor.paleYellow)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(BCSColor.divider))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("aiAnalysisProgress")
    }

    private var analysisContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let analysis = workflow.caseAnalysis {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ЧТО ДЕЛАТЬ")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(BCSColor.secondary)
                    Text(analysis.summary)
                        .font(.bcsEditorial(23))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(analysis.recommendedAction)
                        .font(.bcsBody(15))
                        .foregroundStyle(BCSColor.secondary)
                        .lineSpacing(3)
                }
                .padding(16)
                .background(BCSColor.surface)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(BCSColor.divider))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                reviewedFacts

                ForEach(analysis.warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark")
                        .font(.bcsBody(13))
                        .foregroundStyle(BCSColor.ink)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BCSColor.paleYellow)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if !analysis.questions.isEmpty {
                    Text("Уточните детали")
                        .font(.bcsEditorial(26))
                        .padding(.top, 4)
                    ForEach(Array(analysis.questions.prefix(5))) { question in
                        AIQuestionControl(question: question, answer: answerBinding(for: question))
                    }
                }
            }
        }
    }

    private var reviewedFacts: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ПРОВЕРЕННЫЕ ФАКТЫ")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(BCSColor.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

            ForEach(workflow.currentCase.extractedFields) { field in
                HStack(alignment: .firstTextBaseline) {
                    Text(field.label)
                        .foregroundStyle(BCSColor.secondary)
                    Spacer()
                    Text(field.value.isEmpty ? "Не указано" : field.value)
                        .multilineTextAlignment(.trailing)
                }
                .font(.bcsBody(14))
                .padding(.horizontal, 14)
                .frame(minHeight: 38)
                BCSDivider().padding(.horizontal, 14)
            }
        }
        .background(BCSColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(BCSColor.divider))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func answerBinding(for question: AIQuestion) -> Binding<String> {
        Binding(
            get: { workflow.answers[question.id] ?? "" },
            set: { workflow.setAnswer(questionID: question.id, value: $0) }
        )
    }

    private func prepareDocument() {
        guard !isPreparingDocument else { return }
        isPreparingDocument = true
        Task {
            await workflow.generateAIDocument()
            isPreparingDocument = false
            router.open(.signature)
        }
    }

    private var isAnalyzing: Bool {
        workflow.aiState == .idle
            || workflow.aiState == .analyzingEvidence
            || workflow.aiState == .analyzingText
    }

    private var progressTitle: String {
        workflow.aiState == .analyzingEvidence
            ? "Проверяем документ"
            : "Разбираем ситуацию"
    }
}
