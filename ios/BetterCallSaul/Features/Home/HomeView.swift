import SwiftUI

struct HomeView: View {
    let router: AppRouter
    @Bindable var workflow: CaseWorkflowStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    @State private var isSaulAssistantPresented = false
    @State private var assistant: SaulAssistantViewModel
    @State private var routingTask: Task<Void, Never>?

    init(
        router: AppRouter,
        workflow: CaseWorkflowStore,
        problemClassifier: any ProblemClassifying
    ) {
        self.router = router
        self.workflow = workflow
        _assistant = State(
            initialValue: SaulAssistantViewModel(classifier: problemClassifier)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                brandHeader
                    .padding(.bottom, 16)

                Text("Добрый вечер, Алим")
                    .font(.bcsBody(17))
                    .foregroundStyle(BCSColor.secondary)

                BCSEditorialTitle(text: "Что случилось?")
                    .padding(.top, 8)

                Text("Опишите ситуацию — остальное соберём сами.")
                    .font(.bcsBody())
                    .foregroundStyle(BCSColor.secondary)
                    .padding(.top, 10)

                BCSPrimaryButton("Создать обращение", systemImage: "square.and.pencil") {
                    beginCase(.subscription)
                }
                .accessibilityIdentifier("createCaseButton")
                .padding(.top, 20)

                caseTypes
                    .padding(.top, 16)

                activeCase
                    .padding(.top, 12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 96)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : BCSMotion.entryOffset(reduceMotion: reduceMotion))
        }
        .background(BCSColor.canvas)
        .onAppear {
            withAnimation(BCSMotion.spring(reduceMotion: reduceMotion)) {
                isVisible = true
            }
        }
        .onDisappear {
            routingTask?.cancel()
        }
        .sheet(isPresented: $isSaulAssistantPresented, onDismiss: cancelSaulWork) {
            SaulAssistantSheet(assistant: assistant) {
                closeSaulAssistant()
            }
        }
        .onChange(of: assistant.state) { _, state in
            guard case .routing(let type) = state else { return }
            scheduleRouting(to: type)
        }
    }

    private var brandHeader: some View {
        HStack(alignment: .top) {
            HStack(spacing: 14) {
                Text("Better\nCall\nSaul")
                    .font(.bcsEditorial(24))
                    .lineSpacing(-5)
                Rectangle()
                    .fill(BCSColor.yellow)
                    .frame(width: 2, height: 58)
                Text("Всё по закону.")
                    .font(.bcsBody(14))
                    .foregroundStyle(BCSColor.secondary)
            }
            Spacer()
            Button {
                routingTask?.cancel()
                assistant.reset()
                isSaulAssistantPresented = true
            } label: {
                SaulMascotView(
                    state: .idle,
                    size: 96,
                    isDecorative: false
                )
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Сол, помощник")
            .accessibilityHint("Открывает помощника по выбору обращения")
            .accessibilityIdentifier("saulMascotButton")
        }
    }

    private var caseTypes: some View {
        VStack(spacing: 0) {
            BCSDivider()
            ForEach(CaseType.allCases) { type in
                Button {
                    beginCase(type)
                } label: {
                    HStack(spacing: 15) {
                        Image(systemName: type.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 34, height: 34)
                            .overlay(Circle().stroke(BCSColor.divider, lineWidth: 1))
                        Text(type.rawValue)
                            .font(.bcsBody(17))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(BCSColor.secondary)
                    }
                    .frame(minHeight: 44)
                    .foregroundStyle(BCSColor.ink)
                }
                .accessibilityIdentifier("caseType.\(type.routingIdentifier)")
                BCSDivider()
            }
        }
    }

    private var activeCase: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("АКТИВНОЕ ОБРАЩЕНИЕ")
                .font(.system(size: 11, weight: .medium))
                .tracking(1)
                .foregroundStyle(BCSColor.secondary)

            HStack(spacing: 8) {
                Rectangle()
                    .fill(BCSColor.yellow)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(workflow.currentCase.title)
                        .font(.bcsEditorial(20))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(workflow.currentCase.number)
                        .font(.bcsMeta(10))
                        .foregroundStyle(BCSColor.secondary)
                }
                .layoutPriority(1)
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    BCSStatusBadge(title: workflow.currentCase.status.rawValue, isActive: true)
                    Text(activeCaseDeadline)
                        .font(.bcsBody(13))
                        .foregroundStyle(BCSColor.secondary)
                }
            }
            .frame(minHeight: 62)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("activeCaseCard")

            Text("S’all good")
                .font(.system(size: 12, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(BCSColor.secondary.opacity(0.6))
                .frame(maxWidth: .infinity)
        }
    }

    private func beginCase(_ type: CaseType) {
        closeSaulAssistant()
        workflow.start(type: type)
        router.open(.evidence)
    }

    private func closeSaulAssistant() {
        cancelSaulWork()
        isSaulAssistantPresented = false
    }

    private func cancelSaulWork() {
        routingTask?.cancel()
        routingTask = nil
        assistant.reset()
    }

    private func scheduleRouting(to type: CaseType) {
        routingTask?.cancel()
        let narrative = assistant.composedNarrative
        routingTask = Task { @MainActor in
            if !reduceMotion {
                try? await Task.sleep(for: .milliseconds(650))
            }
            guard !Task.isCancelled,
                  isSaulAssistantPresented,
                  assistant.state == .routing(type) else {
                return
            }

            workflow.start(type: type)
            workflow.updateNarrative(narrative)
            isSaulAssistantPresented = false
            router.open(.evidence)
            routingTask = nil
        }
    }

    private var activeCaseDeadline: String {
        guard let deadline = workflow.currentCase.responseDeadline else {
            return "Черновик"
        }
        return "до \(deadline.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "ru_RU"))))"
    }
}
